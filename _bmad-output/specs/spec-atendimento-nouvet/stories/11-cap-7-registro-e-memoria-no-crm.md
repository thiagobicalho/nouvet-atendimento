---
title: 'CAP-7 — Registro e Memória no CRM'
type: 'feature'
created: '2026-09-03'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: ['oversized']
deferred:
  - summary: >-
      A detecção de possível duplicidade familiar (match só por nome de pet, case-insensitive,
      entre telefones diferentes) pode gerar falso positivo entre famílias sem relação alguma.
    evidence: |-
      Lógica herdada da CTE `duplicidade` de `identidade_cliente_pet_resolver` (Story 4,
      `n8n/migrations/0006_identidade_porta_unica.sql`, não alterada por esta story): compara
      só `lower(btrim(nome_pet))` entre linhas de telefones distintos, sem nenhum sinal de
      nome do dono/endereço. Nomes de pet comuns (Rex, Mel, Bob) entre dois clientes reais e
      não aparentados disparam o alerta. Já era uma limitação conhecida e documentada desde a
      Story 4 ("não elimina o caso... só avisa o caller"), mas até esta story o caller
      (sub-workflow de Task) não existia -- Story 11 é quem ativa esse aviso contra tráfego
      real pela primeira vez, então o volume de falsos positivos em produção é uma incógnita
      nova.
    location: >-
      n8n/migrations/0006_identidade_porta_unica.sql (CTE `duplicidade`)
    severity: medium
  - summary: >-
      A Task de "possível duplicidade familiar" não é idempotente entre atendimentos futuros
      do mesmo cliente -- pode criar uma Task nova a cada fechamento de seção enquanto a
      duplicidade não for resolvida por um humano.
    evidence: |-
      `possivel_duplicidade_familiar` é recalculado a cada chamada de
      `identidade_cliente_pet_resolver` (não é um estado persistido/resolvido). O node
      "Precisa criar Task?" (`n8n/workflows/04 - Registrar Atendimento CRM.json`) só olha a
      flag da chamada atual, sem checar se já existe uma Task aberta equivalente no deal. Um
      cliente com duplicidade não resolvida que fecha múltiplas seções no futuro pode acumular
      várias Tasks repetidas no mesmo card. O `Always` do contrato desta story só exige
      deduplicar as duas causas (cadastro pendente + duplicidade) *dentro da mesma chamada*,
      nunca promete idempotência entre chamadas futuras -- por isso não é um intent_gap nem
      bad_spec desta story, mas vale acompanhar (risco de poluir o card e, em escala, virar
      ruído percebido -- mesma preocupação de spam que a Story 12/SM-C2 já trata para
      escalonamento humano).
    location: >-
      n8n/workflows/04 - Registrar Atendimento CRM.json (nodes "Precisa criar Task?" / "Criar Task de Revisão")
    severity: low
baseline_revision: '630459b499e4c8d0fcaeffd7bc3970168e4ff112'
---

<intent-contract>

## Intent

**Problem:** `n8n/workflows/01 - Agente.json` (Stories 5-10) fecha os 5 fluxos de setor (Seções 3.6/4.5/5.5/6.4/7.3) só com texto ("um humano vai continuar") — nenhum contato/card é criado no RD CRM, `identidade_cliente_pet_resolver` (Story 4, AD-11) nunca foi chamado em tempo real, e não existe mecanismo de Task pedindo cadastro manual no SimplesVet para cliente novo.

**Approach:** Novo sub-workflow `04 - Registrar Atendimento CRM.json` (ferramenta `Registrar_atendimento_crm`, padrão tool-subworkflow AD-4), chamado ao fechar cada uma das 5 seções: resolve identidade via `identidade_cliente_pet_resolver` (grava Postgres, porta única AD-11), busca/cria o contato e o deal único no RD CRM (pipeline único, CAP-7), atualiza `stage_id` do deal para o setor corrente (`mapeamento_stage_crm`, AD-1/FR-23) e acrescenta uma Note por atendimento (histórico append-only, mais recente = última criada, nunca sobrescrito). Quando o resolver indica `criado=true` e `simplesvet_status='pendente'`, ou `possivel_duplicidade_familiar=true`, cria uma Task nativa no card pedindo revisão/cadastro manual (etiqueta descartada como mecanismo).

## Boundaries & Constraints

