# n8n/seed

Dados iniciais de `atendimento_config` — tom, dados institucionais, catálogo de serviços,
lista interina de sinais de alerta clínico, limiares de SLA/follow-up, contatos de
plantonista/emergência (AD-1, Config-as-Data).

`atendimento_profissionais` ainda não tem seed — Thiago não passou a lista real de
profissionais por setor (DW-42, `deferred-work.md`). Não bloqueia o build (a leitura
seletiva já devolve `[]` corretamente sem dado), bloqueia só o go-live: sem isso o
agente não consegue responder "quais profissionais vocês têm?" com informação real.

Este seed é o **ponto de partida** para popular a tabela na primeira subida do banco de
cada ambiente (dev, depois produção) — não é a fonte viva depois disso. Durante o Piloto,
edição de conteúdo em produção é feita só pela equipe Btech via acesso direto ao banco
(Consistency Conventions da spine), não reaplicando este seed.

## Aplicação (manual, não automática)

Diferente de `n8n/migrations` (montado em `docker-entrypoint-initdb.d`, roda sozinho na
primeira subida do volume — ver `docker-compose.yml`), `n8n/seed` **não** é montado no
container nem roda automaticamente. Depois de subir a stack e aplicar as migrations
0001-0009, aplicar o seed manualmente, conectado ao banco da aplicação
(`$POSTGRES_APP_DB`, default `nouvet_app`):

```sh
psql -h <host> -U <superusuário ou app_role> -d "${POSTGRES_APP_DB:-nouvet_app}" -f n8n/seed/0001_atendimento_config.sql
```

Idempotente (`ON CONFLICT (id) DO NOTHING`) — reaplicar não duplica nem sobrescreve a
linha singleton (`id=1`).

## Import inicial do SimplesVet (identidade cliente/pet)

`identidade_cliente_pet` (AD-6) tem um segundo processo de carga inicial, distinto do
seed de `atendimento_config` acima: o import único do cadastro existente no SimplesVet.
**Arquivo real ainda não fornecido pela Btech neste momento** — o que existe aqui é só
o processo documentado e reaplicável, para ser exercido assim que o export chegar.

Passo a passo:

1. Exportar o cadastro do SimplesVet para um arquivo tabular (CSV/planilha) com, no
   mínimo, telefone, nome do cliente, nome do pet, espécie e raça — os mesmos campos
   já pedidos hoje pelo cadastro SimplesVet (ver Structural Seed da spine).
2. Carregar esse arquivo numa tabela de staging temporária (`COPY`/`\copy` para uma
   tabela criada ad-hoc no momento do import, fora deste diretório de migrations
   versionadas — staging não é schema permanente).
3. Para cada linha de staging, chamar `identidade_cliente_pet_resolver(telefone,
   nome_cliente, nome_pet, especie_pet, raca_pet, 'import_simplesvet', NULL)`
   (`n8n/migrations/0006_identidade_porta_unica.sql`) — **nunca** `INSERT` direto na
   tabela, mesma regra de porta única (AD-6/AD-11) que vale para qualquer outro ponto
   do sistema. `origem='import_simplesvet'` marca a linha como vinda deste processo
   (distingue de `'cadastro_direto'`, feito pelo sub-workflow n8n em tempo real). Uma
   linha de staging cujo `resolver` devolve `NULL` (telefone não-normalizável ou
   nome_cliente/nome_pet vazio, entrada inválida do próprio export) ou cujo retorno traz
   `'possivel_duplicidade_familiar': true` nunca deve ser silenciosamente ignorada —
   registrar (log/planilha à parte) e revisar manualmente essas linhas depois do import.
4. O `resolver` já absorve, de graça, os casos de borda do import: telefones/pets
   duplicados no export do SimplesVet não criam linhas repetidas (dedup por
   `(telefone, lower(btrim(nome_pet)))`, DW-10), e `rd_crm_contact_id` fica `NULL`
   nesta carga (o vínculo com o card do RD CRM é resolvido depois, por story futura
   que consome esta porta única — FR-21). Cada chamada do `resolver` é idempotente
   por si só (DW-31..DW-35), então uma falha no meio do import é segura de retomar —
   basta reprocessar as linhas de staging que ainda não foram confirmadas, sem
   necessidade de transação única cobrindo o import inteiro.
5. Descartar a tabela de staging ao final do import — ela não é reaplicada, só o
   `identidade_cliente_pet_resolver` fica como contrato permanente e reutilizável
   para qualquer carga futura (reimport, correção pontual).

Atenção ao export de telefone: `telefone_normalizar` sempre insere o 9º dígito em
número local de 10 dígitos, sem distinguir celular antigo de telefone fixo — se o
export do SimplesVet um dia incluir telefone fixo de contato (hoje o único canal é
WhatsApp, celular), o import pode normalizar um fixo para um número que colide com um
celular real não relacionado (risco já registrado no ledger de deferred work desta
story).

Só a equipe Btech executa este import, com acesso direto ao banco (mesma convenção de
edição manual de `atendimento_config`, ver spine).

**Pendência aberta (DW-43):** `identidade_cliente_pet_resolver` (`0006`) ainda só
recebe `(telefone, nome_cliente, nome_pet, especie_pet, raca_pet, origem,
rd_crm_contact_id)` — os campos novos da `0009` (CPF, RG, endereço, dados do animal)
não têm caminho de escrita ainda. Não bloqueia hoje (o import real também está
pendente), mas a função precisa ser estendida antes deste runbook ser exercido de
verdade.
