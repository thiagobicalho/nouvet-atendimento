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
status: resolved
resolution: `n8n/migrations/0005_debounce_lock_ttl.sql` adiciona `lock_adquirido_em` a `n8n_status_atendimento` e a função atômica `lock_conversa_adquirir` que a usa para recuperar o lock travado além do TTL.

### DW-3: n8n_fila_mensagens não tem coluna de status/processado nem índice único em id_mensagem para deduplicação.
origin: spec-deferred 61f85afed68c
location: n8n/migrations/0002_schema_operacional.sql (tabela n8n_fila_mensagens)
source_spec: `1-infra-e-persistencia-base.md`
severity: low
reason: O mecanismo de debounce/dedup é lógica de workflow da Story 3, não desta story; o schema atual só cria a fila crua.
status: resolved
resolution: `n8n/migrations/0005_debounce_lock_ttl.sql` adiciona a coluna `processada` e um índice único em `id_mensagem` (usado pelo workflow de ingestão via `ON CONFLICT (id_mensagem) DO NOTHING`, fora do escopo desta migration). Este resolved cobre só o pré-requisito de schema: o `INSERT ... ON CONFLICT (id_mensagem) DO NOTHING` real e a marcação de `processada` em runtime ainda não existem em nenhum workflow -- ficam para a Story 5 (ingestão) implementar sobre este schema.

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

### DW-18: lock_conversa_liberar não usa fencing token — uma execução genuinamente lenta (não travada por crash) que ultrapassa o TTL pode liberar o lock que uma outra execução já recuperou legitimamente, reabri
origin: spec-deferred a4fdda71fe4b
location: n8n/migrations/0005_debounce_lock_ttl.sql (lock_conversa_liberar)
source_spec: `3-debounce-e-lock-com-recuperacao-de-ttl.md`
severity: medium
reason: AD-5 (ARCHITECTURE-SPINE.md) descreve o "mecanismo mínimo obrigatório" sem mencionar fencing/token de posse, aceitando esse risco residual explicitamente ("um Error Trigger... é bem-vindo mas não substitui a checagem de TTL"); achado do review adversarial (blind hunter), não introduzido além do que a própria arquitetura já assume como risco conhecido.
status: open

### DW-19: lock_conversa_adquirir não valida p_ttl_minutos NULL/zero/negativo -- NULL faz a função nunca recuperar o lock (falha fechada), zero ou negativo faz todo lock parecer sempre expirado (derruba a exclus
origin: spec-deferred f57c3a55e208
location: n8n/migrations/0005_debounce_lock_ttl.sql (lock_conversa_adquirir); DW-11
source_spec: `3-debounce-e-lock-com-recuperacao-de-ttl.md`
severity: low
reason: Mesma lacuna já registrada em DW-11 (secretaria_config.lock_ttl_minutos sem CHECK de faixa), agora com consumidor real e concreto pela primeira vez; achado do review adversarial (edge-case hunter).
status: open

### DW-20: lock_conversa_adquirir/lock_conversa_liberar não fixam SET search_path.
origin: spec-deferred ba9d892a4ac8
location: n8n/migrations/0005_debounce_lock_ttl.sql
source_spec: `3-debounce-e-lock-com-recuperacao-de-ttl.md`
severity: low
reason: Mesma lacuna de hardening já registrada em DW-14 para secretaria_config_ler, agora duplicada nas duas novas funções; achado do review adversarial (blind hunter).
status: open

### DW-21: Migration 0005 usa ALTER TABLE/CREATE UNIQUE INDEX sem guards de idempotência (IF NOT EXISTS) -- falha se reaplicada contra um cluster já migrado.
origin: spec-deferred b3d2524a6a36
location: n8n/migrations/0005_debounce_lock_ttl.sql
source_spec: `3-debounce-e-lock-com-recuperacao-de-ttl.md`
severity: low
reason: Mesma classe de problema já registrada em DW-1 para o bootstrap 0001; achado do review adversarial (blind hunter).
status: open

### DW-22: CREATE UNIQUE INDEX em n8n_fila_mensagens(id_mensagem) falharia se já existirem linhas com id_mensagem duplicado (ex. dado de dev/teste remanescente).
origin: spec-deferred bc7d5a2d61cb
location: n8n/migrations/0005_debounce_lock_ttl.sql
source_spec: `3-debounce-e-lock-com-recuperacao-de-ttl.md`
severity: low
reason: Baixo risco prático hoje -- nenhum workflow ainda escreve em n8n_fila_mensagens (Story 5 pendente), então a tabela está vazia em qualquer ambiente atual; achado do review adversarial (edge-case hunter).
status: open

### DW-23: O uso real do dedup de enfileiramento (INSERT ... ON CONFLICT (id_mensagem) DO NOTHING) e da marcação de processada continuam pendentes -- esta story só entrega o pré-requisito de schema, não o workfl
origin: spec-deferred 6853420b5aee
location: n8n/migrations/0005_debounce_lock_ttl.sql; Story 5
source_spec: `3-debounce-e-lock-com-recuperacao-de-ttl.md`
severity: low
reason: DW-3 foi marcado resolved (instrução explícita do invocador), mas seu texto original nomeava o mecanismo de dedup em uso real, não só o schema; achado do review adversarial (intent-alignment). Consumo real fica para a Story 5 (CAP-1, "01 - Agente.json").
status: open

