---
title: 'Config-as-Data (AD-1)'
type: 'feature'
created: '2026-09-02'
status: 'done'
baseline_revision: 'ac1480b074b0886d92f844308e78a00c16080e11'
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: ['oversized']
deferred:
  - summary: >-
      Nenhuma barreira de privilégio garante que secretaria_config só é acessada via
      secretaria_config_ler — app_role já tem SELECT, INSERT, UPDATE e DELETE diretos
      na tabela (concedido na Story 1), então a "porta única" é uma convenção de
      código, não uma garantia de banco; o risco cobre leitura e escrita direta, não
      só leitura.
    evidence: |-
      Revogar acesso direto de app_role e permitir leitura só via função exigiria
      SECURITY DEFINER ou um esquema de papéis adicional — mudança estrutural maior,
      fora do escopo desta story; achado do review adversarial (blind hunter), com a
      abrangência real do GRANT (SELECT/INSERT/UPDATE/DELETE, não só SELECT)
      confirmada no follow-up review.
    location: >-
      n8n/migrations/0002_schema_operacional.sql (GRANT SELECT, INSERT, UPDATE,
      DELETE ... TO app_role); n8n/migrations/0004_config_leitura_seletiva.sql
    severity: medium
  - summary: >-
      Não existe fonte única que fixe os nomes exatos de setor usados como chave de
      filtro (p_setor) — glossary.md lista 8 setores distintos (Care Center, Exames,
      Consultas, Vacinas, Orçamentos, Internação, Oncologia, Financeiro), mas o PRD
      §4.4 descreve Consultas e Vacinas como um único agente/fluxo "por analogia".
    evidence: |-
      A Story 5/6 precisa decidir se passa p_setor distintos para Consultas e Vacinas ou
      unifica — comparação por string exata sem lista canônica é risco de resultado
      vazio silencioso; achado do review adversarial (blind hunter).
    location: >-
      n8n/migrations/0004_config_leitura_seletiva.sql; glossary.md
    severity: medium
  - summary: >-
      secretaria_config_ler não fixa SET search_path.
    evidence: |-
      Hardening geral de função Postgres; risco baixo aqui porque a função não é
      SECURITY DEFINER e roda com privilégio do chamador (app_role), mas é uma boa
      prática ausente; achado do review adversarial (blind hunter).
    location: >-
      n8n/migrations/0004_config_leitura_seletiva.sql
    severity: low
  - summary: >-
      secretaria_config_ler não trata explicitamente o caso da linha singleton (id=1)
      ainda não existir (seed não aplicado) — retorna NULL silenciosamente.
    evidence: |-
      Comportamento coerente com o caso já documentado de fase inválida (NULL, nunca
      dump), mas sem guard/erro explícito para esse cenário operacional específico;
      achado do review adversarial (edge-case hunter).
    location: >-
      n8n/migrations/0004_config_leitura_seletiva.sql
    severity: low
---

<intent-contract>

## Intent

**Problem:** `secretaria_config` (Story 1) existe mas está vazia e sem nenhum contrato de leitura — qualquer node futuro do agente (Story 5+) poderia ser tentado a fazer `SELECT *`/dump completo, violando AD-1 e a preocupação de custo/tamanho de prompt já confirmada por Thiago.

**Approach:** Uma função Postgres única (`secretaria_config_ler`) que é a única porta de leitura, sempre devolvendo uma fatia por fase da conversa — `triagem` (antes do setor ser classificado) ou `setor` (depois, com a fatia daquele setor) — nunca a linha inteira; e um seed SQL manual (`n8n/seed/`) que popula a linha singleton (`id=1`) com tom, catálogo de serviços do Care Center, limiares de SLA/lock, lista interina de sinais de alerta e placeholders documentados para o que ainda não foi fornecido (contatos de plantonista, mapeamento de stage do funil, dados institucionais).

## Boundaries & Constraints

