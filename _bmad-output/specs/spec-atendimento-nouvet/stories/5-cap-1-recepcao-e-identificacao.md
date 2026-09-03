---
title: 'CAP-1 — Recepção e Identificação'
type: 'feature'
created: '2026-09-03'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: ['oversized']
deferred: []
baseline_revision: '3510dcfa98534f004d2bd38d44a6c956b200428e'
---

<intent-contract>

## Intent

**Problem:** Nenhum workflow n8n hoje recebe mensagem do WhatsApp/RD Conversas nem responde automaticamente — as primitivas Postgres já construídas (config seletiva Story 2, debounce/lock Story 3, identidade Story 4) nunca foram ligadas a uma conversa real, então nenhuma mensagem gera resposta e CAP-1 (Recepção e Identificação) não existe.

**Approach:** Criar `n8n/workflows/01 - Agente.json` (convenção já documentada, orquestração única) cobrindo só a fase de Recepção/Identificação: webhook RD Conversas → enfileirar+travar (Story 3, TTL de `atendimento_config_ler`) → esperar/reconsultar/agregar → resolver identidade (Story 4) → nó agente LangChain cujo `systemMessage` é remontado a cada turno pela fatia `triagem` de `atendimento_config_ler` (Story 2), organizado no esqueleto de seções do `01 - Secretária V3.json` (molde organizacional, conteúdo reescrito do zero) com uma seção nova de Sinais de Alerta/Emergência logo no topo → resposta enviada via RD Conversas → destravar.

## Boundaries & Constraints

**Always:** `systemMessage` nunca hardcoded — remontado a cada execução a partir de `atendimento_config_ler('triagem')` + identidade resolvida (AD-1), nunca cacheado. Ordem fixa das seções: Papel → Personalidade/Tom → **Sinais de Alerta e Emergência Declarada** (logo no topo, prioridade máxima — nunca dentro de Casos Especiais, é o guardrail de segurança nº1) → Contexto (fatia `triagem`) → SOP (um único fluxo numerado: Abertura/Identificação/Descoberta de intenção) → Ferramentas Disponíveis (formato id/uso/parâmetros/quando) → Validações → Exemplos de Fluxo (grounded em `user-journeys.md` UJ-1/UJ-2/UJ-4) → Casos Especiais → Observações Finais → Informações do Sistema. Identidade sempre resolvida ANTES do turno do agente via `identidade_cliente_pet_buscar(telefone_normalizar(telefone))` (Story 4) — o agente nunca pergunta "você tem cadastro?"; telefone reconhecido personaliza com nome/pet já conhecidos sem repetir pergunta já respondida; telefone não reconhecido segue fluxo de cliente novo sem travar a conversa. Ingresso reusa `lock_conversa_adquirir`/`lock_conversa_liberar` e dedup `n8n_fila_mensagens` (`ON CONFLICT (id_mensagem) DO NOTHING`, Story 3) — nunca reimplementa lock/dedup inline; lock permanece travado até a resposta ser enviada (AD-7). `lock_ttl_minutos` só vem de `atendimento_config_ler` (nunca hardcoded) — a função é estendida para expor esse campo nas duas fatias (`triagem`/`setor`), fechando DW-26 sem criar coluna nova (o dado já existe em `atendimento_config`). Agente nunca oferece convênio proativamente (instrução explícita no `systemMessage`) e sempre se identifica como atendente virtual. Resposta enviada via RD Conversas `POST /v2/messages/{contact_id}/send`, form-urlencoded, `sent_by=bot` (AD-7). Nenhuma credencial embutida no JSON exportado (AD-2) — só referência por nome/id de credential do n8n.

**Block If:** Nenhuma decisão bloqueante identificada — nomes/posições exatos de nó ficam a critério de quem implementa. O schema exato do payload do webhook de mensagem recebida do RD Conversas não é documentado como contrato formal em `rd-station-api` (só o formato de *envio* é); a extração de `contact_id`/telefone/texto desse payload fica a critério de quem implementar, mapeada num node `Set` logo após o webhook — validar contra o payload real na VPS de dev antes do go-live (mesmo tratamento de dado externo ainda não confirmado já usado nas Stories 1-4).

