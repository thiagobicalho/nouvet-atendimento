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
status: resolved
resolution: `n8n/migrations/0006_identidade_porta_unica.sql` adiciona `idx_identidade_cliente_pet_rd_crm_contact_id` (índice parcial, `WHERE rd_crm_contact_id IS NOT NULL`) sobre `identidade_cliente_pet`.

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
status: resolved
resolution: `n8n/migrations/0006_identidade_porta_unica.sql` troca o índice único para `(telefone, lower(btrim(nome_pet)))` (case-insensitive, fecha a metade "Rex"/"rex" da DW-10) e `identidade_cliente_pet_resolver` trata dois pets reais com nome idêntico no mesmo telefone como a mesma identidade (última chamada atualiza espécie/raça) — limitação aceita e documentada explicitamente no design da story, não um bug residual.

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
status: resolved
resolution: correct-course (sprint-change-proposal-2026-09-02.md) — Consultas e Vacinas são 2 setores distintos (`p_setor='Consultas'` / `p_setor='Vacinas'`, nunca fundidos), critério é a intenção declarada pelo cliente na abertura do contato. Lista canônica de `p_setor` em escopo no Piloto = os 5 setores com Agente de Setor/roteamento (Care Center, Exames, Consultas, Vacinas, Orçamentos — glossary.md linhas 9/13); Internação/Oncologia/Financeiro (também listados no glossário como setores do Nouvet) nunca são usados como `p_setor` — fora do escopo do Piloto. Decisão registrada em `stories.yaml` (Story 2 e Story 8).

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
status: resolved
resolution: duplicado de DW-13 (mesmo achado, review passes diferentes) — mesma resolução: correct-course (sprint-change-proposal-2026-09-02.md) fixa Consultas/Vacinas como setores distintos e a lista canônica de 5 `p_setor` em escopo no Piloto.

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
status: resolved
resolution: `n8n/migrations/0010_atendimento_config_ler_lock_ttl.sql` (Story 5) estende `atendimento_config_ler` (renomeada `secretaria_config_ler` -> `atendimento_config_ler` na 0007) para expor `lock_ttl_minutos` nas fatias `triagem` e `setor`; o node de lock de `n8n/workflows/01 - Agente.json` lê o TTL de lá e passa para `lock_conversa_adquirir`, nunca hardcoded.

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

### DW-31: identidade_role mantém GRANT direto de INSERT/UPDATE/DELETE em identidade_cliente_pet (herdado da 0003) sem revogação -- a "porta única" de AD-11 é uma convenção de código, não uma garantia de banco.
origin: spec-deferred 1c79c7929bdb
location: n8n/migrations/0003_identidade_cliente_pet.sql (GRANT SELECT, INSERT, UPDATE, DELETE ... TO identidade_role); n8n/migrations/0006_identidade_porta_unica.sql
source_spec: `4-identidade-cliente-pet-porta-unica-idempotente.md`
severity: medium
reason: Mesma classe de gap já registrada em DW-12/DW-16 (secretaria_config) e DW-24 (n8n_status_atendimento) -- aqui nunca foi rastreada para a tabela de identidade; achado do review adversarial (blind hunter). Revogar exigiria SECURITY DEFINER ou esquema de papéis adicional, mudança estrutural maior, fora do escopo desta story.
status: open

### DW-32: telefone_normalizar sempre insere o 9º dígito em qualquer número local de 10 dígitos, sem distinguir celular antigo de telefone fixo -- um fixo poderia ser normalizado para um número que colide com um
origin: spec-deferred ec08334c320d
location: n8n/migrations/0006_identidade_porta_unica.sql (telefone_normalizar)
source_spec: `4-identidade-cliente-pet-porta-unica-idempotente.md`
severity: medium
reason: Risco baixo hoje porque o único canal é WhatsApp (AD-7, só celular) e nenhum import real do SimplesVet rodou ainda; relevante se a exportação do SimplesVet um dia incluir telefone fixo de contato; achado do review adversarial (edge-case hunter).
status: open

### DW-33: CREATE UNIQUE INDEX case-insensitive em identidade_cliente_pet (0006) não trata dado pré-existente que já colida sob lower(btrim(nome_pet)) -- falharia se "Rex"/"rex" já existirem como linhas separada
origin: spec-deferred de5fefd7cb31
location: n8n/migrations/0006_identidade_porta_unica.sql (DROP CONSTRAINT / CREATE UNIQUE INDEX)
source_spec: `4-identidade-cliente-pet-porta-unica-idempotente.md`
severity: low
reason: Mesma classe de risco já aceita em DW-1/DW-21/DW-22 (migrations sem guard de idempotência/dado pré-existente); baixo risco prático hoje porque nenhum workflow real ainda escreve em identidade_cliente_pet; achado do review adversarial (verification-gap).
status: open

### DW-34: possivel_duplicidade_familiar só enxerga linhas já commitadas -- duas chamadas genuinamente simultâneas do resolver para o mesmo nome de pet vindas de dois telefones reais diferentes podem, sob READ C
origin: spec-deferred 9130fb79bbf9
location: n8n/migrations/0006_identidade_porta_unica.sql (identidade_cliente_pet_resolver, CTE duplicidade)
source_spec: `4-identidade-cliente-pet-porta-unica-idempotente.md`
severity: low
reason: Limite já reconhecido explicitamente em AD-11 na spine ("este segundo caso pode não ser 100% eliminado por normalização de telefone... são números realmente diferentes") -- comportamento aceito por design, documentado aqui como o mecanismo exato da lacuna para referência futura; achado do review adversarial (blind hunter).
status: open

### DW-35: pg_advisory_xact_lock(hashtext(telefone)) usa hash de 32 bits como chave do lock -- colisão de hash entre telefones não relacionados os faria serializar entre si (latência, não incorretude).
origin: spec-deferred a6cc9b517952
location: n8n/migrations/0006_identidade_porta_unica.sql (identidade_cliente_pet_resolver)
source_spec: `4-identidade-cliente-pet-porta-unica-idempotente.md`
severity: low
reason: Risco desprezível na escala do Piloto (uma clínica, poucas conversas simultâneas); achado do review adversarial (blind hunter), documentado para referência caso o volume cresça muito no futuro.
status: open