**Always:** `secretaria_config_ler(p_fase, p_setor)` nunca faz `SELECT *` nem serializa a linha inteira — cada ramo (`CASE`) monta só o subconjunto de campos daquela fase via `jsonb_build_object`; fase desconhecida retorna `NULL`, nunca cai num fallback que devolva tudo. `GRANT EXECUTE` só para `app_role` (nunca `identidade_role`, AD-3). Seed usa `ON CONFLICT (id) DO NOTHING` — idempotente, sem duplicar a linha singleton. Nenhum segredo/credencial de integração no seed (AD-2) — a tabela já não tem coluna pra isso. Strings de setor no `catalogo_servicos`/consultas usam os nomes exatos do glossário (`Care Center`, `Exames`, `Consultas`, `Vacinas`, `Orçamentos`), com acentuação.

**Block If:** Nenhuma decisão bloqueante — dado de negócio real ainda não fornecido (endereço/telefone/horário institucional, contatos reais de plantonista, mapeamento de `stage_id` do funil RD CRM) fica `NULL`/`[]`/`{}` com comentário SQL explicando a pendência, mesmo padrão de Assumption/Open Question já registrado no SPEC (não bloqueia build, bloqueia só o go-live).

**Never:** Não inclui o node/consulta dentro do workflow do agente que efetivamente chama essa função (isso é Story 5/6, quando `01 - Agente.json` for criado) — esta story entrega só o contrato de dados que essas stories vão consumir. Não popula `secretaria_profissionais` (fora do escopo desta story). Não inclui UI de autoatendimento de config (Deferred na spine).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Fase triagem | `p_fase='triagem'` | JSON com tom, dados institucionais mínimos, `sinais_alerta_clinico`, `destinatarios_emergencia` — sem `catalogo_servicos`/`exames_exigem_anestesia`/stage | Nenhum erro esperado |
| Fase setor conhecido | `p_fase='setor', p_setor='Care Center'` | JSON com a fatia do setor: `catalogo_servicos` filtrado (só itens `setor='Care Center'`), `sla_resposta_minutos`, guardrails (alerta/emergência) | Nenhum erro esperado |
| Setor sem itens de catálogo | `p_fase='setor', p_setor='Exames'` | `catalogo_servicos` retorna `[]` (não é erro); `exames_exigem_anestesia` presente | Array vazio, nunca exceção |
| Fase inválida | `p_fase='bogus'` | Retorna `NULL` | Nunca cai num `SELECT` que devolva a linha inteira |
| Seed reaplicado | `psql -f n8n/seed/0001_secretaria_config.sql` duas vezes | Segunda execução não insere linha duplicada | `ON CONFLICT (id) DO NOTHING`, sem erro |

</intent-contract>

## Code Map

- `n8n/migrations/0002_schema_operacional.sql` -- já existe (Story 1); define todas as colunas de `secretaria_config` que a função e o seed desta story usam (`catalogo_servicos`, `sinais_alerta_clinico`, `exames_exigem_anestesia`, `destinatarios_emergencia`, `mapeamento_stage_crm`, `sla_resposta_minutos`, `lock_ttl_minutos`) — nenhuma coluna nova é necessária.
- `n8n/migrations/0004_config_leitura_seletiva.sql` -- não existe ainda; criar. `CREATE OR REPLACE FUNCTION secretaria_config_ler(p_fase TEXT, p_setor TEXT DEFAULT NULL) RETURNS JSONB` com `CASE p_fase WHEN 'triagem' ... WHEN 'setor' ... ELSE NULL END`, seguido de `GRANT EXECUTE ... TO app_role`.
- `n8n/seed/0001_secretaria_config.sql` -- não existe ainda; criar. `INSERT INTO secretaria_config (id, ...) VALUES (1, ...) ON CONFLICT (id) DO NOTHING`.
- `n8n/seed/README.md` -- já existe; acrescentar o comando manual de aplicação (`psql ... -f n8n/seed/0001_secretaria_config.sql`) e a nota de que não é montado em `docker-entrypoint-initdb.d` (só `n8n/migrations` é, ver `docker-compose.yml`).
- `ARCHITECTURE-SPINE.md` AD-1 (linha "Montagem do `systemMessage` é seletiva por setor...") -- regra que a função implementa; ler antes de codar o `CASE`.
- `.claude/skills/n8n-agent-patterns/references/config-postgres.md` -- mostra o padrão de referência (`Buscar Config` lido a cada turno) que a Story 5/6 vai usar para *chamar* esta função — não replicar o schema de lá 1:1, já divergiu na Story 1.
- PRD `prd.md` FR-8/FR-16/FR-30/FR-31/FR-34/FR-41 -- fonte dos únicos exemplos concretos disponíveis hoje: sinal de alerta "vômito por 3 dias seguidos" (linha 515), exame que exige anestesia "tomografia" (linhas 79/220) — usar exatamente esses, não inventar outros.

