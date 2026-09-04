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
  - summary: >-
      Os `httpRequest` de criação (POST) do novo sub-workflow usam `retryOnFail` sem idempotency
      key; se a criação suceder no servidor RD CRM mas a resposta expirar/falhar no n8n antes de
      chegar, o retry automático pode criar um 2º contato/deal/task duplicado.
    evidence: |-
      `Criar Contato RD CRM`, `Criar Deal` e `Criar Task de Revisão`
      (`n8n/workflows/04 - Registrar Atendimento CRM.json`) têm `retryOnFail: true` -- exigido
      pelo `Always` desta story para todo `httpRequest`, sem exceção para chamadas de escrita --
      mas nenhum mecanismo de idempotency key ou de verificação pós-retry de que a criação
      anterior já teve sucesso. `.claude/skills/rd-station-api/references/crm.md` não documenta
      suporte a idempotency key nesses endpoints. Os guards `Busca de Contato/Deal Bem-sucedida?`
      desta mesma rodada já mitigam o caso de a *busca* falhar (evitando um 2º contato/deal por
      busca malsucedida tratada como "não encontrado"), mas não cobrem o caso de a própria
      *criação* ter sucesso silencioso no servidor seguido de um retry do cliente.
    location: >-
      n8n/workflows/04 - Registrar Atendimento CRM.json (nodes "Criar Contato RD CRM", "Criar Deal", "Criar Task de Revisão")
    severity: medium
baseline_revision: '705d6925ce109224ed7bbad3f6f06b404bb1e4f3'
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
- `python3 -c "import json; d = json.load(open('n8n/workflows/04 - Registrar Atendimento CRM.json')); nodes = {n['name']: n for n in d['nodes']}; postgres = [n for n in d['nodes'] if n.get('type') == 'n8n-nodes-base.postgres']; assert postgres and all((n.get('onError') or n['parameters'].get('onError')) and (n.get('retryOnFail') or n['parameters'].get('retryOnFail')) for n in postgres), 'todo node Postgres precisa de onError+retryOnFail (erro de banco nunca pode propagar ao Agente Nouvet)'; conns = d['connections']; abort = 'Registro CRM Não Realizado'; guard_continuations = {'Identidade Resolvida?': ('Buscar Mapeamento de Stage CRM', '\$json.identidade !== null && \$json.identidade !== undefined'), 'Busca de Contato Bem-sucedida?': ('Contato encontrado por telefone?', 'Array.isArray(\$json.data)'), 'Busca de Deal Bem-sucedida?': ('Deal existente?', 'Array.isArray(\$json.data)'), 'Contato Persistido?': ('Repassar Contato Persistido', '\$json.identidade !== null && \$json.identidade !== undefined'), 'Contato Criado Com Sucesso?': ('Usar Contato Criado', '\$json.data !== null && \$json.data !== undefined'), 'Deal Criado Com Sucesso?': ('Deal ID (Criado)', '\$json.data !== null && \$json.data !== undefined')}; assert set(guard_continuations) <= set(nodes), 'guard nodes de identidade/busca/persistência/criação ausentes'; checks = [(g, conns[g]['main']) for g in guard_continuations]; assert all(len(outs) == 2 for _, outs in checks), 'todo guard precisa ter exatamente 2 saídas (true/false)'; assert all({c['node'] for c in outs[0]} == {guard_continuations[g][0]} for g, outs in checks), 'saída true (index 0) de algum guard não aponta para a continuação esperada'; assert all({c['node'] for c in outs[1]} == {abort} for g, outs in checks), 'saída false (index 1) de algum guard não aponta para o NoOp de aborto'; assert all(guard_continuations[g][1] in nodes[g]['parameters']['conditions']['conditions'][0]['leftValue'] for g, _ in checks), 'condição booleana de algum guard foi alterada/invertida (não é só a existência da aresta que importa, mas qual lado do teste ela representa)'; print('OK')"` -- expected: `OK` (versão endurecida desta rodada: além dos 4 guards já cobertos, agora inclui os 2 novos guards "Contato Criado Com Sucesso?"/"Deal Criado Com Sucesso?" criados nesta passada; e, fechando a lacuna de verificação encontrada nesta rodada — a checagem anterior validava só a topologia do grafo (existência da aresta + índice true/false), nunca o conteúdo da expressão booleana de cada guard —, agora também assert que o fragmento esperado da condição aparece no `leftValue` de cada guard; uma inversão do operador (`!==`→`===`) ou um typo no nome do campo, que a versão anterior deixava passar silenciosamente, agora falha).
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

