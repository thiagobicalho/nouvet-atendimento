---
title: 'CAP-6 — Orçamentos (Roteamento puro)'
type: 'feature'
created: '2026-09-03'
status: 'done'
baseline_revision: '3dc1b8d56b9f5c7f21c7559aace5f2dd7ed651b7'
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: ['oversized']
deferred:
  - summary: >-
      Não há regra simétrica à Validação 16 para quando o cliente muda de assunto
      saindo da Seção 7 (Orçamentos) em direção a um setor com coleta ativa (ex.:
      "na verdade, só agenda o banho mesmo").
    evidence: |-
      Validação 16 cobre apenas a direção "Seções 3, 4, 5 ou 6 -> Seção 2 -> outro
      setor"; a Seção 7 nunca existiu antes desta story, então este caminho de saída
      nunca pôde ocorrer antes. Não há nenhuma outra validação genérica de troca de
      assunto no restante do systemMessage (confirmado por busca textual). O I/O &
      Edge-Case Matrix desta story não cobre este cenário, e o comportamento
      resultante depende inteiramente da competência geral do LLM em retriagem, sem
      instrução explícita.
    location: >-
      n8n/workflows/01 - Agente.json (systemMessage, Validação 16 / Seção 7)
    severity: low
  - summary: >-
      Typo pré-existente "sigo com o que you já me passou" (deveria ser "eu") no
      Exemplo 14, não relacionado a esta story.
    evidence: |-
      Encontrado incidentalmente durante a revisão desta story; o texto do Exemplo
      14 não foi tocado por este diff (é de uma story anterior) e continua com o
      erro.
    location: >-
      n8n/workflows/01 - Agente.json (systemMessage, Exemplo 14)
    severity: low
---

<intent-contract>

## Intent

**Problem:** `n8n/workflows/01 - Agente.json` (Stories 5-9) já classifica Orçamentos como um dos 5 setores em escopo (SOP Seção 2.1) e já tem seções de coleta ativas para os outros 4 setores (3-6), mas o `systemMessage` ainda trata Orçamentos como "fase seguinte ainda não construída" em 4 apontamentos (`<papel>`, SOP "1. Abertura", SOP "2.2", Validação 8) e a `description` da ferramenta `Buscar_info_setor` promete indevidamente estendê-la a Orçamentos — nenhuma seção do SOP cobre o que fazer quando o cliente pede um orçamento.

**Approach:** Acrescentar a Seção "7. Fluxo Orçamentos" ao SOP implementando roteamento puro (CAP-6, sem Agente de Orçamento dedicado): nenhuma coleta de catálogo/data/horário/profissional, nenhuma chamada a `Buscar_info_setor` — confirmado por inspeção de `atendimento_config_ler('setor', p_setor)` (migration `0010`) que a fatia `setor` para `p_setor='Orçamentos'` sempre devolve `catalogo_servicos`/`profissionais` vazios (nenhum item de catálogo tem `setor='Orçamentos'`, nenhum profissional tem `'Orçamentos'` em `atendimento_profissionais.setores`) — a seção só reconhece o pedido com as próprias palavras do cliente (citando o serviço, se já mencionado) e informa que um humano vai continuar diretamente com o orçamento. Fecha os 4 apontamentos de "fase seguinte" (Orçamentos é o último setor pendente) e corrige a `description` de `Buscar_info_setor`.

## Boundaries & Constraints

