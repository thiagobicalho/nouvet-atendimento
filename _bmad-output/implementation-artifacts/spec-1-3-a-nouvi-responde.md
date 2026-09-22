---
title: 'Story 1.3 — A Nouvi responde'
type: 'feature'
created: '2026-09-21'
status: done
baseline_revision: '5c7bbaa7814bc6e2239c62f55e05bfd452492ec3'
review_loop_iteration: 0
followup_review_recommended: false
operator_actions:
  - >-
    Reimportar n8n/workflows/01 - Agente.json na instância real por cima do workflow
    "01 - Agente" (id ivPwIf28PgVGX8LW, hoje active=true servindo tráfego real com o
    conteúdo antigo do Piloto) — a instância real ainda não reflete esta story.
  - >-
    Aplicar a migration n8n/migrations/0015_atendimento_falha_registro.sql no banco da
    aplicação (roda automaticamente em docker-entrypoint-initdb.d em um ambiente novo;
    em um ambiente já provisionado, aplicar manualmente em ordem, como as demais
    migrations).
  - >-
    Reaplicar n8n/seed/0001_atendimento_config.sql — como o INSERT usa ON CONFLICT (id)
    DO NOTHING, um ambiente que já tem a linha singleton (id=1) gravada com o nome
    antigo "Assistente Nouvet" não é atualizado por este seed; fazer UPDATE manual de
    nome_secretaria e tom_voz direto no banco (mesma convenção de edição em produção já
    registrada na spine).
  - >-
    Rodar um teste real contra a instância: derrubar/negar acesso ao Postgres ou ao
    OpenRouter de propósito e confirmar que (a) o cliente recebe a mensagem de fallback
    honesta e (b) uma linha aparece em atendimento_falha_registro — valida o caminho de
    falha que este build só verificou estruturalmente (sem n8n/Postgres/OpenRouter real
    alcançável neste ambiente).
  - >-
    Confirmar por teste real que a apresentação única (Nouvi se apresenta uma vez e não
    repete em turnos seguintes, mesmo dias depois) se comporta como esperado — depende
    só de instrução ao modelo (sem estado/contador no código), então só uma conversa
    real com o LLM configurado confirma o comportamento.
context:
  - '_bmad-output/implementation-artifacts/epic-1-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      `Memory` usa `contextWindowLength: 50`; uma conversa muito longa pode deixar a
      apresentação original fora da janela, arriscando repeti-la.
    evidence: |-
      Comportamento pré-existente do node `Memory` (config não alterada por esta
      story) -- a regra de "apresentação única" desta story depende inteiramente do
      histórico injetado por ele, sem contador/flag explícito.
    location: n8n/workflows/01 - Agente.json (node Memory)
    severity: low
  - summary: >-
      A regra de emoji 🐾 desta story ("duas situações", UX-DR14) diverge do design de
      conversa, que mostra um terceiro uso (pedido de feedback pós-atendimento).
    evidence: |-
      `_bmad-output/planning-artifacts/design-conversa/2026-09-18-design-de-conversa-onda1.md`
      usa 🐾 numa mensagem de feedback pós-serviço, fora das duas situações que
      `epics.md`/UX-DR14 (fonte canônica citada pela AC desta story) definem. Divergência
      pré-existente entre dois documentos de planejamento, não introduzida por esta
      story -- o prompt novo segue a fonte canônica (UX-DR14) à risca.
    location: '_bmad-output/planning-artifacts/design-conversa/2026-09-18-design-de-conversa-onda1.md vs. epics.md UX-DR14'
    severity: low
  - summary: >-
      `Registrar Falha` tem `onError: continueRegularOutput`; se a própria gravação de
      log falhar (ex. Postgres totalmente indisponível), essa falha específica não
      deixa rastro algum.
    evidence: |-
      Falha composta (a consulta original falha E a gravação em
      `atendimento_falha_registro` também falha) não é coberta -- o cliente ainda
      recebe a mensagem de fallback (`Montar Mensagem de Falha` sempre executa), mas a
      alegação implícita de "equipe avisada" fica sem registro nesse caso específico.
    location: 'n8n/workflows/01 - Agente.json (node Registrar Falha)'
    severity: low
  - summary: >-
      `atendimento_falha_registro` não tem coluna identificando qual dos pontos de
      falha (`Buscar Config`/`Normalizar telefone`/`Buscar Identidade`/`Info`/`Agente
      Nouvet`) gerou a linha -- só o texto livre de `erro`.
    evidence: |-
      Os 5 pontos de falha convergem num único node `Registrar Falha`; diferenciar a
      origem exigiria um node de marcação por branch, não fiz por manter o grafo
      simples nesta story -- o texto de `erro` já carrega pista suficiente na maioria
      dos casos (erro de SQL vs. erro de modelo têm formatos bem diferentes).
    location: 'n8n/migrations/0015_atendimento_falha_registro.sql'
    severity: low