**Always:** Chama `identidade_cliente_pet_resolver` primeiro (`telefone` sempre de `Info.telefone_normalizado`, nunca `$fromAI`; `nome_cliente`/`nome_pet` via `$fromAI` — o agente relata o nome já estabelecido nesta conversa, seja o do Contexto para telefone reconhecido, seja o que o cliente acabou de informar para cliente novo — decisão registrada em 2026-09-04 após intent gap: `Info` só reflete estado pré-turno e nunca carrega o nome de um cliente genuinamente novo, então exigir `Info` para esses 2 campos tornava o registro de cliente novo impossível por construção); usa `rd_crm_contact_id` já retornado, senão busca por telefone (`GET /contacts?filter=phone:`) antes de criar (idempotência best-effort, nunca cria 2º contato quando já existe) e persiste o id de volta via 2ª chamada ao resolver (`p_rd_crm_contact_id`). Busca deal existente do contato (`GET /deals?filter=contact_id:`) antes de criar — pipeline único, nunca mais de 1 card por cliente (AD-6: `rd_crm_deal_id` nunca persistido em Postgres, o CRM é a única fonte de verdade do funil). Se o deal existe, atualiza `stage_id` para `mapeamento_stage_crm[setor]` (card muda de etapa a cada novo atendimento); se não existe, cria com esse `stage_id` já na criação. Sempre acrescenta uma Note nova (`POST /deals/{id}/notes`) com setor + preferências coletadas + estado + timestamp — nunca edita/sobrescreve uma nota existente (resolve a Open Question do SPEC.md sobre reposicionamento: card muda de etapa, histórico vive em Notes append-only). Task (`POST /tasks`, `status` só aceita `open` na criação) é criada quando `criado=true AND simplesvet_status='pendente'` (pedido de cadastro manual no SimplesVet) e/ou `possivel_duplicidade_familiar=true` (alerta de revisão humana, texto literal já previsto em AD-11) — mesma Task cobre os dois motivos quando ambos ocorrem. `simplesvet_status` nasce `'pendente'` para `origem='cadastro_direto'` e `'cadastrado'` para `origem='import_simplesvet'`, gravado só no INSERT, nunca alterado por chamada seguinte do resolver. Credencial RD CRM é sempre OAuth2 nativo do n8n (`genericCredentialType`/`oAuth2Api`, AD-2) — refresh automático do n8n, nunca token fixo nem `refresh_token` gravado em Postgres. Telefone reaproveita `Info.telefone_normalizado` (nunca renormalizado inline, AD-8). Nós `httpRequest` desta story usam `onError: continueRegularOutput`/`retryOnFail` (falha da API RD CRM nunca derruba o turno do agente — mesmo achado já registrado como deferred nas Stories 6/7 para os `httpRequest` anteriores, corrigido aqui desde o início).

**Block If:** Nenhuma decisão bloqueante. `mapeamento_stage_crm` (config) segue vazio (`{}`, dado pendente do Nouvet) — quando `mapeamento_stage_crm[setor]` não existir, omite `stage_id` do `POST /deals` (RD CRM aplica a etapa default do pipeline) e do `PUT` (não move o card), mesmo padrão de fallback "não inventa" já usado nas Stories 7-10; ajustar quando Thiago providenciar o material do funil real (assumption já registrada no SPEC.md e nesta invocação). `workflowId` do novo `toolWorkflow` e a credencial OAuth2 usam `"value": "SET_IN_N8N_UI"` (mesmo tratamento AD-2 já usado nas Stories 6/7) — relinkar/configurar na VPS de dev.

**Never:** Não modifica `02 - Escalar Humano.json` nem os 3 motivos de handoff da Seção 2.3 (Sinal de Alerta/Fora de escopo/Convênio) — decisão já registrada pela Story 6 ("Escalar_humano só envia mensagem de alerta... nunca cria/atualiza contato"), mantida aqui; cobertura de SM-1 para esses casos fica como lacuna conhecida, não resolvida nesta story. Não persiste `rd_crm_deal_id`/estágio do funil em Postgres (AD-6). Não implementa nenhuma tool de agenda (AD-4) nem calcula/altera `pipeline_id` (somente leitura na API, implícito pelo `stage_id`). Não cria/edita `custom_fields` do deal (schema não confirmado com o Nouvet) — setor/preferências/estado vivem só no texto da Note. Não constrói mecanismo de retenção/exclusão de dado (Deferred na spine).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cliente novo, 1ª coleta completa | `identidade_cliente_pet_resolver` → `criado=true`, `simplesvet_status='pendente'` | Cria contato + deal (`stage_id` do setor) + Note; cria Task pedindo cadastro manual no SimplesVet | Nenhum erro |
| Cliente reconhecido, retorna com outro setor | Contato/deal já existem (`rd_crm_contact_id` presente) | Reusa contato/deal, atualiza `stage_id` para o novo setor, acrescenta nova Note; nenhuma Task nova | Nenhum erro |
| Cliente já vindo do import SimplesVet | `origem='import_simplesvet'`, `simplesvet_status='cadastrado'` desde o import | Cria/atualiza deal/Note normalmente; nunca cria Task de cadastro pendente | Nenhum erro |
| Possível duplicidade familiar | Resolver retorna `possivel_duplicidade_familiar=true` | Contato/deal criados normalmente + Task de revisão humana sinalizando a duplicidade | Nenhum erro |
| Falha da API RD CRM (token expirado, 5xx) | `httpRequest` retorna erro | Turno do agente não quebra (erro contido no sub-workflow via `onError`); cliente recebe o fechamento normal da seção; registro no CRM fica pendente sem log persistido (risco residual aceito, mesmo padrão já deferido nas Stories 6/7) | Erro contido, nunca propaga ao `Agente Nouvet` |

