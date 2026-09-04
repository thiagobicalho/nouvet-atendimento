---
title: 'CAP-8 — Temporizadores, Continuidade e SLA'
type: 'feature'
created: '2026-09-04'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** O handoff ao humano (fechamento de cada um dos 5 fluxos de setor via `Registrar_atendimento_crm`, Story 11) não tem nenhum mecanismo de temporização — nada renova a visibilidade do card, nada lembra o cliente inativo, e nada escalona ao gestor quando a equipe não responde, violando SM-3 ("zero leads perdidos silenciosamente") e a Constraint de SLA de 5 minutos do SPEC.

**Approach:** Um estado de espera por sessão (`n8n_status_atendimento.estado_espera`: `aguardando_cliente` default / `aguardando_atendimento_humano`, setado por `Registrar_atendimento_crm` no fechamento de um fluxo de setor); uma Task dedicada de SLA no deal do RD CRM (criada/renovada por um novo sub-workflow reutilizável `05 - Gerenciar Task SLA.json`), `due_date` = agora + `sla_resposta_minutos` (já existe, seedado=5, exposto por `atendimento_config_ler` desde a Story 5, sem consumidor até agora); e um novo workflow cron independente (`06 - Lembretes e Escalonamento SLA.json`, `scheduleTrigger`, AD-1) que varre sessões `aguardando_cliente` vencidas (lembrete ao cliente) e Tasks de SLA abertas vencidas no RD CRM, **reconferindo ao vivo no momento do disparo** que a Task ainda está `open` (condição obrigatória de Murat, evita SM-C2), antes de atualizar o cliente e escalonar ao gestor (reusando `02 - Escalar Humano.json`) com urgência crescente a cada ciclo.

## Boundaries & Constraints

**Always:** `sla_resposta_minutos` é a única fonte do intervalo para os dois estados — nunca hardcoded, nunca um campo novo. Antes de enviar qualquer mensagem de lembrete/escalonamento ligada a uma Task de SLA, o cron reconfere ao vivo (`GET /tasks?filter=status:open`) que ela continua aberta — nunca age sobre estado potencialmente desatualizado. `estado_espera` só é setado para `aguardando_atendimento_humano` por `Registrar_atendimento_crm`, no fechamento de um dos 5 fluxos de setor (Care Center/Consultas/Vacinas/Exames/Orçamentos) — nunca por `Escalar_humano`. A Task de SLA é distinta da Task de cadastro-pendente/duplicidade (Story 11): `name` fixo próprio (ex. "Acompanhamento SLA"), nunca reaproveita nem sobrescreve a Task da Story 11 no mesmo deal — um deal pode ter as duas Tasks simultaneamente. "Resposta relevante do lead" que renova o vencimento é detectada via `n8n_status_atendimento.updated_at` (já tocado a cada turno por `lock_conversa_adquirir`, Story 3, sem alteração necessária) — o cron compara essa marca contra o início do ciclo atual da Task antes de escalonar: se o lead esteve ativo desde então, renova o `due_date` sem enviar mensagem nem incrementar `numero_ciclo_escalonamento` (implementa "renovar a cada resposta relevante do lead" sem exigir nenhuma mudança em `01 - Agente.json`). Escalonamento ao gestor reusa `02 - Escalar Humano.json` (chamado via `executeWorkflowTrigger` pelo cron, não pelo agente) com `destinatarios_gestor_sla` (novo campo de config, mesmo formato/convenção de `destinatarios_emergencia`, público distinto — CAP-12 nunca reusa este campo e vice-versa). Urgência crescente é expressa objetivamente (número do ciclo + minutos totais de atraso no texto), nunca por rótulos de severidade inventados sem confirmação do Nouvet. `numero_ciclo_escalonamento` reseta a 0 sempre que `Registrar_atendimento_crm` (re)marca `aguardando_atendimento_humano`.

**Block If:** Nenhuma decisão bloqueante. Nome exato da Task de SLA, granularidade do `scheduleTrigger` (referência: 1 minuto) e o mecanismo de correlação Task→telefone (`deal.contact_id` → `identidade_cliente_pet.rd_crm_contact_id`) ficam a critério de quem implementa, dentro das invariantes acima.