## Tasks & Acceptance

**Execution:**
- `n8n/migrations/0004_config_leitura_seletiva.sql` -- criar `secretaria_config_ler(p_fase, p_setor)` (fatia `triagem` / fatia `setor`, `ELSE NULL`) + `GRANT EXECUTE` a `app_role` -- implementa a porta única de leitura seletiva exigida por AD-1.
- `n8n/seed/0001_secretaria_config.sql` -- `INSERT` da linha singleton com tom de voz (grounded em NFR-5/FR-32/CAP-1), `sla_resposta_minutos=5`, `lock_ttl_minutos=5`, `catalogo_servicos` (3 itens de Care Center: banho cachorro, banho gato, tosa), `sinais_alerta_clinico=["Vômito por 3 dias seguidos ou mais"]`, `exames_exigem_anestesia=["Tomografia"]`, `destinatarios_emergencia=[]` e `mapeamento_stage_crm={}` (ambos com comentário SQL explicando a pendência de dado real) -- popula a config exigida para qualquer leitura funcionar.
- `n8n/seed/README.md` -- documentar o comando manual de aplicação e a não-automação via `docker-entrypoint-initdb.d` -- evita alguém assumir que o seed roda sozinho no primeiro boot.

**Acceptance Criteria:**
- Given as migrations 0001-0004 aplicadas e o seed 0001 aplicado, when se roda `SELECT * FROM secretaria_config WHERE id = 1`, then existe exatamente uma linha com `catalogo_servicos` contendo os 3 itens de Care Center, `sinais_alerta_clinico` contendo o item interino de vômito, e `exames_exigem_anestesia` contendo "Tomografia".
- Given o seed já aplicado, when `n8n/seed/0001_secretaria_config.sql` é aplicado uma segunda vez, then nenhum erro ocorre e a tabela continua com exatamente uma linha (`id=1`).
- Given a função `secretaria_config_ler`, when chamada com `('triagem')`, then o JSON retornado não contém as chaves `catalogo_servicos`, `exames_exigem_anestesia` nem `stage_crm`.
- Given a função `secretaria_config_ler`, when chamada com `('setor', 'Care Center')`, then `catalogo_servicos` no JSON retornado contém só itens com `setor = 'Care Center'`.
- Given a função `secretaria_config_ler`, when chamada com uma fase desconhecida (ex.: `('bogus')`), then o retorno é `NULL`, nunca a linha inteira serializada.
- Given o papel `identidade_role`, when se inspeciona `GRANT EXECUTE` de `secretaria_config_ler`, then `identidade_role` nunca aparece como concedido (só `app_role`).

## Spec Change Log

## Review Triage Log