### DW-36: identidade_cliente_pet_resolver não expõe forma de voltar especie_pet/raca_pet/ rd_crm_contact_id para NULL depois de gravado uma vez -- COALESCE(EXCLUDED.x, tabela.x) preserva sempre o valor já conhe
origin: spec-deferred 7e4b873b4123
location: n8n/migrations/0006_identidade_porta_unica.sql (identidade_cliente_pet_resolver, CTE upsert)
source_spec: `4-identidade-cliente-pet-porta-unica-idempotente.md`
severity: medium
reason: Trade-off direto do patch [medium] já aplicado nesta mesma story (que trocou overwrite incondicional por COALESCE para não perder dado em atualização parcial) -- resolver o oposto (permitir limpar) exigiria um mecanismo explícito de "limpar campo" (sentinela ou parâmetro dedicado), decisão de design fora do escopo de um patch trivial; achado do review adversarial (blind hunter / edge-case hunter).
status: open

### DW-37: pg_advisory_xact_lock(hashtext(telefone)) não tem timeout nem retry -- uma transação presa (ex.: sessão travada, erro de aplicação que nunca comita/aborta) bloquearia indefinidamente qualquer chamada
origin: spec-deferred 15f863aa643d
location: n8n/migrations/0006_identidade_porta_unica.sql (identidade_cliente_pet_resolver, CTE travado)
source_spec: `4-identidade-cliente-pet-porta-unica-idempotente.md`
severity: medium
reason: Primeiro uso de pg_advisory_xact_lock no diretório (0005 usa outro mecanismo de lock, não advisory lock) -- não há precedente estabelecido de padrão de timeout/retry para copiar; decisão de política de timeout é de design, fora do escopo de um patch trivial; achado do review adversarial (edge-case hunter).
status: open

### DW-38: Não existe script de teste versionado no repositório que exercite os 8 cenários da I/O & Edge-Case Matrix contra um motor Postgres real -- a validação via @electric-sql/pglite mencionada no `## Verifi
origin: spec-deferred b5f83601589b
location: n8n/migrations/0006_identidade_porta_unica.sql (identidade_cliente_pet_buscar, identidade_cliente_pet_resolver); ## Verification da story
source_spec: `4-identidade-cliente-pet-porta-unica-idempotente.md`
severity: medium
reason: Achado do review adversarial (verification-gap) -- a única checagem automatizada persistida no repo é o comando estrutural (busca de texto/posição no SQL) e o mirror Python isolado de telefone_normalizar; nenhum dos dois exercita identidade_cliente_pet_buscar/identidade_cliente_pet_resolver contra um banco de verdade. Fora do escopo de um patch trivial (exigiria decidir onde/como versionar um script Node+pglite e sua dependência).
status: open

### DW-39: As 3 novas funções (telefone_normalizar, identidade_cliente_pet_buscar, identidade_cliente_pet_resolver) não fixam SET search_path.
origin: spec-deferred b2375141b1bf
location: n8n/migrations/0006_identidade_porta_unica.sql (telefone_normalizar, identidade_cliente_pet_buscar, identidade_cliente_pet_resolver)
source_spec: `4-identidade-cliente-pet-porta-unica-idempotente.md`
severity: low
reason: Mesma lacuna de hardening já aceita a severidade baixa em DW-14 (secretaria_config_ler, 0004) e DW-20 (lock_conversa_adquirir/lock_conversa_liberar, 0005) -- padrão pré-existente no diretório, não uma regressão desta story; achado do review adversarial (blind hunter).
status: open

### DW-40: 0006 usa ALTER TABLE/DROP CONSTRAINT e CREATE UNIQUE INDEX sem guards de idempotência (IF EXISTS/IF NOT EXISTS) -- falha se reaplicada contra um cluster já migrado.
origin: spec-deferred a7f2a44bb9aa
location: n8n/migrations/0006_identidade_porta_unica.sql (DROP CONSTRAINT / CREATE UNIQUE INDEX)
source_spec: `4-identidade-cliente-pet-porta-unica-idempotente.md`
severity: low
reason: Mesma classe de risco já aceita em DW-21/DW-22 (migration 0005, mesmo padrão) -- já citada como precedente aceito no próprio deferred existente desta story (ver item "CREATE UNIQUE INDEX case-insensitive ... não trata dado pré-existente"); achado do review adversarial (blind hunter).
status: open

### DW-41: A CTE duplicidade compara lower(btrim(nome_pet)) entre telefones diferentes sem índice de apoio (o único índice único tem telefone como coluna líder) -- toda chamada do resolver faz um scan sequencial
origin: spec-deferred b95ceb7ef0eb
location: n8n/migrations/0006_identidade_porta_unica.sql (identidade_cliente_pet_resolver, CTE duplicidade)
source_spec: `4-identidade-cliente-pet-porta-unica-idempotente.md`
severity: low
reason: Risco desprezível na escala do Piloto (uma clínica, poucas linhas na tabela), mesma linha de raciocínio já aceita em DW-35 (colisão de hash do advisory lock); achado do review adversarial (blind hunter).
status: open

### DW-42: atendimento_profissionais criada e conectada em atendimento_config_ler, mas sem dado real -- seed fica vazio/placeholder.
origin: correct-course sprint-change-proposal-2026-09-02.md
location: n8n/seed/ (a criar, seed de atendimento_profissionais); n8n/migrations/0008_atendimento_profissionais.sql
source_spec: n/a (achado de correct-course, não de story)
severity: medium
reason: Thiago ainda não passou a lista real de profissionais por setor (mesmo tratamento já dado à lista interina de sinais de alerta clínico na Story 2) -- não bloqueia o build (a função já devolve `[]` corretamente sem dado), mas bloqueia o agente responder "quais profissionais vocês têm?" com informação real. Bloqueia o go-live de 08/09, não o início da construção.
status: open

### DW-43: identidade_cliente_pet_resolver (0006) não escreve os campos novos de 0009 (CPF, RG, endereço, dados do animal) -- só os 5 parâmetros originais (telefone, nome_cliente, nome_pet, especie_pet, raca_pet).
origin: correct-course sprint-change-proposal-2026-09-02.md
location: n8n/migrations/0006_identidade_porta_unica.sql (identidade_cliente_pet_resolver); n8n/migrations/0009_identidade_cliente_pet_campos_reais.sql
source_spec: n/a (achado de correct-course, não de story)
severity: medium
reason: 0009 adicionou colunas à tabela mas não estendeu a função de escrita única (AD-11) que deveria populá-las -- import real (última ação antes do go-live) ainda está pendente de qualquer forma, mas o resolver precisa ser estendido antes desse runbook ser exercido de verdade, senão os campos novos ficam sempre NULL mesmo com dado real disponível.
status: open