**Never:** Não modifica `01 - Agente.json` nem o `systemMessage`/tools do `Agente Nouvet`. Não modifica `02 - Escalar Humano.json` além de chamá-lo como sub-workflow a partir do novo cron. Não cobre handoffs via `Escalar_humano` (Sinal de Alerta/fora de escopo/convênio) — esses continuam sem card no RD CRM (gap de SM-1 já conhecido e deixado em aberto pela Story 11, DW-50); esta story cobre só a SLA de atendimentos que já têm card (fechamento de fluxo de setor), não fecha aquele gap. Não implementa "aguardando_cliente" pré-card com Task no RD CRM — é só lembrete via WhatsApp, rastreado inteiramente em Postgres, sem tocar CRM. Não altera a porta única de identidade (Story 4) nem a lógica de contato/deal/Note (Story 11) além do hook mínimo ao final do fechamento de setor.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Lead responde durante Aguardando Atendimento Humano | Task de SLA aberta; `n8n_status_atendimento.updated_at` mais recente que o início do ciclo atual | Cron renova `due_date` (+sla) sem enviar mensagem nem incrementar ciclo | Nenhum erro |
| Humano não responde 1 ciclo | Task de SLA vencida (`due_date` no passado), sem atividade recente do lead | Cron reconfere `status:open`, envia atualização ao cliente + escalona ao gestor (ciclo 1), renova `due_date` | Nenhum erro |
| Humano já resolveu | Task marcada `completed`/`canceled` no RD CRM antes do disparo | Cron não envia nada (excluída pelo filtro `status:open` da reconferência) | Nenhum erro, sem spam (SM-C2) |
| Cliente inativo pré-handoff | `estado_espera='aguardando_cliente'`, sessão vencida (`now() - updated_at >= sla_resposta_minutos`) | Cron envia lembrete automático ao cliente via RD Conversas | Nenhum erro |
| Escalonamento repetido | Task ainda vencida no ciclo seguinte, sem atividade do lead | `numero_ciclo_escalonamento` incrementa; texto reflete urgência crescente (minutos totais + número do ciclo) | Nenhum erro |

</intent-contract>

## Code Map

- `n8n/migrations/0002_schema_operacional.sql` -- schema atual de `n8n_status_atendimento` (`aguardando_followup`, `numero_followup`) e `atendimento_config` (`lembretes_horas`, `follow_ups_horas`, `max_followups`); nenhum dos 5 é seedado, exposto por `atendimento_config_ler` ou referenciado por qualquer workflow hoje (confirmado por grep) -- a `0012` remove os 5 e adiciona os substitutos desta story.
- `n8n/migrations/0005_debounce_lock_ttl.sql` -- `lock_conversa_adquirir` já seta `updated_at = now()` em toda aquisição de lock (a cada turno) -- é a marca de "última atividade do lead" reaproveitada por esta story, sem alteração.
- `n8n/migrations/0010_atendimento_config_ler_lock_ttl.sql` -- corpo atual de `atendimento_config_ler` (já expõe `sla_resposta_minutos` e `destinatarios_emergencia` na fatia `triagem`) -- a `0012` estende via `CREATE OR REPLACE` incluindo `destinatarios_gestor_sla`, mesmo padrão.
- `.claude/skills/rd-station-api/references/crm.md` -- Tasks hoje só documenta `POST /tasks`; `GET /tasks` (filtros RDQL `deal_id`/`status`/`due_date`, comparadores `<`/`>`) e `PUT /tasks/{id}` (campos editáveis `due_date`/`status`, enum `open|completed|canceled`, sem valor "done") confirmados nesta sessão via `developers.rdstation.com/reference/crm-v2-list-tasks.md` e `.../crm-v2-update-task.md` -- expandir a referência com esse contrato antes de implementar (mesma prática já usada pela Story 11 para Tasks/Notes).
- `n8n/workflows/04 - Registrar Atendimento CRM.json` -- nó "Criar Note no Deal" (fim do fluxo, após o branch de Task da Story 11): acrescentar chamada a `05 - Gerenciar Task SLA.json` (input: `deal_id`) + `atendimento_estado_espera_marcar(telefone, 'aguardando_atendimento_humano')` -- único ponto de escrita de estado desta story no fluxo principal, sem tocar nos nós/branches já existentes da Story 11.
- `n8n/workflows/02 - Escalar Humano.json` -- reusado sem alteração como sub-workflow chamado pelo novo cron (`destinatarios_gestor_sla` no lugar de `destinatarios_emergencia`, `motivo`/`resumo` compostos pelo cron, não por `$fromAI`).
- `stories/11-cap-7-registro-e-memoria-no-crm.md` -- Code Map/Boundaries (porta única de contato/deal, `rd_crm_deal_id` nunca persistido em Postgres/AD-6, Tasks/Notes já wired, `mapeamento_stage_crm`) como base a estender, não recriar.
- `stories/6-cap-2-triagem-e-direcionamento.md` -- DW-47 (guarda contra `Escalar_humano` repetido, candidato a esta story) e o padrão de sub-workflow de alerta reusado aqui.
- `ARCHITECTURE-SPINE.md` AD-1 (gatilho cron confirmado + condição obrigatória de reconferir resolução antes de disparar, redigida quase identicamente à instrução de Thiago nesta invocação) -- invariante central desta story.

