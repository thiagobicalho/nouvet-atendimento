---
title: 'CAP-8 — Temporizadores, Continuidade e SLA'
type: 'feature'
created: '2026-09-04'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
baseline_revision: '42c5bd40c6c95789e938cbf9fffa3119a956ade1'
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: ['oversized']
deferred:
  - summary: >-
      Se a criação da Task de SLA falhar em `04` enquanto `estado_espera` ainda é
      marcado `aguardando_atendimento_humano`, o handoff fica sem SLA rastreado.
    evidence: |-
      "Gerenciar Task SLA (CAP-8)" e "Marcar Aguardando Atendimento Humano (CAP-8)"
      rodam em branches independentes a partir de "Criar Note no Deal", ambas com
      onError: continueRegularOutput. Se a primeira falhar (mesmo após retry) e a
      segunda suceder, nenhuma Task de SLA existe para aquele deal, e o Sweep B do
      cron (06) só varre Tasks já existentes -- o handoff fica permanentemente sem
      monitoramento de SLA. Mesmo padrão de branches paralelos tolerantes a falha
      parcial já usado em `04` desde a Story 11, não é um padrão novo desta story,
      mas o risco concreto (SLA nunca rastreado) é novo.
    location: >-
      n8n/workflows/04 - Registrar Atendimento CRM.json (nós "Gerenciar Task SLA
      (CAP-8)" e "Marcar Aguardando Atendimento Humano (CAP-8)")
    severity: medium
  - summary: >-
      Branches terminais novas (Task/deal/contato/identidade não encontrados) em
      `05`/`06` não têm log, alerta nem limite de tentativas.
    evidence: |-
      "Task SLA Não Gerenciada", "Deal da Task Não Encontrado", "Contato do Deal
      Ausente", "Identidade Não Encontrada (tenta próximo ciclo)" e "Busca de Tasks
      SLA Falhou" são todos noOp puros -- uma Task irrecuperável (ex. contato
      deletado no CRM) é reprocessada todo tick do cron (1 min) para sempre, sem
      visibilidade. Mesma convenção de branches terminais silenciosos já usada em
      workflows anteriores do projeto (não é um padrão novo desta story), mas é uma
      lacuna de observabilidade que vale atenção dedicada no nível do projeto.
    location: >-
      n8n/workflows/05 - Gerenciar Task SLA.json e n8n/workflows/06 - Lembretes e
      Escalonamento SLA.json (branches noOp terminais)
    severity: medium
  - summary: >-
      Comparação entre timestamp Postgres sem timezone e string ISO do Luxon via
      `new Date()` depende de tratamento implícito de timezone do node Postgres do
      n8n.
    evidence: |-
      "Lead Ativo Desde o Início do Ciclo?" (06) compara
      `n8n_status_atendimento.updated_at` (TIMESTAMP WITHOUT TIME ZONE) contra
      `inicio_ciclo_atual` (ISO construído via Luxon) usando `new Date(...)` puro em
      JS, sem normalização explícita de UTC em nenhum dos dois lados. Mesma classe
      de risco já presente onde quer que este projeto compare timestamps através da
      fronteira driver-pg/JS (ex. recuperação de lock por TTL da Story 3), não é
      exclusivo desta story.
    location: >-
      n8n/workflows/06 - Lembretes e Escalonamento SLA.json (nó "Lead Ativo Desde o
      Início do Ciclo?")
    severity: low
  - summary: >-
      `estado_espera` nunca é gravado de volta para `aguardando_cliente` -- uma vez que
      um telefone é marcado `aguardando_atendimento_humano` por um handoff, fica assim
      para sempre, mesmo em conversas futuras totalmente novas do mesmo cliente.
    evidence: |-
      `atendimento_estado_espera_marcar` só é chamada por `04` com o literal
      `'aguardando_atendimento_humano'` -- nenhum ponto do projeto (agente, cron,
      qualquer sub-workflow) jamais chama com `'aguardando_cliente'`. Como
      `n8n_status_atendimento.session_id` é `UNIQUE` por telefone (uma única linha por
      cliente, reaproveitada para sempre, Story 3), qualquer cliente que já passou por
      um handoff fica permanentemente fora do alcance do Sweep A (que exige
      `estado_espera='aguardando_cliente'`) em qualquer conversa futura e não relacionada
      -- mesmo que a Task de SLA daquele handoff antigo já tenha sido concluída no CRM
      há muito tempo. A leitura literal do Always da story (só `Registrar_atendimento_crm`
      escreve o estado, nunca especifica retorno) sustenta isso como comportamento
      monotônico por design, mas o efeito prático (lembrete de inatividade pré-handoff
      nunca mais dispara para um cliente recorrente) não é mencionado em nenhum lugar do
      Intent/Edge-Case Matrix.
    location: >-
      n8n/migrations/0012_temporizadores_sla.sql (função
      atendimento_estado_espera_marcar) e n8n/workflows/04 - Registrar Atendimento
      CRM.json (único chamador)
    severity: medium
  - summary: >-
      O cron `06` não tem trava contra suas próprias execuções sobrepostas -- só a
      criação/renovação de Task dentro de `05` é protegida por lock; o envio de
      mensagem/escalonamento por Task individual, em `06`, não é.
    evidence: |-
      A granularidade de referência do `scheduleTrigger` é de 1 minuto (nota da própria
      story, não é invariante travada). Se o processamento sequencial de uma leva de
      Tasks vencidas (deal -> contato -> identidade -> Conversas -> enviar/escalonar,
      por Task) ultrapassar esse intervalo, o próximo tick pode reprocessar a mesma Task
      vencida antes que o ciclo anterior tenha concluído sua renovação de `due_date`,
      gerando mensagem duplicada ao cliente/gestor e incremento duplo de
      `numero_ciclo_escalonamento` -- risco adjacente a SM-C2 (lembrete não pode virar
      spam percebido) sob volume real.
    location: >-
      n8n/workflows/06 - Lembretes e Escalonamento SLA.json (Sweep B, varredura
      sequencial de Tasks vencidas)
    severity: medium
  - summary: >-
      A correlação Task->telefone via `deal.contact_id -> identidade_cliente_pet` usa
      `ORDER BY i.updated_at DESC LIMIT 1`, que pode escolher a identidade errada quando
      mais de um telefone compartilha o mesmo `rd_crm_contact_id` (núcleo familiar,
      AD-11) -- e o `LEFT JOIN` resultante para `n8n_status_atendimento` pode então não
      casar linha nenhuma, quebrando silenciosamente a persistência do contador de
      ciclo.
    evidence: |-
      "Buscar Identidade e Status por Contato" (06) faz `SELECT ... FROM
      identidade_cliente_pet i LEFT JOIN n8n_status_atendimento s ON
      telefone_normalizar(s.session_id) = i.telefone WHERE i.rd_crm_contact_id = $1
      ORDER BY i.updated_at DESC LIMIT 1`. O próprio AD-11 documenta duplicidade familiar
      (cônjuges com o mesmo pet) como cenário real deste projeto, e a correlação
      Task->telefone via `deal.contact_id -> identidade_cliente_pet.rd_crm_contact_id`
      foi deliberadamente deixada a critério de quem implementa pelo "Block If" desta
      story -- sem outro campo para desambiguar, a heurística de recência pode
      selecionar o telefone/nome de um familiar que não é quem está de fato naquele
      atendimento. Quando isso acontece, o `LEFT JOIN` pode não encontrar a sessão do
      telefone errado, e "Incrementar Ciclo de Escalonamento" (`UPDATE ... WHERE
      telefone_normalizar(session_id) = $1`) afeta 0 linhas silenciosamente -- toda
      escalonação subsequente reporta "ciclo 1" mesmo que já tenham ocorrido vários.
    location: >-
      n8n/workflows/06 - Lembretes e Escalonamento SLA.json (nós "Buscar Identidade e
      Status por Contato" e "Incrementar Ciclo de Escalonamento")
    severity: medium
  - summary: >-
      "Enviar Atualização ao Cliente" (Sweep B) não verifica sucesso/falha do envio,
      diferente do fix já aplicado a "Enviar Lembrete ao Cliente" (Sweep A) para o mesmo
      tipo de risco.
    evidence: |-
      O nó é terminal (`onError: continueRegularOutput`, sem IF de status depois) --
      uma falha de envio ao cliente é engolida em silêncio, sem sinal em lugar nenhum.
      Diferente do caso já corrigido em Sweep A, aqui isso não suprime nenhum
      mecanismo futuro (a renovação da Task e o alerta ao gestor rodam em um branch
      paralelo independente, não acoplado ao sucesso desta mensagem) -- o cliente só
      deixa de saber que a equipe foi notificada novamente, sem efeito colateral em
      dados/estado.
    location: >-
      n8n/workflows/06 - Lembretes e Escalonamento SLA.json (nó "Enviar Atualização ao
      Cliente")
    severity: low
  - summary: >-
      `task_sla_lock_adquirir` não trata `p_ttl_minutos` nulo -- se a leitura de config
      upstream falhar, um lock preso pode nunca ser reclamado por TTL.
    evidence: |-
      `task_sla_lock_adquirir` usa `make_interval(mins => p_ttl_minutos)` sem
      `COALESCE`. Se "Buscar SLA Config" (05) falhar (`onError:
      continueRegularOutput`, padrão já usado em todo o projeto) e o valor chegar
      indefinido, `now() - make_interval(mins => NULL)` é `NULL`, e a condição de
      reclamo do `DO UPDATE` (`lock_adquirido_em < NULL`) nunca é verdadeira -- um
      lock preso por essa falha composta (config falha E existe lock preso) só se
      resolve quando uma leitura de config bem-sucedida ocorrer de novo para aquele
      `deal_id`.
    location: >-
      n8n/migrations/0012_temporizadores_sla.sql (função task_sla_lock_adquirir)
    severity: low
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
- `python3 -c "\nimport json\nd = json.load(open('n8n/workflows/05 - Gerenciar Task SLA.json'))\nnames = [n['name'] for n in d['nodes']]\nassert 'Adquirir Lock de Task SLA' in names and 'Liberar Lock de Task SLA' in names\nc = d['connections']\nassert c['Lock de Task SLA Adquirido?']['main'][0][0]['node'] == 'Buscar Tasks Abertas do Deal'\nfor n in ['Task SLA Não Gerenciada', 'Task SLA Renovada', 'Task SLA Criada', 'Falha ao Criar Task de SLA', 'Falha ao Renovar Task de SLA']:\n    assert c[n]['main'][0][0]['node'] == 'Liberar Lock de Task SLA'\nprint('OK')\n"` -- expected: `OK` (lock de concorrência por `deal_id` guarda a busca-então-cria/renova, e todo desfecho -- sucesso, falha de API ou não-gerenciado -- libera o lock).
- `python3 -c "import json; d = json.load(open('n8n/workflows/06 - Lembretes e Escalonamento SLA.json')); c = d['connections']; tb = [e['node'] for e in c['Task de SLA Confirmada Aberta?']['main'][0]]; assert 'Incrementar Ciclo de Escalonamento' in tb and 'Compor Dados de Escalonamento' in tb; fb = [e['node'] for e in c['Task de SLA Confirmada Aberta?']['main'][1]]; assert fb == ['Task de SLA Já Resolvida (Nenhuma Ação)']; print('OK')"` -- expected: `OK` (reconferência individual de cada Task, imediatamente antes de agir, é a única porta para enviar mensagem/escalonar; Task já resolvida durante o lote não gera nem mensagem nem recriação de Task -- SM-C2).
- `python3 -c "import json; d = json.load(open('n8n/workflows/06 - Lembretes e Escalonamento SLA.json')); c = d['connections']; assert c['Enviar Lembrete ao Cliente']['main'][0][0]['node'] == 'Envio de Lembrete Bem-sucedido?'; assert c['Envio de Lembrete Bem-sucedido?']['main'][0][0]['node'] == 'Renovar Janela de Espera do Cliente'; assert c['Envio de Lembrete Bem-sucedido?']['main'][1][0]['node'] == 'Envio de Lembrete Falhou (janela não renovada)'; assert c['Escalar ao Gestor (SLA)']['main'][0][0]['node'] == 'Escalonamento ao Gestor Bem-sucedido?'; assert c['Escalonamento ao Gestor Bem-sucedido?']['main'][0][0]['node'] == 'Renovar Task de SLA (Escalonado)'; print('OK')"` -- expected: `OK` (janela do cliente só renova após confirmar o envio do lembrete; Task só é renovada como "escalonada" após confirmar que o alerta ao gestor não falhou).
- `python3 -c "\nfor path in ['n8n/workflows/05 - Gerenciar Task SLA.json','n8n/workflows/06 - Lembretes e Escalonamento SLA.json']:\n    content = open(path).read()\n    assert 'atendimento_config_ler' in content\n    assert 'FROM atendimento_config' not in content\nprint('OK')\n"` -- expected: `OK` (`05`/`06` leem `sla_resposta_minutos`/`lock_ttl_minutos`/`destinatarios_gestor_sla` só via `atendimento_config_ler`, nunca por `SELECT` direto na tabela -- ponto único de leitura, AD-1).

**Manual checks (if no CLI):**
- Na VPS de dev: fechar um fluxo de setor de teste, confirmar no RD CRM que a Task "Acompanhamento SLA" nasce com `due_date` = agora+5min; aguardar sem responder e confirmar que o cron envia a atualização ao cliente e o alerta ao gestor após o vencimento, e que marcar a Task como `completed` no RD CRM impede o próximo disparo.
- Confirmar que mandar uma mensagem do telefone de teste enquanto a Task está vencida renova o `due_date` sem gerar mensagem duplicada de escalonamento.
- Invocar `05 - Gerenciar Task SLA.json` duas vezes em sequência rápida para o mesmo `deal_id` (ex.: duas execuções manuais quase simultâneas, ou `04` e um ciclo do cron `06` disparando para o mesmo deal) e confirmar no RD CRM que existe exatamente uma Task "Acompanhamento SLA" aberta no deal ao final (nunca duas) — valida o lock de concorrência por `deal_id` (`task_sla_lock_adquirir`/`task_sla_lock_liberar`, `n8n_task_sla_lock`) contra o Acceptance Criterion de não-duplicação.

## Review Triage Log

### 2026-09-04 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 7: (high 6, medium 0, low 1)
- defer: 3: (high 0, medium 2, low 1)
- reject: 10: (high 0, medium 0, low 10)
- addressed_findings:
  - `[high]` `[patch]` Sweep B (`06`, "Buscar Tasks de SLA Vencidas") lê `GET /tasks?filter=status:open+due_date:<agora` sem paginação e sem escopo por `deal_id` — em volume real pode deixar Tasks vencidas fora da primeira página sem disparar (risco a SM-3). Ação: paginar a busca.
  - `[high]` `[patch]` Filtro `due_date:<' + $now.toISO()` (06) usa ISO padrão do Luxon (milissegundos + offset numérico), nunca validado contra a RDQL real do RD CRM e com risco de colidir com o `+` que a própria RDQL usa como combinador de filtros. Ação: forçar `$now.toUTC().toISO({ suppressMilliseconds: true })` (sufixo `Z`, sem offset).
  - `[high]` `[patch]` `05 - Gerenciar Task SLA.json` não tem trava de concorrência no branch buscar-então-criar/renovar — chamadas concorrentes (hook do `04` e um tick do cron `06` para o mesmo `deal_id`, ou dois ticks do `06` sobrepostos) podem criar duas Tasks "Acompanhamento SLA" no mesmo deal, violando o próprio AC da story ("nunca duplicada entre execuções"). Ação: lock consultivo do Postgres por `deal_id` (mesmo padrão de `lock_conversa_adquirir`) ao redor do branch, mais nota de verificação manual confirmando Task única sob invocação repetida/concorrente.
  - `[high]` `[patch]` A reconfirmação ao vivo em Sweep B (06) acontece uma vez por lote (na busca inicial), não imediatamente antes de cada envio individual — uma Task resolvida por humano no meio do processamento do lote ainda pode receber lembrete/escalonamento obsoleto, o que fragiliza a condição obrigatória de Murat (SM-C2) citada explicitamente na invocação desta story. Ação: reconferir a Task individualmente (`GET /tasks/{id}` ou equivalente) imediatamente antes de "Enviar Atualização ao Cliente" e "Escalar ao Gestor (SLA)".
  - `[high]` `[patch]` `GET /v2/contacts/phone/{phone}` (RD Conversas) é usado pela primeira vez no projeto em `05`/`06`, assumindo campo `.id` na resposta sem confirmação — `02 - Escalar Humano.json` sempre usou `contact_id` pré-armazenado, nunca essa busca ao vivo; `crm.md` já registra que o formato de telefone do Conversas pode não bater com E.164 limpo. Ação: confirmar contra a documentação oficial do Conversas, corrigir campo/formato se necessário, documentar em `conversas.md` (mesma prática já aplicada a Tasks nesta mesma story do lado CRM).
  - `[high]` `[patch]` Em `06`, "Enviar Lembrete ao Cliente" tem `onError: continueRegularOutput` e seu output alimenta incondicionalmente "Renovar Janela de Espera do Cliente" — um envio que falha ainda assim renova `updated_at`, suprimindo silenciosamente o próximo lembrete por uma janela inteira de SLA mesmo sem o cliente ter recebido nada (ameaça direta a SM-3). Ação: só renovar a janela no branch de sucesso do envio.
  - `[low]` `[patch]` `destinatarios_gestor_sla` está tipado `"string"` no schema de input do `executeWorkflow` de "Escalar ao Gestor (SLA)", apesar de ser array JSONB (mesmo formato de `destinatarios_emergencia`) — inofensivo hoje só porque `attemptToConvertTypes` é `false`. Ação: corrigir o tipo do schema.


### 2026-09-04 — Review pass (follow-up)
- intent_gap: 0
- bad_spec: 0
- patch: 10: (high 3, medium 5, low 2)
- defer: 5: (high 0, medium 3, low 2)
- reject: 11: (high 0, medium 2, low 9)
- addressed_findings:
  - `[high]` `[patch]` Em `06`, o branch falso de "Task de SLA Confirmada Aberta?" (Task resolvida por humano durante a reconferência individual) chamava `05 - Gerenciar Task SLA.json` só com `deal_id` -- como nenhuma Task "Acompanhamento SLA" aberta existe mais, `05` criava uma nova, ressuscitando um caso já resolvido pelo humano. Ação: esse branch agora vira um noOp ("Task de SLA Já Resolvida (Nenhuma Ação)"), sem nenhuma chamada a `05`.
  - `[high]` `[patch]` `05 - Gerenciar Task SLA.json` tratava as chamadas `POST`/`PUT` a `/tasks` (`onError: continueRegularOutput`) como sucesso incondicional, liberando o lock e marcando "Task SLA Criada/Renovada" mesmo que a API tivesse retornado erro -- SLA nunca de fato rastreado, sem nenhum sinal. Ação: `options.response.response.fullResponse` habilitado nos dois `httpRequest`, com IF de `statusCode` 2xx antes de "Task SLA Criada"/"Task SLA Renovada"; falha vai para novos noOps ("Falha ao Criar/Renovar Task de SLA") que ainda liberam o lock.
  - `[high]` `[patch]` Em `06`, "Escalar ao Gestor (SLA)" (`onError: continueRegularOutput`, `retryOnFail`) alimentava "Renovar Task de SLA (Escalonado)" incondicionalmente -- uma falha no alerta ao gestor (a mensagem mais crítica do mecanismo de SLA) passava despercebida. Ação: novo IF "Escalonamento ao Gestor Bem-sucedido?" (`$json.error` ausente) antes da renovação; falha vai a um noOp dedicado e a Task não é renovada, permitindo nova tentativa no próximo ciclo do cron (due_date continua vencido).
  - `[medium]` `[patch]` `05`/`06` liam `sla_resposta_minutos`/`lock_ttl_minutos`/`destinatarios_gestor_sla` via `SELECT ... FROM atendimento_config WHERE id = 1` direto na tabela, contradizendo o próprio comentário da migration 0012 ("o cron lê a config via este mesmo ponto único de leitura (AD-1), nunca por SELECT direto na tabela") e o padrão já estabelecido em `01 - Agente.json`/`03 - Buscar Info Setor.json`. Ação: as duas queries agora usam `SELECT atendimento_config_ler('triagem') AS config`, com todas as expressões downstream ajustadas para `.item.json.config.<campo>` (mesmo padrão já usado no restante do projeto).
  - `[medium]` `[patch]` Em `06`, "Escalar ao Gestor (SLA)" mapeava um texto gerado pelo próprio cron ("Task de SLA vencida sem resposta humana...") para `mensagem_relevante`, campo que o template de `02 - Escalar Humano.json` renderiza literalmente como `Mensagem relevante do cliente: "..."` -- atribuindo ao cliente uma frase que ele nunca disse. Ação: campo `mensagem_relevante` esvaziado nesta chamada (o contexto já é transmitido corretamente via `motivo`/`resumo`, que são compostos pelo cron).
  - `[medium]` `[patch]` Nenhuma verificação automatizada cobria o lock de concorrência de `05` (só o "Manual checks" cobria, sob invocação humana). Ação: novo comando de verificação estrutural confirmando que o lock guarda a busca-então-cria/renova e que todo desfecho (sucesso, falha de API, ou não-gerenciado) libera o lock.
  - `[medium]` `[patch]` Nenhuma verificação automatizada cobria a reconferência individual obrigatória de Murat (SM-C2) em `06`. Ação: novo comando de verificação estrutural confirmando que só o branch verdadeiro de "Task de SLA Confirmada Aberta?" alimenta o envio/escalonamento, e que o branch falso não recria a Task.
  - `[medium]` `[patch]` Nenhuma verificação automatizada cobria os dois novos gates de sucesso-antes-de-renovar (lembrete ao cliente em Sweep A, escalonamento ao gestor em Sweep B). Ação: novo comando de verificação estrutural confirmando a topologia dos dois gates.
  - `[low]` `[patch]` Comentário da migration 0012 atribuía a origem do telefone usado por `atendimento_estado_espera_marcar` a um nó `Info` de `01 - Agente.json` que não existe nesse workflow -- o chamador real é `$('Receber Solicitação').item.json.telefone` em `04`. Ação: comentário corrigido para citar o nó/campo real.
  - `[low]` `[patch]` `conversas.md` tinha uma referência cruzada pendurada ("ver Deferred/observação abaixo") sem nenhuma observação correspondente no restante do arquivo. Ação: nota reescrita para ser autocontida.

## Auto Run Result

**Resumo:** Rodada de revisão de follow-up (sem novo intent) sobre a implementação já `done` do CAP-8. Não houve intent_gap nem bad_spec -- todos os achados de consequência ficaram dentro do espaço de decisão já delegado pela `<intent-contract>` original. Dez achados de `patch` foram corrigidos nesta passada (três `high`), cinco novos riscos foram para `deferred` (nenhum bloqueante), e onze achados foram descartados como ruído/duplicata/já coberto pelo spec literal.

**Arquivos alterados nesta passada:**
- `n8n/workflows/05 - Gerenciar Task SLA.json` -- leitura de config via `atendimento_config_ler('triagem')` (antes, SELECT direto); gate de `statusCode` 2xx antes de tratar `POST`/`PUT /tasks` como sucesso, com novos noOps de falha que ainda liberam o lock.
- `n8n/workflows/06 - Lembretes e Escalonamento SLA.json` -- leitura de config via `atendimento_config_ler('triagem')`; branch de Task-já-resolvida-durante-reconferência não chama mais `05` (evitava recriar uma Task já fechada pelo humano); gate de sucesso antes de renovar a Task como "escalonada" (`Escalonamento ao Gestor Bem-sucedido?`); `mensagem_relevante` não fabrica mais uma citação do cliente.
- `n8n/migrations/0012_temporizadores_sla.sql` -- comentário corrigido (fonte real do telefone em `04`).
- `.claude/skills/rd-station-api/references/conversas.md` -- referência cruzada pendurada removida.
- `_bmad-output/specs/spec-atendimento-nouvet/stories/12-cap-8-temporizadores-continuidade-e-sla.md` -- 4 novos comandos de verificação estrutural; 5 novos itens `deferred`; este `Auto Run Result` e a entrada de triagem desta passada.

**Achados de revisão (esta passada):**
- Patch: 10 (high 3, medium 5, low 2) -- todos aplicados e reverificados (ver Review Triage Log).
- Deferred: 5 (medium 3, low 2) -- adicionados à lista `deferred` do frontmatter.
- Reject: 11 (medium 2, low 9) -- descartados (duplicata de itens já deferidos em passada anterior, comportamento já coberto pela leitura literal do spec, ou sem dano concreto demonstrado).

**Recomendação de follow-up:** `true` (3 achados `high` nesta passada; score 3×5(medium)+1×2(low) = 17, já acima do limiar por conta dos `high`).

**Verificação realizada:**
- Os 5 comandos originais da story (schema/migration, grep de campos removidos, estrutura de `05`/`06`/`04`) foram reexecutados após os patches -- todos `OK`.
- 4 novos comandos de verificação estrutural adicionados e confirmados `OK`: lock de concorrência de `05` guardando e sendo liberado em todo desfecho; reconferência individual de Murat (SM-C2) como única porta de envio/escalonamento em `06`; gates de sucesso-antes-de-renovar (lembrete ao cliente e escalonamento ao gestor); ausência de leitura direta de `atendimento_config` em `05`/`06`.
- Integridade estrutural de `05`/`06` (todo nó referenciado em `connections` existe, nenhuma referência solta) verificada via inspeção Python após cada edição.
- RD CRM/n8n reais não disponíveis neste ambiente de build -- verificação manual na VPS de dev (já descrita na story) permanece pendente para o Nouvet/Btech.Cloud antes do go-live.

**Riscos residuais:** os 8 itens agora em `deferred` (3 da passada anterior + 5 desta), nenhum bloqueante para esta story: risco de SLA não-rastreado se `05` falhar como sub-workflow a partir de `04` (DW-75 já registrado); branches terminais silenciosos sem alerta/log (DW-76 já registrado); comparação de timestamp sem normalização explícita de UTC (DW-77 já registrado); `estado_espera` monotônico (nunca retorna a `aguardando_cliente`, afeta só clientes recorrentes pós-handoff); ausência de trava contra execuções sobrepostas do próprio cron `06`; heurística de correlação Task->telefone pode escolher o familiar errado quando um `rd_crm_contact_id` é compartilhado; "Enviar Atualização ao Cliente" sem verificação de sucesso (sem efeito colateral em estado); `task_sla_lock_adquirir` sem guarda contra TTL nulo.

**Nota de finalização:** `_bmad-output/implementation-artifacts/deferred-work.md` permanece modificado e não commitado nesta passada, por instrução explícita da invocação (arquivo de ledger de propriedade do orquestrador do bmad-loop, não revisado nem tocado por este run).