**Always:** Classificar o setor Orçamentos (Seção 2.1, item 5) sempre segue para a nova Seção 7 — nunca aciona `Escalar_humano` (roteamento/coleta concluída não é um dos 3 motivos da Seção 2.3, mesmo invariante já usado nas Seções 3.6/4.5/5.5/6.4). A Seção 7 nunca chama `Buscar_info_setor` (não existe fatia de catálogo/profissionais própria de Orçamentos — ver Design Notes) e nunca calcula, estima, negocia ou informa valor algum, em nenhuma circunstância, mesmo se o cliente insistir — reforça o guardrail já presente nas Seções 3.6/4.5/5.5/6.4, agora também explícito para o próprio setor Orçamentos. A seção reconhece o pedido com as próprias palavras do cliente, citando o serviço já mencionado (se houver) sem validar contra nenhum catálogo — Orçamentos aceita qualquer serviço citado, já que não há Agente de Orçamento dedicado para confirmá-lo. Quando o cliente pede orçamento no meio da coleta de outro setor (Care Center/Consultas/Vacinas/Exames, ex.: "quanto custa isso?"), a Validação 16 já existente (mudar de assunto no meio da coleta → reclassificar) se aplica normalmente — Orçamentos é um dos 5 setores da Seção 2.1, então essa reclassificação já está coberta; a única extensão necessária é deixar explícito que, ao reclassificar para Orçamentos, o destino é a Seção 7 e nenhuma chamada nova a `Buscar_info_setor` é feita (Validação 16 já isenta os setores sem coleta ativa dessa chamada — Orçamentos passa a ser esse caso). Os 4 apontamentos de "fase seguinte ainda não construída" (`<papel>`, SOP "1. Abertura", SOP "2.2", Validação 8) são reescritos para não citar nenhum setor pendente — depois desta story, os 5 setores da Seção 2.1 têm todos seção de fluxo ativa (Orçamentos é o último a fechar essa lista, mesmo padrão de manutenção já feito pelas Stories 6-9). A `description` de `Buscar_info_setor` é corrigida para não prometer extensão a Orçamentos.

**Block If:** Nenhuma decisão bloqueante identificada — roteamento puro não introduz ambiguidade de implementação nova; a única suposição (fatia `setor` vazia para Orçamentos) já está confirmada por inspeção direta da função Postgres existente, não uma incerteza a validar depois.

**Never:** Não cria nem atualiza contato ou card no RD CRM (Story 11/CAP-7, ainda não construída) — "roteado direto a um humano com todo o contexto já coletado anexado ao card" (linguagem do SPEC) permanece, nesta story, um roteamento textual (aviso ao cliente), mesmo padrão de "contrato antes do consumidor" já usado nas Stories 5-9; o anexo real ao card é responsabilidade da Story 11. Não introduz nenhum sub-workflow novo nem estende `Buscar_info_setor` para aceitar `"Orçamentos"` como setor válido — decisão desta story é o oposto (nunca chamar a ferramenta para este setor). Não altera o comportamento das Seções 3-6 além dos 4 apontamentos de "fase seguinte" e do esclarecimento da Validação 16 — nenhuma mudança na lógica de coleta já entregue pelas Stories 7-9. Não calcula, estima nem menciona valor de nenhum serviço em nenhum setor.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Pedido direto de orçamento, sem serviço específico | Cliente pergunta algo como "quanto custa o atendimento?" sem contexto prévio de setor | Classificado Orçamentos (Seção 2.1); segue Seção 7: reconhece o pedido com as próprias palavras, sem coletar nenhum dado, informa que um humano vai continuar diretamente com o orçamento | Nenhum erro |
| Pedido de orçamento de serviço específico | Cliente pergunta "quanto custa um banho?" | Classificado Orçamentos (não Care Center, por já ser pedido de valor — Seção 2.1 item 5); Seção 7 reconhece o serviço citado (banho) nas próprias palavras, sem chamar `Buscar_info_setor` nem validar contra catálogo, informa que um humano vai continuar | Nenhum erro |
| Pedido de orçamento no meio da coleta de outro setor | Cliente já em coleta ativa (ex.: Seção 3, Care Center, já informou o serviço) e pergunta "quanto isso custa?" | Validação 16 (mudar de assunto no meio da coleta) se aplica: interrompe a coleta corrente, reclassifica para Orçamentos, segue a Seção 7 — sem chamar `Buscar_info_setor` de novo (Orçamentos não tem fluxo de coleta ativo) | Nenhum erro |
| Fechamento da Seção 6 (Exames) permanece inalterado | Cliente concluiu a coleta da Seção 6 (Exames, Story 9) | Seção 6.4 já informa que um humano vai continuar com o orçamento (comportamento pré-existente da Story 9) — não há reclassificação para Orçamentos nem chamada nova à Seção 7 neste mesmo turno, é a continuação normal já entregue | Nenhum erro, sem regressão |

