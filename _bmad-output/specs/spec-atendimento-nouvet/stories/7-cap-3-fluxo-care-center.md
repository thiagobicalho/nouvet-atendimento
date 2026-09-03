---
title: 'CAP-3 — Fluxo Care Center'
type: 'feature'
created: '2026-09-03'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: ['oversized']
deferred:
  - summary: >-
      Seção 3 do SOP não trata pedido de mais de um serviço do catálogo na
      mesma mensagem (ex. "banho e tosa").
    evidence: |-
      A Seção 3.2 é fraseada para coleta de um único serviço por vez ("qual
      serviço... o cliente quer"), sem instrução explícita para coletar
      múltiplos serviços quando citados juntos na mesma mensagem.
    location: >-
      n8n/workflows/01 - Agente.json (systemMessage, Seção 3.2)
    severity: medium
  - summary: >-
      Seção 3 não cobre o cliente revisando uma preferência já coletada
      (serviço, data/horário ou profissional) no meio da coleta.
    evidence: |-
      O texto da Seção 3 descreve só a primeira coleta, sem instrução para o
      caso de correção/mudança de uma preferência já dada anteriormente na
      mesma conversa.
    location: >-
      n8n/workflows/01 - Agente.json (systemMessage, Seção 3)
    severity: medium
  - summary: >-
      Nenhuma instrução evita chamadas repetidas de Buscar_info_setor a cada
      turno da mesma sub-conversa do Care Center.
    evidence: |-
      Ao contrário da Validação #10 (que proíbe chamar Escalar_humano duas
      vezes para o mesmo evento), não há orientação equivalente para
      reutilizar o retorno já obtido de Buscar_info_setor em vez de
      re-consultar a cada turno.
    location: >-
      n8n/workflows/01 - Agente.json (systemMessage, Seção 3.1)
    severity: low
  - summary: >-
      Seção 3 não trata o cliente mudando de assunto para outro setor no meio
      da coleta do Care Center.
    evidence: |-
      Não há instrução para interromper a coleta e reclassificar quando o
      cliente pede algo de outro setor (ex. Consultas) no meio do fluxo do
      Care Center.
    location: >-
      n8n/workflows/01 - Agente.json (systemMessage, Seção 3)
    severity: medium
  - summary: >-
      Seção 3.4 não orienta o que fazer quando mais de um profissional da
      lista retornada corresponde aproximadamente ao nome citado pelo
      cliente.
    evidence: |-
      A instrução atual só cobre "nome bate" ou "nome não está na lista", sem
      tratar ambiguidade entre múltiplos nomes parecidos.
    location: >-
      n8n/workflows/01 - Agente.json (systemMessage, Seção 3.4)
    severity: low
  - summary: >-
      O input `setor` do trigger de "03 - Buscar Info Setor.json" não é
      marcado como obrigatório no schema do workflowInputs.
    evidence: |-
      Hardening de defesa em profundidade — hoje depende só do agente sempre
      preencher `setor` via `$fromAI`; sem `required: true` no trigger, um
      valor vazio passaria silenciosamente para a query Postgres.
    location: >-
      n8n/workflows/03 - Buscar Info Setor.json (executeWorkflowTrigger)
    severity: low
baseline_revision: '75ac4a2289a6a8ddb62ea6a2b19ca9926152c0b6'
---

<intent-contract>

## Intent

**Problem:** `n8n/workflows/01 - Agente.json` (Stories 5/6) classifica o setor Care Center (SOP Seção 2) mas termina aí — nenhum mecanismo coleta serviço/data/horário/profissional preferidos, e o `systemMessage` não tem acesso à fatia `setor` de `atendimento_config_ler` (catálogo de serviços, profissionais), só à fatia `triagem`.

**Approach:** Estender o `systemMessage` do `Agente Nouvet` com a Seção 3 do SOP ("Fluxo Care Center"), e adicionar uma nova ferramenta `Buscar_info_setor` (novo sub-workflow `n8n/workflows/03 - Buscar Info Setor.json`, padrão tool-subworkflow de AD-4) que o próprio agente chama, já classificado o setor, para obter sob demanda a fatia `setor` de `atendimento_config_ler` (catálogo + profissionais) — implementa a montagem seletiva por setor "não cumulativa" (AD-1) sem workflow persistir o setor classificado (decisão já tomada na Story 6).

## Boundaries & Constraints

