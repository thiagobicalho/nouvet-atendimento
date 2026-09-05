---
title: 'CAP-12 — Emergências Declaradas pelo Cliente'
type: 'feature'
created: '2026-09-04'
status: 'in-review'
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: [oversized]
deferred: []
baseline_revision: 'f9b5bb9ed1623fc72fa13b16aa3eef750476c366'
---

<intent-contract>

## Intent

**Problem:** O `systemMessage` de `01 - Agente.json` já reserva o título "SINAIS DE ALERTA E EMERGÊNCIA DECLARADA", mas a tag `<sinais-de-alerta>` só implementa a metade "Sinal de Alerta" (sintoma da lista de config, inferido pela IA) — quando o próprio cliente declara explicitamente uma emergência (distinto do Sinal de Alerta, ver `glossary.md`), hoje isso cai só no fluxo normal de triagem, sem handoff de prioridade máxima nem alerta a humano.

**Approach:** Estender a mesma seção de prioridade máxima do `systemMessage` com o reconhecimento comportamental de Emergência Declarada e um 5º motivo (`"Emergência Declarada"`) da ferramenta `Escalar_humano` já existente — reaproveitando `destinatarios_emergencia` e o sub-workflow `02 - Escalar Humano.json` sem nenhuma alteração de código (o `splitOut` já envia a TODOS os itens do array desde a Story 6, satisfazendo "todos os profissionais envolvidos", padrão escalar-humano-multi de AD-4).

## Boundaries & Constraints

**Always:** Emergência Declarada é distinta de Sinal de Alerta (`glossary.md`): Emergência é afirmada explicitamente pelo próprio cliente, nunca depende de bater com a lista `sinais_alerta_clinico`; Sinal de Alerta continua sendo só o sintoma inferido pela IA a partir dessa lista — os dois convivem como motivos separados, nenhum substitui o outro. `destinatarios_emergencia` (mesmo campo de config, já lido pelo nó `Info` desde a Story 6) continua sendo a única fonte de destinatários — nunca hardcoded, nunca decidido pelo LLM; nenhuma mudança de topologia em `02 - Escalar Humano.json` é necessária (já é array + `splitOut`, "já adaptado para multi desde já"). Quando a mesma mensagem contém tanto um sintoma configurado quanto uma declaração explícita de emergência, uma única chamada de `Escalar_humano` é feita (mesmo invariante da Validação 10) com `motivo="Emergência Declarada"` — mais específico, prevalece sobre Sinal de Alerta quando ambos se aplicam ao mesmo evento. Emergência Declarada tem a mesma prioridade máxima de Sinal de Alerta: interrompe qualquer outra seção do SOP, inclusive Abertura/Identificação, a qualquer momento da conversa; a IA nunca diagnostica nem minimiza. Todo ponto do prompt que hoje enumera "4 motivos"/"4 casos"/"4 valores" de `Escalar_humano` (tool `description`, hint `$fromAI('motivo', ...)`, SOP 2.3 intro/fechamento, Validação 23) passa a 5, preservando os 4 textos já existentes byte-a-byte (mesma disciplina "nenhuma regressão" já usada pela Story 13 ao passar de 3 para 4 motivos).

**Block If:** Nenhuma decisão bloqueante identificada — reaproveita 100% do mecanismo já existente (config + sub-workflow), sem schema novo, sem sub-workflow novo, sem tool nova.