### 2026-09-02 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 6 (high 1, medium 3, low 2)
- defer: 4 (medium 2, low 2)
- reject: 8 (low 8)
- addressed_findings:
  - `[high]` `[patch]` `secretaria_config_ler` não tinha `REVOKE EXECUTE ... FROM PUBLIC` antes do `GRANT ... TO app_role` — Postgres concede `EXECUTE` em função nova a `PUBLIC` por padrão, então `identidade_role` conseguia chamar a função apesar do Boundary "nunca `identidade_role`" (AD-3) e da AC 6, e a checagem estática só grepava a string `IDENTIDADE_ROLE`, nunca detectando essa classe de regressão. Corrigido: `REVOKE EXECUTE ... FROM PUBLIC` adicionado antes do `GRANT`, e a checagem estática do migration reforçada para também exigir `REVOKE EXECUTE` + `FROM PUBLIC` no texto.
  - `[medium]` `[patch]` `exames_exigem_anestesia` vazava para a fatia de qualquer setor (ex.: Care Center recebia a lista de exames que exigem anestesia), contrariando o objetivo explícito de AD-1 de "reduzir a superfície de um setor vazar informação de outro". Corrigido: campo agora só populado quando `p_setor = 'Exames'`, `'[]'::jsonb` nos demais.
  - `[medium]` `[patch]` A fatia de `triagem` sempre incluía ~8 campos institucionais hoje `NULL` (endereço, telefone, etc.), inflando toda leitura de triagem apesar do Problem desta story ser justamente custo/tamanho de prompt. Corrigido: as duas fatias (`triagem` e `setor`) agora passam por `jsonb_strip_nulls(...)`, removendo chaves nulas do JSON retornado.
  - `[medium]` `[patch]` O mirror em Python da lógica SQL na Verification só reimplementava 2 de ~10-15 campos por fase, dando falsa confiança — uma regressão real no `CASE` (ex.: uma fase vazando `catalogo_servicos`) passaria pelo mirror sem ser detectada. Corrigido: mirror expandido para reproduzir o conjunto completo de campos de cada fase (pós-patch, incluindo o `jsonb_strip_nulls`), e a nota de risco residual ajustada.
  - `[low]` `[patch]` `n8n/migrations/README.md` não mencionava que `0004` introduz a primeira função/GRANT armazenados do diretório (até então só DDL de tabela). Corrigido: uma frase adicionada.
  - `[low]` `[patch]` O comando de exemplo em `n8n/seed/README.md` fixava `-d nouvet_app` logo após explicar que o nome real vem de `$POSTGRES_APP_DB` — inconsistente se a variável for sobrescrita. Corrigido: exemplo trocado para `-d "${POSTGRES_APP_DB:-nouvet_app}"`.

### 2026-09-02 — Review pass (follow-up)
- intent_gap: 0
- bad_spec: 0
- patch: 4 (high 0, medium 1, low 3)
- defer: 0
- reject: 11 (low 11)
- addressed_findings:
  - `[medium]` `[patch]` O item `deferred` sobre `app_role` ter acesso direto a `secretaria_config` (DW-12) descrevia o risco como só `SELECT` direto, mas o `GRANT` real da Story 1 (0002) concede `SELECT, INSERT, UPDATE, DELETE` — subestimando o risco real (escrita/exclusão direta, não só leitura). Corrigido: `summary`/`evidence`/`location` do item `deferred` correspondente reescritos para refletir a abrangência real do `GRANT`.
  - `[low]` `[patch]` `secretaria_config_ler('setor', NULL)` (chamada com a fase `'setor'` mas sem `p_setor`, permitido pelo `DEFAULT NULL`) não tinha tratamento explícito e devolvia uma fatia quase vazia silenciosamente, mascarando um possível bug do chamador. Corrigido: novo guard `CASE WHEN p_setor IS NULL THEN NULL ELSE ... END` dentro do ramo `'setor'`, mesmo padrão de "fase desconhecida retorna NULL" já usado no `ELSE` externo; mirror em Python e Verification atualizados para cobrir o caso.
  - `[low]` `[patch]` A checagem estática de `REVOKE EXECUTE ... FROM PUBLIC` antes do `GRANT ... TO app_role` verificava só a presença isolada das duas substrings, sem checar ordem nem se miravam a assinatura correta da função — uma regressão que invertesse a ordem ou mirasse outra função ainda passaria. Corrigido: checagem reforçada para exigir `REVOKE` antes do `GRANT`, `FROM PUBLIC` entre os dois, e a assinatura `SECRETARIA_CONFIG_LER(TEXT, TEXT)` logo após cada um.
  - `[low]` `[patch]` Typo no Review Triage Log da passada anterior: "also exigir" (palavra em inglês misturada a frase em português). Corrigido para "também exigir".