### DW-44: Quando `destinatarios_emergencia` estiver vazio (situação atual em produção), o `systemMessage` ainda instrui a IA a dizer ao cliente que a solicitação "está sendo registrada com prioridade máxima" me
origin: spec-deferred 86932cd9bd63
location: n8n/workflows/01 - Agente.json (seção "SINAIS DE ALERTA E EMERGÊNCIA DECLARADA" e SOP 2.4) + n8n/workflows/02 - Escalar Humano.json (nó "Alerta não configurado")
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: medium
reason: Achado convergente do Blind Hunter e do Intent Alignment Auditor na review desta story. O fallback de lista vazia (`noOp` em `02 - Escalar Humano.json`) já é comportamento aceito e documentado (mesmo tratamento de dado pendente usado para `sinais_alerta_clinico`/`atendimento_profissionais`), mas a combinação com o texto fixo de "prioridade máxima" no SOP cria uma promessa não cumprida ao cliente enquanto `destinatarios_emergencia` seguir `[]`. Revisar antes do go-live, junto com o preenchimento real da lista pelo Nouvet.
status: open

### DW-45: Nenhum nó `httpRequest` do fluxo (nem o já existente "Enviar resposta RD Conversas" da Story 5, nem o novo "Enviar alerta RD Conversas") tem `retryOnFail`/`continueOnFail` configurado.
origin: spec-deferred 465c95bc7729
location: n8n/workflows/01 - Agente.json (nó "Enviar resposta RD Conversas") e n8n/workflows/02 - Escalar Humano.json (nó "Enviar alerta RD Conversas")
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: low
reason: Achado do Blind Hunter e do Edge Case Hunter, confirmado por inspeção direta do JSON (`retryOnFail`/`onError`/`continueOnFail` ausentes nos dois nós). É um padrão pré-existente desde a Story 5, não introduzido por esta story, mas com efeito mais sensível aqui: numa lista com múltiplos destinatários, uma falha de rede num item interrompe o `splitOut` e os destinatários restantes não recebem o alerta.
status: open

### DW-46: O SOP não cobre explicitamente uma mensagem do cliente que misture mais de um setor em escopo na mesma frase (ex. "queria saber de vacina e também um orçamento de banho").
origin: spec-deferred 9e0ed5a71dfc
location: n8n/workflows/01 - Agente.json (SOP Seção 2)
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: low
reason: Achado do Blind Hunter. Não é uma leitura obrigatória do intent desta story (nenhum cenário da I/O & Edge-Case Matrix cobre isso) nem foi mencionado em stories.yaml/SPEC.md — fica como refinamento de UX para uma passada futura sobre o SOP, não bloqueia esta story.
status: open

### DW-47: Não existe guarda contra chamadas repetidas de `Escalar_humano` para a mesma condição em turnos sucessivos da mesma conversa (ex. Sinal de Alerta que persiste por várias mensagens) — cada turno pode r
origin: spec-deferred 14dd0b305f09
location: n8n/workflows/01 - Agente.json (SOP Seção 2.3/2.4)
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: low
reason: Achado do Blind Hunter e do Edge Case Hunter. Fora do escopo desta story (que não introduz nenhum estado de conversa novo) — potencial candidato a CAP-8/ Story 12 (Temporizadores, Continuidade e SLA), que já vai mexer em `n8n_status_atendimento` para marcar "Aguardando Atendimento Humano".
status: open

### DW-48: O regex de checagem de "nenhuma credencial em texto plano" no script de verificação desta story (herdado literalmente da Story 5) não cobre as palavras-chave `token`/`secret` isoladas, só `api[_-]?key
origin: spec-deferred ac0963b4d71e
location: _bmad-output/specs/spec-atendimento-nouvet/stories/5-cap-1-recepcao-e-identificacao.md e 6-cap-2-triagem-e-direcionamento.md (seção Verification)
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: low
reason: Achado do Edge Case Hunter. Convenção pré-existente desde a Story 5, replicada aqui por consistência — não introduzida por esta story. Vale revisar o padrão em todas as stories na próxima oportunidade, não só nesta.
status: open

### DW-49: Nenhum comando de Verification desta story inspeciona a configuração real do `httpRequest` "Enviar alerta RD Conversas" (URL, método, `contentType`, `sent_by=bot`) — só a topologia/roteamento em volta
origin: spec-deferred f64db09da457
location: n8n/workflows/02 - Escalar Humano.json (nó "Enviar alerta RD Conversas")
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: low
reason: Achado do Blind Hunter, confirmado por inspeção direta: os 3 comandos de Verification checam nós/conexões/campos de entrada, nunca os parâmetros do próprio nó `httpRequest`. Mesmo padrão já usado desde a Story 5 (o node "Enviar resposta RD Conversas" também não tem seus parâmetros de request verificados por script) — não introduzido por esta story, só replicado por consistência com o nó novo.
status: open

### DW-50: Não existe nenhum registro persistido (tabela, log estruturado) dos acionamentos de `Escalar_humano` (motivo, horário, destinatário) consultável pelo Nouvet — a única trilha é a mensagem transitória d
origin: spec-deferred d7c073261c8f
location: n8n/workflows/02 - Escalar Humano.json (sem consumidor de log/tabela)
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: medium
reason: Achado do Blind Hunter. Fora do Code Map desta story (que deliberadamente não persiste setor classificado nem introduz coluna nova, ver Boundaries "Never") — potencial candidato a uma story futura de observabilidade/auditoria de handoffs (relacionado a CAP-8/Story 12, que já vai mexer em `n8n_status_atendimento`).
status: resolved
resolution: Story 15 (CAP-11) fecha o gap — `02 - Escalar Humano.json` ganhou o ramo "Motivo Gera Registro no CRM?" que, para exatamente os 3 motivos nomeados (`Sinal de Alerta`, `Fora de escopo`, `Convênio mencionado`), normaliza o telefone e delega a `04 - Registrar Atendimento CRM.json` (reusa 100% da lógica de card/Note já existente). `04` agora grava toda classificação (setor real ou desvio) em `atendimento_registro_setor` (append-only, `n8n/migrations/0013_indicadores_e_esteira.sql`), servida sob demanda por `atendimento_indicadores_ler` — 2026-09-05.

