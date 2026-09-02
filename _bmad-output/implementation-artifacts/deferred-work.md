### DW-1: Migrations de bootstrap (0001) não são idempotentes (CREATE DATABASE/CREATE ROLE sem guards de existência).
origin: spec-deferred 5ea989a74307
location: n8n/migrations/0001_bootstrap_bancos_e_papeis.sh
source_spec: `1-infra-e-persistencia-base.md`
severity: medium
reason: docker-entrypoint-initdb.d só roda uma vez em volume vazio, então a AC de "primeira subida" não é afetada, mas um re-run manual contra um cluster já existente (reset de dev, disaster recovery) falha explicitamente em vez de ser reaplicável.
status: open

### DW-2: n8n_status_atendimento não tem coluna de timestamp de aquisição do lock, necessária para calcular expiração por TTL.
origin: spec-deferred 37bd13f456d0
location: n8n/migrations/0002_schema_operacional.sql (tabela n8n_status_atendimento)
source_spec: `1-infra-e-persistencia-base.md`
severity: low
reason: AD-5 (recuperação automática de lock travado por TTL) é escopo da Story 3 ("Debounce e lock com recuperação de TTL"); esta story só cria o schema base. Story 3 provavelmente precisa de uma migration adicional (ex. 0004) adicionando essa coluna.
status: open

### DW-3: n8n_fila_mensagens não tem coluna de status/processado nem índice único em id_mensagem para deduplicação.
origin: spec-deferred 61f85afed68c
location: n8n/migrations/0002_schema_operacional.sql (tabela n8n_fila_mensagens)
source_spec: `1-infra-e-persistencia-base.md`
severity: low
reason: O mecanismo de debounce/dedup é lógica de workflow da Story 3, não desta story; o schema atual só cria a fila crua.
status: open

### DW-4: identidade_cliente_pet.rd_crm_contact_id não tem índice.
origin: spec-deferred f932572f660e
location: n8n/migrations/0003_identidade_cliente_pet.sql
source_spec: `1-infra-e-persistencia-base.md`
severity: low
reason: Esse é o caminho de lookup provável quando a Story 4 (porta única idempotente) ou a Story 11 (registro no CRM) resolverem conversa -> contato do RD CRM; adicionar quando o padrão de acesso real dessas stories estiver implementado.
status: open

### DW-5: n8n exposto em 0.0.0.0:5678 sem proxy reverso/TLS nem N8N_HOST/WEBHOOK_URL/ N8N_SECURE_COOKIE configurados.
origin: spec-deferred fc5b3166ae1b
location: docker-compose.yml (serviço n8n)
source_spec: `1-infra-e-persistencia-base.md`
severity: low
reason: Fora do escopo desta story ("Não inclui provisionamento da VPS em si"), mas é um hardening real necessário antes de expor a stack numa VPS de produção.
status: open

### DW-6: Sem GENERIC_TIMEZONE/TZ no n8n nem locale pt_BR no Postgres.
origin: spec-deferred f3148ad759b8
location: docker-compose.yml (serviço n8n); n8n/migrations/0001_bootstrap_bancos_e_papeis.sh (criação do cluster)
source_spec: `1-infra-e-persistencia-base.md`
severity: low
reason: Afeta corretude de horários de lembrete/follow-up (secretaria_config.lembretes_horas/ follow_ups_horas) e ordenação com acentuação em campos de texto em português; não exigido pelos ACs desta story.
status: open

### DW-7: n8n sobe sem nenhuma flag de telemetria/diagnóstico desativada (N8N_DIAGNOSTICS_ENABLED, N8N_VERSION_NOTIFICATIONS_ENABLED, etc.).
origin: spec-deferred 2e239ca1d350
location: docker-compose.yml (serviço n8n)
source_spec: `1-infra-e-persistencia-base.md`
severity: low
reason: O projeto tem postura de privacidade forte (papel de identidade à parte, chave de criptografia obrigatória), mas a decisão de manter ou desativar telemetria do n8n (relevante para LGPD) nunca foi tomada explicitamente; não exigido pelos ACs desta story.
status: open

### DW-8: Colunas updated_at (DEFAULT CURRENT_TIMESTAMP) não têm nenhum mecanismo (trigger ou convenção de app) que as atualize de fato em UPDATE.
origin: spec-deferred 77e06a8ab18a
location: n8n/migrations/0002_schema_operacional.sql; n8n/migrations/0003_identidade_cliente_pet.sql (todas as tabelas com updated_at)
source_spec: `1-infra-e-persistencia-base.md`
severity: low
reason: DEFAULT só dispara em INSERT; sem trigger ou disciplina de aplicação definida, a coluna tende a ficar com o valor de criação mesmo após updates reais. A lógica de escrita em runtime é de stories futuras, então a decisão (trigger vs. app seta manualmente) fica para quando essa lógica for implementada.
status: open

### DW-9: Não existe runner/mecanismo para aplicar migrations futuras (0004+) contra um cluster já inicializado.
origin: spec-deferred d0143b23f517
location: n8n/migrations/README.md; docker-compose.yml (serviço postgres)
source_spec: `1-infra-e-persistencia-base.md`
severity: low
reason: docker-entrypoint-initdb.d só executa na primeira inicialização de um volume vazio; distinto do DW já registrado sobre idempotência do bootstrap 0001 (re-rodar scripts existentes), este é sobre como migrations novas, criadas por stories futuras, chegam a ser aplicadas depois do primeiro boot — nenhum runner/tabela de controle de versão foi definido.
status: open