</intent-contract>

## Code Map

- `n8n/workflows/01 - Agente.json` -- nó `Agente Nouvet` (`systemMessage`): acrescenta "7. Fluxo Orçamentos" ao `<sop>` (após "6. Fluxo Exames"); reescreve os 4 apontamentos "fase seguinte ainda não construída" em `<papel>`, SOP "1. Abertura..." (parágrafo introdutório), SOP "2.2" e Validação 8 para não citar nenhum setor pendente; corrige a `description` da ferramenta `Buscar_info_setor` (remove a promessa de extensão a Orçamentos, deixa explícito que só os 4 setores com fluxo de coleta ativo a usam); estende a Validação 16 citando a Seção 7 como destino de reclassificação para Orçamentos e reforçando que nenhuma chamada nova a `Buscar_info_setor` ocorre nesse caso; acrescenta Validação 19 (Orçamentos: nunca `Buscar_info_setor`, nunca valor/cálculo, roteamento puro); acrescenta 2 exemplos novos grounded em UJ-3 (pedido direto de orçamento; reclassificação no meio de outro fluxo).
- `n8n/migrations/0010_atendimento_config_ler_lock_ttl.sql` -- só referência, nenhuma mudança: confirma que `atendimento_config_ler('setor', 'Orçamentos')` sempre devolve `catalogo_servicos: []` e `profissionais: []` (nenhum item de `catalogo_servicos` tem `setor = 'Orçamentos'`; nenhuma linha de `atendimento_profissionais` tem `'Orçamentos'` em `setores`) — evidência de que `Buscar_info_setor` não tem utilidade para este setor.
- `stories/6-cap-2-triagem-e-direcionamento.md` -- Seção 2.1 (Orçamentos já listado como um dos 5 setores) e Seção 2.2 (apontamento "fase seguinte" a fechar) como base a estender, não recriar.
- `stories/7-cap-3-fluxo-care-center.md` / `8-cap-4-fluxo-consultas-e-vacinas.md` / `9-cap-5-fluxo-exames.md` -- padrão de fechamento de seção ("Chamar Escalar_humano não é necessário aqui... não é um dos 3 motivos da Seção 2.3") a replicar na Seção 7; Story 9 já registrou explicitamente no seu Boundaries "Não implementa Orçamentos (Story 10, roteamento puro)" como o contrato que esta story cumpre agora.

## Tasks & Acceptance

**Execution:**
- `n8n/workflows/01 - Agente.json` -- acrescentar SOP "7. Fluxo Orçamentos" (reconhecer o pedido sem coletar dado de catálogo, sem chamar `Buscar_info_setor`, fechar informando que um humano vai continuar diretamente com o orçamento) -- implementa CAP-6.
- `n8n/workflows/01 - Agente.json` -- reescrever os 4 apontamentos "fase seguinte ainda não construída" (`<papel>`, SOP 1, SOP 2.2, Validação 8) para não citar nenhum setor pendente -- fecha a manutenção iniciada pelas Stories 6-9, nenhum setor da Seção 2.1 fica sem seção de fluxo.
- `n8n/workflows/01 - Agente.json` -- corrigir a `description` de `Buscar_info_setor` (remover a promessa de extensão a Orçamentos) -- mantém a documentação da tool precisa para o LLM.
- `n8n/workflows/01 - Agente.json` -- estender a Validação 16 (citar Seção 7 como destino, sem nova chamada a `Buscar_info_setor`) e acrescentar a Validação 19 (Orçamentos: roteamento puro, nunca catálogo, nunca valor) -- mantém o prompt internamente consistente.
- `n8n/workflows/01 - Agente.json` -- acrescentar Exemplo 15 (pedido direto de orçamento) e Exemplo 16 (reclassificação no meio de outro fluxo), grounded em UJ-3 e na Validação 16 -- reduz ambiguidade de tom/comportamento na Seção 7, mesma prática das Stories 7-9.

