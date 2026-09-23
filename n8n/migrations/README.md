# n8n/migrations

Migrations SQL versionadas e numeradas (`0001_<descricao>.sql`, `0002_<descricao>.sql`, ...)
do schema do **banco dedicado da aplicação** (AD-3): `atendimento_config`,
`atendimento_profissionais`, `n8n_historico_mensagens`, `n8n_fila_mensagens`,
`n8n_status_atendimento`, `identidade_cliente_pet` (AD-6/AD-11).

Não cobre o *schema* do banco interno do n8n (workflows/execuções/credenciais) — esse é
gerenciado pelo próprio n8n. A criação do banco/papel em si (`nouvet_n8n`/`n8n_role`) é
feita pela `0001` (bootstrap), já que o n8n não provisiona seu próprio banco.

Aplicar sempre em ordem, mesmo processo em dev e produção. Reflete a direção provável de
corte dev→produção já registrada na spine: export/import nativo de workflows+credenciais
do n8n + migrations versionadas do schema — não dump/restore bruto do Postgres (processo
exato do corte segue Deferred).

A partir da `0004`, o diretório passa a incluir também função/`GRANT` armazenados (não só
DDL de tabela) — a porta única de leitura seletiva de config (AD-1), hoje chamada
`atendimento_config_ler` (renomeada na `0007`, ver abaixo).

A `0005` introduz `lock_conversa_adquirir`/`lock_conversa_liberar` — as funções atômicas
de debounce/lock com recuperação de TTL (AD-5) — mais as colunas `lock_adquirido_em`
(`n8n_status_atendimento`) e `processada` + índice único em `id_mensagem`
(`n8n_fila_mensagens`).

A `0006` entrega a porta única idempotente de identidade cliente/pet (AD-6/AD-11):
`telefone_normalizar` (normalização centralizada de telefone, AD-8, concedida tanto a
`app_role` quanto a `identidade_role`), `identidade_cliente_pet_buscar`/
`identidade_cliente_pet_resolver` (leitura e escrita únicas de `identidade_cliente_pet`,
com lock consultivo por telefone normalizado — só `identidade_role`), troca do índice
único de `identidade_cliente_pet` para case-insensitive `(telefone, lower(btrim(nome_pet)))`
e índice em `rd_crm_contact_id`. `identidade_cliente_pet_resolver` também devolve
`possivel_duplicidade_familiar` — sinal booleano de que outro telefone já tem pet com o
mesmo nome (núcleo familiar com dois telefones), pro sub-workflow futuro decidir alerta
de revisão humana no card do RD CRM (AD-11).

A `0007` renomeia `secretaria_config` → `atendimento_config`, `secretaria_profissionais`
→ `atendimento_profissionais` e `secretaria_config_ler` → `atendimento_config_ler`
(achado de correct-course, `sprint-change-proposal-2026-09-02.md`: os nomes originais
reaproveitavam o prefixo do template de referência `secretariav3-completo` sem decisão
do Thiago). Tabelas `n8n_*` e `identidade_cliente_pet` não mudam de nome.

A `0008` redesenha `atendimento_profissionais` (schema criado vazio na `0002`, nunca
conectado a nenhuma leitura até aqui): uma linha por profissional, `setores TEXT[]`
(quem atende mais de um setor, ex. clínico geral em Consultas e Vacinas) em vez de
`setor` singular, `UNIQUE (nome)`. Conecta a tabela em `atendimento_config_ler`: campo
`profissionais` novo, só na fatia `setor`, filtrado por `p_setor = ANY(setores) AND
ativo = true` — nunca aparece na fatia `triagem`, nunca mostra profissional de outro
setor. Seed ainda pendente de dado real (DW-42).

A `0009` substitui o schema chutado de `identidade_cliente_pet` (4 colunas de negócio
da Story 1) por campos reais do cadastro do Nouvet, com base em
`_bmad-output/reference/clientes.csv` (export real do SimplesVet) e print de tela do
cadastro: responsável (CPF, RG, data de nascimento, email), endereço completo, e
animal (pelagem, esterilização, pedigree, microchip, vivo/morto, data de nascimento,
referência ao código do animal no SimplesVet). Deliberadamente NÃO importa colunas
comerciais/analíticas do SimplesVet (NPS, ranking ABC, valores pagos) — isso é papel
do funil no RD CRM (AD-6), não da identidade operacional rápida.

A `0010` fecha DW-26: estende `atendimento_config_ler` para expor `lock_ttl_minutos`
nas duas fatias (`triagem`/`setor`) — mesma classe de campo operacional que
`sla_resposta_minutos`, já presente nas duas; nenhuma coluna nova em
`atendimento_config` (o campo já existe desde a `0002`). Consumida por
`n8n/workflows/01 - Agente.json` (Story 5/CAP-1) para passar o TTL a
`lock_conversa_adquirir` sem hardcode.