### 2026-09-02 — Review pass (follow-up 2)
- intent_gap: 0
- bad_spec: 0
- patch: 2 (high 0, medium 0, low 2)
- defer: 0
- reject: 20 (low 20)
- addressed_findings:
  - `[low]` `[patch]` O item `deferred` sobre ausência de fonte única de nomes de setor afirmava que `glossary.md` lista "5 setores distintos", mas `glossary.md` (linha 13) lista 8 (Care Center, Exames, Consultas, Vacinas, Orçamentos, Internação, Oncologia, Financeiro) — achado do review adversarial (blind hunter). Corrigido: `summary` do item `deferred` correspondente atualizado com a contagem e a lista corretas.
  - `[low]` `[patch]` `secretaria_config_ler('setor', '')` (fase `'setor'` com `p_setor` string vazia, distinto do caso `NULL` já tratado) não caía no guard existente e devolvia uma fatia quase vazia (setor `''`, catálogo `[]`) silenciosamente, mesma classe de risco já corrigida para `p_setor IS NULL` numa passada anterior — achado do review adversarial (edge-case hunter). Corrigido: guard do ramo `'setor'` estendido para `p_setor IS NULL OR p_setor = ''`; mirror em Python e Verification atualizados para cobrir o caso.

## Design Notes

`p_fase`/`p_setor` como discriminador único (em vez de uma função por fase/setor) foi escolhido para manter uma porta única de leitura (mesmo espírito de AD-11 — "porta única" já usado alhures neste projeto), mais fácil de garantir "nunca dump" num só lugar do que espalhado em N funções. Exemplo de uso pretendido (Story 5/6 vai chamar isto via node Postgres, não fixo em código):

```sql
SELECT secretaria_config_ler('triagem');
SELECT secretaria_config_ler('setor', 'Care Center');
```

`sinais_alerta_clinico`/`destinatarios_emergencia` aparecem nas DUAS fases (não só triagem) porque um Sinal de Alerta ou uma Emergência Declarada (CAP-12) pode surgir a qualquer momento da conversa, mesmo depois do setor já classificado — nunca só na saudação inicial.

Conteúdo de negócio real ainda não fornecido (endereço, telefone, contatos de plantonista, `stage_id` do funil) fica deliberadamente `NULL`/`[]`/`{}` com comentário SQL — mesmo padrão dos Assumptions/Open Questions já registrados no SPEC.md (não fantasiar dado que Thiago ainda não passou).

## Verification