### DW-51: Follow-up review still recommended for 6 after the damping cap was spent
origin: review-budget-followup
location: n/a
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: low
reason: The follow-up-review damping cap (limits.max_followup_reviews = 1) was spent with the story finalized (status: done, verify green) while the review pass still recommended an independent follow-up. The work was committed by bmad-loop run 20260903-084456-f955; this entry preserves the lingering recommendation for a deliberate later review.
status: resolved
resolution: Independent `bmad-review` run manually on 2026-09-03 (adversarial + edge-case-hunter + verification-gap lenses) against the story 6 diff. 3 cheap findings patched directly (prompt clarification on "registrar" = histórico de conversa, tool description reinforcing "continue a conversa" after handoff, new Verification assertions closing the gap on the motivo-literal guard). 7 remaining findings triaged and filed as new deferred items in `6-cap-2-triagem-e-direcionamento.md` (see DW-52 to DW-58 below) rather than acted on immediately — see story's Review Triage Log entry "2026-09-03 — Revisão independente" for full rationale per item.

### DW-52: Nem o `httpRequest` "Enviar alerta RD Conversas" nem o `toolWorkflow` "Escalar Humano" têm `onError`/`retryOnFail` — falha da API Tallos pode propagar como erro do nó `Agente Nouvet`
origin: independent-review-post-DW51
location: n8n/workflows/02 - Escalar Humano.json (nó "Enviar alerta RD Conversas") + n8n/workflows/01 - Agente.json (nó "Escalar Humano")
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: medium
reason: Aprofunda o achado de retry já conhecido (DW-45) com uma consequência mais severa e específica — o cliente pode ficar sem NENHUMA resposta no turno, não só sem o alerta ao humano, já que uma exceção não tratada no sub-workflow tende a derrubar a execução do nó chamador no n8n.
status: open

### DW-53: `resumo`/`motivo` de `Escalar_humano` são gerados via `$fromAI` sem guardrail de prompt injection — canal novo onde texto do cliente chega a um humano sem revisão
origin: independent-review-post-DW51
location: n8n/workflows/01 - Agente.json (Ferramentas Disponíveis / SOP Seção 2.3)
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: medium
reason: Guardrails de prompt injection são CAP-9/Story 13, ainda não construída — risco aceito como fora de escopo desta story, mas deve ser considerado quando a Story 13 for desenhada.
status: resolved
resolution: Story 13 (CAP-9) adiciona `<guardrails-ia>` ao `systemMessage` de `n8n/workflows/01 - Agente.json`, formalizando que `motivo` permanece restrito aos 4 valores literais fixos (nunca ditado pelo cliente) e que `resumo` é sempre síntese neutra nas palavras do agente, nunca reprodução literal de texto/link/instrução do cliente — reforçado por `<validacoes>` item 23 e Exemplo 17.

### DW-54: SOP não define comportamento para uma mensagem que combine 2 motivos distintos de `Escalar_humano` no mesmo turno
origin: independent-review-post-DW51
location: n8n/workflows/01 - Agente.json (systemMessage, Validação 10 e SOP 2.3)
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: low
reason: Ambiguidade de UX/produto, não um bug — decisão pendente sobre se motivos múltiplos no mesmo turno devem gerar 1 ou 2 chamadas da ferramenta.
status: open

### DW-55: Nenhum timeout explícito configurado no `httpRequest` "Enviar alerta RD Conversas"
origin: independent-review-post-DW51
location: n8n/workflows/02 - Escalar Humano.json (nó "Enviar alerta RD Conversas")
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: low
reason: Uma resposta lenta da API Tallos pode prender a execução do sub-workflow (e o turno do agente) sem limite de tempo definido.
status: open

### DW-56: Itens duplicados em `destinatarios_emergencia` (mesmo `contact_id`) não são deduplicados antes do envio
origin: independent-review-post-DW51
location: n8n/workflows/02 - Escalar Humano.json (splitOut + httpRequest sequencial)
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: low
reason: Depende de qualidade de dado na config (`atendimento_config`), não de um bug de lógica do fluxo — o mesmo destinatário poderia receber a mesma mensagem 2x.
status: open

### DW-57: Nenhum limite documentado para o tamanho do array `destinatarios_emergencia`
origin: independent-review-post-DW51
location: n8n/workflows/01 - Agente.json (nó Info, campo destinatarios_emergencia)
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: low
reason: A lista alimenta chamadas HTTP sequenciais dentro do mesmo turno do agente — uma lista grande alonga a latência do turno do cliente proporcionalmente.
status: open

### DW-58: Caminho de `destinatarios_emergencia` vazio (nó `noOp` "Alerta não configurado") termina silenciosamente, sem log distinto do caminho de sucesso
origin: independent-review-post-DW51
location: n8n/workflows/02 - Escalar Humano.json (nó "Alerta não configurado")
source_spec: `6-cap-2-triagem-e-direcionamento.md`
severity: medium
reason: Relacionado ao DW-50 (ausência de registro persistido de acionamentos bem-sucedidos), mas cobre especificamente o caminho de falha silenciosa — o mais crítico operacionalmente enquanto `destinatarios_emergencia` seguir vazio (estado real de produção hoje).
status: open

### DW-59: Seção 3 do SOP não trata pedido de mais de um serviço do catálogo na mesma mensagem (ex. "banho e tosa").
origin: spec-deferred 6e77cb428b38
location: n8n/workflows/01 - Agente.json (systemMessage, Seção 3.2)
source_spec: `7-cap-3-fluxo-care-center.md`
severity: medium
reason: A Seção 3.2 é fraseada para coleta de um único serviço por vez ("qual serviço... o cliente quer"), sem instrução explícita para coletar múltiplos serviços quando citados juntos na mesma mensagem.
status: resolved
resolution: Adicionada Validação 13 ao `systemMessage` (`01 - Agente.json`), cobrindo Seções 3/4/5 — coletar todos os itens do catálogo mencionados na mesma mensagem, não só o primeiro. Coberto por assert na Verification da story 7 (2026-09-03, revisão independente pós-DW-59/60/61/62/63).

### DW-60: Seção 3 não cobre o cliente revisando uma preferência já coletada (serviço, data/horário ou profissional) no meio da coleta.
origin: spec-deferred 48f3b11b87df
location: n8n/workflows/01 - Agente.json (systemMessage, Seção 3)
source_spec: `7-cap-3-fluxo-care-center.md`
severity: medium
reason: O texto da Seção 3 descreve só a primeira coleta, sem instrução para o caso de correção/mudança de uma preferência já dada anteriormente na mesma conversa.
status: resolved
resolution: Adicionada Validação 14 ao `systemMessage` (`01 - Agente.json`), cobrindo Seções 3/4/5 — atualizar a preferência com o novo valor informado, sem insistir no valor anterior. Coberto por assert na Verification da story 7 (2026-09-03, revisão independente pós-DW-59/60/61/62/63).