</intent-contract>

## Code Map

- `n8n/workflows/01 - Agente.json` -- `systemMessage`: linhas ~130-131 (3.6), ~149-150 (4.5), ~168-169 (5.5), ~184-185 (6.4), ~197-198 (7.3) — os 5 fechamentos de seção passam a chamar `Registrar_atendimento_crm` antes/junto do texto de fechamento (mesmo padrão de "continue a conversa após chamar a ferramenta" já usado em `Escalar_humano`, Seção 2.4); linha ~228 (`<ferramentas>`, frase final "nenhuma tool de cadastro/CRM (CAP-7/Story 11)") substituída pela entrada real da nova ferramenta; linha 4 (`<papel>`, "cria cadastro/CRM... isso nunca é feito por você") ajustada para refletir que o agente aciona a ferramenta, mas não executa a chamada de API ele mesmo (mesma distinção já usada para `Escalar_humano`); novo nó `toolWorkflow` "Registrar Atendimento CRM" conectado via `ai_tool`.
- `n8n/workflows/04 - Registrar Atendimento CRM.json` -- novo arquivo (convenção `02+`): `executeWorkflowTrigger` (inputs: `telefone`, `nome_cliente`, `nome_pet`, `setor`, `resumo_atendimento`) → Postgres `identidade_cliente_pet_resolver` → IF `rd_crm_contact_id` presente → (busca/cria contato RD CRM) → 2ª chamada ao resolver persistindo `rd_crm_contact_id` → (busca/cria/atualiza deal, `stage_id` = `mapeamento_stage_crm[setor]`) → `POST /deals/{id}/notes` → IF `criado AND simplesvet_status='pendente'` OU `possivel_duplicidade_familiar` → `POST /tasks`.
- `n8n/migrations/0006_identidade_porta_unica.sql` -- `identidade_cliente_pet_resolver` atual (assinatura, UPSERT, `RETURNING`/`jsonb_build_object`) — a `0011` estende via `CREATE OR REPLACE FUNCTION` preservando `REVOKE`/`GRANT` já existentes, mesmo padrão da `0010`; `origem` NUNCA está no `SET` do `DO UPDATE` (linhas 216-226) — `simplesvet_status` segue o mesmo padrão (só gravado no `INSERT`, nunca sobrescrito).
- `n8n/migrations/0003_identidade_cliente_pet.sql` -- schema atual de `identidade_cliente_pet` (sem `simplesvet_status`) — a `0011` altera via `ALTER TABLE`, nunca recria.
- `n8n/migrations/0002_schema_operacional.sql` -- `atendimento_config.mapeamento_stage_crm JSONB` (linha 33) já existe; `n8n/seed/0001_atendimento_config.sql` grava `'{}'::jsonb` (dado pendente, comentado) — nenhuma migration nova para ler esse campo, ler via `SELECT mapeamento_stage_crm FROM atendimento_config WHERE id = 1` (não precisa da porta seletiva `atendimento_config_ler`, que só filtra por fase triagem/setor, não por este campo isolado).
- `n8n/workflows/02 - Escalar Humano.json` / `03 - Buscar Info Setor.json` -- referência de estilo (`executeWorkflowTrigger`, `httpRequest` form/JSON, `Set` de projeção) a seguir na nova sub-workflow.
- `.claude/skills/rd-station-api/references/crm.md` -- Contacts (`GET/POST/PUT /contacts`, filtro `phone:`), Deals (`POST/PUT /deals`, `stage_id` escreve etapa, `pipeline_id` só leitura) já documentados; seção "Tarefas"/Notes ainda só cita `crm-v2-tasks` sem schema — expandir com o contrato real (`POST /tasks`: `name`, `description`, `type`, `status` só `open` na criação, `due_date`, `deal_id`, `owner_ids`; `POST /deals/{deal_id}/notes`: `description`, `user_id`) para não obrigar a próxima story a redescobrir.
- `ARCHITECTURE-SPINE.md` AD-6 (Postgres complementar ao CRM, nunca duplica estágio de funil), AD-11 (porta única idempotente, texto literal da Task de cadastro pendente + alerta de duplicidade), AD-1 (mapeamento de stage_id por setor, FR-23) -- invariantes centrais.
- `stories/4-identidade-cliente-pet-porta-unica-idempotente.md` -- Design Notes/`Never` ("a Task de cadastro pendente no SimplesVet... é de story(s) futura(s), CAP-1/CAP-7") confirma que esta story é a consumidora prevista da porta única.

