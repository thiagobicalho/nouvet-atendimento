---
title: 'Infra e persistência base'
type: 'chore'
created: '2026-09-02'
status: 'done'
baseline_revision: '20cdfa1bb66fdc23fb1696b8eafb7d24a31a7243'
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: ['oversized']
deferred:
  - summary: >-
      Migrations de bootstrap (0001) não são idempotentes (CREATE DATABASE/CREATE ROLE
      sem guards de existência).
    evidence: |-
      docker-entrypoint-initdb.d só roda uma vez em volume vazio, então a AC de
      "primeira subida" não é afetada, mas um re-run manual contra um cluster já
      existente (reset de dev, disaster recovery) falha explicitamente em vez de ser
      reaplicável.
    location: >-
      n8n/migrations/0001_bootstrap_bancos_e_papeis.sh
    severity: medium
  - summary: >-
      n8n_status_atendimento não tem coluna de timestamp de aquisição do lock, necessária
      para calcular expiração por TTL.
    evidence: |-
      AD-5 (recuperação automática de lock travado por TTL) é escopo da Story 3
      ("Debounce e lock com recuperação de TTL"); esta story só cria o schema base.
      Story 3 provavelmente precisa de uma migration adicional (ex. 0004) adicionando
      essa coluna.
    location: >-
      n8n/migrations/0002_schema_operacional.sql (tabela n8n_status_atendimento)
    severity: low
  - summary: >-
      n8n_fila_mensagens não tem coluna de status/processado nem índice único em
      id_mensagem para deduplicação.
    evidence: |-
      O mecanismo de debounce/dedup é lógica de workflow da Story 3, não desta story;
      o schema atual só cria a fila crua.
    location: >-
      n8n/migrations/0002_schema_operacional.sql (tabela n8n_fila_mensagens)
    severity: low
  - summary: >-
      identidade_cliente_pet.rd_crm_contact_id não tem índice.
    evidence: |-
      Esse é o caminho de lookup provável quando a Story 4 (porta única idempotente) ou
      a Story 11 (registro no CRM) resolverem conversa -> contato do RD CRM; adicionar
      quando o padrão de acesso real dessas stories estiver implementado.
    location: >-
      n8n/migrations/0003_identidade_cliente_pet.sql
    severity: low
  - summary: >-
      n8n exposto em 0.0.0.0:5678 sem proxy reverso/TLS nem N8N_HOST/WEBHOOK_URL/
      N8N_SECURE_COOKIE configurados.
    evidence: |-
      Fora do escopo desta story ("Não inclui provisionamento da VPS em si"), mas é um
      hardening real necessário antes de expor a stack numa VPS de produção.
    location: >-
      docker-compose.yml (serviço n8n)
    severity: low
  - summary: >-
      Sem GENERIC_TIMEZONE/TZ no n8n nem locale pt_BR no Postgres.
    evidence: |-
      Afeta corretude de horários de lembrete/follow-up (secretaria_config.lembretes_horas/
      follow_ups_horas) e ordenação com acentuação em campos de texto em português; não
      exigido pelos ACs desta story.
    location: >-
      docker-compose.yml (serviço n8n); n8n/migrations/0001_bootstrap_bancos_e_papeis.sh
      (criação do cluster)
    severity: low
  - summary: >-
      n8n sobe sem nenhuma flag de telemetria/diagnóstico desativada
      (N8N_DIAGNOSTICS_ENABLED, N8N_VERSION_NOTIFICATIONS_ENABLED, etc.).
    evidence: |-
      O projeto tem postura de privacidade forte (papel de identidade à parte, chave de
      criptografia obrigatória), mas a decisão de manter ou desativar telemetria do n8n
      (relevante para LGPD) nunca foi tomada explicitamente; não exigido pelos ACs desta
      story.
    location: >-
      docker-compose.yml (serviço n8n)
    severity: low
  - summary: >-
      Colunas updated_at (DEFAULT CURRENT_TIMESTAMP) não têm nenhum mecanismo (trigger
      ou convenção de app) que as atualize de fato em UPDATE.
    evidence: |-
      DEFAULT só dispara em INSERT; sem trigger ou disciplina de aplicação definida, a
      coluna tende a ficar com o valor de criação mesmo após updates reais. A lógica de
      escrita em runtime é de stories futuras, então a decisão (trigger vs. app seta
      manualmente) fica para quando essa lógica for implementada.
    location: >-
      n8n/migrations/0002_schema_operacional.sql; n8n/migrations/0003_identidade_cliente_pet.sql
      (todas as tabelas com updated_at)
    severity: low
  - summary: >-
      Não existe runner/mecanismo para aplicar migrations futuras (0004+) contra um
      cluster já inicializado.
    evidence: |-
      docker-entrypoint-initdb.d só executa na primeira inicialização de um volume vazio;
      distinto do DW já registrado sobre idempotência do bootstrap 0001 (re-rodar scripts
      existentes), este é sobre como migrations novas, criadas por stories futuras, chegam
      a ser aplicadas depois do primeiro boot — nenhum runner/tabela de controle de versão
      foi definido.
    location: >-
      n8n/migrations/README.md; docker-compose.yml (serviço postgres)
    severity: low
  - summary: >-
      UNIQUE (telefone, nome_pet) em identidade_cliente_pet não trata variação de
      maiúsculas/minúsculas nem dois pets do mesmo cliente com o mesmo nome.
    evidence: |-
      "Rex" e "rex" não colidem hoje (unique é case-sensitive) e dois pets distintos com
      o mesmo nome para o mesmo telefone seriam rejeitados na inserção; a chave natural
      escolhida é adequada para o caso comum, mas o tratamento desses casos de borda fica
      para quando a porta única de escrita (Story 4) definir a regra de deduplicação real.
    location: >-
      n8n/migrations/0003_identidade_cliente_pet.sql (identidade_cliente_pet)
    severity: low
  - summary: >-
      Colunas numéricas de secretaria_config (sla_resposta_minutos, lock_ttl_minutos,
      max_followups) não têm CHECK de faixa e aceitariam 0 ou negativo.
    evidence: |-
      A tabela é editada manualmente (config de personalização, AD-1) e nenhuma AC desta
      story exige validação de valor, só existência/grants das tabelas; a lógica que lê e
      usa esses valores em runtime (debounce/lock, follow-up) ainda não existe, então a
      decisão de faixa válida fica melhor colocada quando essa lógica de leitura for
      implementada, junto com o resto da validação de secretaria_config.
    location: >-
      n8n/migrations/0002_schema_operacional.sql (tabela secretaria_config)
    severity: low