**Never:** Não inclui classificação de setor nem qualquer branch de SOP por setor (Care Center/Consultas/Vacinas/Exames/Orçamentos) — isso é CAP-2 (Story 6, que estende este mesmo `systemMessage` com a triagem/direcionamento) e CAP-3–6 (Stories 7-10); o SOP desta story tem exatamente um fluxo numerado (identificação/descoberta de intenção inicial), que termina apontando para a triagem como próximo passo, não implementando-a. Não inclui a ferramenta `Escalar_humano` nem qualquer tool-workflow de handoff — isso é Story 6/CAP-2 e Story 14/CAP-12; a seção de Sinais de Alerta já instrui textualmente prioridade máxima (nunca diagnosticar, nunca minimizar, nunca continuar a coleta normal), mas sem mecanismo de ação ainda ligado ao agente — comportamento aceito e documentado (mesmo padrão de "contrato antes do consumidor" das Stories 2-4), não um bug. Não inclui nenhuma tool de agenda, leitura ou escrita (AD-4), nem cobrança/Asaas (fora do Piloto). Não inclui pacing de texto separado — RD Conversas não suporta indicador de digitação nem envio pausado nativo (confirmado em `rd-station-api`). Não inclui criação/atualização de contato ou card no RD CRM (Story 11/CAP-7) nem criação de contato no RD Conversas (assume que o contato já existe no Conversas, pois foi ele quem gerou o webhook).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Telefone reconhecido | `identidade_cliente_pet_buscar` retorna cliente+pet | Agente personaliza a saudação com nome do cliente/pet já conhecidos, pergunta o que precisa hoje sem presumir com base no atendimento anterior | Nenhum erro |
| Telefone novo | `identidade_cliente_pet_buscar` retorna vazio/NULL | Agente segue fluxo de cliente novo (pergunta o que precisa) sem exigir cadastro explícito nem travar | Nenhum erro |
| Sinal de Alerta logo no início | Cliente relata sintoma da lista `sinais_alerta_clinico` antes de qualquer setor classificado | Agente interrompe a coleta normal, reconhece a gravidade sem diagnosticar/minimizar, comunica prioridade — sem ainda acionar handoff automático (tool de Story 6, fora de escopo aqui) | Comportamento aceito, documentado no Boundaries |
| Mensagens picadas (2+ seguidas) | Cliente manda várias mensagens em sequência | Debounce agrega tudo numa resposta só (Story 3) | Nenhum erro |
| Fora do horário comercial | Mensagem chega à noite/fim de semana | Resposta automática inicial ocorre do mesmo jeito (24/7) | Nenhum erro |

</intent-contract>

## Code Map

- `n8n/workflows/README.md` -- já define a convenção `01 - Agente.json` (orquestração única, Recepcionista IA/Agente de Setor mesmo nó) -- este arquivo é a entrega principal desta story.
- `_bmad-output/reference/modelo-n8n/secretariav3-completo/01 - Secretária V3.json` -- nó `Secretária v3` (`@n8n/n8n-nodes-langchain.agent`), campo `parameters.options.systemMessage` -- ESQUELETO de seções (Papel/Personalidade/Contexto/SOP/Ferramentas/Validações/Exemplos/Casos Especiais/Observações Finais/Info Sistema) a seguir como molde organizacional; conteúdo reescrito do zero, nunca copiado (não tem fluxo de agenda/cobrança/pacing).
- `.claude/skills/n8n-agent-patterns/references/agente-e-subfluxos.md` -- padrão de ingresso (webhook → fila → lock → wait → reconsulta → agrega); usar como referência de topologia, mas o lock chama as funções atômicas da Story 3, não o `SELECT`+`UPDATE` genérico ali descrito.
- `.claude/skills/n8n-agent-patterns/references/config-postgres.md` -- padrão de leitura em runtime (`Buscar Config` + `Set "Info"`); adaptar para chamar `atendimento_config_ler('triagem')` em vez de `SELECT *`.
- `.claude/skills/rd-station-api/references/conversas.md` -- `POST /v2/messages/{contact_id}/send` (form-urlencoded, `message`/`sent_by`); webhook de entrada configurado no painel Tallos, sem schema REST documentado (ver Block If).
- `n8n/migrations/0008_atendimento_profissionais.sql` -- corpo atual de `atendimento_config_ler` (fatias `triagem`/`setor`, sem `lock_ttl_minutos`) -- a `0010` estende via `CREATE OR REPLACE FUNCTION` preservando `REVOKE`/`GRANT` já existentes.
- `n8n/migrations/0005_debounce_lock_ttl.sql` -- `lock_conversa_adquirir(p_session_id, p_ttl_minutos)`/`lock_conversa_liberar(p_session_id)` -- chamar via node Postgres, nunca reimplementar.
- `n8n/migrations/0006_identidade_porta_unica.sql` -- `telefone_normalizar(TEXT)`/`identidade_cliente_pet_buscar(TEXT)` -- chamar via node Postgres.
- `n8n/seed/0001_atendimento_config.sql` -- conteúdo real hoje (`tom_voz`, `sinais_alerta_clinico=["Vômito por 3 dias seguidos ou mais"]`, `sla_resposta_minutos`/`lock_ttl_minutos=5`) -- grounding do `systemMessage`/Exemplos.
- `user-journeys.md` UJ-1/UJ-2/UJ-4, `glossary.md` -- fonte dos Exemplos de Fluxo e termos verbatim.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- `DW-26` a marcar `resolved`.