**Never:** Não cria nenhuma lista de "palavras-gatilho de emergência" configurável nova — reconhecer "declaração explícita de emergência" é julgamento comportamental do LLM sobre o texto do cliente (ex.: "isso é uma emergência", "é urgente, ele pode morrer"), não um `IN` contra lista de config, mesmo padrão já usado para reconhecer convênio mencionado (SOP 2.3, item 3) sem lista fechada. Não altera `02 - Escalar Humano.json` (já suporta multi-destinatário desde a Story 6). Não cria campo novo em `atendimento_config` nem migration nova — reaproveita `destinatarios_emergencia` já exposto por `atendimento_config_ler('triagem')` desde a Story 2/0004. Não introduz tool nova nem sub-workflow novo. Não persiste motivo/timestamp em nenhuma tabela (mesmo escopo self-imposed das Stories 6/13).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cliente declara emergência explicitamente | "isso é uma emergência, meu cachorro comeu veneno" | `Escalar_humano(motivo="Emergência Declarada")` chamado; IA reconhece a gravidade, nunca diagnostica/minimiza, informa prioridade máxima; conversa continua depois | Se `destinatarios_emergencia` vazio, `noOp` silencioso (mesmo fallback já aceito desde a Story 6) |
| Sintoma da lista sem declaração explícita de emergência | "ele está vomitando há 3 dias" (sem citar "emergência"/"urgente") | Continua sendo Sinal de Alerta (`motivo="Sinal de Alerta"`), comportamento inalterado desde a Story 6 | Idem |
| Sintoma configurado + declaração explícita no mesmo evento | "é uma emergência, ele vomita há 3 dias" | Uma única chamada de `Escalar_humano`, `motivo="Emergência Declarada"` (mais específico) | Idem |
| `destinatarios_emergencia` vazio no momento da emergência | `[]` (estado real de produção hoje) | Sub-workflow termina em `noOp`; IA ainda informa prioridade registrada (mesmo risco residual documentado em DW-44, não resolvido por esta story) | Nenhuma exceção, só ausência de envio |

</intent-contract>

## Code Map

- `n8n/workflows/01 - Agente.json` -- nó `Agente Nouvet`, `systemMessage`: seção `<sinais-de-alerta>` (título já existente "SINAIS DE ALERTA E EMERGÊNCIA DECLARADA") ganha o bloco de Emergência Declarada; SOP `### 2.3` (4→5 casos, incl. frase de fechamento "nunca invente um quinto motivo"→"sexto"); tool `Escalar Humano` (`description` + hint `$fromAI('motivo', ...)`, 4→5 valores); `<validacoes>` item 23 (4→5 valores fixos) e itens 11/12/18/19 ("não é um dos 4 motivos"→"5 motivos"); `<exemplos>` recebe Exemplo 19.
- `n8n/workflows/02 - Escalar Humano.json` -- só referência, sem alteração: `splitOut` já envia a todos os itens de `destinatarios_emergencia` (padrão escalar-humano-multi, AD-4), reusado tal como está desde a Story 6.
- `n8n/migrations/0010_atendimento_config_ler_lock_ttl.sql` -- `atendimento_config_ler('triagem')` já expõe `destinatarios_emergencia`; nenhuma migration nova.
- `stories/6-cap-2-triagem-e-direcionamento.md` -- Code Map/Design Notes ("a Story 14 deve reutilizar o mesmo campo/sub-workflow, não duplicar") e histórico do padrão multi já adaptado desde o início.
- `stories/13-cap-9-guardrails-de-ia.md` -- precedente direto de como estender de N para N+1 motivos (tool description, hint, SOP, validações, exemplos) sem regressão nos anteriores.
- `glossary.md` -- definição verbatim de Sinal de Alerta vs. Emergência Declarada ("inferido pela IA" vs. "declarado pelo cliente").
- `_bmad-output/implementation-artifacts/deferred-work.md` -- DW-44 (texto de "prioridade máxima" mesmo com `destinatarios_emergencia` vazio) passa a cobrir também Emergência Declarada — não resolvido por esta story, só carregado como risco residual já conhecido.

## Tasks & Acceptance

**Execution:**
- `n8n/workflows/01 - Agente.json` -- adicionar o bloco de Emergência Declarada em `<sinais-de-alerta>` (reconhecimento comportamental, nunca lista de config), estender SOP 2.3 com o 5º motivo, propagar "5" em tool `description`/hint/validações, acrescentar Exemplo 19 -- implementa CAP-12.