---

<intent-contract>

## Intent

**Problem:** O repo ainda não tem stack nem persistência — não existe `docker-compose.yml` nem schema do banco da aplicação, e sem isso nenhuma story seguinte (config, debounce/lock, identidade, workflows) tem onde rodar ou persistir dado.

**Approach:** Provisionar `docker-compose.yml` na raiz com n8n `2.14.2` e Postgres `16.15-alpine3.24` pinados (AD-10); duas bases Postgres no mesmo servidor — interna do n8n (`DB_TYPE=postgresdb`) e da aplicação — cada uma com papel de privilégio mínimo próprio, e um terceiro papel ainda mais restrito só para a tabela de identidade cliente/pet (PII permanente) dentro do banco da aplicação (AD-3); migrations SQL numeradas em `n8n/migrations/` criando todo o schema do banco da aplicação; `N8N_ENCRYPTION_KEY` obrigatória via variável de ambiente, com falha explícita na subida se ausente (AD-2).

## Boundaries & Constraints

**Always:** `n8nio/n8n:2.14.2` e `postgres:16.15-alpine3.24` como tags literais completas (nunca `latest`/`16-alpine` soltas, AD-10). `N8N_ENCRYPTION_KEY` só via variável de ambiente, presente antes de qualquer `docker compose up`, sem fallback nem geração automática (AD-2). n8n usa `DB_TYPE=postgresdb` apontando pro seu próprio banco interno, nunca SQLite. Duas bases Postgres, cada uma com usuário próprio de privilégio mínimo; dentro do banco da aplicação, a tabela de identidade cliente/pet usa um papel Postgres à parte, mais restrito que o papel das tabelas de fila/lock/config (AD-3). Nenhuma credencial real em texto no repo — só `.env.example` com placeholders (`.gitignore` já reserva a exceção). Migrations numeradas e aplicadas na mesma ordem/processo em dev e produção (`n8n/migrations/README.md`).

