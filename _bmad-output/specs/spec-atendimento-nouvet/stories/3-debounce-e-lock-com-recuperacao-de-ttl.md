---
title: 'Debounce e lock com recuperação de TTL (AD-5)'
type: 'feature'
created: '2026-09-02'
status: 'done'
baseline_revision: 'dff993272d51e1b7af91c5b973bdf99d5fa0fe4a'
review_loop_iteration: 0
followup_review_recommended: true
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: ['oversized']
deferred:
  - summary: >-
      lock_conversa_liberar não usa fencing token — uma execução genuinamente lenta
      (não travada por crash) que ultrapassa o TTL pode liberar o lock que uma outra
      execução já recuperou legitimamente, reabrindo a janela de duas execuções
      processando a mesma conversa.
    evidence: |-
      AD-5 (ARCHITECTURE-SPINE.md) descreve o "mecanismo mínimo obrigatório" sem
      mencionar fencing/token de posse, aceitando esse risco residual explicitamente
      ("um Error Trigger... é bem-vindo mas não substitui a checagem de TTL"); achado
      do review adversarial (blind hunter), não introduzido além do que a própria
      arquitetura já assume como risco conhecido.
    location: >-
      n8n/migrations/0005_debounce_lock_ttl.sql (lock_conversa_liberar)
    severity: medium
  - summary: >-
      lock_conversa_adquirir não valida p_ttl_minutos NULL/zero/negativo -- NULL faz a
      função nunca recuperar o lock (falha fechada), zero ou negativo faz todo lock
      parecer sempre expirado (derruba a exclusão mútua).
    evidence: |-
      Mesma lacuna já registrada em DW-11 (secretaria_config.lock_ttl_minutos sem CHECK
      de faixa), agora com consumidor real e concreto pela primeira vez; achado do
      review adversarial (edge-case hunter).
    location: >-
      n8n/migrations/0005_debounce_lock_ttl.sql (lock_conversa_adquirir); DW-11
    severity: low
  - summary: >-
      lock_conversa_adquirir/lock_conversa_liberar não fixam SET search_path.
    evidence: |-
      Mesma lacuna de hardening já registrada em DW-14 para secretaria_config_ler,
      agora duplicada nas duas novas funções; achado do review adversarial (blind
      hunter).
    location: >-
      n8n/migrations/0005_debounce_lock_ttl.sql
    severity: low
  - summary: >-
      Migration 0005 usa ALTER TABLE/CREATE UNIQUE INDEX sem guards de idempotência
      (IF NOT EXISTS) -- falha se reaplicada contra um cluster já migrado.
    evidence: |-
      Mesma classe de problema já registrada em DW-1 para o bootstrap 0001; achado do
      review adversarial (blind hunter).
    location: >-
      n8n/migrations/0005_debounce_lock_ttl.sql
    severity: low
  - summary: >-
      CREATE UNIQUE INDEX em n8n_fila_mensagens(id_mensagem) falharia se já existirem
      linhas com id_mensagem duplicado (ex. dado de dev/teste remanescente).
    evidence: |-
      Baixo risco prático hoje -- nenhum workflow ainda escreve em n8n_fila_mensagens
      (Story 5 pendente), então a tabela está vazia em qualquer ambiente atual; achado
      do review adversarial (edge-case hunter).
    location: >-
      n8n/migrations/0005_debounce_lock_ttl.sql
    severity: low
  - summary: >-
      O uso real do dedup de enfileiramento (INSERT ... ON CONFLICT (id_mensagem) DO
      NOTHING) e da marcação de processada continuam pendentes -- esta story só entrega
      o pré-requisito de schema, não o workflow que os consome.
    evidence: |-
      DW-3 foi marcado resolved (instrução explícita do invocador), mas seu texto
      original nomeava o mecanismo de dedup em uso real, não só o schema; achado do
      review adversarial (intent-alignment). Consumo real fica para a Story 5 (CAP-1,
      "01 - Agente.json").
    location: >-
      n8n/migrations/0005_debounce_lock_ttl.sql; Story 5
    severity: low
  - summary: >-
      app_role mantém os GRANTs diretos de UPDATE/INSERT em n8n_status_atendimento
      (herdados da 0002) sem revogação -- qualquer node do fluxo de ingestão pode
      contornar lock_conversa_adquirir/lock_conversa_liberar com um UPDATE cru,
      derrubando a exclusão mútua que esta story existe para garantir.
    evidence: |-
      Mesma classe de gap já registrada em DW-12/DW-16 para secretaria_config, mas
      nunca rastreada para a tabela de lock -- aqui é mais consequente, pois é
      exatamente a garantia de atomicidade que esta story entrega; achado do review
      adversarial (blind hunter).
    location: >-
      n8n/migrations/0002_schema_operacional.sql (GRANT de app_role em
      n8n_status_atendimento); n8n/migrations/0005_debounce_lock_ttl.sql
    severity: medium
  - summary: >-
      Migration 0005 não usa BEGIN/COMMIT explícito -- se o CREATE UNIQUE INDEX falhar
      (ex. dado duplicado pré-existente, DW-22), os ALTER TABLE/backfill anteriores já
      teriam sido commitados, deixando o schema parcialmente migrado sem caminho de
      recuperação documentado.
    evidence: |-
      Mesma classe de risco de migration não-atômica já aceita nas migrations
      anteriores (0001-0004, nenhuma delas usa BEGIN/COMMIT explícito tampouco); achado
      do review adversarial (blind hunter), não introduzido além do padrão já existente
      no diretório.
    location: >-
      n8n/migrations/0005_debounce_lock_ttl.sql
    severity: low
  - summary: >-
      secretaria_config_ler (0004) não expõe lock_ttl_minutos em nenhuma das fases
      ('triagem'/'setor') -- não existe porta única (AD-1) pela qual quem for chamar
      lock_conversa_adquirir (Story 5) obtenha o TTL sem ler a tabela diretamente.
    evidence: |-
      O intent desta story exige "TTL vem de secretaria_config.lock_ttl_minutos (nunca
      hardcoded)", mas secretaria_config_ler só devolve as fatias 'triagem'/'setor' do
      JSON, nenhuma incluindo lock_ttl_minutos -- confirmado lendo
      0004_config_leitura_seletiva.sql; achado do review adversarial (blind hunter), fora
      do escopo desta story (Code Map/Tasks não tocam a 0004).
    location: >-
      n8n/migrations/0004_config_leitura_seletiva.sql (secretaria_config_ler); Story 5
    severity: medium
  - summary: >-
      .claude/skills/n8n-agent-patterns/references/agente-e-subfluxos.md ainda descreve
      o lock da ingestão de forma genérica (SELECT+UPDATE separados), sem citar as novas
      funções atômicas lock_conversa_adquirir/lock_conversa_liberar.
    evidence: |-
      O doc de referência do padrão de ingestão não foi atualizado por esta story -- o
      Code Map só cita a diferença a não replicar, não pede atualização do doc; achado do
      review adversarial (blind hunter).
    location: >-
      .claude/skills/n8n-agent-patterns/references/agente-e-subfluxos.md
    severity: low
  - summary: >-
      .claude/skills/n8n-agent-patterns/references/config-postgres.md ainda mostra o
      schema anterior à 0005 (sem lock_adquirido_em/processada).
    evidence: |-
      Doc de referência de schema ficou desatualizado após a 0005; achado do review
      adversarial (blind hunter).
    location: >-
      .claude/skills/n8n-agent-patterns/references/config-postgres.md
    severity: low
  - summary: >-
      Migration 0005 não documenta um caminho de rollback/down-migration (duas ALTER
      TABLE + backfill + índice único + duas funções).
    evidence: |-
      Nenhuma das migrations 0001-0004 documenta rollback tampouco, mas a 0005 é a
      primeira com múltiplos passos interdependentes (ALTER + backfill + índice +
      funções), tornando um rollback manual mais arriscado que nas anteriores; achado do
      review adversarial (blind hunter).
    location: >-
      n8n/migrations/0005_debounce_lock_ttl.sql
    severity: low