**Acceptance Criteria:**
- Given os 4 cenários da I/O & Edge-Case Matrix, when reproduzidos contra o `systemMessage`/topologia do workflow (inspeção estática), then o comportamento bate com a coluna "Expected Output/Behavior".
- Given uma mensagem do cliente com declaração explícita de emergência, when o `systemMessage` é seguido, then `Escalar_humano` é chamado com `motivo="Emergência Declarada"`.
- Given os 4 motivos pré-existentes de `Escalar_humano`, when o `systemMessage`/tool são inspecionados após a mudança, then os 4 textos permanecem byte-a-byte idênticos, só o 5º item é novo.
- Given a tool `Escalar Humano`, when inspecionada, then `destinatarios_emergencia` continua vindo só do nó `Info` (nunca `$fromAI`), sem alteração de expressão.
- Given `n8n/workflows/02 - Escalar Humano.json`, when comparado ao estado anterior (git), then nenhuma linha foi alterada.
- Given o texto do `systemMessage`, when se busca por "4 motivos"/"4 casos"/"4 valores"/"quinto motivo", then nenhuma ocorrência residual sobra fora do contexto correto (tudo aponta para 5/sexto).

## Design Notes

Emergência Declarada não ganha lista de config própria porque nem `SPEC.md` nem `stories.yaml` pedem isso — a distinção do glossário é "quem identifica" (IA infere sintoma vs. cliente declara), não "qual lista"; reconhecimento fica como julgamento comportamental do LLM sobre o texto do cliente, mesmo padrão já usado para reconhecer convênio mencionado (SOP 2.3, item 3) sem lista fechada de palavras. Quando sintoma configurado e declaração explícita coincidem no mesmo evento, `motivo="Emergência Declarada"` prevalece (mais específico e mais grave por vir do próprio cliente) — uma única chamada, mesmo invariante da Validação 10 (nunca duas chamadas pro mesmo evento).

## Verification

**Commands:**
- `python3 -c "import json; d = json.load(open('n8n/workflows/01 - Agente.json')); agent = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.agent'][0]; sm = agent['parameters']['options']['systemMessage']; i = sm.index('<sinais-de-alerta>'); j = sm.index('</sinais-de-alerta>'); block = sm[i:j]; assert 'Emergência Declarada' in block and 'Sinal de Alerta' in block; esc = [n for n in d['nodes'] if n['name'] == 'Escalar Humano'][0]; desc = esc['parameters']['description']; hint = esc['parameters']['workflowInputs']['value']['motivo']; motivos = ['Sinal de Alerta', 'Fora de escopo', 'Convênio mencionado', 'Informação indisponível', 'Emergência Declarada']; assert all(m in desc and m in hint for m in motivos); di = esc['parameters']['workflowInputs']['value']['destinatarios_emergencia']; assert 'fromAI' not in di and \"Info').item.json.destinatarios_emergencia\" in di; i23 = sm.index('### 2.3'); i24 = sm.index('### 2.4'); sec23 = sm[i23:i24]; assert 'Emergência Declarada' in sec23; assert 'quinto motivo' not in sm; assert 'sexto motivo' in sec23; iv = sm.index('<validacoes>'); jv = sm.index('</validacoes>'); val = sm[iv:jv]; assert '5 valores' in val and '4 valores' not in val; assert 'Exemplo 19' in sm; print('OK')"` -- expected: `OK` (Emergência Declarada presente na seção de prioridade máxima, os 5 motivos consistentes em tool `description`/hint/SOP 2.3, `destinatarios_emergencia` sem alteração de proveniência, nenhum residual de "quinto motivo"/"4 valores", Exemplo 19 presente).
- `python3 -c "import subprocess; out = subprocess.run(['git','diff','--stat','HEAD','--','n8n/workflows/02 - Escalar Humano.json'], capture_output=True, text=True).stdout; assert out.strip() == '', 'Escalar Humano.json não deve mudar nesta story'; print('OK')"` -- expected: `OK` (sub-workflow reutilizado sem nenhuma alteração).

**Manual checks (if no CLI):**
- Na VPS de dev: simular mensagem com declaração explícita de emergência e confirmar que o alerta chega a todos os contatos de `destinatarios_emergencia` de teste (mais de um), não só ao primeiro.