**Block If:** Nenhuma decisão bloqueante identificada — nomes exatos de papéis/bancos e a extensão do script de bootstrap de papéis/bancos (`.sh` vs `.sql`) ficam a critério de quem implementa, dentro das invariantes AD-2/AD-3/AD-10; o schema da tabela de identidade está marcado na spine como "a detalhar no build" — é justamente esta story que o detalha, não uma decisão pendente de terceiro.

**Never:** Não inclui conteúdo/seed de `secretaria_config` (Story 2, "Config-as-Data"). Não inclui lógica de leitura/escrita em runtime pelos workflows n8n (stories seguintes). Não inclui provisionamento da VPS em si, só os artefatos (`docker-compose.yml`/migrations) reaplicáveis nela. Nunca conceder ao papel de fila/lock/config acesso à tabela de identidade, nem o inverso.

</intent-contract>

## Code Map

- `docker-compose.yml` -- não existe ainda; criar na raiz. Serviços `postgres`/`n8n` pinados (AD-10); `N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY:?...}` (fail-fast); volume `./n8n/migrations:/docker-entrypoint-initdb.d:ro` no serviço postgres.
- `n8n/migrations/README.md` -- já existe; convenção `NNNN_<descricao>.sql`, escopo (só banco da aplicação) e "mesmo processo em dev/produção".
- `n8n/migrations/` -- vazio hoje (só o README); recebe os arquivos numerados desta story.
- `n8n/seed/README.md` -- confirma que conteúdo de `secretaria_config` é seed de Story 2 (aqui só a tabela vazia).
- `.gitignore` -- já ignora `.env`/`.env.*` com exceção `!.env.example` pronta.
- `ARCHITECTURE-SPINE.md` AD-2/AD-3/AD-10 e "Structural Seed" -- invariantes e tabela de referência do schema do banco da aplicação.
- `.claude/skills/n8n-agent-patterns/references/config-postgres.md` -- `CREATE TABLE` de referência (`secretariav3-completo`) para as tabelas operacionais/config; adaptar nomes, não copiar 1:1 — lá a credencial de integração mora na tabela de config, aqui vai para o cofre do n8n (AD-2).

## Tasks & Acceptance

**Execution:**
- `docker-compose.yml` -- criar serviços `postgres:16.15-alpine3.24` (healthcheck, volume nomeado, `./n8n/migrations:/docker-entrypoint-initdb.d:ro`) e `n8nio/n8n:2.14.2` (`DB_TYPE=postgresdb` apontando pro banco interno, `N8N_ENCRYPTION_KEY` obrigatória via `${...:?}`, volume nomeado para `/home/node/.n8n`) -- entrega a stack pinada de AD-10 sobre a base de AD-2/AD-3.
- `.env.example` -- documentar, sem valor real, todas as variáveis exigidas: credenciais do superusuário Postgres, nome+credenciais dos 2 bancos e dos 3 papéis (n8n, aplicação/plumbing, identidade), `N8N_ENCRYPTION_KEY` -- torna o setup reproduzível sem segredo no repo.
- `n8n/migrations/0001_<descricao>.sql` (ou `.sh`, se precisar interpolar senha de env var) -- criar os 2 bancos e os 3 papéis de privilégio mínimo -- implementa AD-3.
- `n8n/migrations/0002_<descricao>.sql` -- criar no banco da aplicação as tabelas `secretaria_config` (singleton, `id=1`), `secretaria_profissionais`, `n8n_historico_mensagens`, `n8n_fila_mensagens`, `n8n_status_atendimento`, concedidas ao papel padrão da aplicação -- schema base da Structural Seed, sem conteúdo/seed.
- `n8n/migrations/0003_<descricao>.sql` -- criar a tabela de identidade cliente/pet no banco da aplicação, concedida só ao papel restrito de PII (nunca ao papel padrão) -- fecha a parte de schema de AD-3/AD-6/AD-11 (a porta única de escrita idempotente é Story 4, fora daqui).