### DW-61: Nenhuma instrução evita chamadas repetidas de Buscar_info_setor a cada turno da mesma sub-conversa do Care Center.
origin: spec-deferred b6751c7060d0
location: n8n/workflows/01 - Agente.json (systemMessage, Seção 3.1)
source_spec: `7-cap-3-fluxo-care-center.md`
severity: low
reason: Ao contrário da Validação #10 (que proíbe chamar Escalar_humano duas vezes para o mesmo evento), não há orientação equivalente para reutilizar o retorno já obtido de Buscar_info_setor em vez de re-consultar a cada turno.
status: resolved
resolution: Adicionada Validação 15 ao `systemMessage` (`01 - Agente.json`) — reutilizar catálogo/profissionais já obtidos para o setor corrente, só re-chamar se o setor mudar. Coberto por assert na Verification da story 7 (2026-09-03, revisão independente pós-DW-59/60/61/62/63).

### DW-62: Seção 3 não trata o cliente mudando de assunto para outro setor no meio da coleta do Care Center.
origin: spec-deferred 703522820836
location: n8n/workflows/01 - Agente.json (systemMessage, Seção 3)
source_spec: `7-cap-3-fluxo-care-center.md`
severity: medium
reason: Não há instrução para interromper a coleta e reclassificar quando o cliente pede algo de outro setor (ex. Consultas) no meio do fluxo do Care Center.
status: resolved
resolution: Adicionada Validação 16 ao `systemMessage` (`01 - Agente.json`) — interromper a coleta corrente e voltar à Seção 2 para reclassificar quando o cliente muda de setor no meio da coleta (Seções 3/4/5). Coberto por assert na Verification da story 7 (2026-09-03, revisão independente pós-DW-59/60/61/62/63).

### DW-63: Seção 3.4 não orienta o que fazer quando mais de um profissional da lista retornada corresponde aproximadamente ao nome citado pelo cliente.
origin: spec-deferred a7ad5940c58c
location: n8n/workflows/01 - Agente.json (systemMessage, Seção 3.4)
source_spec: `7-cap-3-fluxo-care-center.md`
severity: low
reason: A instrução atual só cobre "nome bate" ou "nome não está na lista", sem tratar ambiguidade entre múltiplos nomes parecidos.
status: resolved
resolution: Adicionada Validação 17 ao `systemMessage` (`01 - Agente.json`), cobrindo Seções 3.4/4.4/5.4 — nunca escolher silenciosamente entre nomes parecidos, pedir confirmação ao cliente. Coberto por assert na Verification da story 7 (2026-09-03, revisão independente pós-DW-59/60/61/62/63).

### DW-64: O input `setor` do trigger de "03 - Buscar Info Setor.json" não é marcado como obrigatório no schema do workflowInputs.
origin: spec-deferred d80b06f9667a
location: n8n/workflows/03 - Buscar Info Setor.json (executeWorkflowTrigger)
source_spec: `7-cap-3-fluxo-care-center.md`
severity: low
reason: Hardening de defesa em profundidade — hoje depende só do agente sempre preencher `setor` via `$fromAI`; sem `required: true` no trigger, um valor vazio passaria silenciosamente para a query Postgres.
status: resolved
resolution: Investigado (2026-09-03, revisão independente) — a suposição original não se sustenta: o node `n8n-nodes-base.executeWorkflowTrigger` (`workflowInputs.values`) não suporta um campo `required` por item nesta versão do n8n (confirmado contra todo uso do node no repo, incluindo material de referência) — só o node `toolWorkflow` consumidor tem esse campo, num schema diferente. Um guard real exigiria um nó `IF` novo dentro do sub-workflow (checar `setor` não vazio antes da query Postgres), mudança de topologia fora do escopo de um patch — não implementado agora; documentado aqui para não reabrir a mesma suposição incorreta no futuro.

### DW-65: Follow-up review recomendado para a story 8 nunca rodou (sessão `8-review-1` morreu por limite de uso do adapter codex antes da 2ª passada)
origin: independent-review-post-followup
location: n/a
source_spec: `8-cap-4-fluxo-consultas-e-vacinas.md`
severity: low
reason: `followup_review_recommended: true` ficou sem nenhuma revisão de follow-up de fato executada — a sessão automática (`8-review-1`) foi morta pelo limite de uso do `codex` antes de completar, e a `8-review-2` que o loop disparou em seguida também travou no mesmo limite (rate-limit interativo) e precisou ser parada manualmente; o adapter de review foi trocado para `claude` no `policy.toml` para evitar repetição.
status: resolved
resolution: Revisão manual feita em 2026-09-03 (ver Review Triage Log da story 8, seção "Revisão independente"). A maior parte dos gaps esperados já tinha sido coberta pelas Validações 13-17 adicionadas durante a resolução das pendências da Story 7 (aplicam-se às Seções 3/4/5 simultaneamente). 1 achado novo e específico de Consultas corrigido por simetria com Vacinas (Seção 4.2 agora reconhece a especialidade pedida antes de pivotar para queixa).

### DW-66: A expressão do campo `mensagem` (nó `Extrair dados da mensagem`) nunca trata `$json.body` como potencialmente ausente/nulo — acessa `b.message` direto sem guarda (`b = $json.body`).
origin: spec-deferred 2a7618fe0c24
location: n8n/workflows/01 - Agente.json -- nó "Extrair dados da mensagem", campo `mensagem`
source_spec: `9-cap-5-fluxo-exames.md`
severity: low
reason: Pré-existente desde as Stories 1-4 (o código original já fazia `$json.body.message || $json.body.content || ...` sem checar `body` primeiro); a Story 9 apenas reutilizou a mesma variável `b` para montar a lógica de anexo, sem introduzir o problema. Se o webhook algum dia enviar um payload sem `body`, o node inteiro falha na avaliação da expressão -- risco real, mas de escopo maior que esta story (afeta qualquer setor, não só Exames).
status: open

### DW-67: A Seção 3 (Care Center) do SOP ainda afirma "nunca para os demais setores, que ainda não têm coleta ativa", frase que já ficou falsa desde a Story 8 (Consultas/Vacinas ganharam coleta ativa) e agora t
origin: spec-deferred 544e4f9077b7
location: n8n/workflows/01 - Agente.json -- nó `Agente Nouvet`, `systemMessage`, abertura da Seção "3. Fluxo Care Center"
source_spec: `9-cap-5-fluxo-exames.md`
severity: low
reason: Confirmado por inspeção: as Seções 4 (Consultas) e 5 (Vacinas) já não têm essa frase -- só a Seção 3 ainda a mantém, um resíduo da Story 7 nunca atualizado quando outros setores passaram a ter coleta própria. A Story 9 não tocou na Seção 3.1 (só acrescentou a Seção 6 e atualizou os 4 apontamentos "fase seguinte ainda não construída" explicitamente listados no Boundaries da story), então o problema é anterior e mais amplo que este escopo.
status: open