**Acceptance Criteria:**
- Given os 4 cenários da I/O & Edge-Case Matrix, when reproduzidos contra o `systemMessage`/topologia do workflow (inspeção estática), then o comportamento bate com a coluna "Expected Output/Behavior".
- Given a seção `<sop>` do `systemMessage`, when inspecionada, then contém "1. Abertura...", "2. Triagem...", "3. Fluxo Care Center", "4. Fluxo Consultas", "5. Fluxo Vacinas", "6. Fluxo Exames" e "7. Fluxo Orçamentos", nesta ordem.
- Given as ferramentas conectadas ao `Agente Nouvet` via `ai_tool`, when inspecionadas, then continuam sendo exatamente `{'Refletir', 'Escalar Humano', 'Buscar Info Setor'}` — nenhum nó novo.
- Given a Seção 7 do `systemMessage`, when inspecionada, then não menciona `Buscar_info_setor` nem `Escalar_humano`, e nenhuma frase calcula ou informa valor de serviço.
- Given os textos de apontamento "fase seguinte ainda não construída"/"ainda não construída", when inspecionados após a mudança, then nenhuma ocorrência resta no `systemMessage` — todos os 5 setores da Seção 2.1 têm seção de fluxo ativa.
- Given a `description` da ferramenta `Buscar_info_setor`, when inspecionada, then não promete extensão a Orçamentos e cita exatamente os 4 setores que a usam (Care Center, Consultas, Vacinas, Exames).

## Spec Change Log

## Review Triage Log

### 2026-09-03 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 2: (high 0, medium 0, low 2)
- defer: 2: (high 0, medium 0, low 2)
- reject: 12: (high 0, medium 0, low 12)
- addressed_findings:
  - `[low]` `[patch]` Removida a referência órfã "(ver Design Notes)" (2 ocorrências: intro da Seção 7 e Validação 19) — "Design Notes" só existe no arquivo de spec, nunca no `systemMessage` real enviado ao LLM; a frase ao redor já contém o fato relevante, então a referência foi apenas removida.
  - `[low]` `[patch]` Corrigido fragmento gramatical "mas já ativo" → "mas já está ativo" na introdução da SOP "1. Abertura...".

## Design Notes

`Buscar_info_setor` nunca é chamada para Orçamentos porque a fatia `setor` de `atendimento_config_ler` nunca foi desenhada para esse setor: nenhum item de `catalogo_servicos` carrega `setor = 'Orçamentos'` e nenhuma linha de `atendimento_profissionais` inclui `'Orçamentos'` em `setores` (confirmado por inspeção direta da função em `0010_atendimento_config_ler_lock_ttl.sql`) — chamar a ferramenta sempre devolveria catálogo/profissionais vazios, sem nenhum ganho sobre simplesmente reconhecer o pedido em texto. Isso é consistente com o próprio nome da capability (CAP-6 — Orçamentos, **Roteamento puro**) e com a decisão de produto "não existe Agente de Orçamento dedicado" (stories.yaml, SPEC.md): a Seção 7 é deliberadamente a mais enxuta do SOP, sem nenhuma ferramenta própria, porque não há dado de configuração nem catálogo a validar — só reconhecimento e encaminhamento.

## Verification