---

<intent-contract>

## Intent

**Problem:** `01 - Agente.json` ainda carrega o prompt inteiro do Piloto antigo (CAP-1 a CAP-9: triagem por 5 setores, Escalar_humano, Buscar_info_setor, Registrar_atendimento_crm) — nada disso é a Story 1.3, que é só a resposta de base (FR-5/FR-30/FR-35, NFR-2/NFR-4/NFR-10): identidade, tom, apresentação única e falha nunca virando silêncio. Triagem, catálogo, emergência, transferência e guardrails de injeção são stories futuras (1.8–1.11) que ainda vão redesenhar essas ferramentas contra o modelo novo de catálogo (por `onda`, não por setor fixo).

**Approach:** Reduzir `Agente Nouvet` a um systemMessage novo e enxuto (identidade/tom vindos de `atendimento_config` via `Info`, apresentação única no primeiro turno usando o histórico já injetado pela `Memory`, regra de emoji, limites explícitos desta fase) e remover as 4 ferramentas antigas (`Refletir`, `Escalar_humano`, `Buscar_info_setor`, `Registrar_atendimento_crm`) sem tocar nos arquivos `02`/`03`/`04` nem no node `Buscar Identidade` (dono: Story 1.5). Fechar a lacuna de falha silenciosa com `onError: continueErrorOutput` nas 3 consultas Postgres de triagem/identidade e no próprio node do agente, convergindo para um registro em `atendimento_falha_registro` (tabela nova) e uma mensagem de fallback honesta devolvida como `output` — mesmo contrato que `07 - Ingresso e Fila.json` já consome.

## Boundaries & Constraints

**Always:**
- `Agente Nouvet` se apresenta pelo nome e como atendente virtual uma única vez por conversa, usando o histórico de `Memory` (nunca um contador externo) para saber se já se apresentou.
- Nome, tom de voz e regra de apresentação vêm de `atendimento_config` via `Info`/`Buscar Config` — nunca hardcoded no prompt.
- Toda falha nas 3 consultas Postgres da fase (`Buscar Config`, `Normalizar telefone`, `Buscar Identidade`) ou no node `Agente Nouvet` grava em `atendimento_falha_registro` e devolve `output` com mensagem honesta e sem detalhe técnico — nunca deixa a execução parar sem resposta.
- `n8n/workflows/01 - Agente.json` continua `active: false`; nenhum node de agenda, orçamento ou setor é reintroduzido.

**Block If:** Nenhuma decisão bloqueante identificada — o escopo já está resolvido pelo epic context e pelas ACs da story; nada aqui depende de decisão do Thiago.

**Never:**
- Nunca alterar a query de `Buscar Identidade`/`Normalizar telefone` nem sua posição relativa (dono: Story 1.5, herdado do boundary da Story 1.2).
- Nunca reintroduzir `Escalar_humano`/`Buscar_info_setor`/`Registrar_atendimento_crm` como ferramenta do agente nesta story — cada uma volta redesenhada em story própria (1.8–1.10).
- Nunca ativar (`active: true`) o workflow no n8n real nem reimportar sobre o `id ivPwIf28PgVGX8LW` ao vivo — segue pendente de operador (mesmo boundary da Story 1.2).
- Nunca usar o emoji 🐾 fora das duas situações da regra (que ainda não existem nesta fase — logo, não aparece na prática ainda).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Primeiro turno da conversa | `Memory` sem histórico prévio para o telefone | Resposta inclui apresentação pelo nome + "atendente virtual" | Nenhum erro esperado |
| Conversa retomada dias depois | `Memory` com histórico anterior | Resposta usa o histórico, sem se apresentar de novo | Nenhum erro esperado |
| Pergunta direta "você é um robô?" | Qualquer ponto da conversa | Reafirma que é atendente virtual, nunca finge ser pessoa | Nenhum erro esperado |
| Falha em `Buscar Config`/`Normalizar telefone`/`Buscar Identidade` | Postgres indisponível ou erro de query | `Registrar Falha` grava a linha; `output` é a mensagem honesta de fallback | Execução não para; cliente recebe fallback |
| Falha no node `Agente Nouvet` (modelo/rede) | OpenRouter indisponível ou erro do LLM | Mesmo caminho acima via saída de erro do node | Execução não para; cliente recebe fallback |