## Tasks & Acceptance

**Execution:**
- `n8n/migrations/0010_atendimento_config_ler_lock_ttl.sql` -- `CREATE OR REPLACE FUNCTION atendimento_config_ler` incluindo `lock_ttl_minutos` nas fatias `triagem` e `setor` (mesma classe de campo operacional que `sla_resposta_minutos`, já presente nas duas) -- fecha DW-26.
- `n8n/workflows/01 - Agente.json` -- criar o workflow: webhook (RD Conversas) → enfileirar mensagem (dedup) → `atendimento_config_ler('triagem')` (obtém `lock_ttl_minutos`) → `lock_conversa_adquirir` → espera+reconsulta+agrega (Story 3) → `telefone_normalizar`+`identidade_cliente_pet_buscar` (Story 4) → Set "Info" → nó agente (`memoryPostgresChat` em `n8n_historico_mensagens` por `session_id`, `systemMessage` no molde acima) → enviar resposta (RD Conversas) → `lock_conversa_liberar` -- implementa CAP-1.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- marcar `DW-26` como `status: resolved`, referenciando `0010`.

**Acceptance Criteria:**
- Given os 5 cenários da I/O & Edge-Case Matrix, when reproduzidos contra o `systemMessage`/topologia do workflow (inspeção estática, sem n8n disponível neste ambiente de build), then o comportamento bate com a coluna "Expected Output/Behavior".
- Given `n8n/workflows/01 - Agente.json`, when inspecionado, then é um JSON de export de workflow n8n válido (chaves `nodes`/`connections`) sem nenhuma credencial em texto — só referência por nome/id de credential.
- Given o `systemMessage` do nó de agente, when se inspeciona a ordem das seções, then aparecem exatamente na ordem: Papel, Personalidade/Tom, Sinais de Alerta e Emergência Declarada, Contexto, SOP, Ferramentas Disponíveis, Validações, Exemplos de Fluxo, Casos Especiais, Observações Finais, Informações do Sistema.
- Given o `systemMessage`, when se inspeciona seu conteúdo, then nenhum dado de negócio (nome/tom/sinais de alerta) aparece como texto fixo — só expressões que puxam do node de config — e nunca menciona convênio como oferta proativa.
- Given as ferramentas conectadas ao nó de agente, when inspecionadas, then nenhuma tool de agenda (buscar/criar/atualizar/cancelar evento) nem `Escalar_humano` está presente.
- Given `atendimento_config_ler('triagem')` e `atendimento_config_ler('setor', 'Care Center')` (0010), when chamadas, then o JSON retornado inclui `lock_ttl_minutos`.
- Given o node de lock no workflow, when se inspeciona a expressão do parâmetro de TTL, then referencia o campo `lock_ttl_minutos` lido de `atendimento_config_ler`, nunca um literal numérico.
- Given o ledger `deferred-work.md`, when esta story termina, then `DW-26` aparece com `status: resolved`.

## Design Notes

`atendimento_config_ler` ganha `lock_ttl_minutos` nas duas fatias (não só uma) porque é valor operacional transversal à fase, mesmo tratamento já dado a `sla_resposta_minutos`. Sequência de leitura no workflow: como o lock precisa do TTL antes de qualquer classificação de setor, a chamada a `atendimento_config_ler('triagem')` acontece uma vez, logo no início (antes do lock), e o mesmo resultado é reaproveitado depois para montar o `systemMessage` — não há necessidade de uma segunda leitura nesta story, já que ela nunca opera em fase `setor`. Exemplo de expressão de leitura no `systemMessage` (mesmo padrão do node `Info` da referência, trocando `SELECT *` por `atendimento_config_ler`):

```
{{ $('Buscar Config').item.json.tom_voz }}
{{ $('Buscar Config').item.json.sinais_alerta_clinico }}
```

O SOP desta story tem só a seção "1. Abertura, Identificação e Descoberta de Intenção" — a Story 6 (CAP-2) estende o mesmo arquivo/`systemMessage` acrescentando a seção "2. Triagem e Direcionamento" com o branch por setor, não recria o workflow do zero.

## Verification