**Commands:**
- `python3 -c "content = open('n8n/migrations/0004_config_leitura_seletiva.sql').read(); up = content.upper(); assert 'CREATE OR REPLACE FUNCTION SECRETARIA_CONFIG_LER' in up, 'funcao ausente'; assert 'SELECT *' not in up, 'nunca pode fazer SELECT *'; assert 'IDENTIDADE_ROLE' not in up, 'nunca conceder a identidade_role'; assert 'GRANT EXECUTE' in up and 'APP_ROLE' in up, 'precisa conceder EXECUTE a app_role'; assert 'JSONB_STRIP_NULLS' in up, 'precisa remover campos institucionais nulos da fatia (custo/tamanho de prompt)'; i_revoke = up.find('REVOKE EXECUTE'); i_grant = up.find('GRANT EXECUTE'); assert i_revoke != -1 and i_grant != -1 and i_revoke < i_grant, 'REVOKE EXECUTE precisa preceder o GRANT EXECUTE'; assert 'FROM PUBLIC' in up[i_revoke:i_grant], 'o REVOKE precisa ser especificamente FROM PUBLIC'; assert 'SECRETARIA_CONFIG_LER(TEXT, TEXT)' in up[i_revoke:i_revoke+60] and 'SECRETARIA_CONFIG_LER(TEXT, TEXT)' in up[i_grant:i_grant+60], 'REVOKE e GRANT precisam mirar a assinatura exata da função'; print('OK')"` -- expected: `OK` (checagem estática, sem Docker, de que a função nunca faz dump completo, remove campos nulos da fatia, e que o `REVOKE EXECUTE ... FROM PUBLIC` precede o `GRANT EXECUTE ... TO app_role` mirando a mesma assinatura de função -- não só a presença isolada das duas strings).
- `python3 -c "import re, json; content = open('n8n/seed/0001_secretaria_config.sql').read(); assert 'ON CONFLICT (ID) DO NOTHING' in content.upper(), 'seed precisa ser idempotente'; blocks = re.findall(r\"'(\[[^']*\]|\{[^']*\})'::jsonb\", content, re.S); assert len(blocks) == 5, f'esperado 5 literais jsonb, achou {len(blocks)}'; [json.loads(b) for b in blocks]; assert content.count('\"setor\": \"Care Center\"') == 3, 'esperado 3 servicos de Care Center'; assert 'Vômito por 3 dias' in content and 'Tomografia' in content, 'exemplos documentados ausentes'; print('OK')"` -- expected: `OK` (checagem estática, sem Docker, de que todo literal JSONB do seed é JSON válido e o conteúdo mínimo documentado está presente).
- Mirror em Python da lógica `CASE` de `secretaria_config_ler` (sem Postgres disponível neste ambiente de build), reproduzindo o conjunto COMPLETO de campos de cada fase (pós-patch, incluindo o equivalente a `jsonb_strip_nulls` e o filtro de `exames_exigem_anestesia` só para o setor Exames), executado sobre os dados reais extraídos do seed, cobrindo as 5 linhas da I/O & Edge-Case Matrix (fase `triagem` nunca carrega `catalogo_servicos`/`exames_exigem_anestesia`/`mapeamento_stage_crm`; fase `setor='Care Center'` filtra o catálogo e zera `exames_exigem_anestesia`; fase `setor='Exames'` sem item de catálogo retorna `[]` sem erro mas com `exames_exigem_anestesia` real; fase inválida retorna `None`; seed contém `ON CONFLICT (id) DO NOTHING`):
  ```bash
  python3 << 'PYEOF'
  import re, json
  seed = open('n8n/seed/0001_secretaria_config.sql').read()
  blocks = re.findall(r"'(\[[^']*\]|\{[^']*\})'::jsonb", seed, re.S)
  catalogo, sinais, exames, destinatarios, stage_crm = [json.loads(b) for b in blocks]
  # Campos institucionais ainda não fornecidos (ver seed) -- None aqui espelha a coluna
  # NULL no Postgres; formas_pagamento/convenios não são sobrescritos pelo seed, então
  # ficam no default de coluna (0002): '{}'/'[]', nunca NULL.
  row = {'nome_secretaria': 'Assistente Nouvet', 'nome_empresa': 'Nouvet',
         'endereco': None, 'cidade_estado': None, 'telefone': None, 'whatsapp': None,
         'email': None, 'site': None, 'horario_funcionamento': None, 'tom_voz': 'X',
         'formas_pagamento': [], 'convenios': [],
         'sla_resposta_minutos': 5, 'catalogo_servicos': catalogo, 'sinais_alerta_clinico': sinais,
         'exames_exigem_anestesia': exames, 'destinatarios_emergencia': destinatarios,
         'mapeamento_stage_crm': stage_crm}
  def strip_nulls(d):
      # Mirror de jsonb_strip_nulls: remove só chaves com valor None -- nunca remove
      # arrays/objetos vazios ([]/{}), que continuam presentes no JSON.
      return {k: v for k, v in d.items() if v is not None}
  def ler(p_fase, p_setor=None, row=row):
      if p_fase == 'setor' and not p_setor:
          # Mirror do guard 'CASE WHEN p_setor IS NULL OR p_setor = '''' THEN NULL' --
          # sem p_setor (ou string vazia) não há fatia de setor para montar, tratado
          # como fase inválida (NULL).
          return None
      if p_fase == 'triagem':
          return strip_nulls({
              'nome_secretaria': row['nome_secretaria'], 'nome_empresa': row['nome_empresa'],
              'endereco': row['endereco'], 'cidade_estado': row['cidade_estado'],
              'telefone': row['telefone'], 'whatsapp': row['whatsapp'], 'email': row['email'],
              'site': row['site'], 'horario_funcionamento': row['horario_funcionamento'],
              'tom_voz': row['tom_voz'], 'formas_pagamento': row['formas_pagamento'],
              'convenios': row['convenios'], 'sinais_alerta_clinico': row['sinais_alerta_clinico'],
              'destinatarios_emergencia': row['destinatarios_emergencia'],
              'sla_resposta_minutos': row['sla_resposta_minutos'],
          })
      if p_fase == 'setor':
          return strip_nulls({
              'nome_secretaria': row['nome_secretaria'], 'nome_empresa': row['nome_empresa'],
              'tom_voz': row['tom_voz'], 'setor': p_setor,
              'catalogo_servicos': [i for i in row['catalogo_servicos'] if i.get('setor') == p_setor],
              'exames_exigem_anestesia': row['exames_exigem_anestesia'] if p_setor == 'Exames' else [],
              'mapeamento_stage_crm': row['mapeamento_stage_crm'].get(p_setor),
              'sinais_alerta_clinico': row['sinais_alerta_clinico'],
              'destinatarios_emergencia': row['destinatarios_emergencia'],
              'sla_resposta_minutos': row['sla_resposta_minutos'],
          })
      return None
  r = ler('triagem')
  assert 'catalogo_servicos' not in r and 'exames_exigem_anestesia' not in r and 'mapeamento_stage_crm' not in r
  assert 'endereco' not in r and 'telefone' not in r  # NULL institucional removido por strip_nulls
  r = ler('setor', 'Care Center')
  assert len(r['catalogo_servicos']) == 3 and r['exames_exigem_anestesia'] == []
  r = ler('setor', 'Exames')
  assert r['catalogo_servicos'] == [] and r['exames_exigem_anestesia'] == exames
  assert ler('bogus') is None
  assert ler('setor', None) is None  # p_setor obrigatório na fase 'setor'
  assert ler('setor', '') is None  # string vazia tratada como p_setor ausente
  assert 'ON CONFLICT (id) DO NOTHING' in seed
  print('OK')
  PYEOF
  ```
  -- expected: `OK`. **Risco residual:** este é um mirror em Python da lógica da função, não a execução real do SQL num Postgres vivo (indisponível neste ambiente de build, mesma limitação já documentada na Story 1) — validar com `SELECT secretaria_config_ler(...)` real na VPS de dev antes do go-live (ver Manual checks abaixo).