</intent-contract>

## Code Map

- `n8n/workflows/01 - Agente.json:"Agente Nouvet"` -- systemMessage reescrito do zero (~650 tokens); `onError: continueErrorOutput` novo; ferramentas antigas desconectadas.
- `n8n/workflows/01 - Agente.json:"Info"` -- assignments podados: mantém `contact_id`/`telefone`/`telefone_normalizado`/`mensagem_agregada`/`nome_secretaria`/`nome_empresa`/`tom_voz`/`identidade`/`cliente_reconhecido`/`nome_cliente`/`nome_pet` (últimos 4 intocados, sem consumidor nesta story -- Story 1.5); remove campos institucionais/emergência (`endereco`, `sla_resposta_minutos`, `sinais_alerta_clinico` etc.) sem uso nesta fase.
- `n8n/workflows/01 - Agente.json:"Buscar Config"/"Normalizar telefone"/"Buscar Identidade"` -- só `onError: continueErrorOutput` adicionado; query e posição intocadas (boundary herdado da Story 1.2).
- `n8n/workflows/01 - Agente.json` (novos nodes) -- `Registrar Falha` (Postgres INSERT em `atendimento_falha_registro`, usa só `$('Receber Turno')` -- sempre executado, seguro em qualquer branch de erro) e `Montar Mensagem de Falha` (Set, define `output`) -- leaf que `07`/`Enviar resposta RD Conversas` já consome via `$json.output`, mesmo contrato do caminho de sucesso.
- `n8n/workflows/07 - Ingresso e Fila.json:"Enviar resposta RD Conversas"` -- confirmado (sem alteração) que lê `$json.output` do retorno de `Chamar Agente Nouvet` -- é o que garante que o fallback chega ao cliente pelo mesmo caminho de uma resposta normal.
- `n8n/migrations/0015_atendimento_falha_registro.sql` (novo) -- tabela append-only, `GRANT` só a `app_role`.
- `n8n/seed/0001_atendimento_config.sql` -- `nome_secretaria` 'Assistente Nouvet' → 'Nouvi' (UX-DR1); `tom_voz` reescrito para apresentação única pelo nome. `ON CONFLICT (id) DO NOTHING` -- não afeta ambiente já seedado (nota em `operator_actions`).
- `n8n/migrations/README.md`, `n8n/workflows/README.md` -- entradas novas documentando `0015` e o estado atual (sem ferramenta, `onError` na fase de triagem).

## Tasks & Acceptance

**Execution:**
- `n8n/migrations/0015_atendimento_falha_registro.sql` -- criar tabela + grants -- pré-requisito do `Registrar Falha`.
- `n8n/seed/0001_atendimento_config.sql` -- atualizar `nome_secretaria`/`tom_voz` -- FR-35/UX-DR1.
- `n8n/workflows/01 - Agente.json` -- podar `Info`, remover as 4 ferramentas antigas, reescrever `systemMessage`, adicionar `onError`+`Registrar Falha`+`Montar Mensagem de Falha` -- entrega as 6 ACs da story.
- `n8n/migrations/README.md`, `n8n/workflows/README.md` -- documentar -- mantém os READMEs como fonte de verdade viva (convenção já estabelecida).