### DW-10: UNIQUE (telefone, nome_pet) em identidade_cliente_pet não trata variação de maiúsculas/minúsculas nem dois pets do mesmo cliente com o mesmo nome.
origin: spec-deferred fc4ead48499c
location: n8n/migrations/0003_identidade_cliente_pet.sql (identidade_cliente_pet)
source_spec: `1-infra-e-persistencia-base.md`
severity: low
reason: "Rex" e "rex" não colidem hoje (unique é case-sensitive) e dois pets distintos com o mesmo nome para o mesmo telefone seriam rejeitados na inserção; a chave natural escolhida é adequada para o caso comum, mas o tratamento desses casos de borda fica para quando a porta única de escrita (Story 4) definir a regra de deduplicação real.
status: open

### DW-11: Colunas numéricas de secretaria_config (sla_resposta_minutos, lock_ttl_minutos, max_followups) não têm CHECK de faixa e aceitariam 0 ou negativo.
origin: spec-deferred 020a3d83043f
location: n8n/migrations/0002_schema_operacional.sql (tabela secretaria_config)
source_spec: `1-infra-e-persistencia-base.md`
severity: low
reason: A tabela é editada manualmente (config de personalização, AD-1) e nenhuma AC desta story exige validação de valor, só existência/grants das tabelas; a lógica que lê e usa esses valores em runtime (debounce/lock, follow-up) ainda não existe, então a decisão de faixa válida fica melhor colocada quando essa lógica de leitura for implementada, junto com o resto da validação de secretaria_config.
status: open

### DW-12: Nenhuma barreira de privilégio garante que secretaria_config só é lida via secretaria_config_ler — app_role já tem SELECT direto na tabela (concedido na Story 1), então a "porta única" é uma convenção
origin: spec-deferred 5b4cbe26b4b0
location: n8n/migrations/0002_schema_operacional.sql (GRANT SELECT ... TO app_role); n8n/migrations/0004_config_leitura_seletiva.sql
source_spec: `2-config-as-data.md`
severity: medium
reason: Revogar SELECT direto de app_role e permitir leitura só via função exigiria SECURITY DEFINER ou um esquema de papéis adicional — mudança estrutural maior, fora do escopo desta story; achado do review adversarial (blind hunter).
status: open

### DW-13: Não existe fonte única que fixe os nomes exatos de setor usados como chave de filtro (p_setor) — glossary.md lista 5 setores distintos, mas o PRD §4.4 descreve Consultas e Vacinas como um único agente
origin: spec-deferred 6fddd07a1c28
location: n8n/migrations/0004_config_leitura_seletiva.sql; glossary.md
source_spec: `2-config-as-data.md`
severity: medium
reason: A Story 5/6 precisa decidir se passa p_setor distintos para Consultas e Vacinas ou unifica — comparação por string exata sem lista canônica é risco de resultado vazio silencioso; achado do review adversarial (blind hunter).
status: open

### DW-14: secretaria_config_ler não fixa SET search_path.
origin: spec-deferred 4de0e45a48d7
location: n8n/migrations/0004_config_leitura_seletiva.sql
source_spec: `2-config-as-data.md`
severity: low
reason: Hardening geral de função Postgres; risco baixo aqui porque a função não é SECURITY DEFINER e roda com privilégio do chamador (app_role), mas é uma boa prática ausente; achado do review adversarial (blind hunter).
status: open

### DW-15: secretaria_config_ler não trata explicitamente o caso da linha singleton (id=1) ainda não existir (seed não aplicado) — retorna NULL silenciosamente.
origin: spec-deferred deb99be419e2
location: n8n/migrations/0004_config_leitura_seletiva.sql
source_spec: `2-config-as-data.md`
severity: low
reason: Comportamento coerente com o caso já documentado de fase inválida (NULL, nunca dump), mas sem guard/erro explícito para esse cenário operacional específico; achado do review adversarial (edge-case hunter).
status: open

### DW-16: Nenhuma barreira de privilégio garante que secretaria_config só é acessada via secretaria_config_ler — app_role já tem SELECT, INSERT, UPDATE e DELETE diretos na tabela (concedido na Story 1), então a
origin: spec-deferred bb852ce94033
location: n8n/migrations/0002_schema_operacional.sql (GRANT SELECT, INSERT, UPDATE, DELETE ... TO app_role); n8n/migrations/0004_config_leitura_seletiva.sql
source_spec: `2-config-as-data.md`
severity: medium
reason: Revogar acesso direto de app_role e permitir leitura só via função exigiria SECURITY DEFINER ou um esquema de papéis adicional — mudança estrutural maior, fora do escopo desta story; achado do review adversarial (blind hunter), com a abrangência real do GRANT (SELECT/INSERT/UPDATE/DELETE, não só SELECT) confirmada no follow-up review.
status: open

### DW-17: Não existe fonte única que fixe os nomes exatos de setor usados como chave de filtro (p_setor) — glossary.md lista 8 setores distintos (Care Center, Exames, Consultas, Vacinas, Orçamentos, Internação,
origin: spec-deferred 00082dcc8fc9
location: n8n/migrations/0004_config_leitura_seletiva.sql; glossary.md
source_spec: `2-config-as-data.md`
severity: medium
reason: A Story 5/6 precisa decidir se passa p_setor distintos para Consultas e Vacinas ou unifica — comparação por string exata sem lista canônica é risco de resultado vazio silencioso; achado do review adversarial (blind hunter).
status: open
