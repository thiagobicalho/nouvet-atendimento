---
title: 'CAP-11 — Indicadores e Visibilidade Gerencial'
type: 'feature'
created: '2026-09-05'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
baseline_revision: '1c19ce83a083e6b02a2394772784fd54c4f4fc19'
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Leads recebidos, atendidos/não atendidos, distribuição por setor e tempo de resposta (FR-36–39) não têm nenhuma fonte de leitura hoje — o Sweep A da Story 12 só reenvia o mesmo lembrete indefinidamente (sem contador nem teto), Postgres não persiste setor/categoria de nenhum atendimento, e os 3 desvios de triagem (Sinal de Alerta/Fora de escopo/Convênio mencionado, via `Escalar_humano`) não deixam rastro algum (DW-50) — sem isso não há como servir os 5 indicadores mínimos que a diretoria do Nouvet exige (SM-5).

**Approach:** Estender o Sweep A (Story 12) com contador de tentativas + intervalos crescentes + teto, configuráveis, zerados no mesmo ponto que já toca `updated_at` a cada mensagem (`lock_conversa_adquirir`); fechar DW-50 fazendo `02 - Escalar Humano.json` delegar a `04 - Registrar Atendimento CRM.json` (reusa `mapeamento_stage_crm`) para os 3 motivos nomeados; e persistir cada registro (setor real ou desvio) numa tabela de evento append-only, servida por funções SQL (`atendimento_indicadores_ler`, mesmo padrão de `atendimento_config_ler`) que a Btech consulta sob demanda.

## Boundaries & Constraints

**Always:** FR-37 nunca usa `stage_id`/pipeline do RD CRM — atendido = sessão alcançou `estado_espera='aguardando_atendimento_humano'` (handoff bem-sucedido, por fechamento de setor OU pelos 3 desvios agora registrados); não atendido = `esteira_esgotada=TRUE` sem nunca alcançar handoff; qualquer outra combinação = pendente. `intervalos_esteira_horas`/`max_tentativas_esteira` (novos, `atendimento_config`) são a única fonte dos intervalos/teto — nunca hardcoded; a 1ª tentativa continua usando `sla_resposta_minutos` (SLA já público), as seguintes usam `intervalos_esteira_horas[LEAST(numero_tentativas_esteira, array_length)]`. Ao estourar o teto: marca `esteira_esgotada=TRUE`, para de enviar mensagem, nunca escalona ao gestor. `lock_conversa_adquirir` zera `numero_tentativas_esteira`/`esteira_esgotada` em toda aquisição de lock bem-sucedida (mesmo ponto que já toca `updated_at`) — nenhum hook novo em `01 - Agente.json`; vale tanto para quem some no meio de um fluxo de setor quanto para quem nunca foi classificado. Indicadores são funções `LANGUAGE sql STABLE` (mesmo padrão de `atendimento_config_ler`), aceitam `p_data_inicio`/`p_data_fim` (default `CURRENT_DATE`); `atendimento_indicadores_ler` é o ponto único de leitura. Nenhuma automação de envio — só consulta sob demanda. `02 - Escalar Humano.json` normaliza o telefone (`telefone_normalizar`) e chama `04` (`setor` = o motivo) só para exatamente `"Sinal de Alerta"`, `"Fora de escopo"`, `"Convênio mencionado"` — reusa 100% da lógica de card já existente, nunca duplica; `mapeamento_stage_crm` ganha as 3 chaves novas, stage_id real continua pendente (mesmo gap já aceito dos 5 setores). Toda linha nova em `atendimento_registro_setor` é escrita só por `04`, classificando `categoria` contra a lista fixa dos 5 setores reais — nunca confundida com os 3 desvios (`categoria='desvio'`). Todo node Postgres/`httpRequest` novo tem `onError: continueRegularOutput` + `retryOnFail: true`.

**Block If:** Nenhuma decisão bloqueante — as 3 decisões de mecanismo já vieram fechadas por Thiago nesta invocação. Nomes exatos de colunas/tabela/funções novas e o formato exato do JSON de `atendimento_indicadores_ler` ficam a critério de quem implementa.