### 2026-09-04 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 2: (high 1, medium 1, low 0)
- defer: 1: (high 0, medium 1, low 0)
- reject: 12
- addressed_findings:
  - `[high]` `[patch]` "Persistir rd_crm_contact_id (2ª chamada resolver)" (2ª chamada Postgres ao resolver, que persiste `rd_crm_contact_id`) não tinha guard equivalente ao de "Resolver Identidade (1ª chamada)": com `onError: continueRegularOutput`, uma falha desse node fazia "Repassar Contato Persistido" desreferenciar `$json.identidade.rd_crm_contact_id` sobre um item sem `identidade` (o "último dado válido" reaproveitado não tem esse campo), quebrando o sub-workflow e violando a garantia central ("erro nunca propaga ao Agente Nouvet") — mesma classe de bug já corrigida para a 1ª chamada nesta mesma story, mas deixada residual nesta 2ª. Corrigido com novo guard node "Contato Persistido?" logo após, desviando para o mesmo NoOp de aborto ("Registro CRM Não Realizado") quando `identidade` vem nulo/ausente.
  - `[medium]` `[patch]` O comando de verificação que checa a rota dos 3 guards para o NoOp de aborto só exigia "alguma aresta" para o abort, sem checar qual índice de saída (true/false) era essa aresta — uma inversão acidental dos ramos true/false de um guard (bug fácil de introduzir editando no editor do n8n) passaria despercebida (demonstrado invertendo os ramos de "Identidade Resolvida?" e confirmando que o comando antigo ainda imprimia `OK`). Comando reescrito para checar, por guard (incluindo o novo "Contato Persistido?"), que a saída índice 0 (true) aponta para a continuação esperada e a saída índice 1 (false) aponta para o NoOp de aborto — a mesma inversão simulada agora falha a asserção.
  - `[medium]` `[defer]` `retryOnFail` nos `httpRequest` de criação (POST: "Criar Contato RD CRM", "Criar Deal", "Criar Task de Revisão") sem idempotency key — uma criação que suceda no servidor mas cuja resposta falhe/expire no cliente pode ser duplicada pelo retry automático; API do RD CRM não documenta idempotency key nesses endpoints. Registrado em `deferred` (risco arquitetural do padrão `retryOnFail` já mandatado pelo `Always` da story para todo `httpRequest`, não uma regressão introduzida por um node específico).
  - Verificados e descartados (`reject`) 12 achados dos 4 revisores: mudança de `id`/`versionId` do workflow (sem referência fixada em lugar algum — `01 - Agente.json` usa `workflowId: "SET_IN_N8N_UI"`, placeholder a relinkar manualmente); ausência de campo distintivo/log persistido nos 3 caminhos de aborto (`Registro CRM Não Realizado`) e nos `httpRequest` de escrita sem guard de sucesso — ambos batem com o risco residual já aceito e documentado no próprio `<intent-contract>` ("registro no CRM fica pendente sem log persistido"); "Buscar Mapeamento de Stage CRM" sem guard — verificado como degradação graciosa intencional via `|| null` em "Extrair Identidade e Stage", batendo com o `Block If` do contrato; ausência de sticky note documentando o caminho de erro e de contrato de saída padronizado entre os 3 nodes terminais — melhorias cosméticas/de observabilidade fora do escopo dos ACs; condição duplicada entre 2 guards — estilístico, não é bug; achado de que `$now.format('FFFF')` em `01 - Agente.json` (linha do systemMessage, não tocada por esta story) seria o mesmo bug do Luxon corrigido nesta story — verificado contra a documentação oficial do n8n (`docs.n8n.io/.../expression-reference/datetime`): `.format()` é uma extensão própria do n8n adicionada a objetos Luxon `DateTime` dentro do editor de expressões (só não existe no Code node, que roda Luxon puro) — não é bug; pelo mesmo motivo, o achado de que a troca `$now.format` → `$now.toFormat` desta story careceria de verificação automatizada de regressão foi descartado (a chamada original já funcionava; `toFormat` também funciona, não há comportamento divergente a proteger); guard "Identidade Resolvida?" não distinguir nulo-de-validação de erro de infra — mesmo tratamento (abortar sem propagar) já é o exigido pelo contrato para os dois casos, não uma lacuna.