A `0011` entrega o pré-requisito de schema do Registro e Memória no CRM (CAP-7/Story
11, AD-11): `identidade_cliente_pet` ganha `simplesvet_status` (`'pendente'` ou
`'cadastrado'`), derivado de `origem` só no momento do `INSERT` (`'cadastrado'` para
`origem='import_simplesvet'`, `'pendente'` para `'cadastro_direto'`) e nunca alterado
por uma chamada seguinte do `identidade_cliente_pet_resolver` — mesmo padrão já usado
para a própria coluna `origem` desde a `0006`. `identidade_cliente_pet_resolver` é
reestendido via `CREATE OR REPLACE FUNCTION` (mesmo padrão da `0010`) para calcular e
gravar essa coluna no `INSERT`, incluí-la no `RETURNING`/JSON de saída, e nunca no
`SET` do `UPSERT`. É o sinal que `n8n/workflows/04 - Registrar Atendimento CRM.json`
usa para decidir se cria a Task de cadastro pendente no SimplesVet no card do RD CRM.

A `0012` entrega Temporizadores, Continuidade e SLA (CAP-8/Story 12). Remove
`aguardando_followup`/`numero_followup` (`n8n_status_atendimento`) e
`lembretes_horas`/`follow_ups_horas`/`max_followups` (`atendimento_config`) — schema
morto desde a `0002`, nunca seedado/exposto/referenciado por nenhum workflow — e os
substitui por: `estado_espera` (`n8n_status_atendimento`, `'aguardando_cliente'`
default/`'aguardando_atendimento_humano'`) e `numero_ciclo_escalonamento`
(`n8n_status_atendimento`); `destinatarios_gestor_sla` (`atendimento_config`, mesmo
formato de `destinatarios_emergencia`, público distinto); e a função
`atendimento_estado_espera_marcar(p_session_id, p_estado)`, único ponto de escrita de
`estado_espera` — correlaciona por `telefone_normalizar(session_id) =
telefone_normalizar(p_session_id)` (nunca igualdade crua de string), porque
`n8n_status_atendimento.session_id` é sempre o telefone bruto do webhook (mesmo valor
de `lock_conversa_adquirir`/`sessionKey`), enquanto quem chama a função de dentro de
`04 - Registrar Atendimento CRM.json` só tem o telefone já normalizado
(`Info.telefone_normalizado`) — reaproveita `telefone_normalizar` (AD-8) em vez de
tocar `01 - Agente.json` (vedado pelo `Never` da story) para propagar o telefone bruto.
`atendimento_config_ler` é reestendida (mesmo padrão da `0010`) para expor
`destinatarios_gestor_sla` na fatia `triagem`. `sla_resposta_minutos` (já existente
desde a `0002`, seedado, exposto por `atendimento_config_ler` desde a `0010`, sem
consumidor até esta story) passa a ser a única fonte do intervalo de SLA, lida por
`n8n/workflows/05 - Gerenciar Task SLA.json` (porta única de criação/renovação da Task
de SLA no deal, chamada por `04` e pelo cron `06`) e por
`n8n/workflows/06 - Lembretes e Escalonamento SLA.json` (cron `scheduleTrigger`
independente do `Agente Nouvet`, varre sessões `aguardando_cliente` vencidas e Tasks de
SLA `status:open` vencidas, reconferindo ao vivo a resolução antes de disparar
lembrete/escalonamento, AD-1).

A `0014` entrega a base própria de identidade (Story 1.1, `AD-15`/`AD-3`):
`identidade_tutor`, `identidade_telefone` (tabela filha, `UNIQUE (tutor_id, telefone)`
— não array, para permitir duas linhas legítimas quando o mesmo telefone aparece em
mais de um tutor) e `identidade_pet`, carregadas pelo importador standalone do export
SimplesVet (`import/`, fora do n8n). Só cria tabelas novas — nunca `DROP`/`ALTER` em
`identidade_cliente_pet` (`0003`/`0009`), que segue alimentando os workflows do Piloto
ainda `active: true` na instância n8n real (coexistência, não substituição, até decisão
futura explícita de descomissionamento). `GRANT` só a `identidade_role`. Chave de
upsert do importador é o código de origem do SimplesVet (`simplesvet_codigo_pessoa`/
`simplesvet_codigo_animal`), nunca casamento por nome; ambos únicos porém nullable,
para acomodar tutores/pets futuros sem origem SimplesVet (Story 1.7).