**Acceptance Criteria:**
- Given conversa retomada dias depois, when o cliente escreve, then a resposta usa o histórico de `Memory` sem repetir a apresentação (FR-5).
- Given a primeira fala da Nouvi, when ela se apresenta, then o faz pelo nome e como atendente virtual uma única vez, nunca fingindo ser pessoa mesmo perguntada diretamente (FR-30).
- Given nome/tom/apresentação configurados, when a Btech os edita em `atendimento_config`, then o comportamento muda sem alterar o fluxo n8n (FR-35, NFR-8).
- Given as duas situações da regra de emoji (fechamento de agendamento, lembrete do dia), when elas não existem nesta fase, then 🐾 nunca aparece na prática; a regra fica escrita para quando existirem.
- Given falha do modelo, da rede (Postgres) ou indisponibilidade do RD no caminho já coberto por esta story, when ela ocorre, then o cliente recebe mensagem honesta sem detalhe técnico e a equipe recebe registro em `atendimento_falha_registro` (NFR-4, `AD-31`).
- Given o ambiente de desenvolvimento, when o fluxo roda, then `01 - Agente.json` segue `active: false` e nenhuma mudança desta story ativa envio real (NFR-10, `AD-30`).

## Spec Change Log

_Nenhuma entrada — sem loopback `bad_spec` nesta execução._

## Review Triage Log

### 2026-09-21 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 4 (low 4)
- defer: 6 (low 6)
- reject: 10
- addressed_findings:
  - `[low]` `[patch]` Node `Info` não tinha `onError`, então uma falha ali (ex. `config`/`identidade` em formato inesperado) reproduzia exatamente a falha silenciosa que esta story existe pra fechar — adicionado `onError: continueErrorOutput` + branch de erro para `Registrar Falha`, mesmo padrão dos outros 3 nodes Postgres.
  - `[low]` `[patch]` `atendimento_falha_registro` (migration `0015`) não tinha índice — adicionado `idx_atendimento_falha_registro_created_at`, mesma convenção de `atendimento_registro_setor` (`0013`).
  - `[low]` `[patch]` `GRANT USAGE ON SCHEMA public TO app_role` redundante na `0015` (já concedido na `0002`, nenhuma migration posterior repete) — removido.
  - `[low]` `[patch]` `JSON.stringify($json.error)` em `Registrar Falha` podia serializar `undefined` se a forma do erro variasse entre os 5 pontos de falha — trocado para `JSON.stringify($json.error || $json || 'erro desconhecido')`.
  - 6 achados (truncamento de `Memory` além de 50 mensagens, divergência de "duas situações" do emoji entre `epics.md`/UX-DR14 e o design de conversa, falha composta em `Registrar Falha` sem rastro, ausência de coluna de origem em `atendimento_falha_registro`, ausência de alerta ativo sobre a nova tabela, e ausência de harness de teste para comportamento de prompt multi-turno) registrados em `deferred` no frontmatter — nenhum é causado por esta story (pré-existentes ou decisões de escopo já justificadas nas Design Notes) e nenhum bloqueia a entrega.
  - 10 achados rejeitados: mensagem de fallback ser um texto fixo em vez de vir de `atendimento_config` (correto por design — se `Buscar Config` for justamente quem falhou, ler `tom_voz` da config não é opção); status `in-review` sendo "inconsistente" com o padrão `awaiting-operator` das stories irmãs (estado transitório do próprio processo de review, resolvido no Finalize); ausência de alerta ativo sobre falhas (a AC pede "registro", não "alerta" — escopo já coberto pelas Design Notes); README sem aviso mais explícito de "não ativar" (já coberto por `active: false` + texto existente); `warnings: ['oversized']` sem explicação (convenção já estabelecida nas specs irmãs 1.1/1.2); nome da tabela `atendimento_falha_registro` vs. padrão `registro_falha` (bikeshed cosmético); remoção das 4 ferramentas antigas deixar `02`/`03`/`04` sem chamador (intencional, documentado nas Design Notes); AC5 não cobrir falha de envio pelo RD em `07` (decisão já justificada nas Design Notes, item deferred herdado da Story 1.2); AC1/AC2 dependerem só de instrução ao modelo sem harness de teste (limitação de ambiente pré-existente em todas as stories até aqui, Story 1.4 é quem constrói a bancada); AC4 ter cenários de gatilho que ainda não existem no produto (esperado — Epic 2 ainda não chegou, a regra fica escrita para quando chegar).



**Por que remover as 4 ferramentas em vez de só deixá-las conectadas e inofensivas.** O catálogo novo é por `onda` (`atendimento_servico`), não por setor fixo como `Buscar_info_setor`/`Escalar_humano` assumem hoje -- mantê-las conectadas daria ao agente uma capacidade que a spec desta story não testa nem valida, e a bancada adversarial da Story 1.4 herdaria ferramentas ainda não redesenhadas. Os arquivos `02`/`03`/`04` continuam intactos no disco para quando as stories donas (1.8–1.10) os redesenharem.