**Acceptance Criteria:**
- Given `.env` preenchido com `N8N_ENCRYPTION_KEY` (≥32 chars hex) e as credenciais dos 2 bancos, when `docker compose up -d` sobe a stack pela primeira vez, then o Postgres cria automaticamente as 2 bases e os 3 papéis, e o n8n conecta no seu próprio banco via `DB_TYPE=postgresdb` (nunca SQLite).
- Given `N8N_ENCRYPTION_KEY` ausente do `.env`, when `docker compose up` é executado, then a subida falha explicitamente em vez de deixar o n8n auto-gerar a chave.
- Given as migrations aplicadas, when se inspeciona o banco da aplicação, then existem as tabelas `secretaria_config`, `secretaria_profissionais`, `n8n_historico_mensagens`, `n8n_fila_mensagens`, `n8n_status_atendimento` e a de identidade, e o papel de identidade não tem privilégio sobre as demais tabelas (nem vice-versa).
- Given o `docker-compose.yml` final, when se inspecionam as tags de imagem, then são exatamente `postgres:16.15-alpine3.24` e `n8nio/n8n:2.14.2`, sem tag flutuante.

## Spec Change Log

## Review Triage Log

### 2026-09-02 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 3 (high 1, medium 1, low 1)
- defer: 6 (medium 1, low 5)
- reject: 9 (low 9)
- addressed_findings:
  - `[high]` `[patch]` Interpolação direta de senha em heredoc SQL (`n8n/migrations/0001_bootstrap_bancos_e_papeis.sh`) permitia SQL injection — reproduzido contra Postgres 16.15 real (`DROP TABLE` injetado via senha executou). Corrigido: senhas agora passadas como variáveis do `psql` (`-v`) e referenciadas como `:'nome'`/`:"nome"` no heredoc, que fazem quoting seguro de literal SQL. Reconfirmado com o mesmo teste de injeção (agora inofensivo) e com senhas contendo `'`/`"`.
  - `[medium]` `[patch]` `docker-compose.yml` expunha `POSTGRES_N8N_DB`/`POSTGRES_N8N_ROLE` como se fossem configuráveis via `.env`, mas `0001` sempre cria `nouvet_n8n`/`n8n_role` fixos — risco de conexão do n8n a banco/role inexistente se alguém sobrescrevesse essas vars. Corrigido: valores trocados por literais fixos em `docker-compose.yml`, com comentário explicando que não são configuráveis.
  - `[low]` `[patch]` Colunas `formas_pagamento`, `lembretes_horas`, `follow_ups_horas` em `0002_schema_operacional.sql` aceitavam `NULL` explícito apesar de terem/ganharem default, inconsistente com as colunas JSONB irmãs. Corrigido: as três agora `NOT NULL` (com default `'{}'` adicionado a `formas_pagamento`).