---

<intent-contract>

## Intent

**Problem:** `n8n_fila_mensagens`/`n8n_status_atendimento` (Story 1) só têm o schema cru — não existe mecanismo de lock de concorrência com recuperação de TTL (AD-5); sem recuperação atômica, um crash no meio do processamento trava o telefone para sempre (achado CRÍTICO do review adversarial), e sem dedup de enfileiramento um retry de webhook duplicaria mensagem na fila.

**Approach:** Duas funções Postgres atômicas (mesma "porta única" da Story 2) — `lock_conversa_adquirir(p_session_id, p_ttl_minutos)` (UPSERT single-statement que adquire o lock se estiver livre OU se `lock_adquirido_em` já passou do TTL) e `lock_conversa_liberar(p_session_id)` — mais duas colunas de schema (`n8n_status_atendimento.lock_adquirido_em`, `n8n_fila_mensagens.processada`) e um índice único de dedup (`n8n_fila_mensagens.id_mensagem`). Resolve DW-2 e DW-3.

## Boundaries & Constraints

**Always:** TTL vem de `secretaria_config.lock_ttl_minutos` (nunca hardcoded); aquisição de lock — livre ou recuperado por TTL — é sempre um único statement atômico (`UPSERT` com `WHERE` na cláusula `DO UPDATE`), nunca dois round-trips separados (`SELECT` depois `UPDATE`), pois é exatamente essa janela entre leitura e escrita que permitiria duas execuções concorrentes acharem o lock livre ao mesmo tempo; enfileiramento de mensagem usa `ON CONFLICT (id_mensagem) DO NOTHING` (dedup de retry de webhook); "consumir" mensagens da fila após processar marca/apaga só os ids específicos já agregados naquela execução, nunca `DELETE ... WHERE telefone = ...` cego (apagaria mensagem nova chegada durante a espera). `REVOKE EXECUTE ... FROM PUBLIC` antes de `GRANT ... TO app_role` nas novas funções, nunca a `identidade_role` (AD-3), mesmo padrão da Story 2.

**Block If:** Nenhuma decisão bloqueante identificada — nomes exatos das colunas/funções e se `processada` é boolean ou enum de status ficam a critério de quem implementa, dentro das invariantes acima.

**Never:** Não inclui os nodes n8n reais do fluxo de ingestão (webhook, `Wait`, reconsulta, agregação, chamada ao agente) — isso é a Story 5 (CAP-1, `01 - Agente.json`); esta story entrega só o contrato Postgres (schema + funções atômicas) que esse workflow vai consumir, mesmo padrão da Story 2 (`secretaria_config_ler`). Não mexe no ciclo de follow-up (`aguardando_followup`/`numero_followup`, Story 12/CAP-8). Não decide o momento exato de liberar o lock dentro do pacing de envio de mensagens (AD-7) — só documenta a invariante (lock permanece até a sequência de envio terminar) para quem construir esse workflow depois.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Lock livre | `lock_conversa=false` (ou sessão nova) | `lock_conversa_adquirir` retorna `TRUE`, seta `lock_conversa=true`, `lock_adquirido_em=now()` | Nenhum erro |
| Lock ocupado dentro do TTL | `lock_conversa=true`, `lock_adquirido_em` recente | Retorna `FALSE`, estado não muda | Nenhum erro |
| Lock travado além do TTL (crash) | `lock_conversa=true`, `lock_adquirido_em` mais antigo que `lock_ttl_minutos` | Retorna `TRUE`, recupera o lock, atualiza `lock_adquirido_em` | Nenhum erro |
| Duas chamadas concorrentes, mesma sessão, mesmo instante | Ambas veem lock livre/expirado | Exatamente uma recebe `TRUE` | Atomicidade via lock de linha do UPSERT, nunca dupla aquisição |
| Mensagem duplicada (retry de webhook) | `id_mensagem` já presente na fila | `INSERT ... ON CONFLICT (id_mensagem) DO NOTHING` não duplica | Sem erro, sem nova linha |
| `p_session_id` inválido (`NULL`, vazio ou só espaço) | Chamada a `lock_conversa_adquirir` | Retorna `FALSE`, nenhuma linha inserida/atualizada | Nenhum erro (falha silenciosa, entrada tratada como inválida) |

</intent-contract>

## Code Map