**Always:** `Buscar_info_setor` é chamada nesta story só com `setor="Care Center"` (`$fromAI`, mesmo padrão de `motivo`/`resumo` de `Escalar_humano`) — Stories 8/9 estendem a mesma ferramenta/descrição para seus próprios setores quando forem construídas, nunca duplicam o sub-workflow. Serviço coletado é sempre um dos itens de `catalogo_servicos` retornados pela ferramenta (hoje: Banho - Cachorro, Banho - Gato, Tosa) — nunca hardcoded no `systemMessage` (é dado de `atendimento_config`, AD-1/CAP-10) nem inventado pela IA; profissional preferido, se mencionado, é comparado contra `profissionais` da mesma resposta. Data/horário são só preferência textual do cliente — nunca checados contra agenda real (AD-4, nenhuma tool de agenda ligada ao agente, nem leitura). Depois de coletar serviço + preferência de data/horário (+ profissional/pedido adicional, se houver), a IA informa que um humano vai confirmar contra a agenda real e **nunca** confirma agendamento nem promete horário. Preço/duração nunca são citados (não existem no catálogo hoje). Sinais de Alerta/Emergência (Seção topo do prompt) continuam com prioridade máxima mesmo dentro desta seção. `Escalar_humano` não é chamado ao final da coleta desta seção — coleta completa não é um dos 3 motivos da Seção 2.3 (Story 6); é continuação normal da conversa.

**Block If:** Nenhuma decisão bloqueante. `workflowId` do novo `toolWorkflow` usa `"value": "SET_IN_N8N_UI"` (mesmo tratamento de credencial/link pendente já usado para `Escalar Humano`) — relinkar na VPS de dev após importar.

**Never:** Não persiste nada em tabela nova (preferência coletada fica só na memória de conversa, `n8n_historico_mensagens` — mesmo padrão de "não persiste setor classificado" da Story 6). Não cria/atualiza contato ou card no RD CRM (Story 11/CAP-7, ainda não construída) — o "roteamento a humano" desta story é só textual (aviso ao cliente), sem mecanismo de card ainda, mesmo padrão de "contrato antes do consumidor" já usado nas Stories 2-6. Não inclui nenhuma tool de agenda, leitura ou escrita (AD-4). Não trata "solicitação adicional não agendável" (ex.: hidratação) como serviço agendável nem tenta vendê-la — só registra em texto. Não implementa Consultas/Vacinas/Exames (Stories 8/9) nem Orçamentos (Story 10).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Serviço do catálogo + data/horário | Setor já classificado Care Center; cliente pede banho de cachorro com dia/horário preferidos | Agente chama `Buscar_info_setor("Care Center")`, confirma o serviço no catálogo retornado, coleta serviço + data/horário (+ profissional se citado), informa que um humano vai confirmar contra a agenda real | Nenhum erro |
| Profissional preferido não reconhecido | Cliente cita um nome que não está em `profissionais` da resposta da ferramenta | Agente informa que não reconhece esse profissional (sem inventar), segue coletando normalmente sem forçar um nome da lista | Nenhum erro |
| Serviço do catálogo + pedido adicional não agendável | Cliente pede tosa e pergunta sobre hidratação | Agente coleta a tosa normalmente e registra a hidratação como pedido adicional, sem tentar vender/agendar | Nenhum erro |
| Só pedido não agendável (nenhum serviço do catálogo) | Cliente só pergunta sobre hidratação, sem citar banho/tosa | Agente reconhece que não é um dos 3 serviços agendáveis via IA, registra como pedido adicional, informa que um humano vai continuar — sem empurrar um dos 3 serviços do catálogo | Nenhum erro |

</intent-contract>

## Code Map