**Manual checks (if no CLI):**
- Na VPS de dev (Docker disponível): aplicar `0004` (via novo `docker compose up` num volume limpo, ou `psql -f` direto num cluster já rodando) e depois `psql -f n8n/seed/0001_secretaria_config.sql`; confirmar `SELECT secretaria_config_ler('triagem')` e `SELECT secretaria_config_ler('setor', 'Care Center')` retornam os subconjuntos esperados, e que rodar o seed duas vezes não duplica a linha.
- Confirmar visualmente que nenhum dos dois arquivos novos contém segredo/credencial de integração.

## Auto Run Result

**Resumo da mudança implementada:** esta passada foi um segundo follow-up review sobre a Story 2 já `done` (função `secretaria_config_ler` + seed `0001_secretaria_config.sql` implementados em passadas anteriores). Nenhuma implementação nova de escopo — só duas correções (patch) de baixo risco encontradas pelo review adversarial desta passada.

**Arquivos alterados (nesta passada):**
- `n8n/migrations/0004_config_leitura_seletiva.sql` -- guard do ramo `'setor'` estendido de `p_setor IS NULL` para `p_setor IS NULL OR p_setor = ''`, tratando string vazia (não só `NULL`) como fase inválida (mesma classe de risco já corrigida para `NULL` numa passada anterior).
- `_bmad-output/specs/spec-atendimento-nouvet/stories/2-config-as-data.md` -- item `deferred` sobre nomes de setor corrigido (glossary.md lista 8 setores, não 5); mirror em Python e checagem de Verification atualizados para cobrir `p_setor=''`; novo `Review Triage Log` desta passada.