- `n8n/migrations/0002_schema_operacional.sql` -- schema atual de `n8n_status_atendimento` (sem `lock_adquirido_em`) e `n8n_fila_mensagens` (sem `processada`/índice único) -- a `0005` altera via `ALTER TABLE`, nunca recria as tabelas.
- `n8n/migrations/0004_config_leitura_seletiva.sql` -- referência de estilo para função Postgres + `REVOKE EXECUTE ... FROM PUBLIC` antes de `GRANT ... TO app_role` -- mesmo padrão a seguir nas 2 novas funções.
- `n8n/migrations/0005_debounce_lock_ttl.sql` -- não existe ainda; criar. `ALTER TABLE n8n_status_atendimento ADD COLUMN lock_adquirido_em TIMESTAMP WITHOUT TIME ZONE`; `ALTER TABLE n8n_fila_mensagens ADD COLUMN processada BOOLEAN NOT NULL DEFAULT FALSE` + `CREATE UNIQUE INDEX` em `id_mensagem`; funções `lock_conversa_adquirir(p_session_id TEXT, p_ttl_minutos INTEGER) RETURNS BOOLEAN` e `lock_conversa_liberar(p_session_id TEXT) RETURNS VOID`, ambas com `REVOKE`/`GRANT EXECUTE` para `app_role`.
- `ARCHITECTURE-SPINE.md` AD-5 (regra completa + TTL de referência 5 min) e AD-7 (lock permanece durante todo o pacing de envio) -- invariantes centrais desta story.
- `.claude/skills/n8n-agent-patterns/references/agente-e-subfluxos.md` -- padrão de referência do fluxo de ingestão (enfileirar → travar → esperar → reconsultar → agregar → destravar); a referência usa `SELECT`+`UPDATE` separados para o lock, não atômico -- não replicar essa parte, é justamente o achado corrigido aqui.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- entradas `DW-2`/`DW-3` a marcar `resolved` ao concluir.

## Tasks & Acceptance

**Execution:**
- `n8n/migrations/0005_debounce_lock_ttl.sql` -- `ALTER TABLE` para `lock_adquirido_em` (status_atendimento) e `processada` + índice único `id_mensagem` (fila_mensagens); criar `lock_conversa_adquirir`/`lock_conversa_liberar` com `GRANT`/`REVOKE` -- fecha o achado crítico de recuperação de TTL não atômica e DW-2/DW-3.
- `n8n/migrations/README.md` -- acrescentar frase sobre a `0005` introduzir as funções de lock -- mesmo cuidado de changelog já feito na `0004`.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- marcar `DW-2` e `DW-3` como `status: resolved`, referenciando a `0005`.

**Acceptance Criteria:**
- Given os 5 cenários da I/O & Edge-Case Matrix, when reproduzidos contra a migration aplicada (ou mirror equivalente sem Docker), then o comportamento bate exatamente com a coluna "Expected Output/Behavior".
- Given o `GRANT EXECUTE` das duas novas funções, when se inspeciona `n8n/migrations/0005_debounce_lock_ttl.sql`, then `identidade_role` nunca aparece como concedido, e `REVOKE ... FROM PUBLIC` precede cada `GRANT ... TO app_role` correspondente.
- Given o ledger `deferred-work.md`, when esta story termina, then `DW-2` e `DW-3` aparecem com `status: resolved`.

## Spec Change Log

## Review Triage Log

### 2026-09-02 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 4 (high 1, medium 1, low 2)
- defer: 6 (medium 1, low 5)
- reject: 9 (low 9)
- addressed_findings:
  - `[high]` `[patch]` Migração `0005` deixava `lock_adquirido_em = NULL` para qualquer linha já com `lock_conversa = TRUE` no momento da migração (nenhum backfill), e a cláusula `OR lock_adquirido_em IS NULL` de `lock_conversa_adquirir` trata `NULL` como "recuperável" — resultado: toda conversa legitimamente em andamento no instante do deploy vira instantaneamente roubável, quebrando a exclusão mútua exatamente no momento mais sensível (deploy). Corrigido: `UPDATE n8n_status_atendimento SET lock_adquirido_em = COALESCE(lock_adquirido_em, updated_at, now()) WHERE lock_conversa = TRUE` adicionado logo após o `ADD COLUMN`, dando a qualquer lock já ativo uma janela de TTL completa a partir de `updated_at` (ou `now()` na ausência de um valor melhor) em vez de zero.
  - `[medium]` `[patch]` O comando de Verification que checa atomicidade (`INSERT ... ON CONFLICT ... DO UPDATE ... RETURNING`) só confirmava a presença dessas palavras-chave, nunca o conteúdo real do `WHERE` — reproduzido removendo o disjunto de expiração por TTL da cláusula `WHERE` e confirmando que os comandos 1, 2 e 4 continuavam `OK` (achado do review adversarial, verification-gap). Corrigido: comando reforçado para também extrair e inspecionar o texto do `WHERE` da cláusula `DO UPDATE`, exigindo a presença do comparador contra `lock_adquirido_em` e `make_interval`/TTL, não só as palavras-chave genéricas do UPSERT.
  - `[low]` `[patch]` `lock_conversa_adquirir` não tinha guard para `p_session_id` `NULL`/string vazia, inconsistente com o padrão já estabelecido em `secretaria_config_ler` (Story 2) de tratar entrada malformada do chamador como caso inválido em vez de criar uma linha "válida" para um identificador vazio. Corrigido: `INSERT ... SELECT ... WHERE p_session_id IS NOT NULL AND p_session_id <> ''` (troca de `VALUES` por `SELECT ... WHERE`), garantindo que entrada inválida nunca insere/atualiza linha e a função devolve `FALSE`.
  - `[low]` `[patch]` O motivo original de DW-3 nomeava o *mecanismo* de dedup (`ON CONFLICT ... DO NOTHING` em uso real) como o item adiado para esta story, não só o pré-requisito de schema — marcar DW-3 como `resolved` na íntegra (conforme instrução explícita do invocador) sem um ponteiro para o uso real que falta superestimaria o que foi corrigido (achado do review adversarial, intent-alignment). Corrigido: `DW-2`/`DW-3` mantidos `resolved` (instrução explícita respeitada), e uma nova entrada `deferred` adicionada ao frontmatter apontando que o `INSERT ... ON CONFLICT (id_mensagem) DO NOTHING` real e a marcação de `processada` seguem pendentes de uso pelo workflow de ingestão (Story 5).