### 2026-09-04 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 3: (high 1, medium 1, low 1)
- defer: 0
- reject: 9
- addressed_findings:
  - `[high]` `[patch]` "Criar Contato RD CRM" e "Criar Deal" (`httpRequest` POST, `onError: continueRegularOutput`) não tinham guard equivalente aos já existentes: uma falha de qualquer um dos dois fazia, respectivamente, "Usar Contato Criado" desreferenciar `$json.data.id` e "Deal ID (Criado)" desreferenciar `$json.data.id` sobre um item sem `.data` (o "último dado válido" reaproveitado pelo `continueRegularOutput` não tem esse campo) — isso lança uma exceção de expressão no node `Set`, que (sem `onError` próprio) derruba a execução inteira do sub-workflow; como o node `toolWorkflow` "Registrar Atendimento CRM" em `01 - Agente.json` também não tem `onError`, essa falha propagaria ao `Agente Nouvet`, violando a garantia central da story ("erro nunca propaga ao Agente Nouvet") — mesma classe de bug já corrigida 4 vezes nesta story (identidade, busca de contato, busca de deal, persistência de contato), agora fechada nos 2 pontos de criação que faltavam. Corrigido com 2 novos guard nodes, "Contato Criado Com Sucesso?" (após "Criar Contato RD CRM") e "Deal Criado Com Sucesso?" (após "Criar Deal"), checando `$json.data !== null && $json.data !== undefined` e desviando para o mesmo NoOp de aborto ("Registro CRM Não Realizado") em caso de falha — verificado que "Atualizar Deal (Stage)"/"Deal ID (Atualizado)" não precisam do mesmo tratamento, pois este último lê o id do deal a partir do resultado da busca anterior (`$('Deal existente?')`), nunca da resposta do próprio `PUT`.
  - `[medium]` `[patch]` O comando de verificação dos guards (endurecido na rodada anterior para checar índice de saída true/false) ainda não verificava o conteúdo da condição booleana de cada guard — só a topologia do grafo; uma inversão do operador (`!==`→`===`) ou um typo no nome do campo, mantendo a mesma aresta/índice, passaria despercebida (demonstrado invertendo a condição de "Identidade Resolvida?" para `identidade === null || identidade === undefined` e confirmando que o comando anterior ainda imprimia `OK`). Comando reescrito para também assert que o fragmento esperado da expressão (`leftValue`) aparece em cada guard — a mesma inversão simulada agora falha a asserção; comando também estendido para cobrir os 2 novos guards desta rodada.
  - `[low]` `[patch]` Os 4 guard nodes criados nas 2 rodadas anteriores ("Identidade Resolvida?", "Busca de Contato Bem-sucedida?", "Busca de Deal Bem-sucedida?", "Contato Persistido?") usavam `typeVersion: 2`, enquanto todo `IF` pré-existente no mesmo arquivo ("Contato RD CRM já vinculado?", "Contato encontrado por telefone?", "Deal existente?", "Precisa criar Task?") usa `2.2` — inconsistência sem motivo funcional. Alinhados (e os 2 novos guards desta rodada já criados em `2.2`) à convenção do arquivo.
  - Verificados e descartados (`reject`) 9 achados dos 4 revisores: ausência de conexão de saída do NoOp "Registro CRM Não Realizado"/falta de contrato de saída padronizado para quem chama a tool (mesmo padrão já usado pelo NoOp terminal "Nenhuma Task Necessária", que também não tem saída — design consistente do `executeWorkflowTrigger`, não uma lacuna desta rodada); ausência de Task/log/telemetria nos 4 caminhos de aborto para diagnosticar por que um registro parou — bate com o risco residual já aceito no próprio `<intent-contract>` ("registro no CRM fica pendente sem log persistido"), mesma classe já rejeitada na rodada anterior; "Buscar Mapeamento de Stage CRM" sem guard de sucesso — reconfirmado como degradação graciosa intencional via `|| {}` em "Extrair Identidade e Stage" (`(mapeamento_stage_crm || {})[setor] || null`), sem risco de exceção; `retryOnFail` nas 2 chamadas Postgres ao `identidade_cliente_pet_resolver` sem idempotency key — a porta única é desenhada para ser idempotente por construção (AD-11, "porta única idempotente"; `UPSERT`/`UPDATE` por telefone, não um `INSERT` sem chave), diferente do caso já deferido (`retryOnFail` nos `POST` de criação do RD CRM, que não têm essa garantia); ausência de `maxTries`/`waitBetweenTries` explícitos nos `retryOnFail` — usa o default do n8n, mesmo padrão de todos os `httpRequest`/Postgres já existentes no repositório, não uma regressão desta story; achado de que `$now.format('FFFF')` em `01 - Agente.json` seria o mesmo bug do Luxon corrigido nesta story — já verificado e descartado na rodada anterior (`.format()` é extensão válida do n8n para `DateTime`, não é bug), não tocado por esta story; sticky note não atualizada com o novo caminho de erro — cosmético/observabilidade, mesma classe já rejeitada; posicionamento (x/y) dos guard nodes inconsistente entre si no canvas — estilístico, sem efeito funcional.


