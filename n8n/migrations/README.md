# n8n/migrations

Migrations SQL versionadas e numeradas (`0001_<descricao>.sql`, `0002_<descricao>.sql`, ...)
do schema do **banco dedicado da aplicação** (AD-3): `secretaria_config`,
`secretaria_profissionais`, `n8n_historico_mensagens`, `n8n_fila_mensagens`,
`n8n_status_atendimento`, tabela de identidade cliente/pet (AD-6/AD-11).

Não cobre o *schema* do banco interno do n8n (workflows/execuções/credenciais) — esse é
gerenciado pelo próprio n8n. A criação do banco/papel em si (`nouvet_n8n`/`n8n_role`) é
feita pela `0001` (bootstrap), já que o n8n não provisiona seu próprio banco.

Aplicar sempre em ordem, mesmo processo em dev e produção. Reflete a direção provável de
corte dev→produção já registrada na spine: export/import nativo de workflows+credenciais
do n8n + migrations versionadas do schema — não dump/restore bruto do Postgres (processo
exato do corte segue Deferred).

A partir da `0004`, o diretório passa a incluir também função/`GRANT` armazenados (não só
DDL de tabela) — `secretaria_config_ler`, a porta única de leitura seletiva de
`secretaria_config` (AD-1).

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