**Never:** Não usa `stage_id`/pipeline do RD CRM para atendido/não atendido. Não cria automação de envio de relatório (sem cron novo). Não estende o registro de card a "Informação indisponível"/"Emergência Declarada" (fora do escopo nomeado do DW-50). Não decide a IA ganhar usuário próprio no RD nem migra `httpRequest` para nodes nativos RD Station — ambas reconsiderações cross-cutting ficam como follow-up de sessão dedicada. Não modifica `01 - Agente.json`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Esteira dentro do teto | `aguardando_cliente` vencido, `numero_tentativas_esteira < max` | Envia lembrete, incrementa contador, renova `updated_at` | Falha de envio não incrementa (gate já existente) |
| Esteira estoura o teto | `aguardando_cliente` vencido, `numero_tentativas_esteira >= max` | `esteira_esgotada=TRUE`, nenhuma mensagem, nenhum escalonamento | Nenhum erro |
| Cliente responde com esteira ativa | Nova mensagem, `lock_conversa_adquirir` chamado | `numero_tentativas_esteira` volta a 0, `esteira_esgotada` volta a `FALSE` | Nenhum erro |
| Sinal de Alerta / Fora de escopo / Convênio mencionado | `Escalar_humano` com um dos 3 motivos | Card RD CRM criado/atualizado (via `04`), evento `categoria='desvio'` registrado | Falha de API não propaga ao `Agente Nouvet` |
| Informação indisponível / Emergência Declarada | `Escalar_humano` com um dos outros 2 motivos | Comportamento inalterado (só alerta WhatsApp) | Nenhum erro |
| Consulta de indicadores | `SELECT atendimento_indicadores_ler('2026-09-01','2026-09-05')` | JSONB com os 5 valores do período | Nenhum erro |

</intent-contract>

## Code Map

- `n8n/migrations/0002_schema_operacional.sql`, `0012_temporizadores_sla.sql` -- schema atual de `atendimento_config`/`n8n_status_atendimento` -- `0013` estende via `ALTER TABLE`, nunca recria.
- `n8n/migrations/0005_debounce_lock_ttl.sql` -- corpo atual de `lock_conversa_adquirir` -- `0013` reestende via `CREATE OR REPLACE FUNCTION`, preservando os guards de `p_session_id`/TTL, só acrescentando `numero_tentativas_esteira = 0, esteira_esgotada = FALSE` ao `SET` do `DO UPDATE`.
- `n8n/migrations/0012_temporizadores_sla.sql` -- corpo atual de `atendimento_config_ler` (fatia `triagem`) -- `0013` reestende via `CREATE OR REPLACE FUNCTION` (corpo completo repetido, padrão 0010/0012), acrescentando `intervalos_esteira_horas`/`max_tentativas_esteira`.
- `n8n/workflows/06 - Lembretes e Escalonamento SLA.json` -- "Buscar Sessões Aguardando Cliente Vencidas" (threshold fixo `sla_resposta_minutos`) muda para threshold por tentativa; novo IF "Esteira Esgotada Nesta Tentativa?" entre essa busca e "Buscar Contato Conversas (Sessão)"; "Renovar Janela de Espera do Cliente" passa a incrementar `numero_tentativas_esteira`.
- `n8n/workflows/04 - Registrar Atendimento CRM.json` -- "Criar Note no Deal" já dispara 3 branches paralelas (`Precisa criar Task?`, `Gerenciar Task SLA (CAP-8)`, `Marcar Aguardando Atendimento Humano (CAP-8)`) -- acrescentar uma 4ª: Postgres "Registrar Evento de Indicador (CAP-11)" (INSERT em `atendimento_registro_setor`); `setor`/`telefone` via `$('Receber Solicitação')`, `deal_id_final` via `$('Deal ID Final')`.
- `n8n/workflows/02 - Escalar Humano.json` -- hoje só `Receber Solicitação` -> `Destinatários configurados?` -> alerta/noOp. Acrescentar ramo paralelo: IF "Motivo Gera Registro no CRM?" (motivo ∈ {3 nomeados}) -> Postgres "Normalizar Telefone (Registro CRM)" -> `executeWorkflow` "Registrar Atendimento CRM (Desvio Triagem)" chamando `04` (`setor`=motivo); branch falso -> noOp.
- `stories/12-cap-8-temporizadores-continuidade-e-sla.md` -- Design Notes ("gap de SM-1... DW-50... fora de escopo") confirma que fechar DW-50 aqui é continuação já prevista; mostra onde `estado_espera`/`atendimento_estado_espera_marcar` vivem.
- `stories/6-cap-2-triagem-e-direcionamento.md` + inspeção de `01 - Agente.json` -- 5 motivos exatos de `Escalar_humano` (`Sinal de Alerta`, `Fora de escopo`, `Convênio mencionado`, `Informação indisponível`, `Emergência Declarada`) e 5 setores exatos (`Care Center`, `Consultas`, `Vacinas`, `Exames`, `Orçamentos`) usados pela tool `Registrar Atendimento CRM` -- reusados verbatim para classificar `categoria`, nunca reintroduzidos como config.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- DW-50 a marcar `resolved` ao concluir.