### DW-68: O Set node de projeção em `03 - Buscar Info Setor.json` lê `$json.config.<campo>` para os 3 campos (`catalogo_servicos`, `profissionais`, `exames_exigem_anestesia`) sem nenhuma guarda para `$json.conf
origin: spec-deferred f4be5b8572c0
location: n8n/workflows/03 - Buscar Info Setor.json -- Set node "Selecionar Catálogo e Profissionais"
source_spec: `9-cap-5-fluxo-exames.md`
severity: low
reason: Padrão pré-existente: `catalogo_servicos` e `profissionais` já liam `$json.config.*` sem guarda antes desta story; a Story 9 só acrescentou `exames_exigem_anestesia` seguindo exatamente o mesmo padrão já existente, sem introduzir a falta de guarda.
status: open

### DW-69: Não há regra simétrica à Validação 16 para quando o cliente muda de assunto saindo da Seção 7 (Orçamentos) em direção a um setor com coleta ativa (ex.: "na verdade, só agenda o banho mesmo").
origin: spec-deferred ce4d7e06357b
location: n8n/workflows/01 - Agente.json (systemMessage, Validação 16 / Seção 7)
source_spec: `10-cap-6-orcamentos-roteamento-puro.md`
severity: low
reason: Validação 16 cobre apenas a direção "Seções 3, 4, 5 ou 6 -> Seção 2 -> outro setor"; a Seção 7 nunca existiu antes desta story, então este caminho de saída nunca pôde ocorrer antes. Não há nenhuma outra validação genérica de troca de assunto no restante do systemMessage (confirmado por busca textual). O I/O & Edge-Case Matrix desta story não cobre este cenário, e o comportamento resultante depende inteiramente da competência geral do LLM em retriagem, sem instrução explícita.
status: open

### DW-70: Typo pré-existente "sigo com o que you já me passou" (deveria ser "eu") no Exemplo 14, não relacionado a esta story.
origin: spec-deferred 29d32aa8a57f
location: n8n/workflows/01 - Agente.json (systemMessage, Exemplo 14)
source_spec: `10-cap-6-orcamentos-roteamento-puro.md`
severity: low
reason: Encontrado incidentalmente durante a revisão desta story; o texto do Exemplo 14 não foi tocado por este diff (é de uma story anterior) e continua com o erro.
status: open

### DW-71: A detecção de possível duplicidade familiar (match só por nome de pet, case-insensitive, entre telefones diferentes) pode gerar falso positivo entre famílias sem relação alguma.
origin: spec-deferred e63dd2217048
location: n8n/migrations/0006_identidade_porta_unica.sql (CTE `duplicidade`)
source_spec: `11-cap-7-registro-e-memoria-no-crm.md`
severity: medium
reason: Lógica herdada da CTE `duplicidade` de `identidade_cliente_pet_resolver` (Story 4, `n8n/migrations/0006_identidade_porta_unica.sql`, não alterada por esta story): compara só `lower(btrim(nome_pet))` entre linhas de telefones distintos, sem nenhum sinal de nome do dono/endereço. Nomes de pet comuns (Rex, Mel, Bob) entre dois clientes reais e não aparentados disparam o alerta. Já era uma limitação conhecida e documentada desde a Story 4 ("não elimina o caso... só avisa o caller"), mas até esta story o caller (sub-workflow de Task) não existia -- Story 11 é quem ativa esse aviso contra tráfego real pela primeira vez, então o volume de falsos positivos em produção é uma incógnita nova.
status: open

### DW-72: A Task de "possível duplicidade familiar" não é idempotente entre atendimentos futuros do mesmo cliente -- pode criar uma Task nova a cada fechamento de seção enquanto a duplicidade não for resolvida
origin: spec-deferred 91cd5b7af3db
location: n8n/workflows/04 - Registrar Atendimento CRM.json (nodes "Precisa criar Task?" / "Criar Task de Revisão")
source_spec: `11-cap-7-registro-e-memoria-no-crm.md`
severity: low
reason: `possivel_duplicidade_familiar` é recalculado a cada chamada de `identidade_cliente_pet_resolver` (não é um estado persistido/resolvido). O node "Precisa criar Task?" (`n8n/workflows/04 - Registrar Atendimento CRM.json`) só olha a flag da chamada atual, sem checar se já existe uma Task aberta equivalente no deal. Um cliente com duplicidade não resolvida que fecha múltiplas seções no futuro pode acumular várias Tasks repetidas no mesmo card. O `Always` do contrato desta story só exige deduplicar as duas causas (cadastro pendente + duplicidade) *dentro da mesma chamada*, nunca promete idempotência entre chamadas futuras -- por isso não é um intent_gap nem bad_spec desta story, mas vale acompanhar (risco de poluir o card e, em escala, virar ruído percebido -- mesma preocupação de spam que a Story 12/SM-C2 já trata para escalonamento humano).
status: open

### DW-73: Os `httpRequest` de criação (POST) do novo sub-workflow usam `retryOnFail` sem idempotency key; se a criação suceder no servidor RD CRM mas a resposta expirar/falhar no n8n antes de chegar, o retry au
origin: spec-deferred a4319f17fad6
location: n8n/workflows/04 - Registrar Atendimento CRM.json (nodes "Criar Contato RD CRM", "Criar Deal", "Criar Task de Revisão")
source_spec: `11-cap-7-registro-e-memoria-no-crm.md`
severity: medium
reason: `Criar Contato RD CRM`, `Criar Deal` e `Criar Task de Revisão` (`n8n/workflows/04 - Registrar Atendimento CRM.json`) têm `retryOnFail: true` -- exigido pelo `Always` desta story para todo `httpRequest`, sem exceção para chamadas de escrita -- mas nenhum mecanismo de idempotency key ou de verificação pós-retry de que a criação anterior já teve sucesso. `.claude/skills/rd-station-api/references/crm.md` não documenta suporte a idempotency key nesses endpoints. Os guards `Busca de Contato/Deal Bem-sucedida?` desta mesma rodada já mitigam o caso de a *busca* falhar (evitando um 2º contato/deal por busca malsucedida tratada como "não encontrado"), mas não cobrem o caso de a própria *criação* ter sucesso silencioso no servidor seguido de um retry do cliente.
status: open