### 2026-09-02 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 7 (high 1, medium 2, low 4)
- defer: 2 (medium 1, low 1)
- reject: 20 (medium 1, low 19)
- addressed_findings:
  - `[high]` `[patch]` A checagem estrutural que confirma o predicado de TTL no `WHERE` da cláusula `DO UPDATE` só verificava a presença das substrings `LOCK_ADQUIRIDO_EM`/`MAKE_INTERVAL`, nunca o disjunto `lock_conversa = FALSE` (o caso "lock livre", a linha mais básica da matriz) — demonstrado que trocar esse disjunto por `= TRUE` (quebrando a reconquista de um lock já liberado) passa `OK` em todos os 4 comandos de Verification existentes (achado do review adversarial, verification-gap). Corrigido: comando reforçado com `assert 'LOCK_CONVERSA = FALSE' in ttl_predicate`; mutação re-testada e agora falha corretamente.
  - `[medium]` `[patch]` Nenhum comando de Verification exercitava o backfill de `lock_adquirido_em` (`UPDATE ... WHERE lock_conversa = TRUE`) que corrige o achado `[high]` da passada anterior — demonstrado que removê-lo do arquivo ainda passa `OK` em todos os comandos existentes (achado do review adversarial, verification-gap + blind hunter). Corrigido: novo comando estrutural que localiza o `UPDATE` de backfill logo após o `ADD COLUMN` e falha se estiver ausente ou alterado; mutação re-testada e agora falha corretamente.
  - `[medium]` `[patch]` Nenhum comando de Verification tocava o corpo de `lock_conversa_liberar` — demonstrado que remover a cláusula `WHERE session_id = p_session_id` (destravando toda a tabela numa única chamada) ainda passa `OK` em todos os comandos existentes (achado do review adversarial, verification-gap). Corrigido: novo comando estrutural que extrai o corpo da função, confirma um único statement `UPDATE` e exige `WHERE session_id = p_session_id`; mutação re-testada e agora falha corretamente.
  - `[low]` `[patch]` O guard de `p_session_id` em `lock_conversa_adquirir` checava só `<> ''`, então um valor só-espaço (ex. `' '`) passava incólume e criava uma linha travada com identificador de lixo (achado do review adversarial, edge-case hunter). Corrigido: guard trocado para `btrim(p_session_id) <> ''`.
  - `[low]` `[patch]` A checagem de que o `INSERT` de `lock_conversa_adquirir` usa uma fonte guardada (`SELECT ... WHERE`, não `VALUES`) não tinha nenhuma cobertura automatizada — demonstrado que reverter para `VALUES (p_session_id, TRUE, now(), now())` incondicional ainda passa `OK` em todos os comandos existentes (achado do review adversarial, verification-gap). Corrigido: novo comando estrutural que extrai a fonte do `INSERT` e exige `SELECT`/`P_SESSION_ID IS NOT NULL`/`BTRIM(P_SESSION_ID) <> ''`, rejeitando `VALUES`; mutação re-testada e agora falha corretamente.
  - `[low]` `[patch]` A I/O & Edge-Case Matrix não tinha linha para `p_session_id` inválido, apesar do guard correspondente já existir desde a passada anterior (achado do review adversarial, blind hunter). Corrigido: nova linha adicionada à matriz.
  - `[low]` `[patch]` A entrada de log da passada anterior registrava `defer: 5 (medium 1, low 4)`, mas a lista `deferred` do frontmatter sempre teve 6 itens (medium 1, low 5) — contagem incorreta na própria passada (achado do review adversarial, blind hunter). Corrigido: contagem ajustada para `defer: 6 (medium 1, low 5)`.
  - Itens deferidos (novos): 2 (medium 1, low 1) -- ver frontmatter `deferred`: `app_role` mantém GRANTs diretos de UPDATE/INSERT em `n8n_status_atendimento` sem revogação, permitindo contornar as funções atômicas (mesma classe de DW-12/DW-16, nunca antes rastreada para a tabela de lock); migration `0005` sem `BEGIN`/`COMMIT` explícito (mesmo padrão já presente nas migrations 0001-0004, não introduzido por esta story).
  - Itens rejeitados: 20 (medium 1, low 19) -- incluindo: cabeçalhos truncados em `DW-18`/`DW-19`/`DW-23` (bug no ledger `deferred-work.md`, fora de escopo -- arquivo de propriedade do orquestrador, instrução explícita do invocador de não modificá-lo); contagem de `reject: 9` sem itemização (decisão de design já explícita do workflow -- "reject: Drop silently"); linha da matriz para `lock_conversa_liberar` em sessão inexistente (já rejeitado explicitamente na passada anterior: "baixo valor"); cross-referência de DW-2 para DW-18/DW-19 (cosmético); assimetria de encapsulamento entre lock e dedup (decisão de escopo já coberta por DW-23/Boundaries); `lock_conversa_liberar` sem guard de `p_session_id` NULL/vazio (sem consequência real -- `WHERE session_id = NULL` é no-op silencioso, nunca erro); índice composto `(telefone, processada)` (otimização prematura, nenhum consumidor real ainda existe); duplicação da ressalva de DW-3 entre o próprio DW-3 e o novo DW-23 (decisão intencional já documentada na passada anterior); 6 duplicatas de achados do edge-case hunter já cobertos por `DW-18`/`DW-19`/`DW-20`/`DW-21`/`DW-22` ou já rejeitados (`session_id` > 40 caracteres); assimetria de fronteira `<`/`<=` na expiração de TTL (janela de risco infinitesimal, cosmético); 4 pontos de divergência do intent-alignment (todos já esperados e explicitamente fora de escopo pelas seções Boundaries/Never do próprio intent -- uso real do dedup, atomicidade validada só estruturalmente, invariante de "consumir" sem enforcement, e wiring do TTL sem call site, todos aguardando a Story 5).