**Review findings (esta passada):**
- Patches aplicados: 2 (low 2) -- ver `Review Triage Log` acima para detalhe de cada um.
- Itens deferidos (novos): 0 -- nenhum achado novo desta passada exigiu um item `deferred` novo.
- Itens rejeitados: 20 (todos low/cosmético, não-acionáveis, duplicados de itens já deferidos, ou factualmente incorretos) -- incluindo: achados sobre o item `deferred` de privilégio em `_bmad-output/implementation-artifacts/deferred-work.md` (DW-12 duplicado/desatualizado por DW-16, título de DW-16 truncado) -- fora da autoridade desta execução, que não modifica o ledger de deferred-work por instrução explícita do invocador; `lock_ttl_minutos` não exposto pela função (consumidor é a lógica de debounce/lock, fora do escopo desta story, já documentado em DW-11 da Story 1); `secretaria_profissionais` sem barreira de acesso descrita (explicitamente fora do escopo pela cláusula "Never"); ausência de AC para placeholders de segurança ainda não populados (não acionável sem o dado real); checagem estática de contagem de itens do catálogo por substring (cosmético); ausência de cenário de setor com grafia incorreta na I/O Matrix (duplicata do item `deferred` de nomes de setor); três "edge cases" de coluna JSONB `NULL` (catálogo não-array, sinais/destinatários `NULL`, exames `NULL`) -- impossíveis na prática porque `n8n/migrations/0002_schema_operacional.sql` define essas colunas como `NOT NULL DEFAULT`; linha singleton ausente (duplicata do item `deferred` já existente sobre esse cenário); `review_loop_iteration`/`followup_review_recommended` "desatualizados" (falso achado -- o primeiro só incrementa em loopback de `bad_spec`, que nunca ocorreu, e o segundo está sendo recalculado nesta própria passada); numeração de seed/migrations coincidente (cosmético, já documentado nos READMEs); leitura "porta única" estrutural (Reading B) não implementada e verificação só por mirror Python (duplicatas dos itens `deferred` de privilégio direto e do "Risco residual" já documentado na Verification).

**Follow-up review recommendation:** `false`. Score = 3×0 (medium) + 1×2 (low) = 2 (< 5). Contagem de patches por severidade: high 0, medium 0, low 2.

**Verificação executada:**
- Checagem estática do migration (mesmos `assert`s da passada anterior) -- `OK`.
- Checagem estática do seed (JSON válido, 3 itens Care Center, exemplos documentados) -- `OK`.
- Mirror em Python da lógica `CASE` (expandido com o caso `p_setor=''`) -- `OK`.

**Riscos residuais:** os mesmos já documentados na Verification (mirror em Python, não execução real em Postgres -- validar na VPS de dev antes do go-live) e nos itens `deferred` (DW-12/DW-16 a DW-15, mais o item de nomes de setor com o texto agora corrigido) -- nenhum risco novo introduzido por esta passada. A inconsistência entre DW-12 (desatualizado) e DW-16 (correção do mesmo risco) no ledger `deferred-work.md` permanece sem resolução -- fica para o orquestrador, que é quem possui esse arquivo.

