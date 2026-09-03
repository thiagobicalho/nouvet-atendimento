---
title: 'CAP-4 — Fluxo Consultas e Vacinas'
type: 'feature'
created: '2026-09-03'
status: 'done'
baseline_revision: 'facc3f0b9bb0fa7f42eda143cb0efe173ee06658'
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** `n8n/workflows/01 - Agente.json` (Stories 5-7) já classifica Consultas e Vacinas como setores distintos (Seção 2.1, decisão DW-13/Story 2) e já tem uma ferramenta genérica de leitura seletiva por setor (`Buscar_info_setor`, Story 7), mas o `systemMessage` só ativa coleta de dado para o Care Center (Seção 3) — Consultas e Vacinas continuam apontando para "fase seguinte ainda não construída".

**Approach:** Acrescentar duas novas seções ao SOP — "4. Fluxo Consultas" e "5. Fluxo Vacinas" — cada uma chamando `Buscar_info_setor` com seu próprio `setor` literal (`"Consultas"` / `"Vacinas"`, nunca uma chamada fundida), reutilizando a mesma ferramenta/sub-workflow já entregue pela Story 7 (não duplicar, ver Design Notes daquela story) e o mesmo padrão de "não invente dado fora do retorno da ferramenta". Consultas ganha um ramo extra que o Care Center não tem: quando o cliente não sabe qual especialidade quer, coleta-se a queixa em vez de forçar um item do catálogo (UJ-2).

## Boundaries & Constraints

**Always:** `Buscar_info_setor` é chamada com `setor="Consultas"` exatamente para o fluxo de Consultas e `setor="Vacinas"` exatamente para o fluxo de Vacinas — nunca uma chamada única fundindo os dois (decisão DW-13/Story 2, reforçada nesta story: os 2 setores nunca se fundem). Um profissional pode aparecer nos dois retornos (`atendimento_profissionais.setores` é array, filtro já é `p_setor = ANY(setores)`) — isso é comportamento esperado, não uma inconsistência a corrigir. Em Consultas: se o cliente já indicou uma especialidade, ela é comparada contra `catalogo_servicos` retornado (mesmo padrão de match do Care Center 3.2) — nunca hardcoded; se o cliente não sabe qual especialidade quer, ou o catálogo vier vazio, colete a queixa (sintoma/motivo) em vez de forçar uma escolha — isso não é um "pedido não agendável" (diferente do Care Center 3.5), é o caminho normal de quem já foi classificado em Consultas com direcionamento padrão ao clínico geral (decisão já tomada na Seção 2.1/Story 6 — esta seção não re-decide isso, só coleta o suporte textual). Em Vacinas: a vacina desejada é comparada contra `catalogo_servicos` retornado do mesmo jeito que o Care Center compara serviço; se o catálogo vier vazio ou o cliente não souber qual vacina, registre a preferência em texto sem inventar item, mesmo padrão de fallback do Care Center 3.1. Profissional preferido (opcional, nos dois fluxos) segue exatamente o padrão de match/não-match do Care Center 3.4. Data/horário são só preferência textual, nunca checada contra agenda real (AD-4), nos dois fluxos. Ao fechar a coleta (Consultas ou Vacinas), informe que um humano vai confirmar contra a agenda real — nunca confirma agendamento, nunca cita preço/duração; `Escalar_humano` não é chamado ao final (coleta completa não é um dos 3 motivos da Seção 2.3, mesmo invariante do Care Center 3.6). Sinais de Alerta/Emergência mantêm prioridade máxima mesmo dentro das Seções 4/5. Os textos de apontamento "fase seguinte ainda não construída" (Papel, SOP 1.5-equivalente, SOP 2.2, Validação 8) são atualizados para listar só Exames e Orçamentos como pendentes — Consultas e Vacinas saem dessa lista, mesmo ajuste de manutenção já feito pelas Stories 6/7 quando ativaram suas próprias seções.

**Block If:** Nenhuma decisão bloqueante identificada.