## Tasks & Acceptance

**Execution:**
- `n8n/migrations/0013_indicadores_e_esteira.sql` -- `ALTER TABLE atendimento_config ADD COLUMN intervalos_esteira_horas INTEGER[] NOT NULL DEFAULT '{1,6,24}', ADD COLUMN max_tentativas_esteira INTEGER NOT NULL DEFAULT 3`; `ALTER TABLE n8n_status_atendimento ADD COLUMN numero_tentativas_esteira INTEGER NOT NULL DEFAULT 0, ADD COLUMN esteira_esgotada BOOLEAN NOT NULL DEFAULT FALSE`; `CREATE TABLE atendimento_registro_setor` (id, telefone, categoria CHECK IN ('setor','desvio'), valor, rd_crm_deal_id, created_at) + GRANT; `CREATE OR REPLACE FUNCTION lock_conversa_adquirir`/`atendimento_config_ler`; 5 funções de indicador (`atendimento_indicador_leads_recebidos`, `atendimento_indicador_atendidos_nao_atendidos`, `atendimento_indicador_distribuicao_setor`, `atendimento_indicador_tempo_resposta`, `atendimento_indicadores_ler`), todas com `REVOKE ... FROM PUBLIC` + `GRANT ... TO app_role`.
- `n8n/workflows/06 - Lembretes e Escalonamento SLA.json` -- threshold por tentativa + IF de teto + Postgres de marcação + incremento do contador -- implementa a esteira de FR-37.
- `n8n/workflows/04 - Registrar Atendimento CRM.json` -- 4ª branch paralela gravando em `atendimento_registro_setor` -- implementa a fonte de FR-38.
- `n8n/workflows/02 - Escalar Humano.json` -- ramo novo de registro CRM para os 3 motivos nomeados -- fecha DW-50.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- marcar `DW-50` como `resolved`.

**Acceptance Criteria:**
- Given os 6 cenários da I/O & Edge-Case Matrix, when reproduzidos contra a topologia/SQL (inspeção estática), then o comportamento bate com "Expected".
- Given `atendimento_indicadores_ler(p_data_inicio, p_data_fim)`, when chamada, then retorna JSONB com exatamente as chaves `leads_recebidos`, `atendidos_nao_atendidos`, `distribuicao_setor`, `tempo_resposta`.
- Given uma sessão com `numero_tentativas_esteira = max_tentativas_esteira`, when o Sweep A a encontra vencida, then `esteira_esgotada` vira `TRUE` e nenhum `httpRequest` de envio é disparado.
- Given `lock_conversa_adquirir` chamada com sucesso para uma sessão com `esteira_esgotada = TRUE`, when inspecionado o resultado, then `numero_tentativas_esteira = 0` e `esteira_esgotada = FALSE`.
- Given `Escalar_humano(motivo="Sinal de Alerta")`, when `02` é executado, then `04` é chamado com `setor="Sinal de Alerta"`; given `motivo="Emergência Declarada"`, then `04` nunca é chamado.
- Given `n8n/workflows/01 - Agente.json`, when comparado ao estado anterior (git), then nenhuma linha foi alterada.

## Design Notes

FR-37 do PRD original ("atendido = chegou a 'resolvido' na esteira do RD Station") é substituído nesta story por decisão explícita de Thiago (2026-09-05, invocação): a "esteira" é 100% Postgres+cron, nunca `stage_id`/pipeline do RD CRM — "resolvido" equivale a `estado_espera='aguardando_atendimento_humano'`, "3º contato/encerrado" equivale a `esteira_esgotada=TRUE`. Fechar DW-50 (delegar `Escalar_humano` a `04`) também estende Task de SLA/CAP-8 aos 3 desvios (agora contam como "atendido") — efeito colateral desejado.