### DW-24: app_role mantém os GRANTs diretos de UPDATE/INSERT em n8n_status_atendimento (herdados da 0002) sem revogação -- qualquer node do fluxo de ingestão pode contornar lock_conversa_adquirir/lock_conversa_
origin: spec-deferred 56697306b9ac
location: n8n/migrations/0002_schema_operacional.sql (GRANT de app_role em n8n_status_atendimento); n8n/migrations/0005_debounce_lock_ttl.sql
source_spec: `3-debounce-e-lock-com-recuperacao-de-ttl.md`
severity: medium
reason: Mesma classe de gap já registrada em DW-12/DW-16 para secretaria_config, mas nunca rastreada para a tabela de lock -- aqui é mais consequente, pois é exatamente a garantia de atomicidade que esta story entrega; achado do review adversarial (blind hunter).
status: open

### DW-25: Migration 0005 não usa BEGIN/COMMIT explícito -- se o CREATE UNIQUE INDEX falhar (ex. dado duplicado pré-existente, DW-22), os ALTER TABLE/backfill anteriores já teriam sido commitados, deixando o sch
origin: spec-deferred 2291bbf39fb9
location: n8n/migrations/0005_debounce_lock_ttl.sql
source_spec: `3-debounce-e-lock-com-recuperacao-de-ttl.md`
severity: low
reason: Mesma classe de risco de migration não-atômica já aceita nas migrations anteriores (0001-0004, nenhuma delas usa BEGIN/COMMIT explícito tampouco); achado do review adversarial (blind hunter), não introduzido além do padrão já existente no diretório.
status: open

### DW-26: secretaria_config_ler (0004) não expõe lock_ttl_minutos em nenhuma das fases ('triagem'/'setor') -- não existe porta única (AD-1) pela qual quem for chamar lock_conversa_adquirir (Story 5) obtenha o T
origin: spec-deferred d4e7c38100f3
location: n8n/migrations/0004_config_leitura_seletiva.sql (secretaria_config_ler); Story 5
source_spec: `3-debounce-e-lock-com-recuperacao-de-ttl.md`
severity: medium
reason: O intent desta story exige "TTL vem de secretaria_config.lock_ttl_minutos (nunca hardcoded)", mas secretaria_config_ler só devolve as fatias 'triagem'/'setor' do JSON, nenhuma incluindo lock_ttl_minutos -- confirmado lendo 0004_config_leitura_seletiva.sql; achado do review adversarial (blind hunter), fora do escopo desta story (Code Map/Tasks não tocam a 0004).
status: open

### DW-27: .claude/skills/n8n-agent-patterns/references/agente-e-subfluxos.md ainda descreve o lock da ingestão de forma genérica (SELECT+UPDATE separados), sem citar as novas funções atômicas lock_conversa_adqu
origin: spec-deferred 242ead87a3b6
location: .claude/skills/n8n-agent-patterns/references/agente-e-subfluxos.md
source_spec: `3-debounce-e-lock-com-recuperacao-de-ttl.md`
severity: low
reason: O doc de referência do padrão de ingestão não foi atualizado por esta story -- o Code Map só cita a diferença a não replicar, não pede atualização do doc; achado do review adversarial (blind hunter).
status: open

### DW-28: .claude/skills/n8n-agent-patterns/references/config-postgres.md ainda mostra o schema anterior à 0005 (sem lock_adquirido_em/processada).
origin: spec-deferred 0d74dea69675
location: .claude/skills/n8n-agent-patterns/references/config-postgres.md
source_spec: `3-debounce-e-lock-com-recuperacao-de-ttl.md`
severity: low
reason: Doc de referência de schema ficou desatualizado após a 0005; achado do review adversarial (blind hunter).
status: open

### DW-29: Migration 0005 não documenta um caminho de rollback/down-migration (duas ALTER TABLE + backfill + índice único + duas funções).
origin: spec-deferred c336b219bc21
location: n8n/migrations/0005_debounce_lock_ttl.sql
source_spec: `3-debounce-e-lock-com-recuperacao-de-ttl.md`
severity: low
reason: Nenhuma das migrations 0001-0004 documenta rollback tampouco, mas a 0005 é a primeira com múltiplos passos interdependentes (ALTER + backfill + índice + funções), tornando um rollback manual mais arriscado que nas anteriores; achado do review adversarial (blind hunter).
status: open

### DW-30: Follow-up review still recommended for 3 after the damping cap was spent
origin: review-budget-followup
location: n/a
source_spec: `3-debounce-e-lock-com-recuperacao-de-ttl.md`
severity: low
reason: The follow-up-review damping cap (limits.max_followup_reviews = 1) was spent with the story finalized (status: done, verify green) while the review pass still recommended an independent follow-up. The work was committed by bmad-loop run 20260902-140919-5139; this entry preserves the lingering recommendation for a deliberate later review.
status: open