**Por que a falha de "rede" cobre as 3 consultas Postgres da fase, mas não o envio pelo RD em `07`.** `01 - Agente.json` é o arquivo desta story; a falha de envio em `07 - Ingresso e Fila.json` já está registrada como item `deferred` de severidade média da Story 1.2 (pré-existente, não introduzida por ela) -- reabrir esse arquivo aqui duplicaria decisão já tomada sem uma AC desta story exigir isso. O contrato `$json.output` é o mesmo nos dois caminhos (sucesso e falha), então o fallback desta story chega ao cliente pelo `07` sem precisar tocá-lo.

**Por que os campos de identidade (`cliente_reconhecido`/`nome_cliente`/`nome_pet`) continuam em `Info`, sem uso no prompt novo.** Nenhuma AC desta story pede saudação personalizada por identidade -- isso é FR-1/UX-DR5, explicitamente da Story 1.5. Remover os campos agora exigiria a Story 1.5 recriá-los; mantê-los é diff mínimo e não adiciona superfície ao prompt (eles só existem em `Info`, nunca são projetados no `systemMessage`).

## Verification

**Manual checks (sem ambiente n8n real neste build):**
- `python3 -c "import json; json.load(open('n8n/workflows/01 - Agente.json'))"` -- JSON válido.
- MCP `validate_workflow` (JSON local, sem tocar a instância) -- 0 erros, conexões de erro (`onError`) válidas.
- Inspeção: `Agente Nouvet` sem nenhuma conexão `ai_tool` restante; `Info` só com os 11 campos listados no Code Map; `systemMessage` sem menção a setor/CRM/agenda/Escalar_humano.
- Conferir que `Registrar Falha`/`Montar Mensagem de Falha` referenciam só `$('Receber Turno')` e `$json.error` -- nunca `$('Info')`, que pode não ter executado no branch de erro.
- Reimportar `01` na instância real, aplicar a `0015` e reaplicar o seed atualizado, e confirmar por teste real (derrubar Postgres/OpenRouter de propósito) que o cliente recebe o fallback e a linha aparece em `atendimento_falha_registro`, fica para o operador -- mesma limitação de ambiente das Stories 1.1/1.2 (sem n8n/Postgres real alcançável sem risco a outros tenants).

## Auto Run Result

**Status:** `awaiting-operator` — todo o código desta story está implementado, revisado (4 patches aplicados) e verificado estruturalmente; falta só a verificação de execução real contra o n8n/Postgres/OpenRouter de verdade, que exige o operador (ver `operator_actions`).

**Resumo do que foi implementado:** `01 - Agente.json` reduzido à resposta de base da Story 1.3 — identidade/tom vindos de `atendimento_config` (agora `nome_secretaria = 'Nouvi'`), apresentação única por conversa guiada pelo histórico de `Memory` (nunca um contador externo), regra de emoji 🐾 documentada (dormente nesta fase), e limites explícitos do que a Nouvi ainda não faz (triagem, catálogo, agenda, emergência, transferência). As 4 ferramentas antigas do Piloto (`Refletir`, `Escalar_humano`, `Buscar_info_setor`, `Registrar_atendimento_crm`) foram desconectadas do agente sem tocar nos arquivos `02`/`03`/`04` no disco. Falha nunca vira silêncio (NFR-4/`AD-31`): as 3 consultas Postgres da fase, o node `Info` e o próprio node do agente têm `onError: continueErrorOutput`, convergindo para um registro em `atendimento_falha_registro` (migration `0015`, com índice em `created_at`) e uma mensagem honesta de fallback devolvida como `output` — mesmo contrato que `07 - Ingresso e Fila.json` já consome no caminho de sucesso.

**Arquivos alterados:**
- `n8n/workflows/01 - Agente.json` -- `Info` podado a 11 campos; `Agente Nouvet` com systemMessage reescrito e `onError`; 4 ferramentas antigas removidas; 2 nodes novos (`Registrar Falha`, `Montar Mensagem de Falha`); `onError` em 5 pontos de falha da fase.
- `n8n/migrations/0015_atendimento_falha_registro.sql` (novo) -- tabela append-only com índice em `created_at`, `GRANT` só a `app_role`.
- `n8n/seed/0001_atendimento_config.sql` -- `nome_secretaria` → `'Nouvi'`; `tom_voz` reescrito para apresentação única pelo nome.
- `n8n/migrations/README.md`, `n8n/workflows/README.md` -- documentam a `0015` e o estado atual do `01 - Agente.json`.