**Never:** Não cria nenhum sub-workflow novo — reutiliza `n8n/workflows/03 - Buscar Info Setor.json` exatamente como está (já genérico por `setor`, decisão já registrada nas Design Notes da Story 7: "Stories 8/9 reutilizam este mesmo sub-workflow, nunca duplicam"). Não adiciona seed de `catalogo_servicos` para Consultas/Vacinas nem de `atendimento_profissionais` — dado real ainda pendente do Nouvet (mesma classe do DW-42), os dois fluxos já têm fallback testado para catálogo/profissionais vazios (Care Center, Story 7). Não trata mensagem que mistura Consultas e Vacinas (ou qualquer outro setor) na mesma frase — gap já conhecido e deliberadamente não resolvido pela Story 6 (severidade baixa), não é escopo desta story resolvê-lo agora. Não implementa Exames (Story 9) nem Orçamentos (Story 10). Não inclui nenhuma tool de agenda nem de cadastro/CRM (mesmas restrições AD-4/Story 11 já valendo para o Care Center).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Consultas — especialidade conhecida | Setor já classificado Consultas; cliente pede dermatologista com dia/horário preferidos | Agente chama `Buscar_info_setor("Consultas")`, confirma a especialidade no catálogo retornado, coleta especialidade + profissional (se citado) + data/horário, informa que um humano vai confirmar | Nenhum erro |
| Consultas — não sabe a especialidade | Cliente diz que quer "uma consulta" mas não sabe qual especialidade (UJ-2) | Agente coleta a queixa em vez de forçar uma escolha de especialidade, segue coletando data/horário normalmente, sem acionar `Escalar_humano` | Nenhum erro |
| Vacinas — vacina conhecida | Setor já classificado Vacinas; cliente pede uma vacina específica com dia/horário preferidos | Agente chama `Buscar_info_setor("Vacinas")`, confirma a vacina no catálogo retornado, coleta profissional (se citado) + data/horário | Nenhum erro |
| Vacinas — não sabe qual vacina | Cliente só sabe que "o pet precisa de vacina" sem especificar qual | Agente registra a preferência em texto sem inventar item do catálogo, segue coletando profissional/data/horário, informa que um humano vai continuar | Se `catalogo_servicos` vier vazio, mesmo fallback: não inventa item |
| Profissional preferido não reconhecido | Cliente cita um nome que não está em `profissionais` da resposta da ferramenta, em qualquer um dos 2 setores | Agente informa que não reconhece esse profissional, segue coletando normalmente sem forçar um nome da lista | Nenhum erro |

</intent-contract>

## Code Map

- `n8n/workflows/01 - Agente.json` -- nó `Agente Nouvet` (`systemMessage`): acrescenta "4. Fluxo Consultas" e "5. Fluxo Vacinas" ao `<sop>` (após "3. Fluxo Care Center"); atualiza os apontamentos "fase seguinte ainda não construída" em `<papel>`, SOP "1. Abertura..." (parágrafo introdutório), SOP "2.2" e Validação 8 para listar só Exames/Orçamentos como pendentes; atualiza a `description` da ferramenta `Buscar_info_setor` (hoje fixa em "Care Center") para refletir uso também em Consultas/Vacinas. Nenhum nó novo — `Buscar_info_setor` já é genérico por `setor` (Story 7) e continua conectado via `ai_tool` sem mudança de topologia.
- `n8n/workflows/03 - Buscar Info Setor.json` -- reutilizado sem alteração funcional; só o texto do sticky note (`Sticky Note - Leitura seletiva por setor`) é atualizado para registrar que a Story 8 passou a consumi-lo também (documentação, não muda `nodes`/`connections`).
- `n8n/migrations/0008_atendimento_profissionais.sql` / `0010_atendimento_config_ler_lock_ttl.sql` -- corpo atual de `atendimento_config_ler('setor', p_setor)` já filtra `catalogo_servicos`/`profissionais` por `p_setor` exato (`item ->> 'setor' = p_setor`, `p_setor = ANY(p.setores)`) — nenhuma migration nova nesta story; Consultas e Vacinas já funcionam como valores de `p_setor` distintos sem mudança de schema.
- `n8n/seed/0001_atendimento_config.sql` -- `catalogo_servicos` hoje só tem os 3 itens de Care Center; nenhum item de Consultas/Vacinas — dado pendente do Nouvet (mesma classe do DW-42), fallback de catálogo vazio já testado pela Story 7.
- `stories/7-cap-3-fluxo-care-center.md` -- padrão de Seção 3 (chamada de `Buscar_info_setor`, match contra catálogo/profissionais, fallback "não invente", fechamento sem `Escalar_humano`) como base a adaptar para as Seções 4/5 — Consultas introduz o ramo extra de queixa que o Care Center não tem.
- `stories/6-cap-2-triagem-e-direcionamento.md` -- Seção 2.1 (5 setores) e resolução DW-13 (Consultas/Vacinas distintos, decisão já classificatória) como base a estender, não recriar; Seção 2.2 é um dos pontos de texto a atualizar nesta story.

## Tasks & Acceptance