### 2026-09-02 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 1 (high 1)
- defer: 4 (medium 1, low 3)
- reject: 19 (medium 2, low 17)
- addressed_findings:
  - `[high]` `[patch]` O comando de Verification que checa a atomicidade/TTL (comando 4) só confirmava a *presença* das substrings `LOCK_ADQUIRIDO_EM`/`MAKE_INTERVAL`/`LOCK_CONVERSA = FALSE` no `WHERE` da cláusula `DO UPDATE`, nunca a *direção* do comparador -- demonstrado que trocar `lock_adquirido_em < now() - make_interval(...)` por `>` (invertendo por completo o que conta como "expirado") ainda passa `OK` nesse e em todos os outros comandos existentes (achado do review adversarial, blind hunter). Corrigido: novo `assert` com regex exigindo `LOCK_ADQUIRIDO_EM < NOW() - MAKE_INTERVAL` na ordem/direção corretas; mutação (`<`→`>`) re-testada e agora falha corretamente.
  - Itens deferidos (novos): 4 (medium 1, low 3) -- ver frontmatter `deferred`: `secretaria_config_ler` (0004) não expõe `lock_ttl_minutos` em nenhuma fase, sem porta única (AD-1) para quem for ler o TTL na Story 5 (medium); dois docs de referência do skill `n8n-agent-patterns` desatualizados em relação à 0005 (`agente-e-subfluxos.md` ainda descreve lock não-atômico, `config-postgres.md` ainda mostra schema pré-0005) (low, low); migration 0005 sem caminho de rollback/down-migration documentado, mais arriscado que as anteriores por ter múltiplos passos interdependentes (low).
  - Itens rejeitados: 19 (medium 2, low 17) -- todos duplicatas de itens já cobertos pelo frontmatter `deferred` existente ou já rejeitados/documentados em passadas anteriores, sem informação nova: 8 achados do edge-case hunter (NULL/zero/negativo de `p_ttl_minutos` -- já DW-11/item 2; falta de fencing token em `lock_conversa_liberar` -- já item 1; `p_session_id` > 40 caracteres -- já rejeitado passada anterior; `lock_conversa_liberar` sem guard NULL/inexistente -- já rejeitado passada anterior, no-op sem consequência real; falta `IF NOT EXISTS` -- já item 4; índice único falha com dado duplicado pré-existente -- já item 5; falta `BEGIN`/`COMMIT` -- já item 8); 4 pontos de divergência do intent-alignment (concorrência só validada estruturalmente e dedup não exercitado -- já documentados como "Risco residual" e item 6; GRANTs diretos de `app_role` não revogados -- já item 7; framing "resolved" de DW-2/DW-3 -- já explicado na passada anterior); do blind hunter, 6 achados cosméticos/sem consequência real (disjunto `OR lock_adquirido_em IS NULL` seria "código morto" -- na verdade defende contra o próprio bypass já rastreado no item 7, não documentar isso é cosmético; ausência de `CHECK` constraint reforçando o invariante lock/timestamp -- mesma classe do item 7; `CREATE UNIQUE INDEX` sem `CONCURRENTLY` -- o próprio reviewer already apontou baixo risco, tabela vazia; `lock_conversa_liberar` sem forma de detectar liberação de sessão já destrancada -- mesma raiz do item 1, fencing token; status `done` coexistindo com itens `deferred` médios -- semântica do próprio workflow, não é defeito de código; funções sem declaração explícita de volatilidade -- cosmético, `VOLATILE` default já é o comportamento correto); e o achado único do verification-gap reviewer (nenhum comando de Verification executa SQL real contra Postgres) -- já documentado explicitamente no próprio `## Verification` ("Risco residual") e na seção `Manual checks`, sem informação nova.

## Design Notes

`lock_conversa_adquirir` é a peça crítica: um único `INSERT ... ON CONFLICT (session_id) DO UPDATE ... WHERE <lock livre OU TTL expirado> RETURNING TRUE`, envolto em `COALESCE(..., FALSE)` para nunca devolver `NULL`. O `WHERE` da cláusula `DO UPDATE` é o que torna a operação atômica: duas transações concorrentes disputam o lock de linha do `UPSERT`, e só uma enxerga a condição como verdadeira depois que a outra já commitou. Exemplo de uso:

```sql
SELECT lock_conversa_adquirir('5511999998888', 5); -- true = obteve o lock agora
SELECT lock_conversa_liberar('5511999998888');
```

AD-7 (pacing de envio) implica que quem chamar `lock_conversa_liberar` deve fazê-lo só depois de toda a sequência de mensagens pausadas ser enviada, nunca logo após computar a resposta — decisão de quando chamar é de quem constrói o workflow de envio (fora desta story), documentada aqui como invariante a não violar.

## Verification

**Commands:**
- `python3 -c "content = open('n8n/migrations/0005_debounce_lock_ttl.sql').read(); up = content.upper(); assert 'ADD COLUMN LOCK_ADQUIRIDO_EM' in up, 'coluna de timestamp de lock ausente (DW-2)'; assert 'ADD COLUMN PROCESSADA' in up, 'coluna de status/processado ausente (DW-3)'; assert 'CREATE UNIQUE INDEX' in up and 'ID_MENSAGEM' in up, 'indice unico de dedup ausente (DW-3)'; assert 'LOCK_CONVERSA_ADQUIRIR' in up and 'LOCK_CONVERSA_LIBERAR' in up, 'funcoes de lock ausentes'; print('OK')"` -- expected: `OK` (checagem estática de que as duas colunas, o índice de dedup e as duas funções existem no arquivo).
- Checagem estática de que cada função segue o padrão `REVOKE ... FROM PUBLIC` antes de `GRANT ... TO app_role` (mesma ordem exigida na Story 2) e nunca concede a `identidade_role`:
  ```bash
  python3 << 'PYEOF'
  content = open('n8n/migrations/0005_debounce_lock_ttl.sql').read()
  up = content.upper()
  assert 'IDENTIDADE_ROLE' not in up, 'nunca conceder a identidade_role'
  for fn in ['LOCK_CONVERSA_ADQUIRIR', 'LOCK_CONVERSA_LIBERAR']:
      i_revoke = up.find(f'REVOKE EXECUTE ON FUNCTION {fn}')
      i_grant = up.find(f'GRANT EXECUTE ON FUNCTION {fn}')
      assert i_revoke != -1 and i_grant != -1 and i_revoke < i_grant, f'{fn}: REVOKE precisa preceder o GRANT'
      assert 'FROM PUBLIC' in up[i_revoke:i_grant], f'{fn}: REVOKE precisa ser FROM PUBLIC'
      assert 'TO APP_ROLE' in up[i_grant:i_grant+80], f'{fn}: GRANT precisa ser TO app_role'
  print('OK')
  PYEOF
  ```
  -- expected: `OK`.