A `0015` entrega `atendimento_falha_registro` (Story 1.3, NFR-4/AD-31): tabela
append-only (sem `UPDATE`/`DELETE` concedido) que grava um evento sempre que uma das 3
consultas Postgres da fase de resposta base (`Buscar Config`, `Normalizar telefone`,
`Buscar Identidade`) ou o próprio node `Agente Nouvet` falha em `n8n/workflows/01 -
Agente.json` -- fecha a lacuna de falha silenciosa, junto com `onError:
continueErrorOutput` novo nesses 4 nodes e os 2 nodes novos `Registrar Falha`/`Montar
Mensagem de Falha` (leaf que devolve `output` com mensagem honesta, mesmo contrato de
`$json.output` que `07 - Ingresso e Fila.json` já consome no caminho de sucesso).
`GRANT` só a `app_role` (papel da credencial "Nouvet" usada por `01 - Agente.json`) --
nunca `identidade_role`.

A `0016` entrega a porta única de leitura de identidade por telefone (Story 1.5,
`AD-32`/`AD-3`/`AD-8`): `identidade_tutor_buscar_por_telefone(p_telefone)`, sobre
`identidade_tutor`/`identidade_telefone`/`identidade_pet` (`0014`) -- nunca sobre
`identidade_cliente_pet` (tabela do Piloto, fora de escopo). Devolve `{"status":
"novo"|"reconhecido"|"nao_autorizado", "tutor": {...}|null, "pets": [...]|null}`,
contando `tutor_id` distintos ligados ao telefone normalizado: 0 tutores é `"novo"`, 1 é
`"reconhecido"` (com nome do tutor e pets dele), mais de 1 é `"nao_autorizado"` (`tutor`/
`pets` sempre `null` fora de `"reconhecido"` -- nenhum dado de nenhum dos tutores
ambíguos é exposto). Primeira `SECURITY DEFINER` do diretório -- dona `identidade_role`
(`ALTER FUNCTION ... OWNER TO`), `SET search_path` fixo (`public, pg_catalog`, hardening
contra sequestro de função/tipo via schema malicioso), `REVOKE ... FROM PUBLIC` e
`GRANT EXECUTE` só a `app_role` (nunca `GRANT` direto de `app_role` nas tabelas
`identidade_*`, `AD-3`). Achado registrado por esta migration: `identidade_cliente_pet_buscar`
(`0006`) -- que `n8n/workflows/01 - Agente.json` (`Buscar Identidade`) já chamava com a
credencial "Nouvet"/`app_role` -- nunca teve `GRANT EXECUTE` para `app_role` (só para
`identidade_role`), então esse `SELECT` sempre falhou por permissão contra um Postgres
real; o `onError: continueErrorOutput` da `0015` escondeu a falha ao cair no caminho de
falha honesta em vez de travar. Esta migration substitui a função chamada pelo node --
não conserta a antiga, que fica órfã por coexistência com o Piloto.

A `0017` entrega a preferência estável do pet (Story 1.6, `FR-5a`/`FR-40a`/`UX-DR4`):
coluna `preferencia JSONB` (nullable, sem enum fechado -- a lista do PRD é exemplo, não
schema fixo) em `identidade_pet`. `identidade_tutor_buscar_por_telefone` (`0016`) é
reestendida via `CREATE OR REPLACE FUNCTION` para incluir `preferencia` em cada pet do
array -- nenhum node de `01 - Agente.json` muda, só o formato do dado que já atravessa
`Buscar Identidade`/`Info`. Nova função `identidade_pet_atualizar_preferencia(p_telefone,
p_pet_nome, p_preferencia)` -- segunda `SECURITY DEFINER` do diretório, mesma regra de
autorização de `0016` (só grava com exatamente um tutor resolvido), pet resolvido por
nome case-insensitive dentro desse tutor, e `preferencia` sempre um PATCH (`COALESCE(...,
'{}'::jsonb) || p_preferencia`), nunca um replace -- preserva chaves não mencionadas na
chamada atual. `identidade_pet_atualizar_preferencia` é a primeira porta única de
ESCRITA chamada pelo próprio `Agente Nouvet` como ferramenta (node `Postgres Tool`,
`01 - Agente.json`) -- não por um sub-workflow separado, dado que é uma única query,
mesmo espírito dos nodes Postgres inline já existentes (`Buscar Identidade`/`Buscar
Config`). O importador do SimplesVet (`import/importador/db.py:upsert_pet`, Story 1.1)
já nunca inclui `preferencia` no `SET` do seu `UPSERT` -- achado desta story: a
salvaguarda já existia, escrita de propósito para colunas de domínio próprio futuras,
sem precisar de nenhuma mudança agora (`FR-40a` já estava satisfeito).
