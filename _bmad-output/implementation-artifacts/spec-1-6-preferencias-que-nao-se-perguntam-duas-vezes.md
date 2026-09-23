---
title: 'Story 1.6 — Preferências que não se perguntam duas vezes'
type: 'feature'
created: '2026-09-23'
status: 'awaiting-operator'
baseline_revision: '723493beabcf12bdfa8554dcebd36cc3ace1d4b0'
review_loop_iteration: 0
followup_review_recommended: true
operator_actions:
  - >-
    Aplicar a migration n8n/migrations/0017_identidade_pet_preferencia.sql no Postgres
    real via `docker compose exec -T postgres psql -v ON_ERROR_STOP=1 --username
    "$POSTGRES_SUPERUSER" --dbname "$POSTGRES_APP_DB" <
    n8n/migrations/0017_identidade_pet_preferencia.sql` -- docker-entrypoint-initdb.d só
    roda na primeira inicialização do volume, então o arquivo presente sozinho não
    basta (mesmo padrão da 0014/0016, Stories 1.1/1.5).
  - >-
    Importar a versão atualizada de "n8n/workflows/01 - Agente.json" na instância n8n
    real (via UI ou `n8n import:workflow --input="n8n/workflows/01 - Agente.json"`) e
    confirmar que ela substitui a versão anterior (mesmo workflowId, `ivPwIf28PgVGX8LW`).
  - >-
    Testar manualmente uma conversa (via `08 - Entrada de Teste.json` ou WhatsApp real)
    com um pet que já tenha `preferencia` gravada diretamente no Postgres, confirmando
    que a Nouvi apresenta tudo numa única pergunta fechada, nunca campo a campo, e que
    uma mudança pontual ("hoje sem perfume") preserva as demais chaves já registradas.
  - >-
    Testar manualmente uma conversa com um pet sem `preferencia` registrada,
    confirmando que a Nouvi só pergunta o que a tarefa em curso exige e que a resposta
    vira preferência nova gravada no banco (consultar `identidade_pet.preferencia`
    depois da conversa).
