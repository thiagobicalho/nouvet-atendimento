---
title: 'Identidade de cliente/pet e porta única idempotente (AD-6/AD-11)'
type: 'feature'
created: '2026-09-02'
status: 'done'
baseline_revision: '394fb371fb79cae571ad76c8a838bf513768fa65'
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: ['oversized']
deferred:
  - summary: >-
      identidade_role mantém GRANT direto de INSERT/UPDATE/DELETE em
      identidade_cliente_pet (herdado da 0003) sem revogação -- a "porta única" de
      AD-11 é uma convenção de código, não uma garantia de banco.
    evidence: |-
      Mesma classe de gap já registrada em DW-12/DW-16 (secretaria_config) e DW-24
      (n8n_status_atendimento) -- aqui nunca foi rastreada para a tabela de identidade;
      achado do review adversarial (blind hunter). Revogar exigiria SECURITY DEFINER ou
      esquema de papéis adicional, mudança estrutural maior, fora do escopo desta story.
    location: >-
      n8n/migrations/0003_identidade_cliente_pet.sql (GRANT SELECT, INSERT, UPDATE,
      DELETE ... TO identidade_role); n8n/migrations/0006_identidade_porta_unica.sql
    severity: medium
  - summary: >-
      telefone_normalizar sempre insere o 9º dígito em qualquer número local de 10
      dígitos, sem distinguir celular antigo de telefone fixo -- um fixo poderia ser
      normalizado para um número que colide com um celular real não relacionado.
    evidence: |-
      Risco baixo hoje porque o único canal é WhatsApp (AD-7, só celular) e nenhum
      import real do SimplesVet rodou ainda; relevante se a exportação do SimplesVet
      um dia incluir telefone fixo de contato; achado do review adversarial (edge-case
      hunter).
    location: >-
      n8n/migrations/0006_identidade_porta_unica.sql (telefone_normalizar)
    severity: medium
  - summary: >-
      CREATE UNIQUE INDEX case-insensitive em identidade_cliente_pet (0006) não trata
      dado pré-existente que já colida sob lower(btrim(nome_pet)) -- falharia se
      "Rex"/"rex" já existirem como linhas separadas antes desta migration rodar.
    evidence: |-
      Mesma classe de risco já aceita em DW-1/DW-21/DW-22 (migrations sem guard de
      idempotência/dado pré-existente); baixo risco prático hoje porque nenhum
      workflow real ainda escreve em identidade_cliente_pet; achado do review
      adversarial (verification-gap).
    location: >-
      n8n/migrations/0006_identidade_porta_unica.sql (DROP CONSTRAINT / CREATE UNIQUE
      INDEX)
    severity: low
  - summary: >-
      possivel_duplicidade_familiar só enxerga linhas já commitadas -- duas chamadas
      genuinamente simultâneas do resolver para o mesmo nome de pet vindas de dois
      telefones reais diferentes podem, sob READ COMMITTED, não se verem mutuamente e
      nenhuma sinalizar duplicidade.
    evidence: |-
      Limite já reconhecido explicitamente em AD-11 na spine ("este segundo caso pode
      não ser 100% eliminado por normalização de telefone... são números realmente
      diferentes") -- comportamento aceito por design, documentado aqui como o
      mecanismo exato da lacuna para referência futura; achado do review adversarial
      (blind hunter).
    location: >-
      n8n/migrations/0006_identidade_porta_unica.sql (identidade_cliente_pet_resolver,
      CTE duplicidade)
    severity: low
  - summary: >-
      pg_advisory_xact_lock(hashtext(telefone)) usa hash de 32 bits como chave do lock
      -- colisão de hash entre telefones não relacionados os faria serializar entre si
      (latência, não incorretude).
    evidence: |-
      Risco desprezível na escala do Piloto (uma clínica, poucas conversas simultâneas);
      achado do review adversarial (blind hunter), documentado para referência caso o
      volume cresça muito no futuro.
    location: >-
      n8n/migrations/0006_identidade_porta_unica.sql (identidade_cliente_pet_resolver)
    severity: low
  - summary: >-
      identidade_cliente_pet_resolver não expõe forma de voltar especie_pet/raca_pet/
      rd_crm_contact_id para NULL depois de gravado uma vez -- COALESCE(EXCLUDED.x,
      tabela.x) preserva sempre o valor já conhecido, então uma correção legítima (ex.:
      espécie errada, card do RD CRM desvinculado) nunca consegue limpar o campo via a
      porta única.
    evidence: |-
      Trade-off direto do patch [medium] já aplicado nesta mesma story (que trocou
      overwrite incondicional por COALESCE para não perder dado em atualização parcial)
      -- resolver o oposto (permitir limpar) exigiria um mecanismo explícito de "limpar
      campo" (sentinela ou parâmetro dedicado), decisão de design fora do escopo de um
      patch trivial; achado do review adversarial (blind hunter / edge-case hunter).
    location: >-
      n8n/migrations/0006_identidade_porta_unica.sql (identidade_cliente_pet_resolver,
      CTE upsert)
    severity: medium
  - summary: >-
      pg_advisory_xact_lock(hashtext(telefone)) não tem timeout nem retry -- uma
      transação presa (ex.: sessão travada, erro de aplicação que nunca comita/aborta)
      bloquearia indefinidamente qualquer chamada futura do resolver para o mesmo
      telefone, sem sinal de erro visível pro caller.
    evidence: |-
      Primeiro uso de pg_advisory_xact_lock no diretório (0005 usa outro mecanismo de
      lock, não advisory lock) -- não há precedente estabelecido de padrão de
      timeout/retry para copiar; decisão de política de timeout é de design, fora do
      escopo de um patch trivial; achado do review adversarial (edge-case hunter).
    location: >-
      n8n/migrations/0006_identidade_porta_unica.sql (identidade_cliente_pet_resolver,
      CTE travado)
    severity: medium
  - summary: >-
      Não existe script de teste versionado no repositório que exercite os 8 cenários
      da I/O & Edge-Case Matrix contra um motor Postgres real -- a validação via
      @electric-sql/pglite mencionada no `## Verification` da story (e a validação
      equivalente feita nesta passada de review) rodou num diretório de scratch fora do
      repo, não reproduzível a partir do que está versionado.
    evidence: |-
      Achado do review adversarial (verification-gap) -- a única checagem
      automatizada persistida no repo é o comando estrutural (busca de texto/posição no
      SQL) e o mirror Python isolado de telefone_normalizar; nenhum dos dois exercita
      identidade_cliente_pet_buscar/identidade_cliente_pet_resolver contra um banco de
      verdade. Fora do escopo de um patch trivial (exigiria decidir onde/como versionar
      um script Node+pglite e sua dependência).
    location: >-
      n8n/migrations/0006_identidade_porta_unica.sql (identidade_cliente_pet_buscar,
      identidade_cliente_pet_resolver); ## Verification da story
    severity: medium
  - summary: >-
      As 3 novas funções (telefone_normalizar, identidade_cliente_pet_buscar,
      identidade_cliente_pet_resolver) não fixam SET search_path.
    evidence: |-
      Mesma lacuna de hardening já aceita a severidade baixa em DW-14
      (secretaria_config_ler, 0004) e DW-20 (lock_conversa_adquirir/lock_conversa_liberar,
      0005) -- padrão pré-existente no diretório, não uma regressão desta story; achado
      do review adversarial (blind hunter).
    location: >-
      n8n/migrations/0006_identidade_porta_unica.sql (telefone_normalizar,
      identidade_cliente_pet_buscar, identidade_cliente_pet_resolver)
    severity: low
  - summary: >-
      0006 usa ALTER TABLE/DROP CONSTRAINT e CREATE UNIQUE INDEX sem guards de
      idempotência (IF EXISTS/IF NOT EXISTS) -- falha se reaplicada contra um cluster
      já migrado.
    evidence: |-
      Mesma classe de risco já aceita em DW-21/DW-22 (migration 0005, mesmo padrão) --
      já citada como precedente aceito no próprio deferred existente desta story (ver
      item "CREATE UNIQUE INDEX case-insensitive ... não trata dado pré-existente");
      achado do review adversarial (blind hunter).
    location: >-
      n8n/migrations/0006_identidade_porta_unica.sql (DROP CONSTRAINT / CREATE UNIQUE
      INDEX)
    severity: low
  - summary: >-
      A CTE duplicidade compara lower(btrim(nome_pet)) entre telefones diferentes sem
      índice de apoio (o único índice único tem telefone como coluna líder) -- toda
      chamada do resolver faz um scan sequencial de identidade_cliente_pet pra checar
      duplicidade familiar.
    evidence: |-
      Risco desprezível na escala do Piloto (uma clínica, poucas linhas na tabela),
      mesma linha de raciocínio já aceita em DW-35 (colisão de hash do advisory lock);
      achado do review adversarial (blind hunter).
    location: >-
      n8n/migrations/0006_identidade_porta_unica.sql (identidade_cliente_pet_resolver,
      CTE duplicidade)
    severity: low
---

<intent-contract>

## Intent

**Problem:** `identidade_cliente_pet` (Story 1) só tem o schema cru — telefone nunca é normalizado de forma centralizada (AD-8), não existe mecanismo idempotente de escrita (AD-11) que absorva retry e as duas mensagens quase simultâneas de telefones diferentes do mesmo núcleo familiar (achado HIGH do review adversarial), e o `UNIQUE (telefone, nome_pet)` é case-sensitive e rejeita dois pets reais com o mesmo nome (DW-10). Sem índice em `rd_crm_contact_id` (DW-4), o caminho de lookup conversa→contato do RD CRM não existe.

**Approach:** Uma função `telefone_normalizar` única e centralizada (E.164 limpo, 9º dígito móvel, AD-8); duas funções Postgres sobre `identidade_cliente_pet` — `identidade_cliente_pet_buscar` (leitura, CAP-1) e `identidade_cliente_pet_resolver` (porta única idempotente de escrita, AD-11: lock consultivo por telefone normalizado + UPSERT); índice único trocado para case-insensitive `(telefone, lower(btrim(nome_pet)))` (resolve a metade case da DW-10); índice em `rd_crm_contact_id` (DW-4). Postgres só alimenta a decisão de criar/atualizar o card do RD CRM (AD-6) — cadastro definitivo no CRM em si é responsabilidade de story futura (FR-21).

## Boundaries & Constraints

**Always:** Telefone normalizado sempre via `telefone_normalizar` (nunca reimplementado inline, AD-8). Toda escrita em `identidade_cliente_pet` passa por `identidade_cliente_pet_resolver` — nunca `INSERT`/`UPDATE` direto de outro ponto (AD-6/AD-11), incluindo o import inicial do SimplesVet (`origem='import_simplesvet'`). `identidade_cliente_pet_resolver` adquire `pg_advisory_xact_lock(hashtext(telefone_normalizado))` antes de checar/gravar — o "lock consultivo por telefone normalizado" citado literalmente em AD-11. Chave natural de dedup = `(telefone, lower(btrim(nome_pet)))` — decisão desta story para DW-10: variação de caixa nunca cria linha nova; dois pets reais com nome idêntico no mesmo telefone são tratados como a mesma identidade (última chamada atualiza espécie/raça), limitação aceita e documentada, não um bug. `REVOKE EXECUTE ... FROM PUBLIC` antes de `GRANT ... TO <role>`; funções de leitura/escrita da tabela de identidade só para `identidade_role` (nunca `app_role`, AD-3); `telefone_normalizar` é utilitário genérico sem acesso a PII, concedido a `app_role` e `identidade_role`.

**Block If:** Nenhuma decisão bloqueante — nomes exatos das funções/índices ficam a critério de quem implementa, dentro das invariantes acima.

**Never:** Não inclui o sub-workflow n8n real (`toolWorkflow` que chama a API do RD CRM para checar contato existente, mover card, criar a Task de cadastro pendente no SimplesVet) — isso é de story(s) futura(s) (CAP-1/CAP-7) que consomem esta porta única Postgres como um dos passos, mesmo padrão de Story 2/3 (contrato de dados, não o node n8n). Não inclui dado real de import do SimplesVet (arquivo ainda não fornecido pela Btech) — só o processo documentado e reaplicável, reusando `identidade_cliente_pet_resolver`. Não decide o mecanismo de checagem de contato existente no RD CRM em si (isso é FR-21/Story 11) — só o sinal de `rd_crm_contact_id`/`possivel_duplicidade_familiar` que essa story futura vai consumir.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Telefone em qualquer formato aceito | `'+55 11 99999-8888'`, `'1199998888'` (sem DDI, sem 9º dígito), `'5511999998888'` | `telefone_normalizar` sempre retorna `'+5511999998888'` | Nenhum erro |
| Telefone não reconhecível como celular BR | `'abc'`, `''`, `NULL` | `telefone_normalizar` retorna `NULL` | Nenhum erro (entrada inválida, propaga NULL) |
| Cadastro novo (telefone+pet inéditos) | `identidade_cliente_pet_resolver(...)` | `INSERT`, retorno com `'criado': true` | Nenhum erro |
| Retry idempotente (mesmos dados, nova chamada) | `resolver(...)` chamado 2x seguidas com os mesmos dados | 2ª chamada não duplica linha; `'criado': false` na 2ª | Nenhum erro, nunca 2 linhas |
| Variação de caixa ou correção de dono (cônjuge) | `'Rex'`/`'rex'` mesmo telefone; ou `nome_cliente` diferente, mesmo telefone+pet | `UPDATE` na mesma linha (nunca 2ª linha); campos atualizados pro valor mais recente | Nenhum erro (implementa FR-4 "de graça" via UPSERT) |
| Duas chamadas concorrentes, mesmo telefone+pet | Retry 429/500 do RD CRM, ou 2 mensagens picadas | Lock consultivo serializa; exatamente 1 linha resulta | Atomicidade via `pg_advisory_xact_lock`, nunca linha duplicada |
| Núcleo familiar, 2 telefones distintos, mesmo pet | Telefone A já tem `'Rex'`; telefone B (cônjuge) cadastra `'Rex'` | 2 linhas distintas (telefones diferentes não colidem); retorno de B tem `'possivel_duplicidade_familiar': true` | Nenhum erro; sinal pro caller decidir alerta de revisão humana (AD-11) |
| Entrada inválida (`nome_cliente`/`nome_pet` vazio ou NULL) | `resolver(telefone válido, nome_cliente='', ...)` | Retorna `NULL`, nenhuma linha gravada | Nenhum erro (falha silenciosa, mesmo padrão de Story 2/3) |

</intent-contract>

## Code Map

- `n8n/migrations/0003_identidade_cliente_pet.sql` -- schema atual: `UNIQUE (telefone, nome_pet)` case-sensitive (constraint auto-nomeada `identidade_cliente_pet_telefone_nome_pet_key`), sem índice em `rd_crm_contact_id` -- a `0006` altera via `ALTER TABLE`/`DROP CONSTRAINT`, nunca recria a tabela.
- `n8n/migrations/0004_config_leitura_seletiva.sql`, `0005_debounce_lock_ttl.sql` -- referência de estilo: `REVOKE EXECUTE ... FROM PUBLIC` antes de `GRANT ... TO <role>`, funções `LANGUAGE sql` com CTEs para atomicidade (`0005` já usa `INSERT ... ON CONFLICT ... DO UPDATE ... WHERE` para o mesmo tipo de garantia que `identidade_cliente_pet_resolver` precisa).
- `n8n/migrations/0006_identidade_porta_unica.sql` -- não existe ainda; criar. `telefone_normalizar(TEXT) RETURNS TEXT`; `DROP CONSTRAINT identidade_cliente_pet_telefone_nome_pet_key` + `CREATE UNIQUE INDEX ... (telefone, lower(btrim(nome_pet)))`; `CREATE INDEX ... (rd_crm_contact_id) WHERE rd_crm_contact_id IS NOT NULL` (DW-4); `identidade_cliente_pet_buscar(TEXT) RETURNS JSONB`; `identidade_cliente_pet_resolver(...) RETURNS JSONB` com `pg_advisory_xact_lock`; `REVOKE`/`GRANT` de todas as funções.
- `n8n/migrations/README.md` -- acrescentar frase sobre a `0006` (mesmo padrão de changelog das `0004`/`0005`).
- `n8n/seed/README.md` -- acrescentar seção documentando o processo de import inicial do SimplesVet (staging + `identidade_cliente_pet_resolver`, `origem='import_simplesvet'`, sem dado real ainda).
- `ARCHITECTURE-SPINE.md` AD-6 (Postgres complementar ao CRM), AD-8 (normalização centralizada), AD-11 (porta única idempotente, texto literal do lock consultivo) -- invariantes centrais desta story.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- `DW-4`/`DW-10` a marcar `status: resolved`.

## Tasks & Acceptance

**Execution:**
- `n8n/migrations/0006_identidade_porta_unica.sql` -- criar `telefone_normalizar`, trocar o índice único de `identidade_cliente_pet` para case-insensitive, índice em `rd_crm_contact_id`, `identidade_cliente_pet_buscar`, `identidade_cliente_pet_resolver` (lock consultivo + UPSERT + sinal de duplicidade familiar), `GRANT`/`REVOKE` -- fecha o achado HIGH de duplicidade de card (AD-11), DW-4 e a metade case-insensitive de DW-10.
- `n8n/migrations/README.md` -- acrescentar frase sobre a `0006`.
- `n8n/seed/README.md` -- documentar processo de import inicial do SimplesVet via `identidade_cliente_pet_resolver`.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- marcar `DW-4` e `DW-10` como `status: resolved`, referenciando a `0006`.

**Acceptance Criteria:**
- Given os 8 cenários da I/O & Edge-Case Matrix, when reproduzidos contra a migration aplicada (ou mirror equivalente sem Docker), then o comportamento bate exatamente com a coluna "Expected Output/Behavior".
- Given o índice único de `identidade_cliente_pet`, when se inspeciona `0006`, then ele compara `telefone` e `lower(btrim(nome_pet))` -- nunca a coluna `nome_pet` crua.
- Given os `GRANT EXECUTE` de `identidade_cliente_pet_buscar`/`identidade_cliente_pet_resolver`, when se inspeciona `0006`, then só `identidade_role` aparece concedido (nunca `app_role`), e `REVOKE ... FROM PUBLIC` precede cada `GRANT` correspondente.
- Given o `GRANT EXECUTE` de `telefone_normalizar`, when se inspeciona `0006`, then tanto `app_role` quanto `identidade_role` aparecem concedidos.
- Given `identidade_cliente_pet`, when se inspecionam os índices, then existe um índice em `rd_crm_contact_id` (fecha DW-4).
- Given o ledger `deferred-work.md`, when esta story termina, then `DW-4` e `DW-10` aparecem com `status: resolved`.

## Spec Change Log

## Review Triage Log

### 2026-09-02 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 5 (medium 3, low 2)
- defer: 5 (medium 2, low 3)
- reject: 7 (low 7)
- addressed_findings:
  - `[medium]` `[patch]` `identidade_cliente_pet_resolver`'s `DO UPDATE` sobrescrevia `especie_pet`/`raca_pet` incondicionalmente (sem `COALESCE`, ao contrário de `rd_crm_contact_id`) -- uma chamada de correção de dono (cônjuge) que só manda `nome_cliente` apagaria espécie/raça já conhecidas. Corrigido: `COALESCE(EXCLUDED.x, identidade_cliente_pet.x)` aplicado também a `especie_pet`/`raca_pet`; confirmado via execução real (pglite) que uma correção parcial preserva os campos omitidos.
  - `[medium]` `[patch]` O comando de Verification que checa `GRANT`/`REVOKE` só iterava `identidade_cliente_pet_buscar` -- uma regressão que concedesse `identidade_cliente_pet_resolver` (porta de escrita de PII) a `app_role` passaria batida, achado demonstrado por mutação. Corrigido: `identidade_cliente_pet_resolver(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT)` adicionado ao loop, com janela de checagem relativa ao fim do match (a assinatura de 7 args passa de 80 chars).
  - `[medium]` `[patch]` `assert 'LOWER(BTRIM(NOME_PET))' in up` era uma busca de substring sem escopo -- passava mesmo se o `CREATE UNIQUE INDEX` fosse revertido pra case-sensitive, porque a mesma expressão aparece também no `ON CONFLICT` e na CTE `duplicidade`; demonstrado por mutação. Corrigido: checagem agora localiza o statement `CREATE UNIQUE INDEX idx_identidade_cliente_pet_telefone_nome_pet` primeiro e confirma a expressão case-insensitive só dentro dele.
  - `[low]` `[patch]` Runbook de import do SimplesVet (`n8n/seed/README.md`) não dizia o que fazer quando `identidade_cliente_pet_resolver` retorna `NULL` (linha inválida) ou `possivel_duplicidade_familiar: true` durante a carga em lote. Corrigido: frase adicionada exigindo log/revisão manual desses dois sinais, nunca descarte silencioso.
  - `[low]` `[patch]` A ambiguidade DDI-55-vs-DDD-55 (comentada no próprio SQL) não tinha teste cobrindo o caso. Corrigido: novo caso no mirror Python confirmando que um número de 11 dígitos começando em `55` (DDD Santa Catarina/RS) nunca é lido como DDI.

### 2026-09-02 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 4 (medium 1, low 3)
- defer: 6 (medium 3, low 3)
- reject: 9 (low 9)
- addressed_findings:
  - `[medium]` `[patch]` `identidade_cliente_pet_resolver` não validava `p_origem` contra o domínio do `CHECK (origem IN ('import_simplesvet', 'cadastro_direto'))` da 0003 -- um `origem` inválido chegava ao `INSERT` e estourava uma violação de `CHECK` não tratada, quebrando o contrato de falha silenciosa (retorno `NULL`) que o resto da função segue para as demais entradas inválidas. Corrigido: filtro `AND origem IN ('import_simplesvet', 'cadastro_direto')` adicionado à CTE `valida`; confirmado via execução real (pglite) que um `p_origem` inválido agora retorna `NULL` sem gravar linha e sem lançar exceção.
  - `[low]` `[patch]` `n8n/migrations/README.md` descrevia a `0006` sem mencionar `possivel_duplicidade_familiar` -- o sinal que resolve o achado HIGH original (duplicidade de card no núcleo familiar) ficava ausente do índice do diretório. Corrigido: frase adicionada.
  - `[low]` `[patch]` `n8n/seed/README.md` não avisava sobre o risco de `telefone_normalizar` normalizar incorretamente um telefone fixo do export do SimplesVet (DW-32) durante o import inicial. Corrigido: parágrafo de atenção adicionado, referenciando o item já registrado no deferred.
  - `[low]` `[patch]` `n8n/seed/README.md` não dizia se o import em lote era seguro de retomar após falha parcial. Corrigido: frase adicionada explicando que cada chamada do `resolver` é independentemente idempotente, então retomar reprocessando as linhas pendentes é seguro.
- Verificação desta passada: re-executados os 3 comandos do `## Verification` da story (checagem estrutural, mirror Python de `telefone_normalizar`, checagem do ledger) -- `OK` nos três. Adicionalmente, executados os 8 cenários da I/O & Edge-Case Matrix e o novo caso de `p_origem` inválido contra um motor Postgres real via `@electric-sql/pglite` (script `run.mjs`, diretório de scratch fora do repo, não versionado -- ver item `defer` sobre ausência de script de teste versionado): todos passaram, incluindo checagem de `GRANT`/`REVOKE` via `information_schema.role_routine_grants`.
- Achados rejeitados como ruído/fora de escopo: 4 restatavam itens já cobertos pelos `deferred` existentes (DW-32/33/34/35); 1 sobre o índice de `rd_crm_contact_id` não ter função de leitura própria nesta story (explicitamente fora de escopo pelo `Never` do intent-contract, que reserva o consumo desse sinal pra story futura FR-21/Story 11); 1 sobre número estrangeiro de 11 dígitos ser aceito como BR (especulativo, único canal é WhatsApp BR, AD-7); 1 sobre ausência de `COMMENT ON FUNCTION` (sem convenção estabelecida no diretório); 1 sobre trocar o índice único por `ADD CONSTRAINT ... UNIQUE USING INDEX` para permitir FK futura (especulativo, nenhum consumidor FK existe hoje, achado com confiança baixa do próprio revisor); 1 sobre títulos truncados/com erro de digitação nas entradas `DW-32`/`DW-33`/`DW-34` recém-adicionadas a `deferred-work.md` -- real, mas fora da autoridade desta passada (a instrução de invocação deste run proíbe explicitamente modificar entradas do ledger; reportado ao usuário fora deste arquivo, não tratado aqui).

### 2026-09-02 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 1 (low 1)
- defer: 0
- reject: 13 (low 13)
- addressed_findings:
  - `[low]` `[patch]` `0006` criava o novo índice único case-insensitive `(telefone, lower(btrim(nome_pet)))` mas não removia `idx_identidade_cliente_pet_telefone` (índice simples de `telefone`, criado na `0003`) -- como `telefone` é a coluna líder do novo índice composto, o antigo ficava redundante (regra de prefixo de índice do Postgres: o novo já cobre sozinho qualquer busca só por `telefone`), só adicionando overhead de escrita sem ganho de leitura. Achado do review adversarial (blind hunter), confirmado consultando `0003` diretamente. Corrigido: `DROP INDEX idx_identidade_cliente_pet_telefone;` adicionado a `0006` logo após a criação do novo índice único; confirmado via execução real (pglite) que o índice antigo desaparece de `pg_indexes` e os 9 cenários (8 da matriz + `p_origem` inválido) continuam passando.
- Achados rejeitados como ruído/já coberto: 5 restatavam achados já cobertos pelos `deferred` existentes desta story (DW-31 grant não revogado; COALESCE sem forma de limpar campo; funções sem `SET search_path` fixo; índice único case-insensitive não tratando dado pré-existente; DW-38 sobre ausência de script de teste versionado contra Postgres real -- este último citado por dois revisores diferentes (verification-gap e intent-alignment) mais o auditor de intenção, todos convergindo no mesmo gap já registrado); 2 sobre `identidade_cliente_pet_resolver`/`identidade_cliente_pet_buscar` devolverem `NULL` (em vez de erro explícito ou array vazio) para entrada inválida/zero resultados -- comportamento intencional documentado literalmente no `<intent-contract>` ("Retorna NULL, nenhuma linha gravada... Nenhum erro (falha silenciosa, mesmo padrão de Story 2/3)") e no comentário do próprio SQL; 1 sobre `telefone_normalizar` normalizar incorretamente um número de 12 dígitos malformado começando em "55" (especulativo, mesma classe já rejeitada na passada anterior sobre números estrangeiros -- único canal é WhatsApp BR, AD-7); 1 sobre o filtro `origem IN (...)` duplicar o domínio do `CHECK` da tabela (observação real de duplicação, mas sem correção simples que não adicione complexidade desproporcional -- a validação existe justamente para preservar o contrato de falha silenciosa, não pode ser removida, e espelhar o `CHECK` dinamicamente via `information_schema` seria over-engineering para um patch trivial); 1 sobre ausência de script de rollback/"down" para `0006` (nenhuma migration do diretório -- `0002` a `0005` -- tem rollback script; convenção já estabelecida, não uma regressão desta story); 1 sobre READMEs não documentarem o que o sub-workflow n8n em tempo real deve fazer ao receber `NULL` do resolver (fora de escopo pelo `Never` do intent-contract -- esse sub-workflow é de story futura, CAP-1/CAP-7; o runbook de import do SimplesVet, que É desta story, já documenta isso); 1 sobre o truque `(xmax = 0)` ser instável se hint bits forem limpos por autovacuum (falso positivo -- `RETURNING` avalia `xmax` na mesma execução do comando `INSERT ... ON CONFLICT`, antes de qualquer vacuum rodar); 1 repetindo o achado sobre títulos truncados de `DW-32`/`DW-33`/`DW-34`/`DW-38` em `deferred-work.md` -- mesmo achado real já identificado na passada anterior, mesma razão de fora da autoridade desta passada (instrução de invocação proíbe modificar entradas do ledger).
- Verificação desta passada: re-executados os 3 comandos do `## Verification` da story -- `OK` nos três (o comando estrutural já cobre o novo `DROP INDEX`). Adicionalmente, reexecutados os 8 cenários da I/O & Edge-Case Matrix mais o caso de `p_origem` inválido contra um motor Postgres real via `@electric-sql/pglite`, incluindo checagem explícita de que `idx_identidade_cliente_pet_telefone` desaparece de `pg_indexes` após `0006` e que `idx_identidade_cliente_pet_telefone_nome_pet` permanece -- todos passaram (script em diretório de scratch fora do repo, não versionado -- mesmo gap já registrado em DW-38).

## Design Notes

`identidade_cliente_pet_resolver` é `LANGUAGE sql` com CTEs (mesmo estilo de `lock_conversa_adquirir`), não `plpgsql` — mantém o padrão de função-única-statement já estabelecido no diretório. O `INSERT ... ON CONFLICT (telefone, (lower(btrim(nome_pet)))) DO UPDATE` mira a expressão do índice único (não uma constraint nomeada), então a sintaxe de conflict target usa parênteses extras em torno da expressão. Exemplo de uso pretendido (a Story futura que constrói o sub-workflow n8n de AD-11 chama isto, nunca grava direto):

```sql
SELECT identidade_cliente_pet_buscar('+5511999998888');
SELECT identidade_cliente_pet_resolver('11999998888', 'Mariana', 'Rex', 'Cachorro', NULL, 'cadastro_direto', NULL);
```

`possivel_duplicidade_familiar` no retorno é só um sinal (booleano) -- a decisão de criar a Task de revisão humana no card do RD CRM (AD-11) é do sub-workflow n8n que consome esta função, não desta story.

## Verification

**Commands:**
- Checagem estrutural de que `0006` contém as 3 funções, o novo índice único case-insensitive (checado especificamente dentro do texto do `CREATE UNIQUE INDEX`, não em qualquer lugar do arquivo), o índice de `rd_crm_contact_id`, o lock consultivo, e que nem `identidade_cliente_pet_buscar` nem `identidade_cliente_pet_resolver` concedem a `app_role`:
  ```bash
  python3 << 'PYEOF'
  content = open('n8n/migrations/0006_identidade_porta_unica.sql').read()
  up = content.upper()
  assert 'CREATE OR REPLACE FUNCTION TELEFONE_NORMALIZAR' in up
  assert 'CREATE OR REPLACE FUNCTION IDENTIDADE_CLIENTE_PET_BUSCAR' in up
  assert 'CREATE OR REPLACE FUNCTION IDENTIDADE_CLIENTE_PET_RESOLVER' in up
  assert 'PG_ADVISORY_XACT_LOCK' in up, 'lock consultivo por telefone (AD-11) ausente'
  assert 'DROP CONSTRAINT' in up and 'IDENTIDADE_CLIENTE_PET_TELEFONE_NOME_PET_KEY' in up
  i_idx = up.find('CREATE UNIQUE INDEX IDX_IDENTIDADE_CLIENTE_PET_TELEFONE_NOME_PET')
  assert i_idx != -1, 'indice unico case-insensitive nao encontrado'
  i_idx_end = up.find(';', i_idx)
  assert 'LOWER(BTRIM(NOME_PET))' in up[i_idx:i_idx_end], 'indice unico precisa ser case-insensitive (DW-10)'
  assert 'RD_CRM_CONTACT_ID' in up and 'CREATE INDEX' in up, 'indice de DW-4 ausente'
  for fn in ['IDENTIDADE_CLIENTE_PET_BUSCAR(TEXT)', 'IDENTIDADE_CLIENTE_PET_RESOLVER(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT)']:
      i_revoke = up.find(f'REVOKE EXECUTE ON FUNCTION {fn}')
      i_grant = up.find(f'GRANT EXECUTE ON FUNCTION {fn}')
      assert i_revoke != -1 and i_grant != -1 and i_revoke < i_grant, f'{fn}: revoke/grant ausente ou fora de ordem'
      # janela relativa ao FIM do match (nao ao inicio) -- a assinatura de 7 args do
      # resolver por si so passa de 80 chars, entao uma janela fixa a partir do inicio
      # do GRANT cortaria o " TO identidade_role;" antes de aparecer.
      i_grant_role = i_grant + len(f'GRANT EXECUTE ON FUNCTION {fn}')
      assert 'APP_ROLE' not in up[i_grant_role:i_grant_role+40], f'{fn}: nunca concede a app_role'
      assert 'IDENTIDADE_ROLE' in up[i_grant_role:i_grant_role+40]
  i_revoke_norm = up.find('REVOKE EXECUTE ON FUNCTION TELEFONE_NORMALIZAR')
  i_grant_norm = up.find('GRANT EXECUTE ON FUNCTION TELEFONE_NORMALIZAR')
  assert i_revoke_norm < i_grant_norm
  assert 'APP_ROLE' in up[i_grant_norm:i_grant_norm+80] and 'IDENTIDADE_ROLE' in up[i_grant_norm:i_grant_norm+80]
  print('OK')
  PYEOF
  ```
  -- expected: `OK`.
- Mirror em Python da lógica de `telefone_normalizar` (sem Postgres disponível neste ambiente de build), cobrindo as duas primeiras linhas da matriz e o caso de borda DDI-vs-DDD (`55` como início de um DDD de 11 dígitos, não um DDI, nunca deve ser removido por engano):
  ```bash
  python3 << 'PYEOF'
  import re
  def normalizar(t):
      if t is None: return None
      d = re.sub(r'\D', '', t)
      if len(d) >= 12 and d[:2] == '55':
          local = d[2:]
      else:
          local = d
      if len(local) == 10:
          local = local[:2] + '9' + local[2:]
      return f'+55{local}' if len(local) == 11 else None
  assert normalizar('+55 11 99999-8888') == '+5511999998888'
  assert normalizar('1199998888') == '+5511999998888'
  assert normalizar('5511999998888') == '+5511999998888'
  assert normalizar('551199998888') == '+5511999998888'
  assert normalizar('abc') is None
  assert normalizar('') is None
  assert normalizar(None) is None
  # 11 digitos comecando em '55' sem DDI separado (DDD 55 = Santa Catarina/RS) nunca
  # deve ser lido como DDI+numero de 9 digitos -- o strip de DDI so age com >= 12
  # digitos, entao aqui o '55' inicial e DDD, nao DDI, e o numero local de 11 digitos
  # fica intacto, ganhando o '+55' de DDI normal na frente.
  assert normalizar('55999998888') == '+5555999998888'
  print('OK')
  PYEOF
  ```
  -- expected: `OK`. **Risco residual:** mirror da lógica, não execução real da função SQL num Postgres vivo neste comando específico -- porém, ao contrário das Stories 1-3, esta passada validou `0002`-`0006` de fato, executando contra um motor Postgres real via `@electric-sql/pglite` (WASM) num diretório de scratch fora do repo; os 8 cenários da I/O & Edge-Case Matrix rodaram e passaram contra SQL real, não só o mirror (ver `## Auto Run Result`). Ainda assim, validar com a stack real (Docker) na VPS de dev antes do go-live -- `pglite` é um motor Postgres compatível mas não é o Postgres 16.15-alpine3.24 pinado em produção (AD-10).
- `python3 -c "content = open('_bmad-output/implementation-artifacts/deferred-work.md').read(); import re; assert re.search(r'DW-4:.*?\nstatus: resolved', content, re.S); assert re.search(r'DW-10:.*?\nstatus: resolved', content, re.S); print('OK')"` -- expected: `OK` (DW-4 e DW-10 marcados resolved no ledger).

**Manual checks (if no CLI):**
- Na VPS de dev (Docker disponível): aplicar `0006`; chamar `identidade_cliente_pet_resolver` duas vezes com os mesmos dados e confirmar que não duplica linha; abrir duas conexões `psql` simultâneas chamando o resolver para o mesmo telefone+pet e confirmar que só uma cria a linha, a outra atualiza; testar `identidade_cliente_pet_buscar` com um telefone em formatos diferentes e confirmar que sempre resolve pro mesmo cliente.

## Auto Run Result

**Resumo da mudança implementada:** Porta única idempotente de identidade cliente/pet (AD-6/AD-11) via `n8n/migrations/0006_identidade_porta_unica.sql`: `telefone_normalizar` (normalização centralizada, AD-8), `identidade_cliente_pet_buscar` (leitura, CAP-1), `identidade_cliente_pet_resolver` (escrita única idempotente com lock consultivo por telefone + UPSERT + sinal de duplicidade familiar, AD-11), índice único trocado para case-insensitive `(telefone, lower(btrim(nome_pet)))` (metade case da DW-10) e índice em `rd_crm_contact_id` (DW-4). Esta passada (review via `bmad-build-auto`) rodou uma nova rodada adversarial de 4 lentes sobre o diff completo desde o baseline e aplicou 1 patch trivial.

**Arquivos alterados (desde `394fb37`, baseline desta story):**
- `n8n/migrations/0006_identidade_porta_unica.sql` -- novo; 3 funções, troca de índice único, novo índice; patch desta passada: `DROP INDEX idx_identidade_cliente_pet_telefone` (índice da `0003` que ficou redundante).
- `n8n/migrations/README.md` -- frase descrevendo a `0006`.
- `n8n/seed/README.md` -- runbook de import inicial do SimplesVet via `identidade_cliente_pet_resolver`.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- `DW-4`/`DW-10` marcados `resolved`; `DW-31`..`DW-41` adicionados (achados de risco residual das passadas anteriores).
- `_bmad-output/specs/spec-atendimento-nouvet/stories/4-identidade-cliente-pet-porta-unica-idempotente.md` -- este arquivo (spec da story).

**Review findings desta passada (4 lentes: blind hunter, edge-case hunter, verification-gap, intent-alignment):** 1 patch (low) aplicado; 0 defer (nada novo -- todos os achados substantivos já estavam cobertos pelos itens `deferred` existentes desta story); 13 reject (ruído, especulativo, comportamento intencional documentado no `<intent-contract>`, ou fora da autoridade desta passada). Ver `## Review Triage Log` acima para detalhe completo.

**Follow-up review recommendation:** `false`. Score desta passada: 1 patch de severidade `low` (0 high, 0 medium, 1 low) -> `3×0 + 1×1 = 1`, abaixo do limiar 5; nenhum patch de severidade `high`.

**Verificação realizada:** Reexecutados os 3 comandos versionados do `## Verification` da story -- `OK` nos três (o comando estrutural passou a cobrir também o novo `DROP INDEX`). Validação adicional contra motor Postgres real via `@electric-sql/pglite` (script `run.mjs`, diretório de scratch fora do repo): aplicadas `0003`+`0006` patcheadas, confirmado que `idx_identidade_cliente_pet_telefone` desaparece de `pg_indexes` e `idx_identidade_cliente_pet_telefone_nome_pet` permanece; reexecutados os 8 cenários da I/O & Edge-Case Matrix mais o caso de `p_origem` inválido -- todos passaram; `GRANT`/`REVOKE` confirmados via `information_schema.role_routine_grants` (`app_role` nunca aparece em `identidade_cliente_pet_buscar`/`identidade_cliente_pet_resolver`).

**Riscos residuais:** Nenhum novo. Os riscos residuais conhecidos permanecem os já documentados em `deferred` (frontmatter desta story) e no ledger `deferred-work.md` (`DW-31`..`DW-41`), destacando-se `DW-38` (ausência de script de teste versionado que exercite as funções contra Postgres real -- toda validação real desta e das passadas anteriores, incluindo a validação do patch desta passada, rodou em diretório de scratch fora do repo) e `DW-31` (porta única é convenção de código, não garantia de banco -- `identidade_role` ainda tem `GRANT` direto de `INSERT`/`UPDATE`/`DELETE` herdado da `0003`). Adicionalmente, fora deste arquivo: as entradas `DW-32`/`DW-33`/`DW-34`/`DW-38` em `deferred-work.md` têm títulos truncados/cortados no meio da frase (achado real, identificado nesta e na passada anterior) -- fora da autoridade desta execução por instrução explícita de invocação que proíbe modificar entradas do ledger; reportado aqui para que o usuário corrija diretamente.