- `n8n/workflows/01 - Agente.json` -- nó `Agente Nouvet` (`systemMessage`) recebe a Seção "3. Fluxo Care Center" (após "2. Triagem e Direcionamento") e a nova ferramenta na seção Ferramentas Disponíveis; novo nó `@n8n/n8n-nodes-langchain.toolWorkflow` ("Buscar Info Setor") conectado via `ai_tool`, ao lado de `Refletir`/`Escalar Humano`.
- `n8n/workflows/03 - Buscar Info Setor.json` -- novo arquivo (convenção `02+` do README): `executeWorkflowTrigger` (input: `setor`) → node Postgres `SELECT atendimento_config_ler('setor', $1) AS config` → retorna `config` (contém `catalogo_servicos`, `profissionais`, já filtrados pelo setor).
- `n8n/migrations/0008_atendimento_profissionais.sql` / `0010_atendimento_config_ler_lock_ttl.sql` -- corpo atual de `atendimento_config_ler('setor', p_setor)`, já devolve `catalogo_servicos` (filtrado) e `profissionais` (filtrado, `nome`/`especialidade`); nenhuma migration nova nesta story.
- `n8n/seed/0001_atendimento_config.sql` -- `catalogo_servicos` real hoje: 3 itens Care Center (Banho - Cachorro, Banho - Gato, Tosa), sem preço/duração.
- `stories/6-cap-2-triagem-e-direcionamento.md` -- Seção 2 do SOP (classificação, `Escalar_humano`) como base a estender, não recriar; Seção 2.2 já aponta para "fase seguinte" — texto a atualizar para refletir que a Seção 3 está ativa (mesmo ajuste feito na Seção 1 pela Story 6).

## Tasks & Acceptance

**Execution:**
- `n8n/workflows/03 - Buscar Info Setor.json` -- criar sub-workflow de leitura seletiva por setor (ver Code Map) -- entrega o mecanismo que faltava para a montagem seletiva por setor (AD-1) sem persistir setor classificado.
- `n8n/workflows/01 - Agente.json` -- adicionar nó `toolWorkflow` "Buscar Info Setor" conectado ao agente; acrescentar Seção 3 ("Fluxo Care Center") ao `systemMessage`; atualizar Seção 2.2 para apontar à Seção 3 (ativa) em vez de "fase seguinte" -- implementa CAP-3.

**Acceptance Criteria:**
- Given os 4 cenários da I/O & Edge-Case Matrix, when reproduzidos contra o `systemMessage`/topologia do workflow (inspeção estática), then o comportamento bate com a coluna "Expected Output/Behavior".
- Given `n8n/workflows/03 - Buscar Info Setor.json`, when inspecionado, then é um JSON de export de workflow n8n válido (`nodes`/`connections`), sem credencial em texto, com `executeWorkflowTrigger` expondo `setor` como input.
- Given a seção `<sop>` do `systemMessage`, when inspecionada, then contém "1. Abertura...", "2. Triagem..." e "3. Fluxo Care Center", nesta ordem.
- Given as ferramentas conectadas ao `Agente Nouvet` via `ai_tool`, when inspecionadas, then são exatamente `{'Refletir', 'Escalar Humano', 'Buscar Info Setor'}`.
- Given o `systemMessage`, when se inspeciona a Seção 3, then nenhum nome de serviço/profissional aparece como texto fixo — só instrução para usar o retorno de `Buscar_info_setor`.
- Given o `workflowInputs` do `toolWorkflow` "Buscar Info Setor", when inspecionado, then `setor` vem de `$fromAI`.

## Review Triage Log

### 2026-09-03 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 3 (high 1high, medium 1medium, low 1low)
- defer: 6 (high 0high, medium 3medium, low 3low)
- reject: 6
- addressed_findings:
  - `high` `patch` `Buscar_info_setor` (`n8n/workflows/03 - Buscar Info Setor.json`) devolvia o retorno bruto do Postgres (`{"config": {...}}`) sem recorte, vazando campos não relacionados/sensíveis (`destinatarios_emergencia`, `sla_resposta_minutos`, `tom_voz`, `mapeamento_stage_crm`, `sinais_alerta_clinico`, `lock_ttl_minutos`, etc.) para o contexto de tool-call da IA, em vez de só `catalogo_servicos`/`profissionais` como prometido pelo Intent e pela `description` da própria ferramenta — quebra de AD-1 no nível de campo. Corrigido com um novo node `Set` ("Selecionar Catálogo e Profissionais") entre o node Postgres e a saída do sub-workflow, no mesmo padrão de achatamento já usado pelo node `Info` para `Buscar Config`.
  - `medium` `patch` Seção 3.1 do `systemMessage` não tinha nenhuma instrução de fallback para `Buscar_info_setor` falhar ou devolver `catalogo_servicos`/`profissionais` vazio — risco de a IA inventar serviço/profissional. Corrigido com uma frase adicional na Seção 3.1 instruindo a IA a nunca inventar dado nesse caso e informar que um humano vai continuar o atendimento.
  - `low` `patch` O comando de Verificação da Story 6 (`stories/6-cap-2-triagem-e-direcionamento.md:295`) afirma `len(tools) == 1` e `ai_tool_sources == {'Refletir', 'Escalar Humano'}`, o que não bate mais contra o `01 - Agente.json` atual (Story 7 adicionou um segundo `toolWorkflow`). Mudança legítima, não regressão — corrigido com uma nota `[superseded pela Story 7]` logo após o comando original em `stories/6-cap-2-triagem-e-direcionamento.md`, sem reescrever nem apagar o registro histórico.