### 2026-09-02 — Review pass (follow-up)
- intent_gap: 0
- bad_spec: 0
- patch: 5 (high 0, medium 2, low 3)
- defer: 4 (low 4)
- reject: 16 (low 16)
- addressed_findings:
  - `[medium]` `[patch]` Postgres concede `CONNECT` a `PUBLIC` por padrão em todo banco novo, o que enfraquecia o privilégio mínimo de AD-3 mesmo sem nenhum GRANT explícito adicional. Corrigido: `REVOKE CONNECT ... FROM PUBLIC` em `nouvet_n8n` e no banco da aplicação, logo após a criação, em `n8n/migrations/0001_bootstrap_bancos_e_papeis.sh`.
  - `[medium]` `[patch]` A única verificação automatizada existente (parse de YAML) não cobria os guards fail-fast de AD-2/AD-3 nem a separação de privilégio de AD-3 — uma regressão que removesse `:?` de uma senha/chave obrigatória, ou que concedesse `identidade_role`/`app_role` cruzado, passaria sem detecção neste ambiente sem Docker. Corrigido: dois novos comandos estáticos (sem Docker) adicionados a `## Verification` — um checando presença do guard `:?` para as 5 variáveis obrigatórias, outro checando (com remoção prévia de comentários SQL) que os GRANTs de `0002`/`0003` continuam disjuntos entre `app_role` e `identidade_role`. Ambos re-executados e confirmados `OK` após o patch.
  - `[low]` `[patch]` `identidade_cliente_pet.nome_cliente`/`nome_pet` eram `NOT NULL` mas aceitavam string vazia (`''`), o que corromperia buscas por identidade. Corrigido: `CHECK (nome_cliente <> '')` e `CHECK (nome_pet <> '')` adicionados em `n8n/migrations/0003_identidade_cliente_pet.sql`.
  - `[low]` `[patch]` Serviço `n8n` no `docker-compose.yml` não tinha `healthcheck` (só o `postgres` tinha), então `restart: unless-stopped` não detectaria um processo travado-mas-vivo. Corrigido: `healthcheck` via `wget --spider` em `/healthz` adicionado ao serviço `n8n`.
  - `[low]` `[patch]` `n8n/migrations/README.md` afirmava que o diretório "não cobre o banco interno do n8n", mas a `0001` cria esse banco (`nouvet_n8n`) — a frase lida isoladamente contradizia o que o diff faz. Corrigido: frase reescrita para deixar claro que o que não é coberto é o *schema* interno do n8n, não a criação do banco/papel em si.

### 2026-09-02 — Review pass (fresh review, spec status era `done`)
- intent_gap: 0
- bad_spec: 0
- patch: 2 (high 0, medium 1, low 1)
- defer: 1 (low 1)
- reject: 17 (low 17)
- addressed_findings:
  - `[medium]` `[patch]` Nenhuma verificação estática cobria a consistência entre os literais fixos `nouvet_n8n`/`n8n_role` hardcoded em `docker-compose.yml` (`DB_POSTGRESDB_DATABASE`/`DB_POSTGRESDB_USER`) e os mesmos literais criados em `n8n/migrations/0001_bootstrap_bancos_e_papeis.sh` (`CREATE DATABASE`/`CREATE ROLE`) — um rename futuro de um lado sem o outro só quebraria em runtime (n8n falha ao conectar no Postgres), sem nenhum check estático detectando antes. Corrigido: novo comando estático (sem Docker) adicionado a `## Verification`, extraindo os valores de `docker-compose.yml` e checando que ambos aparecem literalmente em `0001`. Re-executado e confirmado `OK`.
  - `[low]` `[patch]` `identidade_cliente_pet.nome_cliente`/`nome_pet` tinham `CHECK (col <> '')`, mas isso só rejeita string vazia — um valor só com espaços (`'   '`) passava, o que corromperia buscas por identidade do mesmo jeito que o vazio original. Corrigido: `CHECK` trocado para `btrim(nome_cliente) <> ''` / `btrim(nome_pet) <> ''` em `n8n/migrations/0003_identidade_cliente_pet.sql`.

## Design Notes

O bootstrap de papéis/bancos (`0001`) precisa de senha vinda de env var: se `.sql` puro, deixar placeholder documentado e trocar via `ALTER ROLE ... PASSWORD` pós-subida; se `.sh` (heredoc `psql <<-EOSQL ... EOSQL` lendo `$POSTGRES_APP_PASSWORD` etc.), seguir o padrão oficial da imagem `postgres` pra multi-db/multi-user num container. Qualquer um serve — o que não pode variar é o resultado (3 papéis mínimos, 2 bases, sem segredo fixo versionado). Nomes sugeridos: bancos `nouvet_n8n`/`nouvet_app`; papéis `n8n_role`/`app_role`/`identidade_role`.