**Commands:**
- `python3 -c "import json; d = json.load(open('n8n/workflows/01 - Agente.json')); agent = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.agent'][0]; sm = agent['parameters']['options']['systemMessage']; order = ['1. Abertura', '2. Triagem e Direcionamento', '3. Fluxo Care Center', '4. Fluxo Consultas', '5. Fluxo Vacinas', '6. Fluxo Exames', '7. Fluxo Orçamentos']; idxs = [sm.index(s) for s in order]; assert idxs == sorted(idxs); tools = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.toolWorkflow']; names = {t['name'] for t in tools}; assert names == {'Escalar Humano', 'Buscar Info Setor'}; ai_tool_sources = {src for src, out in d['connections'].items() if any(c['node'] == 'Agente Nouvet' for group in out.get('ai_tool', []) for c in group)}; assert ai_tool_sources == {'Refletir', 'Escalar Humano', 'Buscar Info Setor'}; s7 = sm[sm.index('7. Fluxo Orçamentos'):sm.index('</sop>')]; assert 'Buscar_info_setor' not in s7 and 'Buscar Info Setor' not in s7; assert 'Escalar_humano' not in s7 and 'Escalar Humano' not in s7; assert 'ainda não construída' not in sm and 'fase seguinte deste mesmo atendimento' not in sm; buscar = [t for t in tools if t['name'] == 'Buscar Info Setor'][0]; desc = buscar['parameters']['description']; assert 'Orçamentos' not in desc; print('OK')"` -- expected: `OK` (garante ordem do SOP incluindo a Seção 7, tools inalteradas, Seção 7 sem `Buscar_info_setor`/`Escalar_humano`, nenhum apontamento de fase pendente restante, e `description` da tool sem a promessa de extensão a Orçamentos).
- `python3 -c "content = open('n8n/migrations/0010_atendimento_config_ler_lock_ttl.sql').read(); assert \"'Orçamentos'\" not in content; print('OK')"` -- expected: `OK` (confirma, por ausência, que nenhuma migration precisou adicionar uma fatia de catálogo/profissionais própria para Orçamentos — a leitura do Design Notes já cobre esse dado via a função existente, sem mudança de schema).

**Manual checks (if no CLI):**
- Na VPS de dev: com `01 - Agente.json` já importado, testar os 4 cenários da I/O Matrix com um telefone de teste, incluindo o caso de pedir orçamento no meio de uma coleta já iniciada (ex.: Care Center) para confirmar a reclassificação e o texto de fechamento da Seção 7.

## Auto Run Result

Status: `done`
Blocking condition: nenhuma.

**Resumo:** Dispatch pasta+id para a Story 10 (`CAP-6 — Orçamentos (Roteamento puro)`), primeiro despacho para este id (nenhum arquivo prévio em `stories/10-*.md`). Investigação cobriu `SPEC.md`, `user-journeys.md`, `glossary.md`, `ARCHITECTURE-SPINE.md`, as 5 stories anteriores relacionadas (Code Map/Design Notes/Auto Run Result de 5, 6, 7, 8 e 9), `deferred-work.md` (nenhum item bloqueante para Orçamentos) e o `systemMessage` real de `n8n/workflows/01 - Agente.json` no estado atual (pós-Story 9). Spec escrita e verificada contra o padrão READY FOR DEVELOPMENT — nenhum gap de intenção encontrado. Implementação, verificação e revisão executadas nesta mesma passada (sem halt após o planejamento).

**Decisão de escopo tomada no planejamento (registrada no spec, não fantasiada):** confirmado por inspeção direta de `atendimento_config_ler` (migration `0010`) que a fatia `setor` para `p_setor='Orçamentos'` sempre devolve `catalogo_servicos`/`profissionais` vazios — decisão de que a Seção 7 (Orçamentos) nunca chama `Buscar_info_setor`, roteamento puro sem consumo de config de setor, e que a `description` dessa ferramenta (que hoje promete indevidamente estendê-la a Orçamentos) precisa ser corrigida.