## Tasks & Acceptance

**Execution:**
- `n8n/migrations/0012_temporizadores_sla.sql` -- remove `aguardando_followup`/`numero_followup` (`n8n_status_atendimento`) e `lembretes_horas`/`follow_ups_horas`/`max_followups` (`atendimento_config`, nunca usados); adiciona `estado_espera VARCHAR(30) NOT NULL DEFAULT 'aguardando_cliente' CHECK (... IN ('aguardando_cliente','aguardando_atendimento_humano'))` e `numero_ciclo_escalonamento INTEGER NOT NULL DEFAULT 0` a `n8n_status_atendimento`; adiciona `destinatarios_gestor_sla JSONB NOT NULL DEFAULT '[]'::jsonb` a `atendimento_config`; cria `atendimento_estado_espera_marcar(p_session_id TEXT, p_estado TEXT) RETURNS VOID` (seta `estado_espera`, zera `numero_ciclo_escalonamento`, mesma falha silenciosa para estado fora do domínio); estende `atendimento_config_ler` para incluir `destinatarios_gestor_sla` na fatia `triagem` -- schema/contrato base de CAP-8.
- `n8n/workflows/05 - Gerenciar Task SLA.json` -- novo sub-workflow: busca Task de SLA aberta do deal (`GET /tasks?filter=deal_id:...`, filtra por `name` fixo), cria (`POST /tasks`) se ausente ou renova `due_date` (`PUT /tasks/{id}`) se presente -- porta única de criação/renovação da Task de SLA, chamada por `04` e pelo cron `06`.
- `n8n/workflows/04 - Registrar Atendimento CRM.json` -- ao final de cada fechamento de setor, chamar `05` e `atendimento_estado_espera_marcar(telefone, 'aguardando_atendimento_humano')` -- implementa a metade "handoff" de CAP-8 sem tocar no `systemMessage`.
- `n8n/workflows/06 - Lembretes e Escalonamento SLA.json` -- novo workflow cron (`scheduleTrigger`): sweep A (Postgres: sessões `aguardando_cliente` vencidas → lembrete ao cliente via RD Conversas); sweep B (`GET /tasks?filter=status:open+due_date:<now` → para cada Task de SLA, busca deal/contato/telefone, distingue "lead ainda ativo" (renova sem avisar) de "realmente vencido" (renova + envia atualização ao cliente + escalona via `02` com urgência crescente) -- implementa o mecanismo de temporização/escalonamento de CAP-8.
- `.claude/skills/rd-station-api/references/crm.md` -- documentar `GET /tasks` e `PUT /tasks/{id}` (campos, filtros RDQL, enum de status) -- fecha a lacuna encontrada nesta investigação (mesma prática da Story 11).

**Acceptance Criteria:**
- Given os 5 cenários da I/O & Edge-Case Matrix, when reproduzidos contra a topologia dos workflows/migration (inspeção estática, sem n8n/RD CRM real disponível neste ambiente de build), then o comportamento bate com a coluna "Expected Output/Behavior".
- Given `04 - Registrar Atendimento CRM.json`, when um fechamento de setor roda (para o mesmo telefone, mais de uma vez), then `estado_espera` da sessão vira/permanece `aguardando_atendimento_humano` e existe exatamente uma Task de SLA aberta no deal (nunca duplicada entre execuções).
- Given o cron (`06`), when uma Task de SLA está `completed`/`canceled` no momento da varredura, then nenhuma mensagem é enviada (nem cliente, nem gestor).
- Given `n8n/migrations/0012_temporizadores_sla.sql` aplicada, when se inspeciona o repositório, then `aguardando_followup`/`numero_followup`/`lembretes_horas`/`follow_ups_horas`/`max_followups` não aparecem em nenhum arquivo de `n8n/workflows/` (grep vazio).
- Given `atendimento_config_ler('triagem')`, when chamada, then o JSON retornado inclui `destinatarios_gestor_sla`.
- Given a Task de SLA e a Task de cadastro-pendente/duplicidade (Story 11) no mesmo deal, when ambas existem, then `05 - Gerenciar Task SLA.json` nunca edita/lê a Task da Story 11 (distinção por `name`).

## Design Notes

`updated_at` de `n8n_status_atendimento` já é tocado a cada turno desde a Story 3 (`lock_conversa_adquirir`) — reusar esse timestamp como proxy de "última resposta relevante do lead" evita qualquer mudança em `01 - Agente.json` e mantém o hot path do agente sem round-trip novo ao RD CRM por turno (preocupação de latência/NFR-1). A Task de SLA é deliberadamente separada da Task de cadastro-pendente/duplicidade (Story 11) porque servem propósitos distintos (SLA de resposta vs. cadastro/duplicidade) e podem coexistir no mesmo deal sem conflito.

O gap de cobertura para handoffs via `Escalar_humano` (Sinal de Alerta/fora de escopo/convênio, que não passam por `Registrar_atendimento_crm` e portanto não têm card/deal) é uma continuação deliberada do gap de SM-1 já registrado e deixado em aberto pela Story 11 (DW-50) — resolvê-lo exigiria estender `Escalar_humano` para também criar/atualizar um deal, uma mudança de escopo não pedida por `stories.yaml`/pela instrução de Thiago nesta invocação (que trata só da reconferência de resolução antes de disparar), e por isso tratada aqui como fora de escopo, não como gap de intenção desta story.

Reconciliação com `glossary.md` ("Aguardando Cliente/Aguardando Atendimento Humano — estado do card"): antes do handoff nenhum card existe ainda (Story 11 só cria o deal no fechamento do fluxo de setor), então "Aguardando Cliente" pré-handoff é rastreado só em Postgres, sem Task — leitura mais estrita da linguagem do glossário teria essa fase amarrada a um card que ainda não existe; a leitura adotada aqui (Postgres-only antes do card, Task+Postgres depois) é a única que não inventa uma criação de card antecipada não pedida por nenhuma story anterior.

## Verification

**Commands:**
- `python3 -c "content = open('n8n/migrations/0012_temporizadores_sla.sql').read(); up = content.upper(); assert 'DROP COLUMN AGUARDANDO_FOLLOWUP' in up and 'DROP COLUMN NUMERO_FOLLOWUP' in up; assert 'DROP COLUMN LEMBRETES_HORAS' in up and 'DROP COLUMN FOLLOW_UPS_HORAS' in up and 'DROP COLUMN MAX_FOLLOWUPS' in up; assert 'ESTADO_ESPERA' in up and 'NUMERO_CICLO_ESCALONAMENTO' in up and 'DESTINATARIOS_GESTOR_SLA' in up; assert 'ATENDIMENTO_ESTADO_ESPERA_MARCAR' in up; assert up.count('DESTINATARIOS_GESTOR_SLA') >= 2; print('OK')"` -- expected: `OK` (schema removido/adicionado conforme o Code Map, campo novo exposto por `atendimento_config_ler`).
- `python3 -c "import subprocess; out = subprocess.run(['grep','-rl','aguardando_followup\\|numero_followup\\|lembretes_horas\\|follow_ups_horas\\|max_followups','n8n/workflows/'], capture_output=True, text=True).stdout; assert out.strip() == ''; print('OK')"` -- expected: `OK` (nenhum workflow referencia os campos removidos).
- `python3 -c "import json; d = json.load(open('n8n/workflows/05 - Gerenciar Task SLA.json')); assert 'nodes' in d and 'connections' in d; trg = [n for n in d['nodes'] if n.get('type')=='n8n-nodes-base.executeWorkflowTrigger'][0]; assert 'deal_id' in [v['name'] for v in trg['parameters']['workflowInputs']['values']]; print('OK')"` -- expected: `OK` (workflow válido, `deal_id` como input).
- `python3 -c "import json; d = json.load(open('n8n/workflows/06 - Lembretes e Escalonamento SLA.json')); assert 'nodes' in d and 'connections' in d; assert any(n.get('type')=='n8n-nodes-base.scheduleTrigger' for n in d['nodes']); print('OK')"` -- expected: `OK` (cron válido, gatilho `scheduleTrigger`).
- `python3 -c "import json; d = json.load(open('n8n/workflows/04 - Registrar Atendimento CRM.json')); content = json.dumps(d); assert 'Gerenciar Task SLA' in content and 'atendimento_estado_espera_marcar' in content; print('OK')"` -- expected: `OK` (hook de handoff presente).

**Manual checks (if no CLI):**
- Na VPS de dev: fechar um fluxo de setor de teste, confirmar no RD CRM que a Task "Acompanhamento SLA" nasce com `due_date` = agora+5min; aguardar sem responder e confirmar que o cron envia a atualização ao cliente e o alerta ao gestor após o vencimento, e que marcar a Task como `completed` no RD CRM impede o próximo disparo.
- Confirmar que mandar uma mensagem do telefone de teste enquanto a Task está vencida renova o `due_date` sem gerar mensagem duplicada de escalonamento.

## Auto Run Result

Status: `ready-for-dev`
Blocking condition: nenhuma.

**Resumo:** Dispatch pasta+id para a Story 12 (`CAP-8 — Temporizadores, Continuidade e SLA`), primeiro despacho para este id (nenhum arquivo prévio em `stories/12-*.md`). Investigação cobriu `SPEC.md`, `user-journeys.md`, `glossary.md`, `ARCHITECTURE-SPINE.md` (AD-1), as 11 stories anteriores completas (Code Map/Design Notes/Auto Run Result/deferred de cada uma), `deferred-work.md` (DW-47/DW-50, ambos candidatos explícitos a esta story), o estado real dos workflows (`01`-`04`) e migrations (`0001`-`0011`) via inspeção direta (`python3`/`json`), e a documentação oficial da RD Station (`developers.rdstation.com`) para preencher uma lacuna real encontrada na skill `rd-station-api` (Tasks só documentava `POST /tasks`; `GET /tasks` e `PUT /tasks/{id}` confirmados nesta sessão, incluindo o enum `status` e os filtros RDQL necessários). Instrução extra do invocador (reconferência obrigatória de resolução antes do disparo do cron, condição de Murat contra spam/SM-C2) incorporada como invariante `Always` central do spec.

**Decisões de escopo tomadas nesta passada (registradas no spec, não fantasiadas):** (1) o mecanismo de SLA/escalonamento desta story cobre só atendimentos que já têm card no RD CRM (fechamento de um dos 5 fluxos de setor via `Registrar_atendimento_crm`) — handoffs via `Escalar_humano` (Sinal de Alerta/fora de escopo/convênio) continuam sem card, gap de SM-1 já registrado e deixado em aberto pela Story 11 (DW-50), não fechado aqui; (2) "resposta relevante do lead" que renova o vencimento é detectada via `n8n_status_atendimento.updated_at` (já tocado a cada turno desde a Story 3), evitando qualquer mudança em `01 - Agente.json` e round-trip novo ao RD CRM no hot path do agente; (3) a reconferência de resolução exigida por Murat é satisfeita estruturalmente pela própria consulta ao vivo `GET /tasks?filter=status:open` no momento do disparo, não por um passo de dupla checagem separado; (4) `sla_resposta_minutos` (já existente, seedado, exposto por `atendimento_config_ler` desde a Story 5, sem consumidor até agora) é reaproveitado como única fonte do intervalo, em vez de introduzir um campo novo; (5) `aguardando_followup`/`numero_followup` (`n8n_status_atendimento`) e `lembretes_horas`/`follow_ups_horas`/`max_followups` (`atendimento_config`) — schema morto desde a Story 1, nunca seedado/exposto/referenciado por nenhum workflow (confirmado por grep) e de granularidade incompatível com o SLA fixo de 5 minutos do SPEC — são removidos e substituídos pelo modelo desta story, em vez de reaproveitados como estão.

**Riscos residuais explícitos:** primeira story do projeto a fazer `PUT`/`GET` contra a API de Tasks do RD CRM (Stories 11 só usava `POST`) — toda verificação prevista nesta passada é estática (JSON/regex/SQL), sem n8n/RD CRM real disponível neste ambiente de build, mesma limitação já documentada desde a Story 1. O gap de cobertura para handoffs via `Escalar_humano` (item 1 acima) permanece explícito no `Never`/Design Notes, não como item `deferred` formal (nenhuma implementação ainda rodou nesta story para gerar um achado de review).