- Mirror em Python da lógica de decisão de `lock_conversa_adquirir` (sem Postgres disponível neste ambiente de build), cobrindo as 3 primeiras linhas da I/O & Edge-Case Matrix (lock livre, lock ocupado dentro do TTL, lock travado além do TTL):
  ```bash
  python3 << 'PYEOF'
  from datetime import datetime, timedelta

  def lock_conversa_adquirir(row, ttl_minutos, now):
      livre = row is None or not row['lock_conversa']
      expirado = (row is not None and row['lock_conversa']
                  and row['lock_adquirido_em'] is not None
                  and (now - row['lock_adquirido_em']) > timedelta(minutes=ttl_minutos))
      if livre or expirado:
          return True, {'lock_conversa': True, 'lock_adquirido_em': now}
      return False, row

  now = datetime(2026, 9, 2, 12, 0, 0)

  ok, novo = lock_conversa_adquirir(None, 5, now)
  assert ok is True and novo['lock_conversa'] is True

  row = {'lock_conversa': True, 'lock_adquirido_em': now - timedelta(minutes=2)}
  ok, novo = lock_conversa_adquirir(row, 5, now)
  assert ok is False and novo is row

  row = {'lock_conversa': True, 'lock_adquirido_em': now - timedelta(minutes=6)}
  ok, novo = lock_conversa_adquirir(row, 5, now)
  assert ok is True and novo['lock_adquirido_em'] == now

  print('OK')
  PYEOF
  ```
  -- expected: `OK`. Cobre as 3 primeiras linhas da matriz (lock livre, ocupado dentro do TTL, travado além do TTL).
- Checagem estrutural de que `lock_conversa_adquirir` é um único statement atômico (`INSERT ... ON CONFLICT ... DO UPDATE ... RETURNING`, nunca um `SELECT` seguido de `UPDATE` em statements separados) **e de que o `WHERE` da cláusula `DO UPDATE` de fato contém o predicado de expiração por TTL** (comparação contra `lock_adquirido_em` junto com `make_interval`, não só as palavras-chave genéricas do UPSERT -- sem isto, remover o disjunto de TTL e deixar só `WHERE lock_conversa = FALSE` passaria batido, reintroduzindo silenciosamente o "lock nunca recupera" que esta story existe para corrigir) -- cobre a linha 4 da matriz (duas chamadas concorrentes): a garantia de "exatamente uma recebe `TRUE`" vem do lock de linha que o Postgres aplica nativamente durante um único `INSERT ... ON CONFLICT`, então verificar que a função é de fato um statement só (e não dois round-trips) e que a condição de recuperação de TTL não foi silenciosamente removida é a evidência disponível sem um Postgres vivo:
  ```bash
  python3 << 'PYEOF'
  import re
  content = open('n8n/migrations/0005_debounce_lock_ttl.sql').read()
  m = re.search(r'FUNCTION lock_conversa_adquirir\(.*?\)\s*RETURNS BOOLEAN.*?AS \$\$(.*?)\$\$;', content, re.S)
  assert m, 'funcao lock_conversa_adquirir nao encontrada'
  body = m.group(1)
  statements = [s.strip() for s in body.strip().rstrip(';').split(';') if s.strip()]
  assert len(statements) == 1, f'corpo deve ser um unico statement atomico, achou {len(statements)}'
  up = statements[0].upper()
  assert 'INSERT INTO N8N_STATUS_ATENDIMENTO' in up, 'precisa ser um INSERT (upsert), nao SELECT+UPDATE separados'
  assert 'ON CONFLICT' in up and 'DO UPDATE' in up, 'precisa usar ON CONFLICT ... DO UPDATE (upsert atomico)'
  assert 'RETURNING' in up, 'precisa RETURNING para saber se o upsert efetivamente aplicou'
  do_update_block = re.search(r'DO UPDATE(.*?)RETURNING', up, re.S)
  assert do_update_block, 'clausula DO UPDATE nao encontrada'
  where_clause = re.search(r'WHERE(.*)', do_update_block.group(1), re.S)
  assert where_clause, 'DO UPDATE precisa ter clausula WHERE (senao a atualizacao seria incondicional)'
  ttl_predicate = where_clause.group(1)
  assert 'LOCK_ADQUIRIDO_EM' in ttl_predicate, 'WHERE da DO UPDATE precisa comparar lock_adquirido_em -- predicado de expiracao por TTL ausente'
  assert 'MAKE_INTERVAL' in ttl_predicate, 'WHERE da DO UPDATE precisa calcular o TTL via make_interval (ou equivalente) -- nao so checar lock_conversa = FALSE'
  assert 'LOCK_CONVERSA = FALSE' in ttl_predicate, 'WHERE da DO UPDATE precisa manter o disjunto lock_conversa = FALSE (lock livre) -- sem ele, trocar esse disjunto por TRUE (ou removê-lo) passaria batido nos dois asserts acima e quebraria silenciosamente o caso mais básico da matriz (lock livre nunca mais reconquistado), achado do review adversarial (verification-gap)'
  assert re.search(r'LOCK_ADQUIRIDO_EM\s*<\s*NOW\(\)\s*-\s*MAKE_INTERVAL', ttl_predicate), 'comparacao precisa ser lock_adquirido_em < now() - make_interval(...) -- os 3 asserts acima só confirmam presenca de substrings, nao a direcao do operador; inverter para ">" (ou remover o "<") faria todo lock parecer sempre expirado ou nunca expirado e ainda passaria nos 3 asserts anteriores, achado do review adversarial (blind hunter)'
  print('OK')
  PYEOF
  ```
  -- expected: `OK`.