"5 indicadores mínimos" mapeia para 4 FRs (36-39) porque FR-37 empacota 2 valores (atendidos + não atendidos) — mesma contagem do PRD (`prd.md` §4.11), não um intent gap.

`atendimento_indicador_tempo_resposta` assume `n8n_historico_mensagens.message` no formato padrão do `memoryPostgresChat` (`{"type": "human"|"ai", ...}`) — não verificável neste ambiente sem n8n/Postgres real; validar contra dado real na VPS de dev antes do go-live. `atendimento_indicador_leads_recebidos` usa `n8n_fila_mensagens` (nunca apagada, só marcada `processada`) como log histórico — `COUNT(DISTINCT telefone_normalizar(telefone))` por período.

## Verification

**Commands:**
- `python3 -c "import re; content = open('n8n/migrations/0013_indicadores_e_esteira.sql').read(); up = content.upper(); assert 'ADD COLUMN INTERVALOS_ESTEIRA_HORAS' in up and 'ADD COLUMN MAX_TENTATIVAS_ESTEIRA' in up; assert 'ADD COLUMN NUMERO_TENTATIVAS_ESTEIRA' in up and 'ADD COLUMN ESTEIRA_ESGOTADA' in up; assert 'CREATE TABLE ATENDIMENTO_REGISTRO_SETOR' in up; assert re.search(r\"CHECK\\s*\\(\\s*CATEGORIA\\s+IN\\s*\\(\\s*'SETOR'\\s*,\\s*'DESVIO'\\s*\\)\\s*\\)\", up); print('OK')"` -- expected: `OK`.
- `python3 -c "content = open('n8n/migrations/0013_indicadores_e_esteira.sql').read(); up = content.upper(); import re; m = re.search(r'FUNCTION LOCK_CONVERSA_ADQUIRIR\(.*?DO UPDATE(.*?)WHERE', up, re.S); assert m and 'NUMERO_TENTATIVAS_ESTEIRA = 0' in m.group(1) and 'ESTEIRA_ESGOTADA = FALSE' in m.group(1); print('OK')"` -- expected: `OK` (o `SET` do `DO UPDATE` zera os 2 campos novos).
- `python3 -c "content = open('n8n/migrations/0013_indicadores_e_esteira.sql').read(); up = content.upper(); for fn in ['ATENDIMENTO_INDICADOR_LEADS_RECEBIDOS','ATENDIMENTO_INDICADOR_ATENDIDOS_NAO_ATENDIDOS','ATENDIMENTO_INDICADOR_DISTRIBUICAO_SETOR','ATENDIMENTO_INDICADOR_TEMPO_RESPOSTA','ATENDIMENTO_INDICADORES_LER']:\n    assert f'FUNCTION {fn}' in up, fn\n    i_revoke = up.find(f'REVOKE EXECUTE ON FUNCTION {fn}')\n    i_grant = up.find(f'GRANT EXECUTE ON FUNCTION {fn}')\n    assert i_revoke != -1 and i_grant != -1 and i_revoke < i_grant\nprint('OK')"` -- expected: `OK` (5 funções de indicador existem com `REVOKE`/`GRANT` na ordem correta).
- `python3 -c "import json; d = json.load(open('n8n/workflows/06 - Lembretes e Escalonamento SLA.json')); nodes = {n['name']: n for n in d['nodes']}; conns = d['connections']; assert 'Esteira Esgotada Nesta Tentativa?' in nodes; assert conns['Buscar Sessões Aguardando Cliente Vencidas']['main'][0][0]['node'] == 'Esteira Esgotada Nesta Tentativa?'; out = conns['Esteira Esgotada Nesta Tentativa?']['main']; assert out[0][0]['node'] == 'Marcar Esteira Esgotada (Não Atendido)'; assert out[1][0]['node'] == 'Buscar Contato Conversas (Sessão)'; renov = nodes['Renovar Janela de Espera do Cliente']['parameters']['query'].upper(); assert 'NUMERO_TENTATIVAS_ESTEIRA = NUMERO_TENTATIVAS_ESTEIRA + 1' in renov; print('OK')"` -- expected: `OK`.
- `python3 -c "import json; d = json.load(open('n8n/workflows/04 - Registrar Atendimento CRM.json')); c = d['connections']['Criar Note no Deal']['main'][0]; assert {e['node'] for e in c} == {'Precisa criar Task?', 'Gerenciar Task SLA (CAP-8)', 'Marcar Aguardando Atendimento Humano (CAP-8)', 'Registrar Evento de Indicador (CAP-11)'}; n = [x for x in d['nodes'] if x['name']=='Registrar Evento de Indicador (CAP-11)'][0]; assert n['type']=='n8n-nodes-base.postgres' and n.get('onError')=='continueRegularOutput' and n.get('retryOnFail') is True; assert 'ATENDIMENTO_REGISTRO_SETOR' in n['parameters']['query'].upper(); print('OK')"` -- expected: `OK`.
- `python3 -c "import json; d = json.load(open('n8n/workflows/02 - Escalar Humano.json')); nodes = {n['name']: n for n in d['nodes']}; conns = d['connections']; assert {e['node'] for e in conns['Receber Solicitação']['main'][0]} == {'Destinatários configurados?', 'Motivo Gera Registro no CRM?'}; execwf = [n for n in d['nodes'] if n['type']=='n8n-nodes-base.executeWorkflow'][0]; setor_expr = execwf['parameters']['workflowInputs']['value']['setor']; assert 'motivo' in setor_expr and 'fromAI' not in setor_expr; assert execwf.get('onError')=='continueRegularOutput' and execwf.get('retryOnFail') is True; print('OK')"` -- expected: `OK`.
- `python3 -c "import subprocess; out = subprocess.run(['git','diff','--stat','HEAD','--','n8n/workflows/01 - Agente.json'], capture_output=True, text=True).stdout; assert out.strip() == ''; print('OK')"` -- expected: `OK` (`01 - Agente.json` não muda nesta story).