## Tasks & Acceptance

**Execution:**
- `n8n/migrations/0011_registro_crm.sql` -- `ALTER TABLE identidade_cliente_pet ADD COLUMN simplesvet_status VARCHAR(20) NOT NULL DEFAULT 'pendente' CHECK (simplesvet_status IN ('pendente','cadastrado'))`; `CREATE OR REPLACE FUNCTION identidade_cliente_pet_resolver` incluindo `simplesvet_status` no `INSERT` (`CASE WHEN origem = 'import_simplesvet' THEN 'cadastrado' ELSE 'pendente' END`, nunca no `SET` do `DO UPDATE`) e no `RETURNING`/JSON de saída -- fecha o pré-requisito de schema do fluxo de Task.
- `n8n/workflows/04 - Registrar Atendimento CRM.json` -- criar sub-workflow (ver Code Map) -- implementa a porta única de AD-11 (checar/criar contato, criar Task de cadastro pendente, UPSERT Postgres) em tempo real, e a metade "registro" de CAP-7.
- `n8n/workflows/01 - Agente.json` -- adicionar nó `toolWorkflow` "Registrar Atendimento CRM"; editar os 5 fechamentos de seção para chamar a ferramenta; atualizar `<papel>` e a frase final de `<ferramentas>` -- implementa a metade "wiring no SOP" de CAP-7.
- `.claude/skills/rd-station-api/references/crm.md` -- expandir Tarefas/Notes com o contrato real usado por esta story.
- `n8n/migrations/README.md` -- acrescentar frase sobre a `0011` (mesmo padrão de changelog das migrations anteriores).

**Acceptance Criteria:**
- Given os 5 cenários da I/O & Edge-Case Matrix, when reproduzidos contra a topologia do sub-workflow/`systemMessage` (inspeção estática), then o comportamento bate com a coluna "Expected Output/Behavior".
- Given `n8n/workflows/04 - Registrar Atendimento CRM.json`, when inspecionado, then é um JSON de export de workflow n8n válido (`nodes`/`connections`), sem credencial em texto, com `executeWorkflowTrigger` expondo `telefone`/`nome_cliente`/`nome_pet`/`setor`/`resumo_atendimento` como inputs.
- Given `identidade_cliente_pet_resolver` (0011), when chamada para um cliente novo com `p_origem` default (`cadastro_direto`), then o JSON retornado contém `simplesvet_status: "pendente"`; when chamada com `p_origem='import_simplesvet'`, then contém `simplesvet_status: "cadastrado"`.
- Given a mesma linha já existente (2ª chamada do resolver, qualquer origem), when inspecionado o `SET` do `DO UPDATE` em `0011`, then `simplesvet_status` nunca aparece nele (preservado do `INSERT` original).
- Given os 5 fechamentos de seção do `systemMessage` (3.6/4.5/5.5/6.4/7.3), when inspecionados, then todos referenciam a ferramenta `Registrar_atendimento_crm`.
- Given as ferramentas conectadas ao `Agente Nouvet` via `ai_tool`, when inspecionadas, then são exatamente `{'Refletir', 'Escalar Humano', 'Buscar Info Setor', 'Registrar Atendimento CRM'}`.
- Given os nós `httpRequest` de `04 - Registrar Atendimento CRM.json`, when inspecionados, then todos têm `onError`/`retryOnFail` configurado (nunca propagam falha ao `Agente Nouvet`).
- Given o `POST /deals/{id}/notes`, when chamado numa 2ª execução para o mesmo cliente, then uma nova Note é criada (nunca `PUT`/edição de uma nota existente).

## Design Notes

O mecanismo de "reposicionamento do card" (Open Question do SPEC.md, CAP-7/UJ-4) é resolvido nesta story como: o `stage_id` do deal sempre reflete o setor do atendimento **corrente** (atualizado a cada chamada de `Registrar_atendimento_crm`), enquanto o histórico de atendimentos anteriores vive em Notes append-only (nunca sobrescritas) — não existe uma "nova etapa" de reposicionamento nem duplicação de card; o card sempre foi único desde a criação (AD-6/AD-11), só a etapa e o topo do histórico mudam a cada novo atendimento. `pipeline_id` nunca é enviado/calculado (é somente leitura na API do RD CRM — confirmado no schema real de `POST /deals`) porque é implícito pelo `stage_id` escolhido; isso também resolve por que `atendimento_config` só precisa de `mapeamento_stage_crm` (setor → stage_id) e nunca de um campo de pipeline separado — a spine já estava correta ao modelar só esse campo.