**Execution:**
- `n8n/workflows/01 - Agente.json` -- acrescentar SOP "4. Fluxo Consultas" (especialidade OU queixa + profissional opcional + data/horário, via `Buscar_info_setor("Consultas")`) -- implementa a metade Consultas da CAP-4.
- `n8n/workflows/01 - Agente.json` -- acrescentar SOP "5. Fluxo Vacinas" (vacina + profissional opcional + data/horário, via `Buscar_info_setor("Vacinas")`) -- implementa a metade Vacinas da CAP-4.
- `n8n/workflows/01 - Agente.json` -- atualizar os 4 apontamentos "fase seguinte ainda não construída" (`<papel>`, SOP 1, SOP 2.2, Validação 8) para listar só Exames/Orçamentos -- mantém o prompt internamente consistente (mesma manutenção já feita pelas Stories 6/7).
- `n8n/workflows/01 - Agente.json` -- atualizar a `description` da ferramenta `Buscar_info_setor` para citar Consultas/Vacinas, não só Care Center -- mantém a documentação da tool precisa para o LLM.
- `n8n/workflows/03 - Buscar Info Setor.json` -- atualizar texto do sticky note para registrar o consumo pela Story 8 -- documentação, sem mudança funcional.

**Acceptance Criteria:**
- Given os 5 cenários da I/O & Edge-Case Matrix, when reproduzidos contra o `systemMessage`/topologia do workflow (inspeção estática), then o comportamento bate com a coluna "Expected Output/Behavior".
- Given a seção `<sop>` do `systemMessage`, when inspecionada, then contém "1. Abertura...", "2. Triagem...", "3. Fluxo Care Center", "4. Fluxo Consultas" e "5. Fluxo Vacinas", nesta ordem.
- Given as ferramentas conectadas ao `Agente Nouvet` via `ai_tool`, when inspecionadas, then continuam sendo exatamente `{'Refletir', 'Escalar Humano', 'Buscar Info Setor'}` — nenhum nó novo.
- Given as Seções 4 e 5 do `systemMessage`, when inspecionadas, then cada uma referencia `Buscar_info_setor` com um `setor` literal distinto (`"Consultas"` na Seção 4, `"Vacinas"` na Seção 5) — nunca uma chamada fundindo os dois.
- Given os textos de apontamento "fase seguinte ainda não construída", when inspecionados após a mudança, then citam só Exames e Orçamentos como pendentes — Consultas/Vacinas não aparecem mais nessa lista.
- Given a Seção 4 (Consultas), when o cliente não sabe a especialidade, then o texto instrui coletar queixa em vez de forçar escolha de catálogo — sem acionar `Escalar_humano` só por isso.

## Review Triage Log

### 2026-09-03 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 1 (medium 1medium)
- defer: 0
- reject: 12
- addressed_findings:
  - `medium` `patch` As Seções 4.2 (Consultas) e 5.2 (Vacinas) do `systemMessage` só cobriam "cliente não sabe" ou "catálogo vazio" como gatilho para coletar queixa/registrar preferência em texto — não havia instrução para quando o cliente cita uma especialidade/vacina específica que não corresponde a nenhum item do `catalogo_servicos` retornado (não vazio, sem match), achado convergente de dois revisores independentes (blind-hunter e edge-case-hunter). Corrigido ampliando o gatilho existente em ambas as seções para incluir explicitamente esse caso ("ou se a especialidade/vacina citada pelo cliente não corresponder a nenhum item da lista retornada"), reutilizando o mesmo padrão "não force, não invente" já presente nas duas seções — sem introduzir o enquadramento de "pedido não agendável" da Seção 3.5 (Care Center), que o próprio Intent exclui explicitamente para Consultas.

## Design Notes

O ramo de queixa em Consultas não é um "pedido adicional não agendável" (linguagem do Care Center 3.5) — é o caminho normal de quem já foi classificado em Consultas sem especialidade clara, cujo direcionamento padrão ao clínico geral já foi decidido na Triagem (Seção 2.1/Story 6); esta seção só coleta o dado de suporte (queixa), nunca re-decide a classificação. Um profissional que atende os dois setores (`atendimento_profissionais.setores` array) aparece nos dois retornos de `Buscar_info_setor` sem nenhuma lógica extra — o filtro `p_setor = ANY(setores)` já resolvido desde a Story migration 0008 cobre isso.

## Verification