## Design Notes

`Buscar_info_setor` é a primeira leitura da fatia `setor` de `atendimento_config_ler` (exposta desde a Story 2, migration `0004`, estendida por `0008`/`0010`, mas sem consumidor até agora) — via ferramenta chamada pelo próprio agente, não por node Postgres fixo no topo do workflow, porque o setor só é conhecido depois da classificação do próprio turno do agente (Story 6 decidiu não persistir setor classificado em tabela). Isso preserva "seletiva, não cumulativa" (AD-1): cada chamada busca só o setor que o agente já classificou, nunca os 5 de uma vez, e nenhum node roda essa leitura em turnos que não chegam a precisar dela.

## Verification

**Commands:**
- `python3 -c "import json, re; d = json.load(open('n8n/workflows/03 - Buscar Info Setor.json')); assert 'nodes' in d and 'connections' in d; trg = [n for n in d['nodes'] if n.get('type') == 'n8n-nodes-base.executeWorkflowTrigger'][0]; inputs = [v['name'] for v in trg['parameters']['workflowInputs']['values']]; assert 'setor' in inputs; content = json.dumps(d); assert not re.search(r'(Bearer |api[_-]?key|token\s*[:=]|secret|senha\s*[:=])', content, re.I); print('OK')"` -- expected: `OK`.
- `python3 -c "import json; d = json.load(open('n8n/workflows/01 - Agente.json')); agent = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.agent'][0]; sm = agent['parameters']['options']['systemMessage']; assert sm.index('2. Triagem e Direcionamento') < sm.index('3. Fluxo Care Center'); tools = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.toolWorkflow']; names = {t['name'] for t in tools}; assert names == {'Escalar Humano', 'Buscar Info Setor'}; ai_tool_sources = {src for src, out in d['connections'].items() if any(c['node'] == 'Agente Nouvet' for group in out.get('ai_tool', []) for c in group)}; assert ai_tool_sources == {'Refletir', 'Escalar Humano', 'Buscar Info Setor'}; buscar = [t for t in tools if t['name'] == 'Buscar Info Setor'][0]; assert 'fromAI' in buscar['parameters']['workflowInputs']['value']['setor']; print('OK')"` -- expected: `OK`.

**Manual checks (if no CLI):**
- Na VPS de dev: importar `03 - Buscar Info Setor.json`, relinkar `workflowId` do node `toolWorkflow` em `01 - Agente.json`, testar os 4 cenários da I/O Matrix com um telefone de teste classificado em Care Center.

## Auto Run Result

Status: `done`
Blocking condition: nenhuma.

**Resumo do que foi implementado:** Story 7 (CAP-3 — Fluxo Care Center) estende o `systemMessage` do nó `Agente Nouvet` com a Seção 3 do SOP ("Fluxo Care Center") e entrega o mecanismo de leitura seletiva por setor que faltava desde a Story 2 (AD-1): novo sub-workflow `03 - Buscar Info Setor.json` (padrão tool-subworkflow, AD-4), acionado pela ferramenta `Buscar_info_setor` (`setor="Care Center"`, via `$fromAI`), que devolve só `catalogo_servicos` e `profissionais` já filtrados. A IA coleta serviço + preferência textual de data/horário (+ profissional/pedido adicional, se houver) e sempre informa que um humano vai confirmar contra a agenda real — nenhuma tool de agenda (leitura ou escrita) ligada ao agente, nenhuma reserva automática, sem citar preço/duração (AD-4). Uma passada de review adversarial (blind-hunter, edge-case-hunter, verification-gap, intent-alignment) rodou sobre o diff e resultou em 3 patches aplicados nesta mesma passada — ver abaixo.