context:
  - '_bmad-output/implementation-artifacts/epic-1-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Nomes de pet colidindo por case-insensitive dentro do mesmo tutor fariam
      `identidade_pet_atualizar_preferencia` casar mais de uma linha e o Postgres lançar
      "query returned more than one row" em vez do contrato gracioso `pet_nao_encontrado`.
    evidence: |-
      `pet_alvo` filtra só por `lower(btrim(p.nome)) = lower(btrim(p_pet_nome))` dentro do
      tutor único, sem unicidade garantida no schema (`identidade_pet`, migration 0014, não
      tem `UNIQUE (tutor_id, lower(btrim(nome)))`). Mesma condição de dados pré-existente já
      identificada e deliberadamente deferida pela Story 1.5 ("Dois pets do mesmo tutor com
      nomes idênticos... edge case real porém raro, sem AC que exija, fora do escopo desta
      story") -- esta story herda a mesma decisão. `onError: continueRegularOutput` do node
      já garante que, se acontecer, cai no caminho genérico de falha honesta já coberto pela
      linha "Falha da ferramenta" da matriz desta story.
    location: >-
      n8n/migrations/0017_identidade_pet_preferencia.sql (identidade_pet_atualizar_preferencia)
    severity: medium
  - summary: >-
      Não existe caminho para o cliente retirar uma chave de preferência já gravada (só
      merge via `||`, nunca operador de remoção `-`/`#-`).
    evidence: |-
      Nenhuma AC desta story pede remoção -- os exemplos dados são sempre de alterar um
      valor (ex. "sem perfume"), nunca de apagar uma chave inteira. Fica para uma story
      futura se a necessidade aparecer na prática.
    location: >-
      n8n/migrations/0017_identidade_pet_preferencia.sql (identidade_pet_atualizar_preferencia)
    severity: low
  - summary: >-
      Nada garante convenção de valor consistente entre turnos para a mesma chave de
      preferência (ex. `{"perfume": false}` numa conversa vs `{"perfume": "não"}` noutra).
    evidence: |-
      Tradeoff aceito deliberadamente pelo desenho "sem enum fechado" (Design Notes desta
      story) -- JSONB livre é o que permite qualquer categoria de preferência sem migration
      nova, mas isso também não impõe tipo consistente por chave. Vale nota para ajuste
      futuro de prompt/validação se fragmentação aparecer na prática.
    location: >-
      n8n/workflows/01 - Agente.json ("Agente Nouvet" systemMessage, seção <preferencias>)
    severity: low
  - summary: >-
      Comparação de nome de pet em `identidade_pet_atualizar_preferencia` não normaliza
      acento (`lower(btrim(...))`, sem `unaccent`).
    evidence: |-
      Mesmo padrão já usado por `identidade_cliente_pet_buscar` (migration 0006) para
      `nome_pet` -- não é uma regressão introduzida por esta story, é o padrão de
      case-insensitivity já estabelecido no diretório.
    location: >-
      n8n/migrations/0017_identidade_pet_preferencia.sql (identidade_pet_atualizar_preferencia)
    severity: low
---

<intent-contract>

## Intent

**Problem:** A base própria de identidade (`identidade_pet`, Story 1.1) não tem onde guardar a preferência estável de um pet (plano, perfume, acessório, produto próprio, observação livre) que o tutor já informou numa conversa anterior — hoje ela nunca é lembrada, e a Nouvi (`01 - Agente.json`) não tem nenhuma forma de gravar nem de ler esse dado.

**Approach:** Coluna `preferencia JSONB` (nullable, sem schema fixo) em `identidade_pet`, exposta pela função de leitura já existente (`identidade_tutor_buscar_por_telefone`, Story 1.5) e mantida por uma função de escrita nova, `identidade_pet_atualizar_preferencia` (mesma regra de autorização de um-tutor-só, patch parcial via `||`), chamada pelo próprio `Agente Nouvet` como ferramenta (`Postgres Tool`, inline — não sub-workflow, é uma query única). `systemMessage` ganha uma seção nova que apresenta preferência existente numa única pergunta fechada, nunca campo a campo, e só grava depois que o cliente informa ou confirma algo.

## Boundaries & Constraints

**Always:**
- Preferência com pet reconhecido: apresentada numa única pergunta fechada (`FR-5a`/`UX-DR4`) — nunca uma pergunta por campo.
- Cliente confirma que está tudo igual: nenhuma pergunta adicional, nenhuma chamada de ferramenta (nada mudou).
- Cliente muda algo: só as chaves alteradas são enviadas à ferramenta — `identidade_pet_atualizar_preferencia` funde (`||`) sobre o que já existe, nunca substitui o objeto inteiro.
- Pet sem preferência: a Nouvi pergunta só o que a tarefa em curso exige, nunca interroga o perfil inteiro de uma vez; o que for informado vira preferência nova.
- Escrita de preferência usa a mesma regra de autorização de `identidade_tutor_buscar_por_telefone` (`AD-32`): só grava com telefone resolvendo para exatamente um tutor; 0 ou >1 tutores nunca gravam nada.
- O importador do SimplesVet nunca sobrescreve `preferencia` (`FR-40a`) — já garantido por `import/importador/db.py:upsert_pet`, que enumera explicitamente as colunas do seu `SET`; esta story não altera esse arquivo.

**Block If:** Nenhuma decisão bloqueante — forma do dado (JSONB livre, sem enum fechado), regra de autorização e padrão de patch parcial já se resolvem pelos precedentes de `0014`/`0016` e pela própria natureza de "observação livre" do PRD.

**Never:**
- Nunca substitui o objeto `preferencia` inteiro numa escrita — sempre patch parcial.
- Nunca grava preferência para telefone que não resolve a exatamente um tutor.
- Nunca grava preferência por conta própria, sem o cliente ter informado ou confirmado algo nesse turno.
- Nunca introduz um sub-workflow novo para esta ferramenta — é uma query única, mesmo padrão inline de `Buscar Identidade`/`Buscar Config`.
- Nunca altera o importador (`import/importador/db.py`) — a salvaguarda já existe.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Pet com preferência, cliente confirma | `preferencia` não-nula; cliente responde "sim, do mesmo jeito" | Nouvi não pergunta mais nada; nenhuma chamada de ferramenta | — |
| Pet com preferência, cliente muda um campo | idem; cliente diz "hoje sem perfume" | Ferramenta chamada só com `{perfume: false}`; demais chaves preservadas via `\|\|` | — |
| Pet sem preferência, tarefa exige um dado | `preferencia` nula; conversa precisa de um dado específico | Nouvi pergunta só esse dado; resposta vira preferência nova gravada | — |
| Telefone não-autorizado tenta atualizar | `identidade_status = nao_autorizado` | Função devolve `nao_autorizado`, nenhuma linha tocada (defesa em profundidade; `pets` já vem `null` nesse status, então a Nouvi nunca deveria chamar a ferramenta aqui) | `status: 'nao_autorizado'` no retorno |
| Nome de pet não bate com nenhum pet do tutor | chamada de ferramenta com nome fora da lista conhecida | Nenhuma linha tocada | `status: 'pet_nao_encontrado'` no retorno |
| Falha da ferramenta (erro Postgres) | erro de execução na query da ferramenta | Nouvi não trava o turno; reconhece a falha com honestidade, sem jargão técnico (`AD-31`) | `onError: continueRegularOutput` no node — erro vira parte do output que a ferramenta devolve ao modelo, nunca exceção não tratada |

</intent-contract>

## Code Map

- `n8n/migrations/0017_identidade_pet_preferencia.sql` (novo) — `ALTER TABLE identidade_pet ADD COLUMN preferencia JSONB`; `CREATE OR REPLACE FUNCTION identidade_tutor_buscar_por_telefone` (extende o `pets` CTE da `0016` com `preferencia`); `CREATE FUNCTION identidade_pet_atualizar_preferencia(p_telefone, p_pet_nome, p_preferencia)` — segunda `SECURITY DEFINER` do diretório, patch via `||`, dona `identidade_role`, `GRANT EXECUTE` só `app_role`.
- `n8n/migrations/README.md` — entrada narrativa da `0017`, incluindo o achado de que o importador já não toca `preferencia`.
- `n8n/workflows/01 - Agente.json:"Atualizar Preferência do Pet"` (node novo, `n8n-nodes-base.postgresTool`, conectado via `ai_tool` a `Agente Nouvet`) — chama `identidade_pet_atualizar_preferencia($1,$2,$3::jsonb)` com telefone fixo de `Info.telefone_normalizado` e `pet`/`preferencia` via `$fromAI`.
- `n8n/workflows/01 - Agente.json:"Agente Nouvet"` (`systemMessage`) — nova seção `<preferencias>` (pergunta fechada única, patch por mudança, nunca interroga pet sem preferência); `<limites>` ganha a exceção de escrita de preferência; `<validacoes>` ganha o item 8.
- `n8n/workflows/01 - Agente.json:"Info"` — sem alteração de código: `pets` já é passthrough genérico (`identidade.pets || []`), então `preferencia` atravessa automaticamente assim que a função de leitura passar a devolvê-la.
- `import/importador/db.py:upsert_pet` — só leitura/confirmação nesta story: `SET` já enumera colunas de propósito (nunca `preferencia`), comentário already documenta a salvaguarda; nenhuma mudança necessária.

## Tasks & Acceptance

**Execution:**
- `n8n/migrations/0017_identidade_pet_preferencia.sql` -- coluna + função de leitura reestendida + função de escrita nova -- base de dado que toda a story depende.
- `n8n/migrations/README.md` -- documentar a `0017` no mesmo padrão narrativo das entradas anteriores.
- `n8n/workflows/01 - Agente.json` -- node `Postgres Tool` novo conectado como ferramenta do agente, e `systemMessage` ensinado a apresentar/atualizar preferência.

**Acceptance Criteria:**
- Given pet com preferência registrada, when um novo atendimento é conversado, then a Nouvi apresenta as preferências numa única pergunta fechada (`FR-5a`/`UX-DR4`) and nunca como perguntas separadas.
- Given o cliente confirma que está tudo igual, when ele responde, then nenhuma pergunta adicional sobre preferência é feita.
- Given o cliente muda uma preferência, when ele informa a mudança, then a preferência é atualizada (patch parcial, preservando o resto) and passa a valer para os próximos atendimentos.
- Given pet sem preferência registrada, when o atendimento acontece, then a Nouvi pergunta apenas o que a tarefa em curso exige and o que for informado vira preferência para a próxima vez.
- Given preferência alterada pela conversa, when o importador do SimplesVet rodar depois, then o valor vindo da conversa prevalece e não é sobrescrito (`FR-40a`) — já garantido pelo `SET` explícito de `upsert_pet`, verificado nesta story por inspeção.

## Spec Change Log

_Nenhuma entrada — sem loopback `bad_spec` nesta execução._

## Review Triage Log

### 2026-09-23 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 6 (high 1, medium 3, low 2)
- defer: 4 (medium 1, low 3)
- reject: 4
- addressed_findings:
  - `[high]` `[patch]` `identidade_pet_atualizar_preferencia` mesclava `p_preferencia` sem defesa contra `NULL` -- se o parâmetro chegasse `NULL` (`$fromAI` sem valor extraído), `COALESCE(preferencia,'{}'::jsonb) || NULL::jsonb` avalia para `NULL`, apagando silenciosamente toda a preferência já registrada do pet -- corrigido com `COALESCE(p_preferencia, '{}'::jsonb)` do lado direito do `\|\|` também.
  - `[medium]` `[patch]` Nada impedia `p_preferencia` de ser um `jsonb` não-objeto (array/escalar) -- o operador `\|\|` do Postgres, ao concatenar objeto com não-objeto, produz um array em vez de erro, corrompendo silenciosamente o contrato "`preferencia` é sempre objeto" que o `systemMessage` assume (`Object.keys(p.preferencia)`) -- corrigido com checagem `jsonb_typeof(p_preferencia) = 'object'` antes do merge; caso contrário devolve `status: 'preferencia_invalida'` sem gravar nada.
  - `[medium]` `[patch]` `systemMessage` não instruía o que fazer quando a ferramenta devolve `nao_autorizado`/`pet_nao_encontrado`/`preferencia_invalida` (status de sucesso da query, não erro Postgres, então nunca passa pelo caminho de "falha técnica") nem proibia repetir texto técnico de um erro cru ao cliente -- corrigido com uma frase nova em `<preferencias>` tratando qualquer status diferente de sucesso como o mesmo caminho de falha honesta sem jargão já usado no resto do produto, nunca repetindo detalhe técnico da ferramenta.
  - `[low]` `[patch]` Contrato de status de `identidade_pet_atualizar_preferencia` colapsava 0 e >1 tutores no mesmo `nao_autorizado`, inconsistente com o contrato de 3 vias (`novo`/`reconhecido`/`nao_autorizado`) de `identidade_tutor_buscar_por_telefone` -- corrigido para distinguir `novo` (0 tutores) de `nao_autorizado` (>1), mesma nomenclatura da função de leitura.
  - `[medium]` `[patch]` Verificação do spec afirmava "sintaxe válida" para o `psql -f 0017...sql` como se o comando tivesse rodado, mas o próprio ambiente não tem `psql`/docker -- o comando nunca executou -- corrigido o texto para admitir isso explicitamente, mesmo padrão honesto já usado na seção "Manual checks".
  - `[low]` `[patch]` A linha "Falha da ferramenta" da cobertura da matriz afirmava que `mcp__n8n__validate_workflow` confirmava o comportamento em tempo de execução do `onError: continueRegularOutput` -- essa ferramenta só valida estrutura/JSON, nunca executa o node -- corrigido o texto para deixar claro que a validação confirma a presença estrutural do flag, não o comportamento em runtime (que fica para o operador testar manualmente).
  - `[medium]` `[defer]` Nomes de pet colidindo por case-insensitive dentro do mesmo tutor fariam `pet_alvo` casar mais de uma linha, e como a função devolve um `JSONB` escalar, o Postgres lançaria "query returned more than one row" -- exceção não tratada em vez do contrato gracioso `pet_nao_encontrado`. Mesma condição de dados pré-existente já identificada e deliberadamente deferida pela Story 1.5 ("Dois pets do mesmo tutor com nomes idênticos... edge case real porém raro, sem AC que exija, fora do escopo desta story") -- esta story herda a mesma decisão; o `onError: continueRegularOutput` do node já garante que, se acontecer, cai no mesmo caminho genérico de falha honesta já coberto pela linha "Falha da ferramenta" da matriz.
  - `[low]` `[defer]` Não existe caminho para o cliente retirar uma chave de preferência já gravada (só `\|\|`, nunca operador de remoção `-`/`#-`) -- nenhuma AC desta story pede remoção (os exemplos dados são sempre de alterar um valor, nunca de apagar uma chave) -- fica para uma story futura se a necessidade aparecer.
  - `[low]` `[defer]` Nada garante convenção de valor consistente entre turnos (ex. `{"perfume": false}` vs `{"perfume": "não"}` para a mesma ideia) -- tradeoff aceito deliberadamente pelo desenho "sem enum fechado" (Design Notes), mas vale nota para ajuste futuro de prompt se aparecer na prática.
  - `[low]` `[defer]` Comparação de nome de pet não normaliza acento (`lower(btrim(...))`, sem `unaccent`) -- mesmo padrão já usado por `identidade_cliente_pet_buscar` (`0006`) para `nome_pet`, não é regressão desta story.
  - `[reject]` Ausência de casos novos na bancada adversarial -- autorizado como fora de escopo pelo próprio Épico 1 Context (`context:` desta spec), que lista explicitamente quais stories alimentam a bancada com casos de "nunca" (1.5/1.8/1.9/1.11) e não inclui a 1.6.
  - `[reject]` Ausência de índice de expressão case-insensitive para nome de pet (paralelo ao índice da `0006`) -- volume de pets por tutor é baixo (poucas unidades), ganho de performance desprezível, não vale nova migration.
  - `[reject]` Ausência de gate em nível de workflow (node `IF`) antes de chamar a ferramenta com telefone `nao_autorizado` -- redundante: a autorização já é aplicada dentro da própria função Postgres (mesma filosofia de porta única defensiva já documentada nas Design Notes), um gate a mais no workflow não fecha nenhuma lacuna real.
  - `[reject]` Falta de discussão sobre idempotência/retry do node de escrita -- a própria análise que levantou o ponto concluiu que o patch já é idempotente para o mesmo payload repetido; não é um problema real, mesmo padrão de outras funções do diretório que também não discutem isso explicitamente.

## Design Notes

**Ferramenta inline, não sub-workflow.** O padrão de referência (`n8n-agent-patterns`) usa um workflow separado por ação de agenda porque cada ação ali é multi-etapa (OAuth, múltiplas chamadas). Atualizar preferência é uma única query Postgres — mesmo formato de `Buscar Identidade`/`Buscar Config`, só que como variante `Tool` (`n8n-nodes-base.postgresTool`) conectada direto ao `ai_tool` do agente. Isso também evita o problema de referenciar, de um workflow local ainda não importado na instância real, o `workflowId` de um segundo workflow que também ainda não existe lá — toda a mudança fica contida em `01 - Agente.json`, sem exigir a criação prévia de um novo workflow na instância n8n real (operator action) só para o import funcionar.

**Patch via `||`, não replace.** `COALESCE(preferencia, '{}'::jsonb) || COALESCE(p_preferencia, '{}'::jsonb)` funde só as chaves da chamada atual sobre o que já existe (o `COALESCE` do lado direito, adicionado no review, evita que um `p_preferencia` `NULL` apague tudo — ver Review Triage Log). Sem isso, "hoje sem perfume" apagaria "com corte de unha" registrado antes — o merge é o que permite o `systemMessage` nunca precisar reperguntar o que já sabe, e é consistente com a pergunta fechada única (uma mudança pontual não deveria custar o perfil inteiro de novo).

**Autorização reaproveitada, nunca reimplementada.** `identidade_pet_atualizar_preferencia` resolve `tutor_unico` com exatamente as mesmas CTEs de `identidade_tutor_buscar_por_telefone` (`0016`) — mesma regra "só exatamente um tutor" (`AD-32`), citada explicitamente no Épico 1 Context como valendo também para preferências. Na prática a Nouvi nunca deveria tentar atualizar preferência num telefone `nao_autorizado` (não vê pet nenhum nesse status), mas a função defende esse caminho de qualquer forma — mesma postura de "porta única" que não confia só no prompt.

**Achado sem trabalho: `FR-40a` já estava resolvido.** O comentário de `import/importador/db.py:upsert_pet` (Story 1.1) já diz explicitamente que o `SET` do `UPSERT` enumera só as colunas que o importador é dono, "para que colunas futuras (preferência, estado de migração) nunca sejam sobrescritas por esta função quando existirem" — escrito antes de `preferencia` existir. Esta story confirma por inspeção que a salvaguarda já cobre a coluna nova, sem precisar tocar o importador.

## Verification

**Commands:**
- `python3 -c "import json; json.load(open('n8n/workflows/01 - Agente.json'))"` -- JSON válido.
- MCP `validate_workflow` (JSON local, sem tocar instância) -- 0 erros, 0 avisos (já executado nesta sessão de planejamento sobre o JSON completo do node novo + conexão `ai_tool`).
- `psql ... -f n8n/migrations/0017_identidade_pet_preferencia.sql` -- não executado neste ambiente (sem `psql`/docker disponível, mesma limitação das Stories 1.1–1.5); sintaxe verificada só por leitura manual contra o padrão das migrations 0006/0014/0016.

**Manual checks (sem ambiente n8n/Postgres real neste build):**
- Inspeção: `identidade_pet_atualizar_preferencia` segue o mesmo padrão `SECURITY DEFINER` + `search_path` fixo + `REVOKE`/`GRANT` de `identidade_tutor_buscar_por_telefone`.
- Inspeção: `import/importador/db.py:upsert_pet` -- `SET` não lista `preferencia` (confirma `FR-40a` sem precisar de mudança).
- Inspeção: `Info` não precisou de nenhuma edição -- `pets` já era passthrough genérico do JSON de `Buscar Identidade`.
- Fica para o operador: aplicar `0017` no Postgres real, importar `01 - Agente.json` atualizado na instância, e testar manualmente (conversa real ou via `08 - Entrada de Teste.json`) um pet com preferência registrada diretamente no banco -- a bancada adversarial não ganhou casos novos nesta story (fora da lista de stories que alimentam "nunca" adversariais no Épico 1 Context: 1.5/1.8/1.9/1.11), mas o operador pode confirmar manualmente a pergunta fechada única e o patch parcial.

## Auto Run Result

**Status:** `awaiting-operator` — todo o código desta story está implementado, revisado (6 patches aplicados, todos verificados) e será commitado; falta só a execução contra Postgres/n8n reais, que exige o operador (ver `operator_actions`).

**Resumo do que foi implementado:** coluna `preferencia JSONB` (nullable, sem schema fixo) em `identidade_pet`; `identidade_tutor_buscar_por_telefone` (Story 1.5) reestendida para devolver `preferencia` por pet; nova função `identidade_pet_atualizar_preferencia` -- segunda `SECURITY DEFINER` do diretório, mesma regra de autorização de um-tutor-só, patch parcial via `||` (com guarda contra `NULL` e contra payload não-objeto, ambos adicionados no review), contrato de status a 4 vias (`novo`/`nao_autorizado`/`pet_nao_encontrado`/`preferencia_invalida`/`atualizado`). Novo node `Postgres Tool` (`Atualizar Preferência do Pet`) conectado via `ai_tool` ao `Agente Nouvet` -- primeira ferramenta de ESCRITA do agente, inline (sem sub-workflow novo). `systemMessage` ganhou a seção `<preferencias>` (pergunta fechada única, patch por mudança, nunca interroga pet sem preferência, nunca repete erro técnico ao cliente), mais a exceção de escrita em `<limites>` e o item 8 em `<validacoes>`. Importador do SimplesVet inspecionado e confirmado já seguro (nunca sobrescreve `preferencia`) sem precisar de nenhuma mudança.

**Arquivos alterados:**
- `n8n/migrations/0017_identidade_pet_preferencia.sql` (novo) — coluna + função de leitura reestendida + função de escrita nova.
- `n8n/migrations/README.md` — entrada narrativa da `0017`.
- `n8n/workflows/01 - Agente.json` — node `Atualizar Preferência do Pet` (novo) + `systemMessage` da `Agente Nouvet` (seção `<preferencias>`, `<limites>`, `<validacoes>`).

**Findings da revisão:** 4 reviewers em paralelo (blind-hunter, edge-case-hunter, verification-gap, intent-alignment). 6 `patch` aplicados (1 high: `NULL` em `p_preferencia` apagava preferência silenciosamente; 3 medium: payload não-objeto corrompia o contrato, `systemMessage` sem instrução para status não-sucesso, spec superestimava verificação de sintaxe SQL não executada; 2 low: assimetria `novo`/`nao_autorizado` na escrita, spec superestimava o que `validate_workflow` prova sobre comportamento em runtime). 4 `defer` registrados no frontmatter (colisão de nome de pet case-insensitive herdada da Story 1.5, ausência de remoção de chave de preferência, convenção de valor não imposta entre turnos, acento não normalizado na busca de pet -- todos de baixo/médio impacto, nenhum bloqueante). 4 `reject` (bancada sem casos novos -- autorizado pelo próprio Épico 1 Context; índice de expressão; gate redundante em nível de workflow; discussão de idempotência).

**Recomendação de revisão de acompanhamento:** `true` — o pass teve 1 finding `high` corrigido (dispara `true` por si só, independente da fórmula de pontuação por severidade: 1 high + 3 medium + 2 low → score `3×3 + 1×2 = 11`, também ≥ 5).

**Verificação realizada:**
- `python3 -c "import json; json.load(open('n8n/workflows/01 - Agente.json'))"` — válido, re-executado após os 6 patches.
- `mcp__n8n__validate_workflow` sobre o JSON completo (node novo + `systemMessage` atualizado) — `valid: true`, 11 nodes, 14/14 expressões validadas, 0 erros, 0 avisos.
- Inspeção estrutural da migration `0017` (parênteses balanceados, dollar-quotes pareados, `CASE`/`END` consistentes) — sem `psql`/docker disponíveis neste ambiente para execução real, mesma limitação das Stories 1.1–1.5.
- Cobertura da I/O & Edge-Case Matrix por inspeção estrutural (6 cenários, ver seção Verification acima).

**Riscos residuais:** todos os 4 itens `defer` do frontmatter; nenhum bloqueia as ACs desta story. O maior é a colisão de nome de pet (herdada, já aceita pela Story 1.5). Verificação de comportamento em runtime (pergunta fechada única, timing real da chamada da ferramenta) só acontece quando o operador rodar uma conversa real contra a instância aplicada -- nenhuma execução real ocorreu neste ambiente de build.

**Cobertura da I/O & Edge-Case Matrix (sem Postgres/n8n real neste build -- cada linha verificada por inspeção estrutural, nunca por execução, mesmo padrão da Story 1.5):**
- Pet com preferência, cliente confirma -- `<preferencias>` do `systemMessage` instrui explicitamente "não faça nenhuma pergunta adicional... e não chame nenhuma ferramenta" para esse caso; nenhum código força uma chamada, então a garantia é textual/comportamental, como as demais regras de conversa já aceitas neste diretório (mesmo padrão de `<autorizacao>` da Story 1.5).
- Pet com preferência, cliente muda um campo -- garantia estrutural: `identidade_pet_atualizar_preferencia` só recebe as chaves que o `$fromAI('preferencia', ...)` extrair, e o `SET preferencia = COALESCE(preferencia, '{}'::jsonb) || p_preferencia` nunca apaga chave que não está em `p_preferencia` -- propriedade do operador `jsonb` `||`, não depende do prompt acertar.
- Pet sem preferência -- `preferencia IS NULL` é o estado default da coluna (sem `DEFAULT`); `systemMessage` trata esse caso explicitamente como "não interrogue o perfil inteiro".
- Telefone não-autorizado -- garantia estrutural igual à `0016`: `tutor_unico` só produz linha quando `contagem.n = 1` (`JOIN contagem ON contagem.n = 1`); com `contagem.n <> 1` o `CASE` força `'nao_autorizado'` e `pet_alvo`/`atualizado` ficam vazios via `LEFT JOIN`, então o `UPDATE` casa zero linhas.
- Nome de pet não encontrado -- `pet_alvo` filtra por `lower(btrim(p.nome)) = lower(btrim(p_pet_nome))` dentro do `tutor_unico`; sem match, `pet_alvo` fica vazio e o `CASE` força `'pet_nao_encontrado'`, mesma garantia por `LEFT JOIN`.
- Falha da ferramenta -- `mcp__n8n__validate_workflow` (0 erros) confirma só a presença estrutural do flag `onError: continueRegularOutput` no node `Atualizar Preferência do Pet` -- essa ferramenta valida JSON/estrutura/expressões, nunca executa o node, então não prova o comportamento em tempo de execução (que uma falha realmente vira output em vez de exceção); isso fica para o operador testar manualmente, mesmo padrão de honestidade do resto desta subseção.