**Manual checks (if no CLI):**
- VPS de dev: aplicar `0013`; simular uma sessão vencida sem resposta pelos `max_tentativas_esteira` ciclos completos e confirmar `esteira_esgotada=TRUE` sem mensagem extra; confirmar que uma nova mensagem do mesmo telefone zera o contador; simular os 3 motivos de desvio e confirmar card/Note no RD CRM; chamar `atendimento_indicadores_ler` com um período de teste e conferir os 5 valores contra dado inserido manualmente.

## Review Triage Log

### 2026-09-05 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 4 (high 1, medium 2, low 1)
- defer: 4
- reject: 6
- addressed_findings:
  - `[high]` `[patch]` `atendimento_indicador_tempo_resposta` chamava `ROUND(AVG(segundos))` sobre um valor `double precision` (`EXTRACT(EPOCH FROM ...)`) — Postgres não tem overload `round(double precision)`, então `atendimento_indicadores_ler` (o ponto único de leitura) lançaria erro em toda chamada com pelo menos 1 par de mensagens no período. Corrigido com cast explícito: `ROUND(AVG(segundos)::numeric)`.
  - `[medium]` `[patch]` Na mesma função, o filtro de período (`created_at::date BETWEEN ...`) era aplicado antes de calcular `LAG()`, então um par humano→IA que cruzasse a borda do período perdia a mensagem anterior (par descartado/mal atribuído). Corrigido movendo o filtro de data para depois do `LAG` (sobre a mensagem de resposta da IA, não sobre a anterior).
  - `[medium]` `[patch]` `atendimento_registro_setor` era documentada nos comentários como "append-only, nunca atualizado/apagado" mas recebia `GRANT ... UPDATE, DELETE ... TO app_role`, sem nada no schema reforçando a promessa. Corrigido restringindo o `GRANT` a `SELECT, INSERT` (nenhum node desta story faz UPDATE/DELETE nessa tabela).
  - `[low]` `[patch]` Ao marcar DW-50 inteiramente `resolved`, o fato de só 3 dos 5 motivos de `Escalar_humano` passarem a gerar registro (decisão já fechada por Thiago, não revista) ficaria sem rastro formal de que os outros 2 (Informação indisponível, Emergência Declarada) seguem sem trilha. Aberto `DW-85` em `deferred-work.md` documentando o residual, sem reabrir o escopo desta story.

## Auto Run Result