**Arquivos alterados:**
- `n8n/workflows/01 - Agente.json` -- único arquivo alterado (apenas o campo `systemMessage` do nó `Agente Nouvet`): acrescenta SOP "7. Fluxo Orçamentos" (7.1 reconhecer o pedido, 7.2 nunca calcular/informar valor, 7.3 fechar o encaminhamento); reescreve os 4 apontamentos de "fase seguinte ainda não construída" (`<papel>`, SOP "1. Abertura", SOP "2.2", Validação 8); corrige a `description` de `Buscar_info_setor` (remove a promessa de extensão a Orçamentos); estende a Validação 16 e acrescenta a Validação 19; acrescenta os Exemplos 15 e 16 (grounded em UJ-3).

**Revisão (4 camadas em paralelo -- blind-hunter, edge-case-hunter, verification-gap, intent-alignment):**
- patch: 2 (baixa, baixa) -- ambos aplicados: referência órfã "(ver Design Notes)" removida (2 ocorrências, apontava para uma seção que só existe no spec, nunca no `systemMessage` real) e fragmento gramatical "mas já ativo" corrigido para "mas já está ativo".
- defer: 2 (baixa, baixa) -- ver frontmatter `deferred`: (1) ausência de regra simétrica à Validação 16 para o cliente mudar de assunto saindo da Seção 7 (Orçamentos) de volta para um setor com coleta ativa; (2) typo pré-existente "you"/"eu" no Exemplo 14, não relacionado a esta story.
- reject: 12 -- inclui, entre outros: regra normativa "Orçamentos = pedido de valor" já existe na Seção 2.1 item 5 (não é um gap, reviewer não tinha o contexto completo); carryover de dado já coletado (ex. "banho") para a Seção 7 já demonstrado no Exemplo 16; tratamento de múltiplos serviços numa mesma mensagem de Orçamentos não se aplica a roteamento puro (sem coleta/validação de catálogo); gatilhos de Escalar_humano (fora de escopo/convênio) já são avaliados na Triagem (Seção 2), antes de entrar na Seção 7, mesmo padrão das Seções 3-6; divergência "verificação estática vs. comportamento end-to-end" já é reconhecida e coberta pela seção "Manual checks" do próprio spec.
- Nenhum `intent_gap` nem `bad_spec` identificado -- `review_loop_iteration` permanece `0`.

**Follow-up review recommendation:** `false` -- 2 patches, ambos severidade baixa (score: 3×0 medium + 1×2 low = 2, abaixo do limiar de 5; nenhum patch de severidade alta).

**Verificação executada:**
- Os 2 comandos da seção `## Verification` do spec rodaram e imprimiram `OK` três vezes (implementação, revisão, pós-patch): ordem das seções do SOP (incluindo a nova Seção 7), conjunto de tools inalterado (`{Refletir, Escalar Humano, Buscar Info Setor}`), Seção 7 sem `Buscar_info_setor`/`Escalar_humano`, nenhum apontamento de "fase pendente" restante, `description` de `Buscar_info_setor` sem menção a Orçamentos, e a migration `0010` sem qualquer referência a `'Orçamentos'`.
- Matrix Test Audit: as 4 linhas do I/O & Edge-Case Matrix foram cobertas por inspeção direta do texto final da Seção 7, da Validação 16/19 e do fechamento inalterado da Seção 6 -- nenhuma cobertura ausente.
- `git diff --stat` confirmado como escopo único (`n8n/workflows/01 - Agente.json`), sem alteração de formatação incidental (round-trip `json.load`/`json.dump` reproduz o arquivo original byte a byte antes de qualquer edição).

**Riscos residuais:** os 2 itens `defer` acima (baixo risco, sem bloqueio). Nenhuma cobertura de comportamento end-to-end real com o agente rodando (verificação é só por inspeção estática do prompt) -- teste manual na VPS de dev com telefone real, conforme a seção "Manual checks" do spec, continua pendente e é responsabilidade de execução fora deste run automatizado.