**Commands:**
- `python3 -c "import json; d = json.load(open('n8n/workflows/01 - Agente.json')); assert 'nodes' in d and 'connections' in d; agent = [n for n in d['nodes'] if n.get('type') == '@n8n/n8n-nodes-langchain.agent']; assert len(agent) == 1; sm = agent[0]['parameters']['options']['systemMessage']; import re; content = json.dumps(d); assert not re.search(r'(Bearer |api[_-]?key|senha\\s*[:=])', content, re.I); print('OK')"` -- expected: `OK` (workflow válido, exatamente um nó de agente, nenhum segredo em texto plano).
- `python3 -c "content = open('n8n/migrations/0010_atendimento_config_ler_lock_ttl.sql').read(); up = content.upper(); assert 'CREATE OR REPLACE FUNCTION ATENDIMENTO_CONFIG_LER' in up; assert up.count('LOCK_TTL_MINUTOS') >= 2; print('OK')"` -- expected: `OK` (campo exposto nas duas fatias).
- Checagem estrutural da ordem das seções do `systemMessage` (mesma técnica de `find`/índice já usada nas Stories 2-4): localizar os cabeçalhos de cada seção e confirmar `Papel < Personalidade < Sinais de Alerta < Contexto < SOP < Ferramentas < Validações < Exemplos < Casos Especiais < Observações Finais < Informações do Sistema`.
- `python3 -c "content = open('_bmad-output/implementation-artifacts/deferred-work.md').read(); import re; assert re.search(r'DW-26:.*?\nstatus: resolved', content, re.S); print('OK')"` -- expected: `OK`.

**Manual checks (if no CLI):**
- Na VPS de dev (n8n/Docker disponível): importar `01 - Agente.json`, configurar o webhook real do painel Tallos, mandar uma mensagem de telefone conhecido e outro desconhecido, confirmar personalização/fluxo de cliente novo e que o lock destrava após a resposta.
- Confirmar o schema real do payload do webhook do RD Conversas contra a implementação do node `Set` pós-webhook (ver Block If) antes do go-live.

## Auto Run Result

Status: `done`
Blocking condition: nenhuma.

**Nota de recuperação manual (03/set/2026):** a sessão de implementação (`5-dev-2`) estourou o orçamento de tokens da story e foi encerrada por timeout antes de reescrever esta seção — o conteúdo acima (Code Map, Tasks & Acceptance, Design Notes, Verification) já refletia o trabalho concluído, só este resumo final ficou desatualizado (ainda descrevia a passada de planejamento). Arquivo recuperado de `.bmad-loop/runs/20260902-234559-8ae7/deferred/5/`. As 2 verificações Python da seção `## Verification` foram reexecutadas contra os artefatos reais (`n8n/workflows/01 - Agente.json`, `n8n/migrations/0010_atendimento_config_ler_lock_ttl.sql`) e passaram; o guardrail de convênio (nunca ofereça proativamente) foi conferido manualmente no texto do `systemMessage` — correto. Thiago aceitou o resultado sem rodar uma passada de review formal adicional.

**Resumo:** Dispatch pasta+id para a Story 5 (`CAP-1 — Recepção e Identificação`), primeiro despacho para este id (nenhum arquivo prévio em `stories/5-*.md`). Investigação cobriu `SPEC.md`, `user-journeys.md`, `glossary.md`, `ARCHITECTURE-SPINE.md`, as 4 stories anteriores (Code Map/Design Notes/deferred), o estado real do schema pós-`correct-course` (`0007`-`0009`, seed atual), o molde de referência (`01 - Secretária V3.json`) e as skills `n8n-agent-patterns`/`rd-station-api`. Spec escrito e verificado contra o padrão READY FOR DEVELOPMENT (actionable/logical/testable/surface-anchored/complete/sufficient/coherent) — nenhum gap de intenção encontrado; nenhuma ambiguidade exigiu HALT por `intent gap`.

**Decisões de escopo tomadas nesta passada (registradas no spec, não fantasiadas):** (1) Story 5 entrega só a fase de Recepção/Identificação (fluxo único, pré-triagem) — classificação de setor e a ferramenta `Escalar_humano` ficam para a Story 6 (CAP-2), que estende o mesmo `01 - Agente.json`/`systemMessage`; (2) a seção de Sinais de Alerta/Emergência Declarada entra já nesta story, perto do topo do `systemMessage`, como instrução textual de prioridade máxima, mesmo sem o mecanismo de handoff ainda ligado (contrato antes do consumidor, mesmo padrão das Stories 2-4); (3) `atendimento_config_ler` é estendida (migration `0010`) para expor `lock_ttl_minutos`, fechando `DW-26`, sem criar coluna nova; (4) o schema exato do payload do webhook de entrada do RD Conversas (não documentado como contrato formal na skill `rd-station-api`) é tratado como decisão de implementação a validar contra o payload real na VPS de dev antes do go-live, não como bloqueio.

**Riscos residuais explícitos:** primeira story do projeto que entrega um workflow n8n real (as Stories 1-4 eram só Postgres) — toda verificação prevista é estática (JSON/regex), já que Docker/n8n seguem indisponíveis neste ambiente de build; validação end-to-end fica para a VPS de dev, mesma limitação documentada nas Stories 1-4.