### DW-74: Follow-up review still recommended for 11 after the damping cap was spent
origin: review-budget-followup
location: n/a
source_spec: `11-cap-7-registro-e-memoria-no-crm.md`
severity: low
reason: The follow-up-review damping cap (limits.max_followup_reviews = 1) was spent with the story finalized (status: done, verify green) while the review pass still recommended an independent follow-up. The work was committed by bmad-loop run 20260904-152116-904f; this entry preserves the lingering recommendation for a deliberate later review.
status: open

### DW-75: Se a criação da Task de SLA falhar em `04` enquanto `estado_espera` ainda é marcado `aguardando_atendimento_humano`, o handoff fica sem SLA rastreado.
origin: spec-deferred b9cfcb3b3b8b
location: n8n/workflows/04 - Registrar Atendimento CRM.json (nós "Gerenciar Task SLA (CAP-8)" e "Marcar Aguardando Atendimento Humano (CAP-8)")
source_spec: `12-cap-8-temporizadores-continuidade-e-sla.md`
severity: medium
reason: "Gerenciar Task SLA (CAP-8)" e "Marcar Aguardando Atendimento Humano (CAP-8)" rodam em branches independentes a partir de "Criar Note no Deal", ambas com onError: continueRegularOutput. Se a primeira falhar (mesmo após retry) e a segunda suceder, nenhuma Task de SLA existe para aquele deal, e o Sweep B do cron (06) só varre Tasks já existentes -- o handoff fica permanentemente sem monitoramento de SLA. Mesmo padrão de branches paralelos tolerantes a falha parcial já usado em `04` desde a Story 11, não é um padrão novo desta story, mas o risco concreto (SLA nunca rastreado) é novo.
status: open

### DW-76: Branches terminais novas (Task/deal/contato/identidade não encontrados) em `05`/`06` não têm log, alerta nem limite de tentativas.
origin: spec-deferred 54af05f0e1bc
location: n8n/workflows/05 - Gerenciar Task SLA.json e n8n/workflows/06 - Lembretes e Escalonamento SLA.json (branches noOp terminais)
source_spec: `12-cap-8-temporizadores-continuidade-e-sla.md`
severity: medium
reason: "Task SLA Não Gerenciada", "Deal da Task Não Encontrado", "Contato do Deal Ausente", "Identidade Não Encontrada (tenta próximo ciclo)" e "Busca de Tasks SLA Falhou" são todos noOp puros -- uma Task irrecuperável (ex. contato deletado no CRM) é reprocessada todo tick do cron (1 min) para sempre, sem visibilidade. Mesma convenção de branches terminais silenciosos já usada em workflows anteriores do projeto (não é um padrão novo desta story), mas é uma lacuna de observabilidade que vale atenção dedicada no nível do projeto.
status: open

### DW-77: Comparação entre timestamp Postgres sem timezone e string ISO do Luxon via `new Date()` depende de tratamento implícito de timezone do node Postgres do n8n.
origin: spec-deferred ce45bf6dcee2
location: n8n/workflows/06 - Lembretes e Escalonamento SLA.json (nó "Lead Ativo Desde o Início do Ciclo?")
source_spec: `12-cap-8-temporizadores-continuidade-e-sla.md`
severity: low
reason: "Lead Ativo Desde o Início do Ciclo?" (06) compara `n8n_status_atendimento.updated_at` (TIMESTAMP WITHOUT TIME ZONE) contra `inicio_ciclo_atual` (ISO construído via Luxon) usando `new Date(...)` puro em JS, sem normalização explícita de UTC em nenhum dos dois lados. Mesma classe de risco já presente onde quer que este projeto compare timestamps através da fronteira driver-pg/JS (ex. recuperação de lock por TTL da Story 3), não é exclusivo desta story.
status: open

### DW-78: `estado_espera` nunca é gravado de volta para `aguardando_cliente` -- uma vez que um telefone é marcado `aguardando_atendimento_humano` por um handoff, fica assim para sempre, mesmo em conversas futur
origin: spec-deferred 4650cac81bdf
location: n8n/migrations/0012_temporizadores_sla.sql (função atendimento_estado_espera_marcar) e n8n/workflows/04 - Registrar Atendimento CRM.json (único chamador)
source_spec: `12-cap-8-temporizadores-continuidade-e-sla.md`
severity: medium
reason: `atendimento_estado_espera_marcar` só é chamada por `04` com o literal `'aguardando_atendimento_humano'` -- nenhum ponto do projeto (agente, cron, qualquer sub-workflow) jamais chama com `'aguardando_cliente'`. Como `n8n_status_atendimento.session_id` é `UNIQUE` por telefone (uma única linha por cliente, reaproveitada para sempre, Story 3), qualquer cliente que já passou por um handoff fica permanentemente fora do alcance do Sweep A (que exige `estado_espera='aguardando_cliente'`) em qualquer conversa futura e não relacionada -- mesmo que a Task de SLA daquele handoff antigo já tenha sido concluída no CRM há muito tempo. A leitura literal do Always da story (só `Registrar_atendimento_crm` escreve o estado, nunca especifica retorno) sustenta isso como comportamento monotônico por design, mas o efeito prático (lembrete de inatividade pré-handoff nunca mais dispara para um cliente recorrente) não é mencionado em nenhum lugar do Intent/Edge-Case Matrix.
status: open

### DW-79: O cron `06` não tem trava contra suas próprias execuções sobrepostas -- só a criação/renovação de Task dentro de `05` é protegida por lock; o envio de mensagem/escalonamento por Task individual, em `0
origin: spec-deferred 5f03858949f6
location: n8n/workflows/06 - Lembretes e Escalonamento SLA.json (Sweep B, varredura sequencial de Tasks vencidas)
source_spec: `12-cap-8-temporizadores-continuidade-e-sla.md`
severity: medium
reason: A granularidade de referência do `scheduleTrigger` é de 1 minuto (nota da própria story, não é invariante travada). Se o processamento sequencial de uma leva de Tasks vencidas (deal -> contato -> identidade -> Conversas -> enviar/escalonar, por Task) ultrapassar esse intervalo, o próximo tick pode reprocessar a mesma Task vencida antes que o ciclo anterior tenha concluído sua renovação de `due_date`, gerando mensagem duplicada ao cliente/gestor e incremento duplo de `numero_ciclo_escalonamento` -- risco adjacente a SM-C2 (lembrete não pode virar spam percebido) sob volume real.
status: open