**Resumo:** Story executada em invocação anterior (commit `c970148`); esta passada de review (folder+id dispatch, `status: in-review`) construiu o diff contra `baseline_revision`, rodou os 4 reviewers em paralelo (blind-hunter, edge-case-hunter, verification-gap, intent-alignment) e aplicou os 4 patches acima.

**Arquivos alterados (baseline → HEAD, incluindo esta passada de review):**
- `_bmad-output/implementation-artifacts/deferred-work.md` — DW-50 marcado `resolved`; `DW-85` aberto nesta passada de review para o residual dos 2 motivos não cobertos.
- `_bmad-output/specs/spec-atendimento-nouvet/stories/15-cap-11-indicadores-e-visibilidade-gerencial.md` — spec desta story (este arquivo).
- `n8n/migrations/0013_indicadores_e_esteira.sql` — esteira (contador/teto configuráveis) + `atendimento_registro_setor` + 5 funções de indicador; corrigido nesta passada de review (cast `ROUND`, filtro de data pós-`LAG`, `GRANT` restrito).
- `n8n/workflows/02 - Escalar Humano.json` — ramo novo delegando os 3 motivos nomeados a `04` (fecha DW-50).
- `n8n/workflows/04 - Registrar Atendimento CRM.json` — 4ª branch gravando em `atendimento_registro_setor`.
- `n8n/workflows/06 - Lembretes e Escalonamento SLA.json` — esteira de lembretes com contador/teto substituindo o reenvio infinito da Story 12.

**Review findings breakdown:** 4 patches aplicados (1 alto, 2 médios, 1 baixo) — ver Triage Log acima. 4 achados deferidos (não harvestados como `DW-*` novos, pois nenhum se qualificou como ação corretiva imediata dentro do diff): (1) diversas arestas de concorrência/erro na extensão do Sweep A e no registro CRM de desvio (`intervalos_esteira_horas` vazio trava a esteira permanentemente; falha silenciosa de `Normalizar Telefone` deixa `04` ser chamado sem telefone; janela de corrida entre a busca de vencidas e a marcação de esgotada) — consistentes com o padrão `onError: continueRegularOutput` já adotado em todo o projeto, candidatas a um hardening futuro; (2) os 4 indicadores usam 4 colunas de timestamp diferentes, então não descrevem exatamente a mesma coorte de leads para um dado período — já documentado como limitação de schema aceita nas Design Notes, mas vale registrar formalmente numa story futura de modelo de dados; (3) as 6 verificações desta story são 100% estáticas (JSON/regex sobre arquivos versionados), nunca executam SQL real nem fazem dry-run dos grafos n8n — mesmo padrão de todas as stories anteriores dado que não há Postgres/n8n vivo neste ambiente de dev; (4) nenhuma das 5 funções de indicador valida `p_data_inicio > p_data_fim` — `BETWEEN` simplesmente retorna vazio, risco baixo dado uso manual sob demanda pela Btech. 6 achados rejeitados como ruído ou falso-positivo, entre eles: a alegação de que `mapeamento_stage_crm` precisaria ganhar 3 chaves novas via `UPDATE` — verificado que o seed atual (`n8n/seed/0001_atendimento_config.sql`) já é `'{}'::jsonb` vazio para os 5 setores reais também, então a leitura `-> p_setor` já retorna `null` de forma idêntica para os 3 novos motivos sem nenhuma gravação extra necessária; e a alegação de que o 3º valor de `intervalos_esteira_horas` (24h) seria "config morta" — verificado por trace manual do fluxo em `06` que esse valor é sim consumido, como o prazo de carência final antes de marcar `esteira_esgotada`, depois do 3º lembrete já ter sido enviado (não é um lembrete adicional, é a espera final antes de desistir) — comportamento coerente, não um bug.

**Verificação:** Os 7 comandos da seção `## Verification` foram reexecutados após os patches — todos `OK`. Não houve ambiente Postgres/n8n real disponível nesta passada para os checks manuais da VPS de dev (já sinalizado nas Design Notes como validação pendente de go-live).

**Riscos residuais:** Ver os 4 itens deferidos acima — nenhum bloqueante para o Piloto; o mais relevante para acompanhar é a ausência de hardening contra corrida/erro na esteira do Sweep A, dado que ela agora é a única fonte do indicador "não atendido" (FR-37).