**Arquivos alterados:**
- `n8n/workflows/03 - Buscar Info Setor.json` (novo) — sub-workflow de leitura seletiva por setor: `executeWorkflowTrigger` (`setor`) → Postgres `atendimento_config_ler('setor', $1)` → node `Set` "Selecionar Catálogo e Profissionais" que recorta o retorno para só `catalogo_servicos`/`profissionais` (adicionado no patch high desta passada).
- `n8n/workflows/01 - Agente.json` — novo nó `toolWorkflow` "Buscar Info Setor" conectado ao `Agente Nouvet` via `ai_tool`; nova Seção 3 do SOP no `systemMessage` (3.1–3.6: buscar info, coletar serviço, coletar data/horário, profissional preferido, pedido adicional não agendável, fechar coleta — com guarda de fallback para tool vazia/com erro, adicionada no patch medium); Seção 2.2 atualizada para apontar à Seção 3 (ativa); novos exemplos de diálogo (9–12) cobrindo os 4 cenários da I/O Matrix.
- `_bmad-output/specs/spec-atendimento-nouvet/stories/6-cap-2-triagem-e-direcionamento.md` — nota `[superseded pela Story 7]` anexada ao comando de Verificação que afirmava só 1 `toolWorkflow` conectado (patch low desta passada), sem reescrever o registro histórico original.

**Review findings — breakdown:**
- Patches aplicados: 3 (1 high, 1 medium, 1 low) — ver `## Review Triage Log` para detalhe de cada um.
- Itens deferidos: 6 (0 high, 3 medium, 3 low) — multi-serviço na mesma mensagem, correção de preferência já coletada em pleno fluxo, ausência de guarda contra chamadas repetidas de `Buscar_info_setor`, cliente trocando de setor no meio da coleta, ambiguidade entre múltiplos profissionais parecidos, e `setor` não marcado `required: true` no `workflowInputs` do trigger — todos registrados em `deferred` no frontmatter.
- Itens rejeitados: 6 — seed vazio de `atendimento_profissionais` (já rastreado como pendência de dado real do Nouvet no doc de acompanhamento, fora do escopo de código desta story), normalização de data/horário relativo (contraria o design explícito de "preferência textual, nunca checada"), bullet do Code Map sobre Story 6 (já satisfeito pela Seção 2.2 do `systemMessage`), placeholder `workflowId: SET_IN_N8N_UI` sem fallback no prompt (padrão já pré-aprovado, mesmo tratamento do "Escalar Humano"), ausência de teste comportamental ao vivo (risco residual já aceito no despacho original desta mesma story, ambiente sem Docker/n8n), e um nit cosmético de formatação em doc não relacionado ao escopo.

**Follow-up review recommendation:** `true` (patch de severidade `high` presente nesta passada — critério isolado já ativa a recomendação; contagem: high 1, medium 1, low 1, score `3×1 + 1×1 = 4`).

**Verificação realizada:** os 2 comandos automatizados de `## Verification` rodaram e imprimiram `OK` tanto antes quanto depois dos 3 patches (re-executados após cada aplicação); `python3 -m json.tool` confirmou JSON válido em ambos os workflows após as edições; inspeção estática confirmou os 4 cenários da I/O & Edge-Case Matrix cobertos pelo texto da Seção 3 do SOP (3.1–3.6) e pelos Exemplos 9–12. Toda verificação prevista é estática (JSON/texto) — Docker/n8n seguem indisponíveis neste ambiente de build, então os "Manual checks" da spec (teste ao vivo na VPS de dev com telefone de teste) permanecem pendentes, mesmo padrão já aceito nas Stories 5/6.

**Riscos residuais explícitos:** "roteamento a humano" desta story é só textual (aviso ao cliente) — não existe ainda card/CRM (Story 11) nem mecanismo de follow-up (Story 12) que de fato torne o atendimento "Aguardando Atendimento Humano" de forma rastreável; mesmo padrão de "contrato antes do consumidor" já aceito nas Stories 2-6. `workflowId: "SET_IN_N8N_UI"` do novo `toolWorkflow` "Buscar Info Setor" ainda precisa ser relinkado na VPS de dev após importar `03 - Buscar Info Setor.json` (mesmo tratamento pendente já usado para "Escalar Humano"). `atendimento_profissionais` não tem seed hoje — enquanto isso não for populado com dado real do Nouvet, a Seção 3.4 sempre vai informar "profissional não reconhecido" mesmo para staff real (rastreado como pendência de dado, não de código). Os 6 itens deferidos acima ficam para refinamento futuro do SOP da Seção 3.