**Findings da revisão:** ver `## Review Triage Log` acima — 4 `patch` aplicados (todos baixo: `onError`+branch de erro no node `Info`, índice em `atendimento_falha_registro`, remoção de `GRANT` redundante, serialização defensiva do erro), 6 `defer` (registrados em `deferred` no frontmatter — nenhum causado por esta story), 10 `reject` (ver lista completa no Triage Log).

**Verificação realizada:**
- `python3 -c "import json; json.load(open('n8n/workflows/01 - Agente.json'))"` -- JSON válido (confirmado após os 4 patches).
- MCP `validate_workflow` (JSON local, sem tocar a instância) -- `valid: true`, 0 erros, 0 avisos, 13 conexões válidas (confirma o novo branch de erro do `Info`).
- Inspeção programática: `Agente Nouvet` sem nenhuma conexão `ai_tool`; `Info` com exatamente os 11 campos do Code Map + `onError`; `systemMessage` sem menção a setor/CRM/agenda/ferramentas antigas; `Registrar Falha`/`Montar Mensagem de Falha` referenciam só `$('Receber Turno')`/`$json` (nunca `$('Info')`); `Buscar Identidade`/`Normalizar telefone` com query e posição idênticas ao pré-story (byte a byte); `active: false` mantido; `02`/`03`/`04`/`07` intactos no disco (`git status` confirma).

**Riscos residuais:**
- Ver os 4 itens em `deferred` no frontmatter — nenhum bloqueia esta story: truncamento de `Memory` além de 50 mensagens (pode repetir apresentação em conversa muito longa), divergência de "duas situações" do emoji entre dois documentos de planejamento (o prompt segue a fonte canônica UX-DR14), falha composta sem rastro se a própria gravação de log falhar, e ausência de coluna de origem em `atendimento_falha_registro`.
- Nenhum dos comportamentos desta story (apresentação única, uso de histórico, fallback de falha) foi comprovado por execução real — só por inspeção estrutural, mesma limitação de ambiente das Stories 1.1/1.2. Itens de `operator_actions`.

## Operator Confirmation

Confirmed 2026-09-22: the external actions this story owed were carried out.

- Reimportar n8n/workflows/01 - Agente.json na instância real por cima do workflow "01 - Agente" (id ivPwIf28PgVGX8LW, hoje active=true servindo tráfego real com o conteúdo antigo do Piloto) — a instância real ainda não reflete esta story.
- Aplicar a migration n8n/migrations/0015_atendimento_falha_registro.sql no banco da aplicação (roda automaticamente em docker-entrypoint-initdb.d em um ambiente novo; em um ambiente já provisionado, aplicar manualmente em ordem, como as demais migrations).
- Reaplicar n8n/seed/0001_atendimento_config.sql — como o INSERT usa ON CONFLICT (id) DO NOTHING, um ambiente que já tem a linha singleton (id=1) gravada com o nome antigo "Assistente Nouvet" não é atualizado por este seed; fazer UPDATE manual de nome_secretaria e tom_voz direto no banco (mesma convenção de edição em produção já registrada na spine).
- Rodar um teste real contra a instância: derrubar/negar acesso ao Postgres ou ao OpenRouter de propósito e confirmar que (a) o cliente recebe a mensagem de fallback honesta e (b) uma linha aparece em atendimento_falha_registro — valida o caminho de falha que este build só verificou estruturalmente (sem n8n/Postgres/OpenRouter real alcançável neste ambiente).
- Confirmar por teste real que a apresentação única (Nouvi se apresenta uma vez e não repete em turnos seguintes, mesmo dias depois) se comporta como esperado — depende só de instrução ao modelo (sem estado/contador no código), então só uma conversa real com o LLM configurado confirma o comportamento.

_Appended by the bmad-loop orchestrator (`bmad-loop confirm`, #335): a human confirmed these external actions out of band, and the story was advanced from `awaiting-operator` to `done`._