- Checagem estrutural de que `lock_conversa_adquirir` insere via `SELECT ... WHERE` guardado (nunca `VALUES` incondicional) e que o guard cobre tanto `p_session_id` `NULL` quanto vazio/só-espaço -- sem isto, um regressão que trocasse a fonte do `INSERT` de volta para `VALUES` (ou removesse o `btrim`) passaria pelos comandos 1 e 4 acima sem ser detectada, reabrindo o achado `[low]` de entrada inválida criando linha (achado do review adversarial, verification-gap + edge-case hunter):
  ```bash
  python3 << 'PYEOF'
  import re
  content = open('n8n/migrations/0005_debounce_lock_ttl.sql').read()
  m = re.search(r'FUNCTION lock_conversa_adquirir\(.*?\)\s*RETURNS BOOLEAN.*?AS \$\$(.*?)\$\$;', content, re.S)
  assert m, 'funcao lock_conversa_adquirir nao encontrada'
  body_up = m.group(1).upper()
  insert_source = re.search(r'INSERT INTO N8N_STATUS_ATENDIMENTO\s*\([^)]*\)\s*(.*?)ON CONFLICT', body_up, re.S)
  assert insert_source, 'fonte do INSERT nao encontrada'
  guard = insert_source.group(1)
  assert 'VALUES' not in guard, 'INSERT precisa vir de SELECT ... WHERE guardado, nunca VALUES incondicional -- senao p_session_id invalido insere linha'
  assert guard.strip().startswith('SELECT'), 'fonte do INSERT precisa ser um SELECT'
  assert 'P_SESSION_ID IS NOT NULL' in guard, 'guard de p_session_id NULL ausente na fonte do INSERT'
  assert 'BTRIM(P_SESSION_ID)' in guard and "<> ''" in guard, 'guard de p_session_id vazio/so-espaco (btrim) ausente na fonte do INSERT'
  print('OK')
  PYEOF
  ```
  -- expected: `OK`.
- Checagem estrutural de que `lock_conversa_liberar` é um único statement (`UPDATE`) restrito por `WHERE session_id = p_session_id` -- sem isto, uma regressão que removesse esse `WHERE` destravaria TODAS as sessões da tabela numa única chamada, e nenhum outro comando de Verification desta story toca o corpo de `lock_conversa_liberar` (achado do review adversarial, verification-gap):
  ```bash
  python3 << 'PYEOF'
  import re
  content = open('n8n/migrations/0005_debounce_lock_ttl.sql').read()
  m = re.search(r'FUNCTION lock_conversa_liberar\(.*?\)\s*RETURNS VOID.*?AS \$\$(.*?)\$\$;', content, re.S)
  assert m, 'funcao lock_conversa_liberar nao encontrada'
  statements = [s.strip() for s in m.group(1).strip().rstrip(';').split(';') if s.strip()]
  assert len(statements) == 1, f'corpo deve ser um unico statement, achou {len(statements)}'
  up = statements[0].upper()
  assert up.startswith('UPDATE N8N_STATUS_ATENDIMENTO'), 'precisa ser um UPDATE em n8n_status_atendimento'
  where_clause = re.search(r'WHERE(.*)', up, re.S)
  assert where_clause, 'UPDATE precisa de clausula WHERE -- sem ela, destrava TODAS as sessoes de uma vez'
  assert 'SESSION_ID = P_SESSION_ID' in where_clause.group(1).replace(chr(10), ' '), 'WHERE precisa restringir por session_id = p_session_id -- senao destrava toda a tabela'
  print('OK')
  PYEOF
  ```
  -- expected: `OK`.
- Checagem de que o backfill de `lock_adquirido_em` (o achado `[high]` já corrigido) permanece presente logo após o `ADD COLUMN` -- sem isto, uma regressão que removesse ou enfraquecesse esse `UPDATE` reabriria silenciosamente a janela de "lock roubável no deploy" sem que nenhum outro comando detectasse (achado do review adversarial, verification-gap + blind hunter):
  ```bash
  python3 << 'PYEOF'
  import re
  content = open('n8n/migrations/0005_debounce_lock_ttl.sql').read()
  up = content.upper()
  add_idx = up.find('ADD COLUMN LOCK_ADQUIRIDO_EM')
  assert add_idx != -1, 'ADD COLUMN lock_adquirido_em nao encontrado'
  backfill = re.search(r'UPDATE\s+N8N_STATUS_ATENDIMENTO\s+SET\s+LOCK_ADQUIRIDO_EM\s*=\s*COALESCE\(\s*LOCK_ADQUIRIDO_EM\s*,\s*UPDATED_AT\s*,\s*NOW\(\)\s*\)\s+WHERE\s+LOCK_CONVERSA\s*=\s*TRUE', up[add_idx:], re.S)
  assert backfill, 'backfill de lock_adquirido_em (COALESCE com updated_at/now(), WHERE lock_conversa = TRUE) ausente ou alterado logo apos o ADD COLUMN'
  print('OK')
  PYEOF
  ```
  -- expected: `OK`.
- Checagem estrutural de que o índice único de dedup mira exatamente `id_mensagem` (não um índice composto que enfraqueceria o dedup) -- cobre a linha 5 da matriz (mensagem duplicada): dado esse índice, `INSERT ... ON CONFLICT (id_mensagem) DO NOTHING` (a ser usado pelo workflow de ingestão, fora desta story) tem dedup garantido pelo próprio Postgres, comportamento documentado e determinístico que não exige execução empírica para ser confiável:
  ```bash
  python3 << 'PYEOF'
  import re
  content = open('n8n/migrations/0005_debounce_lock_ttl.sql').read()
  up = content.upper()
  m = re.search(r'CREATE UNIQUE INDEX \S+ ON N8N_FILA_MENSAGENS \(([^)]+)\)', up)
  assert m, 'CREATE UNIQUE INDEX em n8n_fila_mensagens nao encontrado no formato esperado'
  assert m.group(1).strip() == 'ID_MENSAGEM', f'indice unico precisa ser exatamente sobre id_mensagem, achou {m.group(1)}'
  print('OK')
  PYEOF
  ```
  -- expected: `OK`. **Risco residual:** nenhum dos comandos acima substitui um teste de concorrência real (duas conexões `psql` simultâneas) nem uma inserção duplicada de fato contra Postgres vivo -- ver Manual checks.

