---
title: 'CAP-3 — Fluxo Care Center'
type: 'feature'
created: '2026-09-03'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
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
- `n8n/workflows/03 - Buscar Info Setor.json` -- novo arquivo (convenção `02+` do README): `executeWorkflowTrigger` (input: `setor`) → node Postgres `SELECT atendimento_config_ler('setor', $1) AS config` → node `Set` projeta e retorna no topo somente `catalogo_servicos` e `profissionais`, já filtrados pelo setor; o `config` bruto não é retornado.
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

### 2026-09-03 — Review pass (build-auto solicitado)
- intent_gap: 0
- bad_spec: 0
- patch: 0
- defer: 0
- reject: 18
- addressed_findings:
  - none

Os achados sobre múltiplos serviços, revisão de preferências, troca de setor, reutilização da consulta, nomes ambíguos e obrigatoriedade de `setor` já constavam no ledger `deferred` da story e foram descartados nesta passagem sem reabrir, modificar ou reescrever as entradas existentes. A lacuna de verificação end-to-end foi rejeitada porque o contrato desta story define inspeção estática e validação manual na VPS como superfícies de aceitação; mudanças posteriores da Story 8 foram tratadas como fora do diff próprio da Story 7.

## Design Notes

`Buscar_info_setor` é a primeira leitura da fatia `setor` de `atendimento_config_ler` (exposta desde a Story 2, migration `0004`, estendida por `0008`/`0010`, mas sem consumidor até agora) — via ferramenta chamada pelo próprio agente, não por node Postgres fixo no topo do workflow, porque o setor só é conhecido depois da classificação do próprio turno do agente (Story 6 decidiu não persistir setor classificado em tabela). Isso preserva "seletiva, não cumulativa" (AD-1): cada chamada busca só o setor que o agente já classificou, nunca os 5 de uma vez, e nenhum node roda essa leitura em turnos que não chegam a precisar dela.

## Verification

**Commands:**
- `python3 -c "import json, re; d = json.load(open('n8n/workflows/03 - Buscar Info Setor.json')); assert 'nodes' in d and 'connections' in d; triggers = [n for n in d['nodes'] if n.get('type') == 'n8n-nodes-base.executeWorkflowTrigger']; assert len(triggers) == 1; trigger = triggers[0]; assert [v['name'] for v in trigger['parameters']['workflowInputs']['values']] == ['setor']; postgres_nodes = [n for n in d['nodes'] if n.get('type') == 'n8n-nodes-base.postgres']; assert len(postgres_nodes) == 1; postgres = postgres_nodes[0]; assert postgres['parameters']['query'] == \"SELECT atendimento_config_ler('setor', $1) AS config\"; assert postgres['parameters']['options']['queryReplacement'] == \"={{ $('Receber Solicitação').item.json.setor }}\"; set_nodes = [n for n in d['nodes'] if n.get('type') == 'n8n-nodes-base.set']; assert len(set_nodes) == 1; final_set = set_nodes[0]; assignments = final_set['parameters']['assignments']['assignments']; assert len(assignments) == 2; assert {a['name']: a['value'] for a in assignments} == {'catalogo_servicos': '={{ $json.config.catalogo_servicos }}', 'profissionais': '={{ $json.config.profissionais }}'}; assert final_set['parameters'].get('includeOtherFields', False) is False; assert d['connections'].get(postgres['name'], {}).get('main') == [[{'node': final_set['name'], 'type': 'main', 'index': 0}]]; assert final_set['name'] not in d['connections']; content = json.dumps(d); assert not re.search(r'(Bearer |api[_-]?key|token\s*[:=]|secret|senha\s*[:=])', content, re.I); print('OK')"` -- expected: `OK`.
- `python3 -c "import json; d = json.load(open('n8n/workflows/01 - Agente.json')); agent = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.agent'][0]; sm = agent['parameters']['options']['systemMessage']; assert sm.index('2. Triagem e Direcionamento') < sm.index('3. Fluxo Care Center'); tools = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.toolWorkflow']; names = {t['name'] for t in tools}; assert names == {'Escalar Humano', 'Buscar Info Setor'}; ai_tool_sources = {src for src, out in d['connections'].items() if any(c['node'] == 'Agente Nouvet' for group in out.get('ai_tool', []) for c in group)}; assert ai_tool_sources == {'Refletir', 'Escalar Humano', 'Buscar Info Setor'}; buscar = [t for t in tools if t['name'] == 'Buscar Info Setor'][0]; assert 'fromAI' in buscar['parameters']['workflowInputs']['value']['setor']; description = buscar['parameters']['description']; assert 'Se apenas catalogo_servicos vier vazio' in description; assert 'Se somente profissionais vier vazio' in description; assert 'continue coletando servico/data/horario normalmente' in description; assert 'Se a ferramenta falhar ou devolver `catalogo_servicos` vazio' in sm; assert 'Se `profissionais` vier vazio mas `catalogo_servicos` estiver disponível' in sm; assert 'continue normalmente a coleta de serviço e preferência de data/horário' in sm; assert 'não confirme nenhuma preferência nominal de profissional' in sm; assert 'Mais de um item do catálogo pedido na mesma mensagem' in sm; assert 'Cliente corrige uma preferência já coletada' in sm; assert 'Buscar_info_setor já retornou dado nesta conversa para o setor corrente' in sm; assert 'Cliente muda de assunto para outro setor no meio da coleta' in sm; assert 'Mais de um profissional da lista corresponde aproximadamente ao nome citado pelo cliente' in sm; print('OK')"` -- expected: `OK` (inclui as 5 novas Validações 13-17 da revisão independente pós-DW-59/60/61/62/63).