A Task cobre dois motivos possíveis com o mesmo mecanismo nativo (nunca etiqueta): cadastro pendente no SimplesVet (`simplesvet_status='pendente'`) e alerta de possível duplicidade familiar (`possivel_duplicidade_familiar=true`, texto já previsto literalmente em AD-11 desde a Story 4) — quando os dois ocorrem juntos (caso raro: cliente novo que também colide em nome de pet com outro telefone), uma única Task cobre ambos, evitando duas Tasks concorrentes no mesmo card.

## Verification

**Commands:**
- `python3 -c "content = open('n8n/migrations/0011_registro_crm.sql').read(); up = content.upper(); assert 'ADD COLUMN SIMPLESVET_STATUS' in up; import re; assert re.search(r\"CHECK\\s*\\(\\s*SIMPLESVET_STATUS\\s+IN\\s*\\(\\s*'PENDENTE'\\s*,\\s*'CADASTRADO'\\s*\\)\\s*\\)\", up), 'CHECK do domínio simplesvet_status ausente ou incorreto'; assert 'CREATE OR REPLACE FUNCTION IDENTIDADE_CLIENTE_PET_RESOLVER' in up; ins = up[up.find('INSERT INTO IDENTIDADE_CLIENTE_PET'):up.find('DO UPDATE')]; assert 'SIMPLESVET_STATUS' in ins; do_update = up[up.find('DO UPDATE'):up.find('RETURNING')]; assert 'SIMPLESVET_STATUS' not in do_update, 'simplesvet_status nunca pode ser sobrescrito no UPDATE'; print('OK')"` -- expected: `OK` (checagem estática de que a coluna/domínio existem com o `CHECK` real do domínio — não só palavras soltas em comentário —, que `simplesvet_status` é gravado no `INSERT` e nunca aparece no `SET` do `DO UPDATE`).
- `python3 -c "import json; d = json.load(open('n8n/workflows/04 - Registrar Atendimento CRM.json')); assert 'nodes' in d and 'connections' in d; trg = [n for n in d['nodes'] if n.get('type') == 'n8n-nodes-base.executeWorkflowTrigger'][0]; inputs = [v['name'] for v in trg['parameters']['workflowInputs']['values']]; assert set(inputs) == {'telefone','nome_cliente','nome_pet','setor','resumo_atendimento'}; http_nodes = [n for n in d['nodes'] if n.get('type') == 'n8n-nodes-base.httpRequest']; assert http_nodes and all((n['parameters'].get('onError') or n.get('onError')) and (n['parameters'].get('retryOnFail') or n.get('retryOnFail')) for n in http_nodes); import re; assert not re.search(r'(Bearer |api[_-]?key|token\\s*[:=]|secret|senha\\s*[:=])', json.dumps(d), re.I); print('OK')"` -- expected: `OK` (exige `onError` **e** `retryOnFail` juntos em todo `httpRequest`, não um ou outro).
- `python3 -c "import json; d = json.load(open('n8n/workflows/04 - Registrar Atendimento CRM.json')); nodes = {n['name']: n for n in d['nodes']}; postgres = [n for n in d['nodes'] if n.get('type') == 'n8n-nodes-base.postgres']; assert postgres and all((n.get('onError') or n['parameters'].get('onError')) and (n.get('retryOnFail') or n['parameters'].get('retryOnFail')) for n in postgres), 'todo node Postgres precisa de onError+retryOnFail (erro de banco nunca pode propagar ao Agente Nouvet)'; conns = d['connections']; abort = 'Registro CRM Não Realizado'; guards = {'Identidade Resolvida?', 'Busca de Contato Bem-sucedida?', 'Busca de Deal Bem-sucedida?'}; assert guards <= set(nodes), 'guard nodes de identidade/busca ausentes'; routed_to_abort = {src for src, out in conns.items() if any(c['node'] == abort for group in out.get('main', []) for c in group)}; assert guards <= routed_to_abort, 'todo guard precisa ter um caminho de saída para o NoOp de aborto'; print('OK')"` -- expected: `OK` (garante que a mitigação desta rodada de review -- identidade nula do resolver e falha de busca no RD CRM tratadas como \"não encontrado\" -- não regride silenciosamente: todo Postgres tem `onError`/`retryOnFail`, e os 3 guards adicionados têm rota de saída para o NoOp de aborto em vez de prosseguir com dado inválido).
- `python3 -c "import json; d = json.load(open('n8n/workflows/01 - Agente.json')); agent = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.agent'][0]; sm = agent['parameters']['options']['systemMessage']; assert sm.count('Registrar_atendimento_crm') >= 5; tools = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.toolWorkflow']; names = {t['name'] for t in tools}; assert names == {'Escalar Humano', 'Buscar Info Setor', 'Registrar Atendimento CRM'}; ai_tool_sources = {src for src, out in d['connections'].items() if any(c['node'] == 'Agente Nouvet' for group in out.get('ai_tool', []) for c in group)}; assert ai_tool_sources == {'Refletir', 'Escalar Humano', 'Buscar Info Setor', 'Registrar Atendimento CRM'}; crm = [t for t in tools if t['name'] == 'Registrar Atendimento CRM'][0]; crm_inputs = crm['parameters']['workflowInputs']['value']; assert \"Info').item.json.telefone_normalizado\" in crm_inputs['telefone'] and 'fromAI' not in crm_inputs['telefone']; assert 'fromAI' in crm_inputs['nome_cliente'] and 'fromAI' in crm_inputs['nome_pet']; print('OK')"` -- expected: `OK` (inclui a asserção da resolução do intent gap: `telefone` sempre de `Info`, `nome_cliente`/`nome_pet` sempre via `$fromAI`).

**Manual checks (if no CLI):**
- Na VPS de dev: configurar a credencial OAuth2 do RD CRM (client_id/secret + fluxo authorization code), importar `04 - Registrar Atendimento CRM.json`, relinkar `workflowId` em `01 - Agente.json`; testar os 5 cenários da I/O Matrix com um telefone de teste, confirmando no painel do RD CRM que o contato/deal/Note/Task aparecem como esperado.
- Popular `mapeamento_stage_crm` com um `stage_id` real de teste e confirmar que o deal nasce na etapa certa e migra ao trocar de setor.

## Review Triage Log

### 2026-09-04 — Review pass
- intent_gap: 2: (high 2, medium 0, low 0)
- bad_spec: 1: (high 0, medium 1, low 0)
- patch: 5: (high 2, medium 3, low 0)
- defer: 1: (high 0, medium 0, low 1)
- reject: 6
- addressed_findings:
  - none

### 2026-09-04 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 7: (high 4, medium 2, low 1)
- defer: 2: (high 0, medium 1, low 1)
- reject: 8
- addressed_findings:
  - `[high]` `[patch]` `$now.format('dd/MM/yyyy HH:mm')` no node "Criar Note no Deal" corrigido para `$now.toFormat(...)` — Luxon (`$now` no n8n) não tem `.format()`; sem o fix, a Note (histórico append-only, entregável central da story) falharia silenciosamente em toda chamada.
  - `[high]` `[patch]` Adicionado `onError: continueRegularOutput` + `retryOnFail: true` aos 3 nodes Postgres do novo sub-workflow ("Resolver Identidade (1ª chamada)", "Buscar Mapeamento de Stage CRM", "Persistir rd_crm_contact_id") — fechava lacuna do próprio AC/I-O Matrix da story ("erro no sub-workflow nunca derruba o turno"), que antes só cobria os nodes `httpRequest`.
  - `[high]` `[patch]` Novo guard node "Identidade Resolvida?" logo após "Resolver Identidade (1ª chamada)": quando o resolver retorna `identidade` nulo/ausente (falha de query ou rejeição de validação), a rota desvia para um NoOp de aborto ("Registro CRM Não Realizado") em vez de desreferenciar `.identidade.id` sobre `null` e quebrar o sub-workflow.
  - `[high]` `[patch]` Novos guards "Busca de Contato Bem-sucedida?"/"Busca de Deal Bem-sucedida?" logo após as buscas por telefone/`contact_id`: com `onError: continueRegularOutput` a falha de busca reaproveita o "último dado válido" (sem `.data`) e antes caía na branch "não encontrado", criando um 2º contato/deal duplicado — violação direta do `Always` ("nunca cria 2º contato", "nunca mais de 1 card por cliente"); agora desvia para o mesmo NoOp de aborto.
  - `[medium]` `[patch]` Apertada a asserção de `CHECK` do `simplesvet_status` no comando de verificação da própria story (constraint real via regex, não mais um `or` satisfeito por palavras soltas em comentário).
  - `[medium]` `[patch]` Apertada a asserção de `onError`/`retryOnFail` dos `httpRequest` para exigir os dois juntos por node (antes: OR de 4 alternativas, que uma regressão futura removendo uma delas ainda passaria).
  - `[low]` `[patch]` `id`/`versionId` placeholder não-UUID do novo workflow substituídos por UUIDs reais, alinhando com a convenção de `01`/`02`/`03 - *.json`.
  - `[medium]` `[defer]` Falso positivo de duplicidade familiar entre famílias não aparentadas (lógica pré-existente da Story 4, ativada ao vivo pela 1ª vez por esta story) — registrado em `deferred`.
  - `[low]` `[defer]` Task de duplicidade familiar não é idempotente entre atendimentos futuros do mesmo cliente — registrado em `deferred`.
  - Acrescentado 1 novo comando de verificação cobrindo os guards recém-criados (onError/retryOnFail em todo Postgres + rota de aborto dos 3 guards), para a mitigação não regredir silenciosamente em passadas futuras.

## Auto Run Result

Status: `done`

**Resumo:** Dispatch pasta+id para a Story 11. Arquivo já existente com `status: in-review` — intent gap da passada anterior (nome/pet de cliente novo; confirmação de `GET /deals?filter=contact_id:`) já havia sido resolvido pelo Thiago fora deste run (commits `8f373f4`/`705d692`: `<intent-contract>` atualizado com a decisão de 2026-09-04 sobre `Info`/`$fromAI`, `.claude/skills/rd-station-api/references/crm.md` atualizado confirmando `contact_id` como filtro RDQL válido em `/deals`, implementação de `n8n/migrations/0011_registro_crm.sql` e `n8n/workflows/04 - Registrar Atendimento CRM.json` re-derivada, spec rearmada para `in-review`). EARLY EXIT direto para o step 4 (Review) por já estar `in-review`. Rodados em paralelo os 4 revisores síncronos (blind-hunter, edge-case-hunter, verification-gap, intent-alignment) contra o diff completo desde `baseline_revision` (8 arquivos, ~2800 linhas). Todo achado relevante foi verificado diretamente no código (inspeção de nodes/conexões via `python3`/`json`, leitura das migrations 0006/0011, consulta à documentação oficial do n8n para o comportamento real de `onError`) antes de triar — vários achados dos revisores automáticos não se confirmaram (ver `reject` abaixo).

**Achados `patch` (aplicados nesta passada, ver diff em `n8n/workflows/04 - Registrar Atendimento CRM.json` e no `## Verification` desta spec):**
1. `[high]` `$now.format('dd/MM/yyyy HH:mm')` no node "Criar Note no Deal" — `$now` do n8n é um `DateTime` do Luxon, que não tem `.format()` (API do Moment.js); corrigido para `$now.toFormat(...)`, mesmo padrão que `.toISO()` já usado em `01 - Agente.json`. Sem o fix, a Note (histórico append-only, entregável central do CAP-7) falharia silenciosamente em toda chamada.
2. `[high]` Nenhum dos 3 nodes Postgres do novo sub-workflow ("Resolver Identidade (1ª chamada)", "Buscar Mapeamento de Stage CRM", "Persistir rd_crm_contact_id") tinha `onError`/`retryOnFail`, ao contrário de todo `httpRequest` do mesmo arquivo — uma falha de banco quebrava o turno do `Agente Nouvet`, violando a garantia já exigida pela própria I/O & Edge-Case Matrix da story ("erro contido, nunca propaga ao Agente Nouvet"), que não é escopada só a falhas da API RD CRM. Corrigido adicionando `onError: continueRegularOutput` + `retryOnFail: true` aos 3.
3. `[high]` "Extrair Identidade e Stage" desreferenciava `.identidade.id`/`.nome_cliente`/etc. sem guarda contra `identidade` nulo (quando o resolver rejeita a linha, ex. `$fromAI` genuinamente falha em extrair nome/pet) — mesma classe de crash do intent gap anterior, agora só residual (a causa raiz — `Info` vs `$fromAI` — já foi resolvida no `<intent-contract>`). Corrigido com um novo guard node "Identidade Resolvida?" logo após o resolver: `identidade` nulo/ausente desvia para um NoOp de aborto ("Registro CRM Não Realizado") em vez de prosseguir.
4. `[high]` As IFs "Contato encontrado por telefone?"/"Deal existente?" (`{{ ($json.data || []).length > 0 }}`) não distinguiam uma busca que falhou (com `onError: continueRegularOutput`, o n8n reaproveita o "último dado válido" — o item de entrada, que não tem `.data` — em vez de expor um campo de erro) de uma busca que genuinamente não encontrou nada; as duas caem no mesmo `false` e criam um 2º contato/deal duplicado, violando o `Always` ("nunca cria 2º contato", "nunca mais de 1 card por cliente" / AD-6/AD-11). Confirmado o comportamento real de `onError` na doc oficial do n8n (`docs.n8n.io` — "Continue": *"proceeds to next node despite error, using last valid data"*, distinto de "Continue using error output"). Corrigido com guards "Busca de Contato Bem-sucedida?"/"Busca de Deal Bem-sucedida?" (`{{ Array.isArray($json.data) }}`) logo após cada busca, desviando falha para o mesmo NoOp de aborto.
5. `[medium]` A própria asserção de verificação da story para o `CHECK` de `simplesvet_status` (migration 0011) tinha um `or` satisfeito por palavras soltas em comentário, passando mesmo sem o `CHECK` real presente/correto. Apertada para exigir o `CHECK` de fato via regex.
6. `[medium]` A própria asserção de verificação para `onError`/`retryOnFail` dos `httpRequest` aceitava só um dos dois (OR de 4 alternativas) quando o `Always`/AC exigem os dois juntos; uma regressão futura removendo um dos dois ainda passaria. Apertada para exigir ambos por node.
7. `[low]` `id`/`versionId` do novo workflow eram placeholders não-UUID (`04regcrm...`), inconsistentes com `01`/`02`/`03 - *.json`. Substituídos por UUIDs reais.

Acrescentado 1 novo comando de `## Verification` cobrindo os guards recém-criados (onError/retryOnFail em todo Postgres + rota de saída para o NoOp de aborto nos 3 guards), para a mitigação não regredir silenciosamente numa passada futura.

**Achados `defer` (registrados em `deferred` no frontmatter, não corrigidos nesta passada):**
- `[medium]` Falso positivo de duplicidade familiar entre famílias não aparentadas — a CTE `duplicidade` (`identidade_cliente_pet_resolver`, Story 4/`0006`, não alterada por esta story) casa só por nome de pet case-insensitive entre telefones diferentes, sem sinal de dono/endereço; Story 11 é quem ativa esse aviso contra tráfego real pela 1ª vez.
- `[low]` Task de duplicidade familiar não é idempotente entre atendimentos futuros do mesmo cliente — `possivel_duplicidade_familiar` é recalculado a cada chamada, sem checar Task já aberta equivalente no deal; o `Always` só exige dedup dentro da mesma chamada, não entre chamadas futuras.

**Achados `reject` (verificados e descartados — não são bugs):**
- `setor` aceito via `$fromAI` sem validação contra os 5 valores canônicos: risco genérico já compartilhado por todo uso de `$fromAI` no projeto; o fallback de `mapeamento_stage_crm[setor]` ausente já é o comportamento gracioso documentado no `Block If`.
- Risco de descompasso de formato de telefone entre `Info.telefone_normalizado` e o filtro `phone:` do RD CRM: verificado que `telefone_normalizar` (`0006`) já produz E.164 limpo (`+55...`), idêntico ao formato oficial documentado para o filtro do CRM — falso positivo do revisor.
- `nome_cliente`/`nome_pet` sobrescritos sem `COALESCE` no `DO UPDATE` (ao contrário de `especie_pet`/`raca_pet`): verificado que é o mesmo comportamento documentado e deliberado desde a Story 4 (FR-4, correção dinâmica de identificação — cônjuge corrigindo nome no mesmo telefone/pet), não uma regressão desta story.
- `SELECT mapeamento_stage_crm FROM atendimento_config` direto (bypass de `atendimento_config_ler`) e preocupação de grant: já é decisão justificada no `Code Map`; verificado que `app_role` tem `GRANT SELECT` direto em `atendimento_config` desde a Story 1 (`0002_schema_operacional.sql`) — a query funciona.
- Confirmação de `GET /deals?filter=contact_id:`: já resolvida nesta mesma diff (`.claude/skills/rd-station-api/references/crm.md` agora documenta `contact_id` como propriedade RDQL filtrável em `/deals`, citando a doc oficial) — não é mais um gap.
- Mecanismo de transição `simplesvet_status` `pendente`→`cadastrado`: fora de escopo explícito desta story (`Always`: "nunca alterado por chamada seguinte do resolver") — problema de uma story futura.
- `identidade_cliente_pet_resolver` chamado duas vezes por invocação da tool: é exatamente o padrão de 2 chamadas prescrito pelo `Always` do contrato, não uma ineficiência de implementação.
- Falta de orientação específica para `resumo_atendimento`/nomes no fechamento de Orçamentos: sem comportamento negativo concreto demonstrado — a seção já roteia a um humano com todo o contexto (Story 10).

**Verificação executada:** os 3 comandos originais de `## Verification` (SQL da migration 0011, shape/onError do novo workflow, wiring de `01 - Agente.json`) re-executados após os patches — `OK` nos três. O novo 4º comando (guards de identidade/busca) também `OK`. Nenhuma verificação manual (VPS de dev/RD CRM real) foi possível nesta sessão — mesma limitação estrutural já documentada nas Stories 1-10 (sem ambiente n8n/RD CRM ao vivo disponível).

**Riscos residuais explícitos:** primeira story do projeto a integrar de fato com a API do RD CRM (OAuth2, Contacts/Deals/Notes/Tasks) — toda a verificação desta sessão foi estática (JSON/regex/SQL + doc oficial do n8n); validação end-to-end contra o RD CRM real (os 5 cenários da I/O Matrix, incl. os caminhos de erro agora endurecidos) fica para a VPS de dev. Os 2 itens em `deferred` (falso positivo de duplicidade familiar, Task não-idempotente) e os itens `reject` documentados acima ficam para acompanhamento/decisão futura se algum se mostrar impactante em produção.

**Followup review recomendado:** `true` — esta passada teve achados `patch` de severidade `high` (4 de 7; `3×medium + 1×low` também já soma 7, acima do limiar de 5).
