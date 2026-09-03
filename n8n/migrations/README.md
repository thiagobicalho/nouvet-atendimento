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
