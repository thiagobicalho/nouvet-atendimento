---
title: 'CAP-2 — Triagem e Direcionamento'
type: 'feature'
created: '2026-09-03'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: ['oversized']
deferred:
  - summary: >-
      Quando `destinatarios_emergencia` estiver vazio (situação atual em produção),
      o `systemMessage` ainda instrui a IA a dizer ao cliente que a solicitação "está
      sendo registrada com prioridade máxima" mesmo que nenhum humano tenha sido
      efetivamente notificado — inclusive no caso de Sinal de Alerta clínico.
    evidence: |-
      Achado convergente do Blind Hunter e do Intent Alignment Auditor na review
      desta story. O fallback de lista vazia (`noOp` em `02 - Escalar Humano.json`)
      já é comportamento aceito e documentado (mesmo tratamento de dado pendente
      usado para `sinais_alerta_clinico`/`atendimento_profissionais`), mas a
      combinação com o texto fixo de "prioridade máxima" no SOP cria uma promessa
      não cumprida ao cliente enquanto `destinatarios_emergencia` seguir `[]`. Revisar
      antes do go-live, junto com o preenchimento real da lista pelo Nouvet.
    location: >-
      n8n/workflows/01 - Agente.json (seção "SINAIS DE ALERTA E EMERGÊNCIA
      DECLARADA" e SOP 2.4) + n8n/workflows/02 - Escalar Humano.json (nó "Alerta não
      configurado")
    severity: medium
  - summary: >-
      Nenhum nó `httpRequest` do fluxo (nem o já existente "Enviar resposta RD
      Conversas" da Story 5, nem o novo "Enviar alerta RD Conversas") tem
      `retryOnFail`/`continueOnFail` configurado.
    evidence: |-
      Achado do Blind Hunter e do Edge Case Hunter, confirmado por inspeção direta
      do JSON (`retryOnFail`/`onError`/`continueOnFail` ausentes nos dois nós). É um
      padrão pré-existente desde a Story 5, não introduzido por esta story, mas com
      efeito mais sensível aqui: numa lista com múltiplos destinatários, uma falha
      de rede num item interrompe o `splitOut` e os destinatários restantes não
      recebem o alerta.
    location: >-
      n8n/workflows/01 - Agente.json (nó "Enviar resposta RD Conversas") e
      n8n/workflows/02 - Escalar Humano.json (nó "Enviar alerta RD Conversas")
    severity: low
  - summary: >-
      O SOP não cobre explicitamente uma mensagem do cliente que misture mais de um
      setor em escopo na mesma frase (ex. "queria saber de vacina e também um
      orçamento de banho").
    evidence: |-
      Achado do Blind Hunter. Não é uma leitura obrigatória do intent desta story
      (nenhum cenário da I/O & Edge-Case Matrix cobre isso) nem foi mencionado em
      stories.yaml/SPEC.md — fica como refinamento de UX para uma passada futura
      sobre o SOP, não bloqueia esta story.
    location: 'n8n/workflows/01 - Agente.json (SOP Seção 2)'
    severity: low
  - summary: >-
      Não existe guarda contra chamadas repetidas de `Escalar_humano` para a mesma
      condição em turnos sucessivos da mesma conversa (ex. Sinal de Alerta que
      persiste por várias mensagens) — cada turno pode reacionar o alerta.
    evidence: |-
      Achado do Blind Hunter e do Edge Case Hunter. Fora do escopo desta story (que
      não introduz nenhum estado de conversa novo) — potencial candidato a CAP-8/
      Story 12 (Temporizadores, Continuidade e SLA), que já vai mexer em
      `n8n_status_atendimento` para marcar "Aguardando Atendimento Humano".
    location: 'n8n/workflows/01 - Agente.json (SOP Seção 2.3/2.4)'
    severity: low
  - summary: >-
      O regex de checagem de "nenhuma credencial em texto plano" no script de
      verificação desta story (herdado literalmente da Story 5) não cobre as
      palavras-chave `token`/`secret` isoladas, só `api[_-]?key`/`Bearer `/`senha`.
    evidence: |-
      Achado do Edge Case Hunter. Convenção pré-existente desde a Story 5, replicada
      aqui por consistência — não introduzida por esta story. Vale revisar o padrão
      em todas as stories na próxima oportunidade, não só nesta.
    location: >-
      _bmad-output/specs/spec-atendimento-nouvet/stories/5-cap-1-recepcao-e-identificacao.md
      e 6-cap-2-triagem-e-direcionamento.md (seção Verification)
    severity: low
  - summary: >-
      Nenhum comando de Verification desta story inspeciona a configuração real do
      `httpRequest` "Enviar alerta RD Conversas" (URL, método, `contentType`,
      `sent_by=bot`) — só a topologia/roteamento em volta dele é verificada.
    evidence: |-
      Achado do Blind Hunter, confirmado por inspeção direta: os 3 comandos de
      Verification checam nós/conexões/campos de entrada, nunca os parâmetros do
      próprio nó `httpRequest`. Mesmo padrão já usado desde a Story 5 (o node
      "Enviar resposta RD Conversas" também não tem seus parâmetros de request
      verificados por script) — não introduzido por esta story, só replicado por
      consistência com o nó novo.
    location: 'n8n/workflows/02 - Escalar Humano.json (nó "Enviar alerta RD Conversas")'
    severity: low
  - summary: >-
      Não existe nenhum registro persistido (tabela, log estruturado) dos
      acionamentos de `Escalar_humano` (motivo, horário, destinatário) consultável
      pelo Nouvet — a única trilha é a mensagem transitória de WhatsApp e o
      histórico de conversa do LLM.
    evidence: |-
      Achado do Blind Hunter. Fora do Code Map desta story (que deliberadamente não
      persiste setor classificado nem introduz coluna nova, ver Boundaries
      "Never") — potencial candidato a uma story futura de observabilidade/auditoria
      de handoffs (relacionado a CAP-8/Story 12, que já vai mexer em
      `n8n_status_atendimento`).
    location: 'n8n/workflows/02 - Escalar Humano.json (sem consumidor de log/tabela)'
    severity: medium
  - summary: >-
      Nem o `httpRequest` "Enviar alerta RD Conversas" nem o nó `toolWorkflow` "Escalar
      Humano" têm `onError`/`retryOnFail` configurado — uma falha da API Tallos (timeout,
      500, `contact_id` inválido) pode propagar como erro do próprio nó `Agente Nouvet`.
    evidence: |-
      Achado de revisão independente (`bmad-review`, pós-DW-51). Aprofunda o item já
      registrado (ausência de retry, ver ledger) com uma consequência mais severa e
      específica: o cliente pode ficar sem NENHUMA resposta no turno (não só sem o
      alerta ao humano), já que uma exceção não tratada no sub-workflow tende a
      derrubar a execução do nó chamador no n8n.
    location: >-
      n8n/workflows/02 - Escalar Humano.json (nó "Enviar alerta RD Conversas") + n8n/workflows/01
      - Agente.json (nó "Escalar Humano")
    severity: medium
  - summary: >-
      `resumo`/`motivo` de `Escalar_humano` são gerados via `$fromAI` a partir da conversa
      do cliente sem nenhum guardrail de prompt injection — esta story abre o primeiro
      canal onde texto do cliente chega a um humano (staff) sem revisão.
    evidence: |-
      Achado de revisão independente (`bmad-review`, pós-DW-51). Guardrails de prompt
      injection são CAP-9/Story 13, ainda não construída — risco aceito como fora de
      escopo desta story, mas deve ser considerado quando a Story 13 for desenhada.
    location: 'n8n/workflows/01 - Agente.json (Ferramentas Disponíveis / SOP Seção 2.3)'
    severity: medium
  - summary: >-
      O SOP não define o comportamento quando uma única mensagem do cliente combina 2
      motivos distintos de `Escalar_humano` (ex. Sinal de Alerta + Convênio mencionado na
      mesma frase) — a Validação 10 só cobre reacionar para "o mesmo evento".
    evidence: |-
      Achado de revisão independente (`bmad-review`, pós-DW-51). Ambiguidade de UX/produto,
      não um bug — decisão pendente sobre se motivos múltiplos no mesmo turno devem gerar
      1 ou 2 chamadas da ferramenta.
    location: 'n8n/workflows/01 - Agente.json (systemMessage, Validação 10 e SOP 2.3)'
    severity: low
  - summary: >-
      Nenhum timeout explícito configurado no `httpRequest` "Enviar alerta RD Conversas".
    evidence: |-
      Achado de revisão independente (`bmad-review`, pós-DW-51). Uma resposta lenta da API
      Tallos pode prender a execução do sub-workflow (e o turno do agente) sem limite de
      tempo definido.
    location: 'n8n/workflows/02 - Escalar Humano.json (nó "Enviar alerta RD Conversas")'
    severity: low
  - summary: >-
      Itens duplicados em `destinatarios_emergencia` (mesmo `contact_id` repetido) não são
      deduplicados antes do envio — o mesmo destinatário pode receber a mesma mensagem 2x.
    evidence: |-
      Achado de revisão independente (`bmad-review`, pós-DW-51). Depende de qualidade de
      dado na config (`atendimento_config`), não de um bug de lógica do fluxo.
    location: 'n8n/workflows/02 - Escalar Humano.json (splitOut + httpRequest sequencial)'
    severity: low
  - summary: >-
      Nenhum limite documentado para o tamanho do array `destinatarios_emergencia` — a
      lista alimenta chamadas HTTP sequenciais dentro do mesmo turno do agente.
    evidence: |-
      Achado de revisão independente (`bmad-review`, pós-DW-51). Uma lista de
      destinatários grande alonga a latência do turno do cliente proporcionalmente.
    location: 'n8n/workflows/01 - Agente.json (nó Info, campo destinatarios_emergencia)'
    severity: low
  - summary: >-
      O caminho de `destinatarios_emergencia` vazio (nó `noOp` "Alerta não configurado")
      termina silenciosamente, sem nenhum log ou sinal distinto do caminho de sucesso —
      é o estado real de produção hoje (`destinatarios_emergencia = []`).
    evidence: |-
      Achado de revisão independente (`bmad-review`, pós-DW-51). Relacionado ao item já
      registrado sobre ausência de registro persistido de acionamentos bem-sucedidos, mas
      cobre especificamente o caminho de falha silenciosa, que é o mais crítico
      operacionalmente enquanto a lista de destinatários seguir vazia.
    location: 'n8n/workflows/02 - Escalar Humano.json (nó "Alerta não configurado")'
    severity: medium
baseline_revision: '3d83acbde44ea213e40626ba3ca1ef7bed83b719'
---

<intent-contract>

## Intent

**Problem:** `n8n/workflows/01 - Agente.json` (Story 5) só cobre Recepção/Identificação — o SOP tem uma única seção que termina reconhecendo a necessidade do cliente sem classificar setor, e não existe nenhum mecanismo de handoff a humano (Story 5 documentou isso como decisão deliberada, "contrato antes do consumidor"), então Sinal de Alerta, fora de escopo e menção a convênio nunca geram ação nenhuma além de texto.

**Approach:** Estender o mesmo `systemMessage` do nó `Agente Nouvet` com a Seção 2 do SOP ("Triagem e Direcionamento"), que classifica a intenção em um dos 5 setores em escopo (Care Center, Consultas, Vacinas, Exames, Orçamentos) ou aciona a nova ferramenta `Escalar_humano` (novo sub-workflow `n8n/workflows/02 - Escalar Humano.json`, padrão tool-subworkflow de AD-4) para Sinal de Alerta, fora de escopo ou convênio mencionado — usando `destinatarios_emergencia` já exposto por `atendimento_config_ler` (0004/0010) nas duas fatias, mas ainda não lido pelo node `Info`.

## Boundaries & Constraints

**Always:** A lista `sinais_alerta_clinico` continua sendo lida só da config (`atendimento_config_ler('triagem')`, já implementado na Story 5) e é interina até validação clínica do Nouvet (Open Question do SPEC.md) — nenhum item dessa lista é copiado/hardcoded em `02 - Escalar Humano.json` nem em qualquer nó novo desta story; trocar a lista em produção continua não exigindo alteração do fluxo n8n (CAP-10/AD-1), inclusive depois desta story. Sinal de Alerta sempre tem prioridade sobre a classificação de setor (mesma ordem já estabelecida na Story 5 — a nova Seção 2 do SOP roda depois da checagem de Sinais de Alerta, nunca antes). Lista dos 5 setores em escopo é fixa no texto do prompt (decisão de produto já registrada em `stories.yaml`/DW-13, não personalização) — nunca confundir com dado de config. `destinatarios_emergencia` (config, ambas as fatias) é a única fonte do(s) destinatário(s) de `Escalar_humano` — nunca hardcoded, nunca decidido pelo LLM (`$fromAI` só para `motivo`/`resumo`, nunca para a lista de destinatários). Classificar setor **nunca** dispara coleta de dados do setor (catálogo de serviço, data/horário) — isso é CAP-3/4/5 (Stories 7-9, não construídas); a Seção 2 do SOP termina reconhecendo o setor classificado e informando que o atendimento segue numa fase seguinte ainda não ativa, mesmo padrão que a Seção 1 (Story 5) já usa para apontar à Seção 2. `Escalar_humano` é chamado para exatamente 3 motivos nesta story: Sinal de Alerta, fora de escopo (Internação/Oncologia/Financeiro/qualquer pedido não coberto pelos 5 setores), convênio mencionado pelo próprio cliente (nunca ofertado, guardrail já presente desde a Story 5) — direcionamento padrão ao clínico geral (setor Consultas) quando a especialidade não está clara NÃO aciona handoff, é classificação normal em Consultas. `atendimento_config_ler('triagem')` continua sendo a única leitura de config desta story (nenhuma leitura da fatia `setor` — Stories 7-9 introduzem isso quando existir consumidor real, mesmo princípio de "não construir infraestrutura sem consumidor" já usado nas Stories 1-5).

**Block If:** Nenhuma decisão bloqueante. `workflowId` do node `toolWorkflow` que aponta para `02 - Escalar Humano.json` usa o placeholder `"value": "SET_IN_N8N_UI"` com `cachedResultName: "02 - Escalar Humano"` (mesmo tratamento já usado para credenciais, AD-2) — sem n8n real disponível neste ambiente de build para gerar um ID de workflow verdadeiro; relinkar na VPS de dev após importar os dois arquivos. Formato exato dos itens de `destinatarios_emergencia` (hoje `[]`, dado pendente do Nouvet, mesmo tratamento que `sinais_alerta_clinico`/`atendimento_profissionais` já receberam) fica a critério de quem implementa: cada item é um objeto com pelo menos `contact_id` (identificador RD Conversas exigido por `POST /v2/messages/{contact_id}/send`) — validar contra dado real quando o Nouvet fornecer a lista, antes do go-live.

**Never:** Não inclui nenhuma tool de agenda nem cadastro/card no RD CRM (Story 11/CAP-7) — `Escalar_humano` só envia mensagem de alerta via RD Conversas, nunca cria/atualiza contato. Não inclui a versão "multi todos os profissionais envolvidos" nem o campo/lógica de Emergência Declarada pelo cliente — isso é CAP-12/Story 14, que pode reutilizar `destinatarios_emergencia` e o sub-workflow `02 - Escalar Humano.json`, mas não é construído aqui. Não introduz nenhuma coluna nova em `n8n_status_atendimento` para marcar "Aguardando Atendimento Humano" nem mecanismo de silenciar respostas automáticas após o handoff — isso é CAP-8/Story 12 (Temporizadores, Continuidade e SLA); nesta story a IA continua respondendo normalmente após acionar `Escalar_humano`, só informando ao cliente que a solicitação foi registrada com prioridade (mesmo texto já usado na Story 5 para Sinal de Alerta). Não persiste setor classificado em nenhuma tabela — a memória de conversa (`n8n_historico_mensagens`) já mantém a classificação implícita no histórico para o LLM.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Intenção clara em setor no escopo | Cliente pede banho / consulta / vacina / exame / orçamento | Agente classifica o setor (um dos 5), reconhece a necessidade e informa que o atendimento segue numa fase seguinte ainda não ativa — sem coletar dado de setor | Nenhum erro |
| Fora de escopo | Cliente pede Internação, Oncologia, Financeiro, ou algo não coberto pelos 5 setores | `Escalar_humano` é chamado (`motivo="Fora de escopo"`); agente informa que um humano vai continuar o atendimento | Se `destinatarios_emergencia` vazio, sub-workflow não envia alerta (fallback silencioso, mesmo tratamento de dado pendente já aceito em outras stories) |
| Convênio mencionado | Cliente cita convênio/plano de saúde espontaneamente | `Escalar_humano` é chamado (`motivo="Convênio mencionado"`) sem a IA confirmar cobertura | Mesmo fallback acima |
| Sinal de Alerta | Sintoma da lista `sinais_alerta_clinico` (checagem já existente da Story 5) | `Escalar_humano` é chamado (`motivo="Sinal de Alerta"`) além do texto de prioridade já existente | Mesmo fallback acima |
| Sem indicação clara de especialidade | Cliente quer "uma consulta" sem saber qual especialidade | Agente classifica setor Consultas (não aciona handoff), segue para a fase seguinte não ativa | Nenhum erro |

</intent-contract>

## Code Map

- `n8n/workflows/01 - Agente.json` -- nó `Agente Nouvet` (`systemMessage`, seção `<sop>`) recebe a nova Seção "2. Triagem e Direcionamento"; nó `Info` ganha o campo `destinatarios_emergencia` (hoje ausente); novo nó `@n8n/n8n-nodes-langchain.toolWorkflow` ("Escalar Humano") conectado ao `Agente Nouvet` via `ai_tool`, ao lado de `Refletir`.
- `n8n/workflows/02 - Escalar Humano.json` -- novo arquivo (convenção `02+` do README): `executeWorkflowTrigger` (inputs: `telefone`, `nome_cliente`, `nome_pet`, `mensagem_relevante`, `motivo`, `resumo`, `destinatarios_emergencia`) → checagem de lista vazia (IF) → `splitOut` + `httpRequest` (`POST /v2/messages/{contact_id}/send`, form-urlencoded, `sent_by=bot`, RD Station Conversas) por destinatário → fallback `noOp` quando vazio.
- `_bmad-output/reference/modelo-n8n/secretariav3-completo/05 - Escalar Humano.json` e `05.1 - Escalar Humano Multi.json` -- padrão de referência (trocar Chatwoot por RD Conversas, `id_conversa_alerta` fixo por `destinatarios_emergencia` array + `splitOut`, já adaptado para "multi" desde já porque o campo de config já é array).
- `.claude/skills/n8n-agent-patterns/references/agente-e-subfluxos.md` (linhas "Escalar para humano") -- padrão tool-subworkflow e precedente do `$fromAI` para campos que o LLM preenche (`resumo`, `motivo`), nunca para `destinatarios_emergencia`.
- `.claude/skills/rd-station-api/references/conversas.md` -- `POST /v2/messages/{contact_id}/send` (mesmo endpoint já usado na Story 5 para a resposta ao cliente, agora reusado para o alerta interno).
- `n8n/migrations/0010_atendimento_config_ler_lock_ttl.sql` -- `atendimento_config_ler('triagem')` já devolve `destinatarios_emergencia`; nenhuma migration nova necessária nesta story.
- `n8n/seed/0001_atendimento_config.sql` -- `destinatarios_emergencia = []` (dado pendente, documentado, não bloqueia).
- `stories/5-cap-1-recepcao-e-identificacao.md` -- Code Map/Design Notes da Story 5 (SOP Seção 1, ordem de seções, `Info`/`Buscar Config`) como base a estender, não recriar.

## Tasks & Acceptance

**Execution:**
- `n8n/workflows/02 - Escalar Humano.json` -- criar sub-workflow de alerta (ver Code Map) -- entrega o mecanismo de handoff que Story 5 deliberadamente deixou de fora.
- `n8n/workflows/01 - Agente.json` -- adicionar `destinatarios_emergencia` ao nó `Info`; acrescentar Seção 2 ("Triagem e Direcionamento") ao `systemMessage` (5 setores + regras de handoff); adicionar nó `toolWorkflow` "Escalar Humano" conectado ao agente -- implementa CAP-2.

**Acceptance Criteria:**
- Given os 5 cenários da I/O & Edge-Case Matrix, when reproduzidos contra o `systemMessage`/topologia do workflow (inspeção estática), then o comportamento bate com a coluna "Expected Output/Behavior".
- Given `n8n/workflows/02 - Escalar Humano.json`, when inspecionado, then é um JSON de export de workflow n8n válido (`nodes`/`connections`), sem credencial em texto, com `executeWorkflowTrigger` expondo `motivo` e `destinatarios_emergencia` como inputs.
- Given a seção `<sop>` do `systemMessage`, when inspecionada, then contém exatamente as seções "1. Abertura..." (Story 5, com escopo/estrutura preservados — só os apontamentos internos para "fase seguinte ainda não ativa" foram atualizados para refletir que a Seção 2 agora está ativa, já que o texto antigo se tornaria factualmente incorreto) e "2. Triagem e Direcionamento", nesta ordem.
- Given o nó `toolWorkflow` "Escalar Humano" em `01 - Agente.json`, when inspecionado, then seu `workflowInputs` mapeia `destinatarios_emergencia` a partir do nó `Info` (nunca de `$fromAI`) e `motivo`/`resumo` a partir de `$fromAI`.
- Given o texto do `systemMessage`, when se inspeciona a lista de setores em escopo, then aparecem exatamente Care Center, Consultas, Vacinas, Exames, Orçamentos (sem Internação/Oncologia/Financeiro).
- Given nenhuma tool de agenda nem de cadastro/CRM, when se inspecionam as tools conectadas ao `Agente Nouvet`, then só `Refletir` e `Escalar Humano` estão presentes.

## Review Triage Log

### 2026-09-03 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 6 (medium 4, low 2)
- defer: 5 (medium 1, low 4)
- reject: 10
- addressed_findings:
  - `[medium]` `[patch]` `02 - Escalar Humano.json` não verificava que o ramo verdadeiro do IF "Destinatários configurados?" leva a `Separar destinatários` e o ramo falso a `Alerta não configurado` (achado do Verification Gap Reviewer) — script de Verification estendido com a checagem das duas conexões.
  - `[medium]` `[patch]` Script de Verification só contava nós do tipo `toolWorkflow` conectados ao agente, sem confirmar o conjunto completo de fontes `ai_tool` (achado convergente do Blind Hunter e do Verification Gap Reviewer — uma tool extra de tipo diferente passaria despercebida) — script estendido para exigir `{'Refletir', 'Escalar Humano'}` exatamente.
  - `[medium]` `[patch]` Nada verificava que `destinatarios_emergencia` no `toolWorkflow` vem do nó `Info` e nunca de `fromAI` (achado do Verification Gap Reviewer, protege o invariante central desta story) — nova asserção adicionada ao script de Verification.
  - `[medium]` `[patch]` `motivo`/`resumo` sem texto de fallback na mensagem de alerta de `02 - Escalar Humano.json`, diferente do padrão já usado para `nome_cliente`/`nome_pet` no mesmo template (achado convergente do Blind Hunter e do Edge Case Hunter) — adicionado `|| '(motivo não informado)'` e `|| '(resumo não informado)'`.
  - `[low]` `[patch]` Script de Verification checava ausência de "Internação"/"Financeiro" no `systemMessage` mas não de "Oncologia", apesar de a própria Acceptance Criteria da story citar os 3 (achado do Blind Hunter) — assert estendido.
  - `[low]` `[patch]` Acceptance Criteria descrevia a Seção 1 do SOP como "(Story 5, inalterada)", mas a implementação precisou atualizar o texto de apontamento interno de "1.5 Próximo passo" (a frase antiga sobre "fase seguinte ainda não ativa" ficaria factualmente incorreta com a Seção 2 ativa) — achado do Intent Alignment Auditor; código já estava correto, só a redação da AC foi ajustada para descrever com precisão o que "preservado" significa aqui (escopo/estrutura da seção, não texto byte-a-byte).

Itens defer (5) e rejeitados (10) desta passada: ver `deferred` no frontmatter para o detalhe dos 5 itens adiados (mensagem de "prioridade máxima" mesmo com `destinatarios_emergencia` vazio; ausência de retry/continueOnFail nos nós `httpRequest`; mensagem multi-setor não coberta pelo SOP; ausência de guarda contra `Escalar_humano` repetido no mesmo turno/condição; regex de credencial do script de Verification não cobre `token`/`secret`). Os 10 rejeitados foram, em ordem de convergência entre revisores: validação de `motivo` por enum em código (padrão já estabelecido de confiar no LLM via prompt, igual a `sinais_alerta_clinico`); ausência de sinal de sucesso/falha retornado ao LLM (comportamento exigido pelo próprio `<intent-contract>`, que manda a IA sempre informar "registrado com prioridade" após acionar a tool); `contact_id` do cliente não repassado ao alerta (fora do Code Map desta story, humano já recebe telefone); validação `strict` do IF sobre array (risco não confirmado — tipo é `array` consistente dos dois lados da fronteira `executeWorkflowTrigger`); nomenclatura `Escalar_humano` (prompt) vs. `Escalar Humano` (nó) — verificado contra `01 - Secretária V3.json` de referência, que usa exatamente essa mesma convenção (`Escalar_humano` no texto, `Escalar humano` no nome do nó); comportamento de "desabilitar assistente após handoff" do material de referência não replicado — já excluído explicitamente no `<intent-contract>` (CAP-8/Story 12); suposta contradição do "Never" sobre versão "multi" — já resolvida no próprio Code Map ("já adaptado para multi desde já"); newline final adicionada ao JSON (mudança de formatação inofensiva); item duplicado sobre `contact_id` malformado indo para `/undefined/send` (já coberto pelo risco residual documentado no Design Notes/Block If sobre formato pendente de validação); e o achado do Intent Alignment Auditor sobre a I/O & Edge-Case Matrix ser verificada só por inspeção estática (padrão já aceito e documentado desde a Story 1, mesma limitação de ambiente sem Docker/n8n).

### 2026-09-03 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 6 (medium 3, low 3)
- defer: 2 (medium 1, low 1)
- reject: 9
- addressed_findings:
  - `[low]` `[patch]` Contagem de rejeitados da passada anterior estava errada (cabeçalho e prosa diziam "11", a lista enumerada tinha exatamente 10 itens) — corrigido para "10" nos dois pontos (achado do Blind Hunter).
  - `[medium]` `[patch]` Script de Verification checava só os nomes dos nós de destino do IF "Destinatários configurados?", nunca o operador da própria condição — uma condição invertida (`empty` em vez de `notEmpty`) passaria pelo check apontando para os mesmos nomes de nó (achado do Blind Hunter) — nova asserção conferindo `operator.operation == 'notEmpty'`.
  - `[medium]` `[patch]` O patch de fallback de `motivo`/`resumo` (`|| '(motivo não informado)'`/`|| '(resumo não informado)'`) aplicado na passada anterior não tinha nenhuma asserção de Verification cobrindo essas strings — uma regressão futura nesse texto não seria detectada (achado do Verification Gap Reviewer) — nova asserção conferindo a presença das 4 strings de fallback (`motivo`, `resumo`, `telefone`, `mensagem_relevante`) no corpo da mensagem.
  - `[low]` `[patch]` `telefone` e `mensagem_relevante` na mensagem de alerta de `02 - Escalar Humano.json` não tinham texto de fallback, diferente do padrão já usado para `nome_cliente`/`nome_pet`/`motivo`/`resumo` no mesmo template (achado convergente do Blind Hunter e do Edge Case Hunter) — adicionado `|| '(telefone não informado)'` e `|| '(mensagem não informada)'`.
  - `[medium]` `[patch]` A Seção 2.2 do SOP instrui a IA a nunca citar o rótulo técnico do setor ao cliente, mas nada equivalente instruía a nunca citar o valor literal de `motivo` (ex. "Fora de escopo", "Convênio mencionado") — achado do Blind Hunter — adicionada frase de guarda equivalente no início da Seção 2.3 do `systemMessage`.
  - `[low]` `[patch]` "Manual checks" só instruía testar os 3 motivos de handoff com `destinatarios_emergencia` populado, nunca o caminho com lista vazia — que é o estado real de produção hoje e o cenário mais provável de ocorrer (achado do Blind Hunter) — adicionado bullet cobrindo esse caminho.

Itens defer (2, novos nesta passada) e rejeitados (9) desta passada: os 2 novos itens `deferred` estão no frontmatter (ausência de verificação automatizada dos parâmetros do `httpRequest` "Enviar alerta RD Conversas" — severidade `low`, padrão pré-existente desde a Story 5; ausência de registro persistido/consultável dos acionamentos de `Escalar_humano` — severidade `medium`, candidato a story futura de observabilidade). Os 9 rejeitados: reuso do mesmo texto "prioridade máxima" para os 3 motivos de `Escalar_humano` (comportamento exigido pelo próprio `<intent-contract>`, que manda usar "mesmo texto já usado na Story 5 para Sinal de Alerta"); `contact_id` ausente levando a `/undefined/send` (já rejeitado na passada anterior com o mesmo raciocínio — risco residual já documentado no Block If); validação de `motivo` por enum em código (já rejeitado na passada anterior — confiar no LLM via prompt, mesmo padrão de `sinais_alerta_clinico`); ausência de `retryOnFail`/`continueOnFail` (já capturado no item `deferred` existente desta mesma story, re-surgiu sem informação nova); ausência de entrada `deferred` dedicada para a decisão de localizar a conversa só por telefone (decisão já tomada e justificada na passada anterior — observação de processo, não um defeito novo); ausência de sticky note em `01 - Agente.json` documentando a Seção 2/`Escalar_humano`, ao contrário do sticky note já existente em `02 - Escalar Humano.json` (preferência estética, não exigida por nenhuma Acceptance Criteria); ausência de um item de checklist formal de go-live amarrando "`destinatarios_emergencia` populado" (o item `deferred` já existente cobre isso em prosa — "revisar antes do go-live" — criar um checklist formal é decisão de processo do Nouvet, fora do artefato desta story); e dois achados do Intent Alignment Auditor — a Verification desta story ser só inspeção estática sem execução real de LLM/n8n (já levantado e explicitamente aceito como limitação de ambiente na passada anterior, desde a Story 1) e a divergência de redação da Seção 1 "inalterada" (já resolvida na passada anterior, registrada no Review Triage Log acima).

### 2026-09-03 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 4 (medium 2, low 2)
- defer: 0
- reject: 9
- addressed_findings:
  - `[low]` `[patch]` Contagem do header da passada anterior do Review Triage Log estava errada ("patch: 7 (medium 3, low 4)" com só 6 bullets enumerados, 3 medium + 3 low) — corrigido para "6 (medium 3, low 3)" (achado do Blind Hunter).
  - `[medium]` `[patch]` Verification só checava que `destinatarios_emergencia` existia pelo nome no nó `Info` e no `toolWorkflow`, nunca a expressão de origem — uma mutação de teste (hardcode no `Info`, ou o `toolWorkflow` apontando para outro campo do `Info`) passava despercebida pelos 3 comandos, ameaçando o invariante central desta story (achado do Verification Gap Reviewer, confirmado por teste de mutação) — comandos 2 e 3 estendidos para checar a expressão exata (`Buscar Config').item.json.config.destinatarios_emergencia` no `Info`; `Info').item.json.destinatarios_emergencia` no `toolWorkflow`).
  - `[medium]` `[patch]` Verification do `02 - Escalar Humano.json` checava só as conexões de saída do IF, nunca a conexão do trigger até o IF nem a do `splitOut` até o `httpRequest` — desconectar qualquer uma delas (ex. edição manual futura no canvas do n8n) silenciaria o envio de alerta sem que nenhum comando detectasse (achado do Verification Gap Reviewer, confirmado por teste de mutação) — comando 1 estendido com as duas asserções de conexão faltantes.
  - `[low]` `[patch]` O `systemMessage` instrui a acionar `Escalar_humano` tanto na seção "Sinais de Alerta" (passo 5) quanto na Seção 2.3 do SOP para o mesmo evento de Sinal de Alerta, sem deixar explícito que é a mesma chamada — risco de o LLM interpretar como duas chamadas separadas no mesmo turno, duplicando o alerta ao humano (achado convergente do Blind Hunter e do Edge Case Hunter) — adicionada Validação 10 ao `systemMessage` esclarecendo que é uma única chamada por evento.

Itens rejeitados (9) desta passada: truncamento sem marcador de continuação dos títulos de DW-44/47/48/49/50 em `deferred-work.md` (padrão pré-existente desde DW-38–43, e o ledger é de propriedade do orquestrador desta execução, fora de escopo para edição aqui); reconsideração de severidade de DW-44 e DW-50 (medium → possivelmente alta) sem evidência nova além da já usada na passada anterior; achado do Blind Hunter sobre formato de telefone pouco articulado, sem ação concreta identificável; guarda `Array.isArray` para `destinatarios_emergencia` não-array no nó `Info` (replica exatamente o padrão já usado para `sinais_alerta_clinico` desde a Story 5, não é regressão desta story); ausência de documentação de shape do item de `destinatarios_emergencia` no schema do banco (já coberta em prosa no "Block If" do `<intent-contract>`); ausência de Verification contra Postgres real para `atendimento_config_ler('triagem')` (limitação de ambiente já aceita desde a Story 1); AC "aparecem exatamente" os 5 setores não ser 100% à prova de um 6º setor não intencional (verificação já cobre os 5 esperados + os 3 mais prováveis de erro, checagem exaustiva teria retorno decrescente); ausência de sticky note em `01 - Agente.json` para a Seção 2/`Escalar_humano` (já rejeitado na passada anterior como preferência estética, reapresentado sem informação nova); e afirmação não verificada em Design Notes sobre a Story 2/0004 ter antecipado o consumo do FR-41/CAP-12 (observação histórica de prosa, sem consequência funcional).

### 2026-09-03 — Revisão independente (`bmad-review`, consumindo DW-51)

Executada fora do `bmad-loop` (lentes `adversarial`, `edge-case-hunter`, `verification-gap`) sobre o diff da story já `done`, para atender à recomendação de follow-up review que o `bmad-loop` não conseguiu rodar (cap de `max_followup_reviews` esgotado — ver DW-51 em `deferred-work.md`).

- 10 achados adversarial, 3 edge-case-hunter, 2 verification-gap.
- `[patch]` aplicados (3): (1) `systemMessage` — Casos Especiais > "Cliente insatisfeito" ganhou uma frase esclarecendo que "registrar" nesta fase é só histórico de conversa, não um protocolo formal; (2) `description` do tool `Escalar Humano` ganhou reforço explícito para a IA continuar a conversa após chamá-lo; (3) Verification comando 2 estendido com 3 novas asserções cobrindo as duas mudanças de prompt acima e a guarda pré-existente contra citar `motivo` literal (que não tinha nenhuma asserção própria).
- `[defer]` (7, novos itens no frontmatter): ausência de `onError`/`retryOnFail` propagando falha para o nó `Agente Nouvet` (aprofunda o achado de retry já conhecido, com consequência mais severa — cliente sem resposta no turno); superfície de prompt injection nova via `resumo`/`motivo` sem guardrail (CAP-9/Story 13 ainda não construída); SOP sem definição para motivos múltiplos no mesmo turno; ausência de timeout no `httpRequest` de alerta; ausência de dedup de `destinatarios_emergencia` duplicado; ausência de limite documentado para o tamanho da lista; caminho de lista vazia (`noOp`) sem log distinto do caminho de sucesso.
- Demais achados (workflowId placeholder / checklist de go-live, `contact_id` malformado, campos não-`required` no schema) já cobertos por risco residual documentado no `<intent-contract>` (Block If) ou já presentes no ledger — não duplicados como novo item.
- DW-51 marcada `resolved` no ledger.

## Design Notes

`destinatarios_emergencia` já vinha exposto por `atendimento_config_ler` desde a 0004 (Story 2) nas duas fatias — Story 2 antecipou esse consumo antes mesmo do FR-41/CAP-12 existir como story própria; esta story é a primeira a efetivamente ler o campo (via `Info`), e a Story 14 (CAP-12) deve reutilizar o mesmo campo/sub-workflow, não duplicar. Exemplo do fallback de lista vazia (mesmo padrão do `05 - Escalar Humano.json` de referência, nó "Alerta não configurado"): se `destinatarios_emergencia` chegar `[]` no `executeWorkflowTrigger`, o sub-workflow termina em `noOp` sem chamar a API do RD Conversas — comportamento aceito e documentado (mesmo tratamento de dado pendente já usado para `sinais_alerta_clinico`/`atendimento_profissionais`), não bloqueia o build.

## Verification

**Commands:**
- `python3 -c "import json, re; d = json.load(open('n8n/workflows/02 - Escalar Humano.json')); assert 'nodes' in d and 'connections' in d; trg = [n for n in d['nodes'] if n.get('type') == 'n8n-nodes-base.executeWorkflowTrigger'][0]; inputs = [v['name'] for v in trg['parameters']['workflowInputs']['values']]; assert 'motivo' in inputs and 'destinatarios_emergencia' in inputs; content = json.dumps(d); assert not re.search(r'(Bearer |api[_-]?key|token\s*[:=]|secret|senha\s*[:=])', content, re.I); ifnode = [n for n in d['nodes'] if n['name'] == 'Destinatários configurados?'][0]; conns = d['connections'][ifnode['name']]['main']; assert {c['node'] for c in conns[0]} == {'Separar destinatários'}; assert {c['node'] for c in conns[1]} == {'Alerta não configurado'}; assert ifnode['parameters']['conditions']['conditions'][0]['operator']['operation'] == 'notEmpty'; trigconns = d['connections']['Receber Solicitação']['main']; assert {c['node'] for c in trigconns[0]} == {'Destinatários configurados?'}; splitconns = d['connections']['Separar destinatários']['main']; assert {c['node'] for c in splitconns[0]} == {'Enviar alerta RD Conversas'}; msgnode = [n for n in d['nodes'] if n['name'] == 'Enviar alerta RD Conversas'][0]; msg = [p['value'] for p in msgnode['parameters']['bodyParameters']['parameters'] if p['name'] == 'message'][0]; assert all(s in msg for s in ['(motivo não informado)', '(resumo não informado)', '(telefone não informado)', '(mensagem não informada)']); print('OK')"` -- expected: `OK` (inclui checagem do roteamento correto do IF, do operador `notEmpty` da condição, e da presença de texto de fallback para `motivo`/`resumo`/`telefone`/`mensagem_relevante` na mensagem de alerta).
- `python3 -c "import json; d = json.load(open('n8n/workflows/01 - Agente.json')); agent = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.agent'][0]; sm = agent['parameters']['options']['systemMessage']; assert sm.index('1. Abertura') < sm.index('2. Triagem e Direcionamento'); assert 'Care Center' in sm and 'Consultas' in sm and 'Vacinas' in sm and 'Exames' in sm and 'Orçamentos' in sm; assert 'Internação' not in sm and 'Financeiro' not in sm and 'Oncologia' not in sm; tools = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.toolWorkflow']; assert len(tools) == 1 and 'Escalar' in tools[0]['name']; ai_tool_sources = {src for src, out in d['connections'].items() if any(c['node'] == 'Agente Nouvet' for group in out.get('ai_tool', []) for c in group)}; assert ai_tool_sources == {'Refletir', 'Escalar Humano'}; tool_inputs = tools[0]['parameters']['workflowInputs']['value']; assert 'fromAI' not in tool_inputs['destinatarios_emergencia'] and \"Info').item.json.destinatarios_emergencia\" in tool_inputs['destinatarios_emergencia']; assert 'fromAI' in tool_inputs['motivo'] and 'fromAI' in tool_inputs['resumo']; assert 'nunca diga ao cliente o valor literal de' in sm; assert 'histórico da conversa' in sm; assert 'continue a conversa normalmente' in tools[0]['parameters']['description']; print('OK')"` -- expected: `OK` (inclui checagem de que só `Refletir`/`Escalar Humano` estão conectados via `ai_tool`, que `Oncologia` também está fora do prompt, que `destinatarios_emergencia` no `toolWorkflow` vem exatamente do campo `destinatarios_emergencia` do nó `Info` e nunca de `fromAI`, e as 3 asserções novas da revisão independente pós-DW-51: guarda contra citar `motivo` literal, esclarecimento de que "registrar" é só histórico de conversa, e reforço na `description` da tool para a IA continuar a conversa após chamá-la).
- `python3 -c "import json; d = json.load(open('n8n/workflows/01 - Agente.json')); info = [n for n in d['nodes'] if n['name']=='Info'][0]; assigns = info['parameters']['assignments']['assignments']; names=[a['name'] for a in assigns]; assert 'destinatarios_emergencia' in names; de = [a for a in assigns if a['name']=='destinatarios_emergencia'][0]; assert \"Buscar Config').item.json.config.destinatarios_emergencia\" in de['value']; print('OK')"` -- expected: `OK` (checa não só o nome do campo no nó `Info`, mas que seu valor vem exatamente de `Buscar Config`, nunca hardcoded).

**Manual checks (if no CLI):**
- Na VPS de dev: importar `02 - Escalar Humano.json`, relinkar o `workflowId` do node `toolWorkflow` em `01 - Agente.json` (ver Block If), popular `destinatarios_emergencia` com um contato de teste e confirmar o recebimento do alerta para os 3 motivos (Sinal de Alerta, fora de escopo, convênio).
- Repetir com `destinatarios_emergencia = []` (estado atual de produção) e confirmar que o sub-workflow termina em `noOp` sem chamar a API do RD Conversas (fallback silencioso, ver Design Notes).

## Auto Run Result

Status: done

**Summary of implemented change:** Story 6 (CAP-2 — Triagem e Direcionamento) estende o `systemMessage` do nó `Agente Nouvet` com a Seção 2 do SOP (classificação em 5 setores + regras de handoff) e entrega o mecanismo de handoff a humano que a Story 5 deliberadamente deixou pendente: novo sub-workflow `02 - Escalar Humano.json` (padrão tool-subworkflow, AD-4) acionado pela ferramenta `Escalar_humano` para Sinal de Alerta, fora de escopo ou convênio mencionado pelo cliente, usando `destinatarios_emergencia` (agora lido pelo nó `Info`, já exposto por `atendimento_config_ler` desde a Story 2/0004). Esta execução (bmad-build-auto) rodou uma passada de review adicional sobre o trabalho já `done`, sem alterar o `<intent-contract>`.

**Files changed:**
- `n8n/workflows/01 - Agente.json` — nó `Info` ganha `destinatarios_emergencia`; `systemMessage` ganha a Seção 2 do SOP e a Validação 10 (guarda contra chamada duplicada de `Escalar_humano` no mesmo evento, patch desta passada); novo nó `toolWorkflow` "Escalar Humano" conectado via `ai_tool`.
- `n8n/workflows/02 - Escalar Humano.json` — novo sub-workflow de alerta (trigger → IF lista vazia → `splitOut` + `httpRequest` por destinatário → `noOp` fallback).
- `_bmad-output/implementation-artifacts/deferred-work.md` — sincronizado externamente pelo orquestrador com os 7 itens `deferred` desta story (DW-44 a DW-50); não modificado por esta execução, por instrução explícita do invocador.
- `_bmad-output/specs/spec-atendimento-nouvet/stories/6-cap-2-triagem-e-direcionamento.md` — este arquivo (status, Verification estendida, Review Triage Log, Auto Run Result).

**Review findings breakdown (esta passada):**
- patch: 4 (medium 2, low 2) — aplicados (ver Review Triage Log acima: correção de contagem no log, duas asserções de Verification que fecham gaps confirmados por teste de mutação, e uma guarda no prompt contra alerta duplicado).
- defer: 0
- reject: 9 (ver Review Triage Log acima para a lista)
- intent_gap: 0 / bad_spec: 0

**Follow-up review recommendation:** `true` — score desta passada = 3×2 (medium) + 1×2 (low) = 8, ≥ 5. Nenhum patch `high` nesta passada.

**Verification performed:** Os 3 comandos Python do `## Verification` foram reexecutados após os patches desta passada e retornaram `OK` (incluindo as duas novas asserções de proveniência de `destinatarios_emergencia` — nó `Info` e `toolWorkflow` — e as duas novas asserções de conexão do sub-workflow, trigger→IF e `splitOut`→`httpRequest`). Cada uma das quatro novas asserções foi adicionalmente testada por mutação (campo de origem trocado, conexão removida) para confirmar que de fato capturam a regressão que motivou o patch — a mutação foi detectada em todos os casos testados. Manual checks (import em VPS de dev com n8n real) seguem pendentes, como já registrado nas passadas anteriores.

**Residual risks:** Os 7 itens em `deferred` (frontmatter, DW-44–DW-50) seguem abertos, com destaque para DW-44 (texto de "prioridade máxima" mesmo com `destinatarios_emergencia` vazio, situação atual de produção) e DW-50 (nenhum registro persistido dos acionamentos de `Escalar_humano`) — ambos `medium`, candidatos a revisão antes do go-live. `workflowId` do node `toolWorkflow` "Escalar Humano" segue com o placeholder `SET_IN_N8N_UI`, a relinkar na VPS de dev após importar os dois arquivos.