## Verification

**Commands:**
- `python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))"` -- expected: parse sem erro (checagem de sintaxe YAML; Docker não está disponível neste ambiente de build para rodar `docker compose config`).
- `python3 -c "content = open('docker-compose.yml').read(); required = ['POSTGRES_SUPERUSER_PASSWORD','POSTGRES_N8N_ROLE_PASSWORD','POSTGRES_APP_ROLE_PASSWORD','POSTGRES_IDENTIDADE_ROLE_PASSWORD','N8N_ENCRYPTION_KEY']; missing = [v for v in required if '\${' + v + ':?' not in content]; assert not missing, missing; print('OK')"` -- expected: `OK` (checagem estática, sem Docker, de que nenhuma senha/chave obrigatória perdeu o guard fail-fast `:?` de AD-2/AD-3).
- `python3 -c "import re; strip = lambda s: re.sub(r'--.*', '', s); app = strip(open('n8n/migrations/0002_schema_operacional.sql').read()); ident = strip(open('n8n/migrations/0003_identidade_cliente_pet.sql').read()); assert 'identidade_role' not in app, '0002 nunca pode conceder a identidade_role'; assert 'app_role' not in ident, '0003 nunca pode conceder a app_role'; print('OK')"` -- expected: `OK` (checagem estática, sem Docker, de que os GRANTs de `app_role`/`identidade_role` permanecem disjuntos, AD-3; comentários SQL são removidos antes da checagem para não gerar falso positivo nas anotações cruzadas de escopo).
- `python3 -c "import re; compose = open('docker-compose.yml').read(); db = re.search(r'DB_POSTGRESDB_DATABASE:\s*(\S+)', compose).group(1); user = re.search(r'DB_POSTGRESDB_USER:\s*(\S+)', compose).group(1); bootstrap = open('n8n/migrations/0001_bootstrap_bancos_e_papeis.sh').read(); assert f'CREATE DATABASE {db};' in bootstrap, f'0001 nao cria o banco {db} esperado por docker-compose.yml'; assert f'CREATE ROLE {user} LOGIN' in bootstrap, f'0001 nao cria o papel {user} esperado por docker-compose.yml'; print('OK')"` -- expected: `OK` (checagem estática, sem Docker, de que o banco/papel do n8n hardcoded em `docker-compose.yml` — `DB_POSTGRESDB_DATABASE`/`DB_POSTGRESDB_USER` — continuam existindo literalmente em `n8n/migrations/0001_bootstrap_bancos_e_papeis.sh`; sem isso, um rename futuro de um lado sem o outro só quebraria em runtime, na conexão do n8n ao Postgres, sem nenhum check estático detectando antes).

**Manual checks (if no CLI):**
- Na VPS de dev (onde Docker está disponível): `docker compose up -d`, depois confirmar via `psql`/`\l`/`\du` que as 2 bases e os 3 papéis existem com os privilégios esperados, e `docker exec n8n n8n --version` / `docker exec <postgres> postgres --version` batendo com as tags pinadas antes de replicar na VPS de produção (AD-10).
- Confirmar manualmente que o valor real de `N8N_ENCRYPTION_KEY` no `.env` (nunca commitado) tem ao menos 32 caracteres hex antes do primeiro `docker compose up` em qualquer ambiente.

## Auto Run Result

**Resumo:** Nova passagem de revisão "fresh" sobre a story já `done` (reabertura solicitada explicitamente para reavaliar o diff completo desde `20cdfa1`, commit `09f9434` + `e0a5f9e`), cobrindo `docker-compose.yml`, `.env.example` e as migrations `0001`-`0003`/README já implementadas e já revisadas em duas passagens anteriores. Quatro camadas rodaram em paralelo (blind hunter, edge-case hunter, verification-gap, intent-alignment) sobre o diff completo. Nenhum `intent_gap`/`bad_spec`. A maioria dos achados novos era duplicata dos itens já deferidos nas duas passagens anteriores, alegação factualmente questionável, ou comportamento intencional (ex.: `docker compose up` falhar explicitamente com nomes de banco/papel mal configurados é o comportamento fail-fast desejado, não um bug). Dois achados reais e triviais foram corrigidos (`patch`) e um gap de validação legítimo, mas fora do escopo das ACs desta story, foi registrado no ledger de itens deferidos.