**Manual checks (if no CLI):**
- Na VPS de dev: importar `03 - Buscar Info Setor.json`, relinkar `workflowId` do node `toolWorkflow` em `01 - Agente.json`, testar os 4 cenários da I/O Matrix com um telefone de teste classificado em Care Center.

### 2026-09-03 — Review pass (revisão independente pós-conclusão)
- intent_gap: 0
- bad_spec: 0
- patch: 3 (high 0high, medium 2medium, low 1low)
- defer: 0
- reject: 13
- addressed_findings:
  - `medium` `patch` A Seção 3.1 tratava `profissionais` vazio como falha impeditiva, embora profissional seja preferência opcional. Corrigido para continuar a coleta de serviço/data/horário quando o catálogo estiver disponível, sem confirmar preferência nominal.
  - `medium` `patch` As verificações não protegiam a projeção restrita do sub-workflow nem o fallback distinto para catálogo e profissionais. Os comandos estáticos agora conferem query parametrizada, conexão Postgres→Set, campos/expressões exatos da saída e as duas orientações do prompt/descrição da ferramenta.
  - `low` `patch` O Code Map ainda descrevia retorno de `config` bruto após a projeção restrita ter sido implementada. Corrigido para documentar os dois campos retornados no topo.

### 2026-09-03 — Resolução manual das pendências DW-59 a DW-64

Executada fora do `bmad-loop`, a pedido do Thiago, pra fechar os 6 itens deferred que a story deixou abertos.

- `[patch]` aplicados (5, DW-59 a DW-63): 5 novas Validações (13-17) acrescentadas ao `systemMessage` (`01 - Agente.json`), cobrindo Seções 3/4/5 (Care Center/Consultas/Vacinas) simultaneamente: (13) coletar múltiplos itens do catálogo pedidos na mesma mensagem; (14) atualizar preferência já coletada quando o cliente corrige; (15) reutilizar retorno de `Buscar_info_setor` já obtido em vez de re-chamar a cada turno; (16) interromper e reclassificar quando o cliente muda de setor no meio da coleta; (17) pedir confirmação quando mais de um profissional corresponde ambiguamente ao nome citado. Verification comando 2 estendido com 5 novas asserções; comando também corrigido (assert de `description` da tool estava desatualizado desde que a Story 8 generalizou o texto para 3 setores — corrigido para refletir o texto atual, achado incidental desta passada).
- `[resolved sem código]` (1, DW-64): investigação mostrou que a suposição original (`required: true` no schema do `executeWorkflowTrigger`) não é suportada por esse tipo de nó nesta versão do n8n — não implementável como descrito. Um guard real exigiria nó `IF` novo (mudança de topologia, fora do escopo de patch). Documentado no ledger para não reabrir a mesma suposição.

## Auto Run Result

- status: done
- finalização: o bloqueio temporário foi resolvido após a execução concorrente da Story 8 concluir; o worktree foi confirmado limpo antes desta atualização terminal.
- data: 2026-09-03
- revisão: quatro lentes independentes (`blind-hunter`, `edge-case-hunter`, `verification-gap`, `intent-alignment`) executadas; achados deduplicados e classificados.
- arquivos alterados nesta passagem: somente esta especificação, para registrar a nova triagem e o resultado final; nenhum workflow recebeu patch novo.
- achados desta passagem: patches 0, deferred novos 0, rejeitados 18; score de follow-up = 0, portanto `followup_review_recommended: false`.
- verificação: verificações estruturais equivalentes em `jq` retornaram `OK` para os dois workflows e para a projeção seletiva do sub-workflow.
- riscos residuais: importação/relink do `workflowId` e os quatro cenários conversacionais continuam dependendo da validação manual na VPS de dev já prevista pela story. As entradas deferred preexistentes não foram abertas, modificadas ou reescritas nesta execução.