### DW-80: A correlação Task->telefone via `deal.contact_id -> identidade_cliente_pet` usa `ORDER BY i.updated_at DESC LIMIT 1`, que pode escolher a identidade errada quando mais de um telefone compartilha o mes
origin: spec-deferred ba3e33c939a0
location: n8n/workflows/06 - Lembretes e Escalonamento SLA.json (nós "Buscar Identidade e Status por Contato" e "Incrementar Ciclo de Escalonamento")
source_spec: `12-cap-8-temporizadores-continuidade-e-sla.md`
severity: medium
reason: "Buscar Identidade e Status por Contato" (06) faz `SELECT ... FROM identidade_cliente_pet i LEFT JOIN n8n_status_atendimento s ON telefone_normalizar(s.session_id) = i.telefone WHERE i.rd_crm_contact_id = $1 ORDER BY i.updated_at DESC LIMIT 1`. O próprio AD-11 documenta duplicidade familiar (cônjuges com o mesmo pet) como cenário real deste projeto, e a correlação Task->telefone via `deal.contact_id -> identidade_cliente_pet.rd_crm_contact_id` foi deliberadamente deixada a critério de quem implementa pelo "Block If" desta story -- sem outro campo para desambiguar, a heurística de recência pode selecionar o telefone/nome de um familiar que não é quem está de fato naquele atendimento. Quando isso acontece, o `LEFT JOIN` pode não encontrar a sessão do telefone errado, e "Incrementar Ciclo de Escalonamento" (`UPDATE ... WHERE telefone_normalizar(session_id) = $1`) afeta 0 linhas silenciosamente -- toda escalonação subsequente reporta "ciclo 1" mesmo que já tenham ocorrido vários.
status: open

### DW-81: "Enviar Atualização ao Cliente" (Sweep B) não verifica sucesso/falha do envio, diferente do fix já aplicado a "Enviar Lembrete ao Cliente" (Sweep A) para o mesmo tipo de risco.
origin: spec-deferred cfa850fcd6b3
location: n8n/workflows/06 - Lembretes e Escalonamento SLA.json (nó "Enviar Atualização ao Cliente")
source_spec: `12-cap-8-temporizadores-continuidade-e-sla.md`
severity: low
reason: O nó é terminal (`onError: continueRegularOutput`, sem IF de status depois) -- uma falha de envio ao cliente é engolida em silêncio, sem sinal em lugar nenhum. Diferente do caso já corrigido em Sweep A, aqui isso não suprime nenhum mecanismo futuro (a renovação da Task e o alerta ao gestor rodam em um branch paralelo independente, não acoplado ao sucesso desta mensagem) -- o cliente só deixa de saber que a equipe foi notificada novamente, sem efeito colateral em dados/estado.
status: open

### DW-82: `task_sla_lock_adquirir` não trata `p_ttl_minutos` nulo -- se a leitura de config upstream falhar, um lock preso pode nunca ser reclamado por TTL.
origin: spec-deferred 5df2faf80a49
location: n8n/migrations/0012_temporizadores_sla.sql (função task_sla_lock_adquirir)
source_spec: `12-cap-8-temporizadores-continuidade-e-sla.md`
severity: low
reason: `task_sla_lock_adquirir` usa `make_interval(mins => p_ttl_minutos)` sem `COALESCE`. Se "Buscar SLA Config" (05) falhar (`onError: continueRegularOutput`, padrão já usado em todo o projeto) e o valor chegar indefinido, `now() - make_interval(mins => NULL)` é `NULL`, e a condição de reclamo do `DO UPDATE` (`lock_adquirido_em < NULL`) nunca é verdadeira -- um lock preso por essa falha composta (config falha E existe lock preso) só se resolve quando uma leitura de config bem-sucedida ocorrer de novo para aquele `deal_id`.
status: open

### DW-83: Validação 4 ("Nunca invente dado fora da seção Contexto") ainda instrui só "reconheça que você não tem essa informação agora" sem exigir o acionamento de Escalar_humano(motivo="Informação indisponível
origin: spec-deferred fccb2e4fda23
location: n8n/workflows/01 - Agente.json — nó Agente Nouvet, systemMessage, <validacoes> item 4
source_spec: `13-cap-9-guardrails-de-ia.md`
severity: medium
reason: Achado convergente de dois reviewers independentes (blind-hunter e verification-gap) no review pass de 2026-09-04 da story 13. A tensão é real, mas não é uma correção óbvia: Validação 4 convive com carve-outs mais específicos que já preveem resposta transparente sem escalonamento para casos pontuais dentro de um fluxo já classificado (ex.: profissional não reconhecido na Validação 17, item de catálogo fora da lista na Validação 13) — generalizar Validação 4 para sempre escalar arriscaria contradizer esses carve-outs. Requer uma revisão de design (não uma correção mecânica) para decidir se/como diferenciar "lacuna pontual dentro de um fluxo" de "pergunta institucional/clínica genuinamente fora de escopo" (a distinção que o Motivo 4 já cobre via a frase de fechamento de `<contexto>`, corrigida nesta mesma passada de review).
status: open

### DW-84: Quando um Sinal de Alerta já acionou Escalar_humano num turno anterior e, em turno posterior, o cliente declara explicitamente que é uma emergência sobre o mesmo evento, não está definido se isso deve
origin: spec-deferred 77035afc5622
location: n8n/workflows/01 - Agente.json — systemMessage, seção <sinais-de-alerta> (bloco Emergência Declarada) / <validacoes> item 10
source_spec: `14-cap-12-emergencias-declaradas-pelo-cliente.md`
severity: medium
reason: A Boundaries & Constraints e a I/O & Edge-Case Matrix desta story só tratam o caso de sintoma configurado e declaração explícita coincidindo na MESMA mensagem ("uma única chamada... mesmo invariante da Validação 10"). O cenário de declaração tardia, em turno separado, sobre um evento já escalado como Sinal de Alerta, não é coberto por nenhum Always/Never nem pela Matrix. A leitura defensável mais direta é que a Validação 10 ("nunca chame Escalar_humano duas vezes para o mesmo evento") já resolve isso suprimindo a segunda chamada, mas isso significa que o motivo mais grave e mais específico (Emergência Declarada) nunca chegaria a ser sinalizado para o humano nesse cenário -- mesma família de risco residual já aceita para destinatarios_emergencia vazio (DW-44), não bloqueante para esta story.
status: open