**Arquivos alterados nesta passagem:**
- `n8n/migrations/0003_identidade_cliente_pet.sql` -- `CHECK (nome_cliente <> '')`/`CHECK (nome_pet <> '')` trocados por `CHECK (btrim(nome_cliente) <> '')`/`CHECK (btrim(nome_pet) <> '')`, para rejeitar também nome só com espaços.
- `_bmad-output/specs/spec-atendimento-nouvet/stories/1-infra-e-persistencia-base.md` -- novo comando estático em `## Verification` checando consistência entre os literais `nouvet_n8n`/`n8n_role` de `docker-compose.yml` e `n8n/migrations/0001_bootstrap_bancos_e_papeis.sh`; 1 novo item em `deferred` (frontmatter); nova entrada em `## Review Triage Log`; este `## Auto Run Result`; `status` transicionado `done` → `in-review` → `done`; `review_loop_iteration` mantido em `0` (nenhum loopback de `bad_spec` disparado).

**Achados da revisão:**
- Patches aplicados: 2 (medium 1, low 1) -- ver `## Review Triage Log` → passe de 2026-09-02 (fresh review).
- Itens deferidos (novo, além dos 10 já existentes): 1, `low` -- colunas numéricas de `secretaria_config` (`sla_resposta_minutos`, `lock_ttl_minutos`, `max_followups`) sem `CHECK` de faixa; fica para quando a lógica de leitura/escrita desses valores em runtime for implementada.
- Itens rejeitados: 17 -- majoritariamente duplicatas de itens já deferidos nesta story (timezone/telemetria do n8n, falta de runner de migrations futuras, dedupe de `n8n_fila_mensagens`, índice em `rd_crm_contact_id`, trigger de `updated_at`, exposição do n8n sem proxy/TLS), além de casos de misconfiguração autoinfligida que falha explicitamente (comportamento fail-fast desejado, não bug), uma alegação sobre a tag de imagem do n8n não reproduzida com evidência, e sugestões estilísticas sem defeito real (ex. privilégios padrão do Postgres já restritivos, deixar explícito seria só documentação).
- Divergência descritiva (auditor de alinhamento de intenção, sem prescrever ação): as 4 ACs desta story são `Given/When/Then` sobre a stack rodando de verdade, mas toda a verificação existente (desta e das passagens anteriores) é estática, já que Docker não está disponível neste ambiente de build -- risco residual já documentado, não uma lacuna nova desta passagem.

**Verificação realizada:**
- Todos os 4 comandos estáticos de `## Verification` (parse YAML, guards `:?` das 5 variáveis obrigatórias, disjunção de GRANTs `app_role`/`identidade_role`, e o novo check de consistência `docker-compose.yml` ↔ `0001`) re-executados após os patches → `OK` em todos.
- `bash -n n8n/migrations/0001_bootstrap_bancos_e_papeis.sh` → sintaxe válida.
- Docker/psql confirmados indisponíveis neste ambiente de build; os checks manuais que exigem stack real seguem pendentes de execução na VPS de dev, como já documentado na própria story.

**Riscos residuais:**
- Mesmos riscos residuais já registrados nas passagens anteriores: comportamento em runtime (criação real de bancos/papéis, isolamento efetivo de privilégio, falha explícita sem `N8N_ENCRYPTION_KEY`, conexão real do n8n ao seu banco) segue verificado só por inspeção estática, sem execução real neste ambiente.
- 11 itens em `deferred` (10 pré-existentes + 1 novo) permanecem como dívida técnica conhecida e documentada, sem bloquear esta story; ficam sob responsabilidade do orquestrador (ledger `deferred-work.md`) para priorização futura.