## Auto Run Result

Status: `done`

**Resumo:** Dispatch por spec file (invocação apontou diretamente para este arquivo, `status: done`) — acionou uma nova passada de revisão (early exit para o step 4, `review_loop_iteration` zerado). Diff revisado: tudo desde `baseline_revision` (`705d6925ce109224ed7bbad3f6f06b404bb1e4f3`) até `HEAD` (`78135a7551fb1e3557c48be3d814458664860d10`) nos arquivos de código da story (`n8n/workflows/04 - Registrar Atendimento CRM.json`), isto é, os patches da rodada de review anterior (commits `0631fa1`/`68e85b2`/`78135a7`). `_bmad-output/implementation-artifacts/deferred-work.md` e a nova `stories/12-*.md` já apareciam modificados/untracked no worktree antes desta invocação (migração da orchestração/sweep para o ledger de deferred-work e uma story futura, ambos fora do escopo desta invocação) — não foram tocados nem incluídos no diff revisado, por instrução explícita da invocação. Rodados em paralelo os 4 revisores síncronos (blind-hunter, edge-case-hunter, verification-gap, intent-alignment) contra o diff escopado. Todo achado relevante foi verificado diretamente no código (leitura completa do grafo de nodes/conexões via `python3`/`json`, checagem dos expressions que dereferenciam a resposta de cada `httpRequest`, mutação real de uma condição de guard para provar a lacuna de verificação, reexecução dos 4 comandos de `## Verification`) antes de triar — vários achados dos revisores automáticos não se confirmaram (ver `reject` no Triage Log acima) ou já haviam sido revisados/rejeitados em rodadas anteriores desta mesma story.

**Arquivos alterados nesta passada:**
- `n8n/workflows/04 - Registrar Atendimento CRM.json` — 2 novos guard nodes, "Contato Criado Com Sucesso?" (após "Criar Contato RD CRM") e "Deal Criado Com Sucesso?" (após "Criar Deal"), fechando a última lacuna de dereferência não protegida de resposta de `httpRequest` nesta sub-workflow; `typeVersion` dos 4 guards de rodadas anteriores alinhado a `2.2` (convenção do arquivo); `versionId` atualizado.
- `_bmad-output/specs/spec-atendimento-nouvet/stories/11-cap-7-registro-e-memoria-no-crm.md` — comando de verificação nº3 estendido para cobrir os 2 novos guards e para checar o conteúdo da condição booleana de cada guard (não só a topologia do grafo); nova entrada no `## Review Triage Log`; este `## Auto Run Result`.

**Achados desta passada — breakdown:** 3 `patch` aplicados (1 `high`, 1 `medium`, 1 `low`), 0 `defer`, 9 `reject` (detalhe completo no Triage Log acima).

**Recomendação de review de acompanhamento:** `true` — 1 dos 3 achados `patch` desta passada foi `high` (critério de severidade `high` já basta, independente do score `3×medium + 1×low`; score desta passada = 3×1 + 1×1 = 4). Patch counts: high=1, medium=1, low=1.

**Verificação executada:** os 4 comandos de `## Verification` (SQL da migration 0011, shape/onError do novo workflow, wiring dos 6 guards agora com checagem de índice de saída **e** de conteúdo da condição booleana, wiring de `01 - Agente.json`) reexecutados após os patches — `OK` nos quatro. Regressão simulada (condição de "Identidade Resolvida?" invertida para `identidade === null || identidade === undefined`) confirmada como capturada pelo comando nº3 endurecido antes de ser descartada (não commitada). Validação estrutural adicional: nenhum node duplicado, todas as arestas de `connections` apontam para nodes existentes (checado via `python3`/`json`, fora do escopo dos comandos formais de `## Verification`). Nenhuma verificação manual (VPS de dev/RD CRM real) foi possível nesta sessão — mesma limitação estrutural já documentada nas Stories 1-10 e nas passadas anteriores desta story.

**Riscos residuais explícitos:** os 3 itens em `deferred` no frontmatter (falso positivo de duplicidade familiar; Task de duplicidade não-idempotente entre atendimentos futuros; `retryOnFail` sem idempotency key nos `httpRequest` de criação) — nenhum item novo adicionado nesta passada. Validação end-to-end contra o RD CRM real segue pendente para a VPS de dev, mesma limitação estrutural das Stories 1-10.