**Commands:**
- `python3 -c "import json; d = json.load(open('n8n/workflows/01 - Agente.json')); agent = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.agent'][0]; sm = agent['parameters']['options']['systemMessage']; order = ['1. Abertura', '2. Triagem e Direcionamento', '3. Fluxo Care Center', '4. Fluxo Consultas', '5. Fluxo Vacinas']; idxs = [sm.index(s) for s in order]; assert idxs == sorted(idxs); tools = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.toolWorkflow']; names = {t['name'] for t in tools}; assert names == {'Escalar Humano', 'Buscar Info Setor'}; ai_tool_sources = {src for src, out in d['connections'].items() if any(c['node'] == 'Agente Nouvet' for group in out.get('ai_tool', []) for c in group)}; assert ai_tool_sources == {'Refletir', 'Escalar Humano', 'Buscar Info Setor'}; s4 = sm[sm.index('4. Fluxo Consultas'):sm.index('5. Fluxo Vacinas')]; s5 = sm[sm.index('5. Fluxo Vacinas'):]; assert 'Buscar_info_setor' in s4 and 'setor=\"Consultas\"' in s4; assert 'Buscar_info_setor' in s5 and 'setor=\"Vacinas\"' in s5; assert 'queixa' in s4.lower(); assert 'Consultas, Vacinas, Exames, Orçamentos' not in sm; print('OK')"` -- expected: `OK`.

**Manual checks (if no CLI):**
- Na VPS de dev: com `01 - Agente.json` já importado (tool `Buscar Info Setor` relinkada desde a Story 7), testar os 5 cenários da I/O Matrix com um telefone de teste classificado em Consultas e outro em Vacinas.

## Auto Run Result

Status: done

**Summary:** Story 8 (CAP-4 — Fluxo Consultas e Vacinas) implementada e revisada via `bmad-build-auto`. Acrescentadas as seções "4. Fluxo Consultas" e "5. Fluxo Vacinas" ao `<sop>` de `01 - Agente.json`, cada uma chamando `Buscar_info_setor` com um `setor` literal distinto (`"Consultas"` / `"Vacinas"`, nunca fundido), reutilizando sem alteração de topologia a mesma ferramenta genérica entregue pela Story 7. Consultas ganhou o ramo extra de queixa (UJ-2) quando o cliente não sabe a especialidade. Os 4 apontamentos "fase seguinte ainda não construída" foram atualizados para citar só Exames/Orçamentos como pendentes.

**Files changed:**
- `n8n/workflows/01 - Agente.json` — nó `Agente Nouvet`: acrescenta SOP §4 (Consultas) e §5 (Vacinas); atualiza os 4 apontamentos de fase pendente (`<papel>`, SOP §1, SOP §2.2, Validação 8); atualiza `description`/hint `$fromAI` da tool `Buscar_info_setor` para citar os 3 setores ativos; adiciona Validação 12 com os invariantes de Consultas/Vacinas. Nenhum nó novo, nenhuma mudança de `connections`.
- `n8n/workflows/03 - Buscar Info Setor.json` — só o texto do sticky note atualizado para registrar o consumo pela Story 8 (Consultas/Vacinas), sem mudança de `nodes`/`connections`.

**Review findings breakdown:** 1 finding triado `patch` (medium) e corrigido nesta passada; 0 `intent_gap`; 0 `bad_spec`; 0 `defer`; 12 `reject` (ruído ou já corretamente fora de escopo pelo próprio Intent — ver Review Triage Log). O patch aplicado ampliou o gatilho de fallback das Seções 4.2/5.2 para cobrir também o caso de especialidade/vacina citada pelo cliente sem correspondência no catálogo retornado (catálogo não vazio, sem match) — gap convergente entre 2 revisores independentes, ausente do texto original.

**Follow-up review recommendation:** `false`. Score = 3 × 1 medium + 1 × 0 low = 3 (< 5), nenhum finding `high`.

**Verification performed:** comando de verificação do spec (`## Verification`) executado após a implementação e novamente após o patch — `OK` nas duas vezes (ordem das seções do SOP, conjunto de tools `ai_tool` inalterado, `setor` literal distinto em cada seção nova, "queixa" presente na Seção 4, apontamento fundido antigo removido). Auditoria da I/O & Edge-Case Matrix: as 5 linhas foram conferidas por inspeção estática do `systemMessage` resultante — todas batem com a coluna "Expected Output/Behavior", incluindo a correção aplicada nesta rodada. Checks manuais na VPS de dev (5 cenários com telefone de teste) não foram executados nesta sessão automatizada — seguem pendentes como verificação manual futura, conforme a própria seção `## Verification` do spec já previa.

**Residual risks:** catálogo de Consultas/Vacinas ainda vazio em `n8n/seed/0001_atendimento_config.sql` (dado real pendente do Nouvet, mesma classe do DW-42, corretamente fora de escopo desta story) — os cenários de "especialidade/vacina conhecida" da I/O Matrix só serão exercitáveis fim-a-fim quando esse dado existir. Mensagens que misturam Consultas/Vacinas (ou outro setor) na mesma frase continuam sem tratamento dedicado — gap já conhecido e deliberadamente não resolvido desde a Story 6, não reaberto por esta story. Checks manuais de VPS (5 cenários) seguem pendentes de execução humana.