**Manual checks (if no CLI):**
- Na VPS de dev (Docker disponível): aplicar `0005`; abrir duas conexões `psql` simultâneas e disparar `SELECT lock_conversa_adquirir('5511999998888', 5)` nas duas ao mesmo tempo (ex. via `\watch` ou dois terminais), confirmar que só uma retorna `TRUE`; forçar `lock_adquirido_em` manualmente para além do TTL e confirmar que uma nova chamada recupera o lock; inserir duas vezes o mesmo `id_mensagem` em `n8n_fila_mensagens` e confirmar que a segunda não duplica.

## Auto Run Result

**Resumo da mudança implementada:** Terceira passada de review adversarial (fresh follow-up review, sem novo código de intenção) sobre o mesmo diff acumulado desde `baseline_revision` — a migration `0005_debounce_lock_ttl.sql` (funções `lock_conversa_adquirir`/`lock_conversa_liberar` com recuperação de TTL, AD-5), o changelog do README e este spec. Quatro reviewers (blind hunter, edge-case hunter, verification-gap, intent-alignment) rodaram em paralelo contra os 470 KB do diff acumulado (excluindo `deferred-work.md`, ledger de propriedade do orquestrador que esta execução foi instruída a não tocar); 1 achado `patch` de severidade `high` foi corrigido — outro gap de verificação que deixava a checagem de atomicidade vulnerável a uma regressão silenciosa, desta vez na *direção* do comparador de TTL (não só na presença das palavras-chave).

**Arquivos alterados nesta passada:**
- `_bmad-output/specs/spec-atendimento-nouvet/stories/3-debounce-e-lock-com-recuperacao-de-ttl.md` -- este arquivo: novo `assert` de regex no comando 4 de Verification, exigindo a direção correta do comparador (`lock_adquirido_em < now() - make_interval(...)`, não só a presença das substrings); 4 novos itens `deferred` no frontmatter; nova entrada de Review Triage Log; este resultado.
- Nenhum outro arquivo de produção (`n8n/migrations/0005_debounce_lock_ttl.sql`, `n8n/migrations/README.md`) foi alterado nesta passada -- o achado corrigido era na suíte de Verification do spec, não no código da migration.

**Review findings (esta passada):**
- Patches aplicados: 1 (high 1):
  - `[high]` O comando de Verification que checa a atomicidade/TTL (comando 4) só confirmava a *presença* das substrings `LOCK_ADQUIRIDO_EM`/`MAKE_INTERVAL`/`LOCK_CONVERSA = FALSE`, nunca a *direção* do comparador -- demonstrado que trocar `lock_adquirido_em < now() - make_interval(...)` por `>` (invertendo por completo o que conta como "expirado": lock livre nunca mais reconquistado, ou lock sempre parecendo expirado) ainda passava `OK` em todos os comandos existentes. Corrigido com novo `assert` de regex exigindo a ordem/direção exatas; mutação re-testada e agora falha corretamente.
- Itens deferidos (novos): 4 (medium 1, low 3) -- ver frontmatter `deferred`: `secretaria_config_ler` (0004) não expõe `lock_ttl_minutos` em nenhuma fase do JSON, sem porta única (AD-1) pela qual a Story 5 possa ler o TTL sem acessar a tabela diretamente (medium); dois docs de referência do skill `n8n-agent-patterns` desatualizados em relação à 0005 (`agente-e-subfluxos.md` ainda descreve o lock não-atômico, `config-postgres.md` ainda mostra o schema pré-0005) (low, low); migration `0005` sem caminho de rollback/down-migration documentado, mais arriscada que as anteriores por ter múltiplos passos interdependentes (low).
- Itens rejeitados: 19 (medium 2, low 17) -- ver `## Review Triage Log` para a lista completa; todos duplicatas de itens já cobertos pelo frontmatter `deferred` existente (fencing token, validação de `p_ttl_minutos`, GRANTs diretos de `app_role`, idempotência, `BEGIN`/`COMMIT`, etc.) ou já rejeitados/documentados em passadas anteriores (`p_session_id` > 40 caracteres, `lock_conversa_liberar` sem guard NULL, ausência de teste de concorrência real contra Postgres vivo -- já explícito como "Risco residual" no próprio `## Verification`).

**Follow-up review recommendation:** `true`. Havia 1 patch `high` nesta passada, que por si só já aciona `true` (regra: `true` se qualquer achado `patch` for `high`, independente do score de medium/low). Contagem de patches por severidade: high 1, medium 0, low 0. Score (3×medium + 1×low) = 0, mas irrelevante dado o `high`.

**Verificação executada:**
- Os 8 comandos de `## Verification` re-executados após o patch -- `OK` em todos.
- Regressão de demonstração (mutation testing) para o novo `assert`: `lock_adquirido_em < now() - make_interval(...)` trocado por `>` -- antes do patch, passava `OK` em todos os comandos; depois do patch, o comando 4 agora falha corretamente com `AssertionError`.
- Docker/Postgres seguem indisponíveis neste ambiente de build (mesma limitação das passadas/Stories anteriores); testes de concorrência real e de dedup real seguem pendentes de execução na VPS de dev, como documentado em `## Verification > Manual checks`.

**Riscos residuais:**
- Os mesmos riscos residuais das passadas anteriores permanecem (concorrência real, `app_role` contornando as funções via GRANTs diretos, uso real do dedup pendente da Story 5) -- ver itens `deferred` no frontmatter (12 no total: 8 herdados + 4 novos desta passada).
- Novo risco residual registrado nesta passada: quem construir a Story 5 (Ingress) não tem hoje uma porta única (AD-1) documentada para ler `secretaria_config.lock_ttl_minutos` sem acessar a tabela diretamente, já que `secretaria_config_ler` (0004) não expõe esse campo em nenhuma fase.
- Verificação desta story continua inteiramente estática (checagens de texto/regex sobre o SQL + mirror Python da lógica de decisão) -- nenhum comando executa contra um Postgres vivo; documentado como risco residual desde a primeira passada e não resolvido nesta.

