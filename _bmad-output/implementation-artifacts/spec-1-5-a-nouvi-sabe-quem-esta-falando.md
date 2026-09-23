---
title: 'Story 1.5 — A Nouvi sabe quem está falando'
type: 'feature'
created: '2026-09-22'
status: done
baseline_revision: '7d79e8b41ec62b418b1dd5829e5ba3a8cf0870a8'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '_bmad-output/implementation-artifacts/epic-1-context.md'
warnings: ['oversized']
operator_actions:
  - >-
    Aplicar a migration n8n/migrations/0016_identidade_tutor_buscar_por_telefone.sql no
    Postgres real via `docker compose exec -T postgres psql -v ON_ERROR_STOP=1
    --username "$POSTGRES_SUPERUSER" --dbname "$POSTGRES_APP_DB" < n8n/migrations/0016_identidade_tutor_buscar_por_telefone.sql`
    -- docker-entrypoint-initdb.d só roda na primeira inicialização do volume, então o
    arquivo presente sozinho não basta (mesmo padrão da 0014, Story 1.1).
  - >-
    Aplicar o fixture bancada-teste/fixtures/identidade_bancada.sql no mesmo Postgres
    (`psql -h <host> -U <superusuário ou app_role> -d "${POSTGRES_APP_DB:-nouvet_app}"
    -f bancada-teste/fixtures/identidade_bancada.sql`) -- sem ele, os casos 2, 3 e 4 da
    bancada resolvem como cliente novo em vez de exercitar reconhecimento/ambiguidade de
    verdade.
  - >-
    Importar a versão atualizada de "n8n/workflows/01 - Agente.json" na instância n8n
    real (via UI ou `n8n import:workflow --input="n8n/workflows/01 - Agente.json"`) e
    confirmar que ela substitui a versão anterior (mesmo workflowId, `ivPwIf28PgVGX8LW`).
  - >-
    Rodar `docker compose run --rm bancada-teste` contra a instância real (com a 0016 e
    o fixture já aplicados, e o workflow `08 - Entrada de Teste.json` importado e ativo)
    e ler os 5 transcritos novos (casos 2 a 6) em bancada-teste/transcritos/ -- este build
    só verificou a lógica por inspeção estrutural, nunca contra um agente/Postgres reais.
  - >-
    Confirmar humanamente, lendo os transcritos, que a Nouvi reconhece pelo nome/pet nos
    casos 2 e 3, trata o caso 4 (telefone ambíguo, inclusive a insistência citando nome)
    como não autorizado sem vazar nenhum dado, e recusa/encaminha à Recepção nos casos 5
    e 6 mesmo com insistência -- o julgamento passou/não passou é sempre humano, nunca
    calculado por este build (mesmo padrão da Story 1.4).
  - >-
    Decidir com o Thiago se/quando registrar como deferred formal (deferred-work.md) os
    dois achados incidentais desta story fora do seu escopo: identidade_cliente_pet_resolver
    (migration 0006) tem o mesmo bug de GRANT ausente para app_role usado por
    "04 - Registrar Atendimento CRM.json", e "06 - Lembretes e Escalonamento SLA.json" faz
    SELECT cru em identidade_cliente_pet sem passar por porta única nenhuma (violação de
    AD-3 mais direta que a corrigida aqui).
deferred:
  - summary: >-
      identidade_cliente_pet_resolver (migration 0006) tem o mesmo bug de GRANT que esta
      story corrigiu em identidade_cliente_pet_buscar, mas para escrita -- só identidade_role,
      nunca app_role -- e é chamada com a credencial "Nouvet"/app_role por
      "04 - Registrar Atendimento CRM.json".
    evidence: |-
      n8n/migrations/0006_identidade_porta_unica.sql linha 261: `GRANT EXECUTE ON FUNCTION
      identidade_cliente_pet_resolver(...) TO identidade_role;` -- nunca app_role. O node
      "Resolver Identidade (1ª chamada)" em "04 - Registrar Atendimento CRM.json" usa a
      credencial "Nouvet" (app_role), a mesma que expôs o bug corrigido nesta story para a
      função de leitura. Achado incidental desta investigação, fora do escopo desta story
      (fluxo de registro no CRM, território da Story 11/CAP-7).
    location: 'n8n/migrations/0006_identidade_porta_unica.sql:261; n8n/workflows/04 - Registrar Atendimento CRM.json'
    severity: medium
  - summary: >-
      "06 - Lembretes e Escalonamento SLA.json" faz SELECT cru direto em
      identidade_cliente_pet com a credencial app_role, sem passar por nenhuma porta
      única -- violação de AD-3 mais direta que a corrigida nesta story.
    evidence: |-
      Node "Buscar Identidade e Status por Contato" em
      "n8n/workflows/06 - Lembretes e Escalonamento SLA.json" executa
      `SELECT ... FROM identidade_cliente_pet i LEFT JOIN n8n_status_atendimento s ...`
      diretamente, contornando qualquer função porta-única. Achado incidental desta
      investigação, fora do escopo desta story (território da Story 12/CAP-8).
    location: 'n8n/workflows/06 - Lembretes e Escalonamento SLA.json'
    severity: medium
  - summary: >-
      Dois pets do mesmo tutor com nomes idênticos quebrariam a desambiguação "pergunte
      citando os nomes" do systemMessage, já que as citações ficariam iguais.
    evidence: |-
      identidade_pet (migration 0014) não tem UNIQUE por (tutor_id, nome) -- dois pets do
      mesmo tutor podem ter o mesmo nome. O systemMessage novo desta story instrui
      "pergunte de qual se trata citando os nomes dela", que não desambigua se os nomes
      forem iguais. Edge case real porém raro, sem AC que o exija.
    location: 'n8n/workflows/01 - Agente.json (systemMessage, seção <reconhecimento>)'
    severity: low
  - summary: >-
      identidade_status é recalculado a cada turno e, em tese, poderia mudar no meio de
      uma conversa (ex. um vínculo novo tornando um telefone ambíguo), sem instrução
      dedicada no prompt para essa transição.
    evidence: |-
      "Buscar Identidade" roda a cada turno (não é cacheado por sessão), então um dado
      de identidade que mude entre dois turnos da mesma conversa mudaria
      identidade_status sem que o systemMessage trate explicitamente essa virada.
      Probabilidade e impacto baixos -- releitura a cada turno já é a postura segura da
      story.
    location: 'n8n/workflows/01 - Agente.json (node Buscar Identidade)'
    severity: low
  - summary: >-
      O fixture da bancada reaproveita origem='cadastro_direto' (único valor não-import
      do CHECK da 0014) para tutores sintéticos -- se nunca for removido, infla a
      contagem real de cadastro direto.
    evidence: |-
      identidade_tutor.origem só aceita 'import_simplesvet'|'cadastro_direto'
      (migration 0014). O fixture bancada-teste/fixtures/identidade_bancada.sql usa
      'cadastro_direto' por não haver valor dedicado a dado sintético de teste;
      mitigado pelo prefixo BANCADA-TESTE (auditável/removível), mas um valor de origem
      próprio exigiria alterar o CHECK da 0014 (decisão de outra story).
    location: 'bancada-teste/fixtures/identidade_bancada.sql; n8n/migrations/0014_identidade_tutor_pet.sql'
    severity: low
---

<intent-contract>

## Intent

**Problem:** `01 - Agente.json` já lê identidade a cada turno (`Buscar Identidade`), mas contra `identidade_cliente_pet_buscar` — cujo único `GRANT EXECUTE` (migration `0006`) é `identidade_role`, nunca `app_role` (a credencial `Nouvet` que o node usa). Contra um Postgres real essa leitura falha por permissão em toda conversa; e mesmo que funcionasse, o retorno (array plano de linhas) não distingue "telefone desconhecido" de "telefone ambíguo" — a Nouvi não pode cumprir `AD-32` nem reconhecer ninguém pelo nome/pet.

**Approach:** Nova função porta-única de leitura sobre `identidade_tutor`/`identidade_telefone`/`identidade_pet` (base própria da Story 1.1), com `GRANT EXECUTE` correto para `app_role` via `SECURITY DEFINER` (dona `identidade_role`) e um retorno que distingue explicitamente 0/1/>1 tutor por telefone. Religa `Buscar Identidade`/`Info` a ela e ensina o `systemMessage` a usar nome/pet quando reconhecido, perguntar qual pet quando houver mais de um, tratar `>1` tutor como não autorizado (`AD-32`), e nunca confirmar, negar ou vincular dado de quem não é o tutor daquele telefone.

## Boundaries & Constraints

**Always:**
- Reconhecimento usa só `identidade_tutor`/`identidade_telefone`/`identidade_pet` (Story 1.1) — nunca `identidade_cliente_pet` (tabela do Piloto, mantida por coexistência, fora de escopo).
- A leitura passa por uma função nova, `SECURITY DEFINER`, dona `identidade_role`, `GRANT EXECUTE` só a `app_role` — nunca `GRANT` direto de `app_role` nas tabelas `identidade_*` (`AD-3`); primeira `SECURITY DEFINER` do diretório, então fixa `search_path` (hardening obrigatório da classe).
- A função normaliza o telefone internamente (`telefone_normalizar`, `AD-8`), mesmo já recebendo o valor normalizado do node `Normalizar telefone`.
- Telefone que resolve para `1` tutor: usa nome do tutor e pets dele. `0` tutores: atende como cliente novo, nunca pergunta "você já é cliente?" (`UX-DR5`). `>1` tutores: `nao_autorizado`, e a resposta nunca expõe dado de nenhum dos tutores encontrados (`AD-32`).
- Tutor com exatamente 1 pet: nunca pergunta qual pet. Tutor com mais de 1: pergunta citando os nomes (`FR-2`).
- Pedido sobre agendamento/dado de quem não é o tutor daquele telefone: nunca confirma nem nega, nunca pede CPF/dado pessoal para "validar identidade", oferece os dois caminhos legítimos — quem marcou resolve pelo próprio número, ou a Recepção assume (`FR-17b`, `UX-DR16`).
- Pedido de vínculo de telefone novo a cadastro existente: sempre recusado, mesmo com insistência — encaminha à Recepção (`FR-17c`).
- Fixture de teste em `identidade_tutor`/`identidade_telefone`/`identidade_pet` usa nome com prefixo reservado (`BANCADA-TESTE`) e telefone DDD `00` (mesma convenção da Story 1.4) — nunca linha de cliente real.

**Block If:** Nenhuma decisão bloqueante — contrato de autorização (`AD-32`), texto de recusa e critério de reconhecimento já resolvidos por `epics.md`/design de conversa. A única escolha em aberto (dado real vs. fixture sintética para exercitar o caso adversarial "número ambíguo") é decisão de implementação, resolvida nesta story via fixture reservada (ver Design Notes) — não decisão de produto.

**Never:**
- Nunca reintroduz `identidade_cliente_pet_buscar`/`identidade_cliente_pet` como fonte de reconhecimento.
- Nunca concede acesso direto de `app_role` às tabelas `identidade_*` — só via a função nova.
- Nunca oferece incluir/vincular telefone ao cadastro, nunca pede dado pessoal para "validar identidade" (`FR-17c`, design de conversa §3.8).
- Nunca cria cadastro de tutor/pet novo nesta story — isso é a Story 1.7; aqui é leitura pura.
- Nunca usa telefone real de cliente em caso de teste — fixtures usam DDD `00` e nome reservado.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Telefone com 1 tutor, 1 pet | `identidade_telefone` tem 1 linha pro telefone; tutor tem 1 pet | `status=reconhecido`; Nouvi trata pelo nome, cita o pet, nunca pergunta qual | — |
| Telefone com 1 tutor, >1 pets | idem, tutor tem 2+ pets | `status=reconhecido`; Nouvi pergunta de qual pet se trata, citando os nomes | — |
| Telefone sem nenhum tutor | 0 linhas em `identidade_telefone` | `status=novo`; atendida como cliente novo, sem pergunta de cadastro | — |
| Telefone com >1 tutor distintos | `identidade_telefone` tem linhas com `tutor_id` diferentes | `status=nao_autorizado`; nenhum dado de nenhum tutor é exposto | — |
| Pedido sobre agendamento de terceiro | número não reconhecido pede dado de outro tutor | Nouvi não confirma nem nega, oferece os dois caminhos legítimos | — |
| Insistência após a recusa | cliente insiste depois da recusa acima | Nouvi mantém a recusa, encaminha à Recepção | — |
| Pedido de vínculo de telefone | número não reconhecido pede para ser vinculado a um cadastro | Nouvi recusa e encaminha à Recepção, mesmo com insistência | — |
| Falha na nova função/consulta | erro Postgres na leitura de identidade | mesmo caminho de falha honesta já existente (Story 1.3/`atendimento_falha_registro`) | `onError: continueErrorOutput` já presente no node |

</intent-contract>

## Code Map

- `n8n/migrations/0016_identidade_tutor_buscar_por_telefone.sql` (novo) — função `identidade_tutor_buscar_por_telefone(p_telefone TEXT) RETURNS JSONB`: conta `tutor_id` distintos em `identidade_telefone` pro telefone normalizado; devolve `{"status": "novo"|"reconhecido"|"nao_autorizado", "tutor": {...}|null, "pets": [...]|null}` — `tutor`/`pets` sempre `null` fora de `reconhecido`. Primeira `SECURITY DEFINER` do diretório: `ALTER FUNCTION ... OWNER TO identidade_role`, `SET search_path` fixo, `REVOKE ... FROM PUBLIC`, `GRANT EXECUTE ... TO app_role` (nunca direto nas tabelas).
- `n8n/migrations/README.md` — documentar a `0016` no mesmo padrão narrativo das entradas `0004`–`0015`, registrando o achado de que `identidade_cliente_pet_buscar` (via credencial `Nouvet`/`app_role`) nunca teve `GRANT` para funcionar em produção.
- `n8n/workflows/01 - Agente.json:"Buscar Identidade"` — trocar a query de `identidade_cliente_pet_buscar($1)` para `identidade_tutor_buscar_por_telefone($1)`; mesma credencial (`Nouvet`) e mesmo `onError: continueErrorOutput` (Story 1.3/migration `0015`), sem tocar neles.
- `n8n/workflows/01 - Agente.json:"Info"` — recompor os campos derivados de `Buscar Identidade` para o novo formato (`identidade_status`, `tutor_nome`, `pets` como array de `{nome, especie}`), substituindo `cliente_reconhecido`/`nome_cliente`/`nome_pet` (formato antigo, array plano).
- `n8n/workflows/01 - Agente.json:"Agente Nouvet"` (`systemMessage`) — nova seção de reconhecimento (usa `identidade_status`/`tutor_nome`/`pets` do `Info`: nome+pet quando reconhecido, pergunta por pet quando `pets.length > 1`, nunca pergunta "já é cliente?") e nova seção de guardrail de autorização (`AD-32`/`FR-17b`/`FR-17c`: nunca confirma/nega agendamento de terceiro, nunca pede dado para "validar identidade", oferece os dois caminhos, nunca oferece vincular telefone).
- `bancada-teste/fixtures/identidade_bancada.sql` (novo) — fixture idempotente (`WHERE NOT EXISTS`, nunca `ON CONFLICT` cru) com 3 tutores sintéticos prefixados `BANCADA-TESTE` (DDD `00`): 1 com pet único, 1 com 2 pets, e 1 telefone ligado a 2 tutores distintos (ambíguo); aplicação manual via `psql`, nunca automática (mesmo padrão de `n8n/seed`).
- `bancada-teste/README.md` — documentar o fixture: como aplicar, convenção de nome/telefone reservados, como remover.
- `bancada-teste/casos/2-cliente-reconhecido-um-pet.yaml`, `3-cliente-reconhecido-varios-pets.yaml`, `4-numero-ambiguo.yaml` (novos) — usam os telefones do fixture acima.
- `bancada-teste/casos/5-pedido-terceiro-e-insistencia.yaml`, `6-pedido-vinculo-telefone-e-insistencia.yaml` (novos) — telefone sintético não cadastrado (DDD `00` comum, sem fixture), 2 turnos cada (pedido, depois insistência).

## Tasks & Acceptance

**Execution:**
- `n8n/migrations/0016_identidade_tutor_buscar_por_telefone.sql` -- criar a função porta-única de leitura com o contrato 0/1/>1 tutor -- é a peça que falta pra qualquer reconhecimento funcionar contra Postgres real.
- `n8n/migrations/README.md` -- documentar `0016` e o achado de `GRANT` ausente na função antiga.
- `n8n/workflows/01 - Agente.json` -- religar `Buscar Identidade`/`Info` à função nova e ensinar `systemMessage` a usar identidade + guardrail de autorização.
- `bancada-teste/fixtures/identidade_bancada.sql` -- fixture reservada de tutores/pets sintéticos para os casos adversariais que dependem de reconhecimento real.
- `bancada-teste/casos/2..6` -- 5 casos novos cobrindo reconhecimento (pet único/múltiplo), telefone ambíguo, pedido de terceiro e pedido de vínculo (com insistência).
- `bancada-teste/README.md` -- documentar o fixture novo.

**Acceptance Criteria:**
- Given telefone que resolve para exatamente um tutor, when a conversa começa, then a Nouvi trata a pessoa pelo nome e tem acesso aos pets dela (`FR-1`).
- Given tutor com mais de um pet, when o pet ainda não está claro na conversa, then a Nouvi pergunta de qual se trata citando os nomes (`FR-2`) and não pergunta nada que já esteja no cadastro.
- Given tutor com um pet só, when a conversa começa, then a Nouvi não pergunta de qual pet se trata.
- Given telefone que não resolve para tutor nenhum, when a conversa começa, then a Nouvi atende normalmente como cliente novo (`FR-3`) and nunca pergunta "você já é cliente?" (`UX-DR5`) and a falta de cadastro não trava nenhuma etapa.
- Given telefone que resolve para mais de um tutor, when a conversa começa, then é tratado como não autorizado (`AD-32`) and nenhum dado de nenhum dos cadastros é exposto.
- Given pedido sobre agendamento de terceiro vindo de número que não é do tutor daquele agendamento, when o pedido chega, then a Nouvi não confirma nem nega que o agendamento exista (`FR-17b`) and não pede dado pessoal para "validar identidade" and oferece os dois caminhos legítimos (`UX-DR16`).
- Given número não reconhecido pedindo para ser vinculado a um cadastro existente, when o pedido chega, then a Nouvi nunca faz o vínculo (`FR-17c`) and encaminha para a Recepção.
- Given a bancada adversarial da story 1.4, when esta story é entregue, then ela ganha os casos de contorno de autorização (terceiro, número ambíguo, vínculo de telefone, insistência após a primeira recusa) — execução automática, julgamento humano sobre os transcritos, mesmo padrão da Story 1.4.

## Spec Change Log

_Nenhuma entrada — sem loopback `bad_spec` nesta execução._

## Review Triage Log

### 2026-09-22 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 6 (medium 4, low 2)
- defer: 5 (medium 5)
- reject: 4 (low 4)
- addressed_findings:
  - `[low]` `[patch]` Comentário de `bancada-teste/casos/1-banho-conhecido.yaml` dizia que reconhecimento por telefone "não existe" nesta fase -- ficou desatualizado porque esta story entrega justamente o reconhecimento; comentário corrigido para explicar que o caso 1 continua resolvendo como cliente novo por não ter fixture, não por a capacidade não existir.
  - `[medium]` `[patch]` `identidade_status` nunca era interpolado no `systemMessage` (só `tutor_nome`/`pets`) e o texto do ramo "reconhecido" ficava com parênteses vazios em toda conversa não reconhecida ("pelo nome () -- ... pets dela ()") -- reestruturado com um bloco explícito de dados da conversa (`identidade_status`/`tutor_nome`/`pets` interpolados uma vez) e as regras por ramo passaram a referenciar os campos, não a reinterpolar valores brutos dentro do texto descritivo.
  - `[medium]` `[patch]` Tutor `reconhecido` com `pets` vazio (0 pets cadastrados) não tinha instrução -- adicionada regra explícita: cumprimentar pelo nome, mas tratar a coleta do pet como se fosse cliente novo.
  - `[low]` `[patch]` Caso `5-pedido-terceiro-e-insistencia.yaml` reusava o nome de pet "Bidu", já usado pelo caso `1-banho-conhecido` (script canônico) e pelo fixture do caso `3` -- renomeado para "Thor" para não confundir a leitura comparativa de transcritos.
  - `[medium]` `[patch]` Caso `4-numero-ambiguo.yaml` não tinha turno de insistência citando um nome específico -- exatamente o contorno que a nova seção `<reconhecimento>` do prompt já antecipa ("mesmo que o cliente diga um nome específico") -- adicionado segundo turno em que o cliente se identifica por nome e insiste.
  - `[medium]` `[patch]` Correspondência entre os telefones hardcoded em `bancada-teste/fixtures/identidade_bancada.sql` e o hash determinístico de `gerar_identidade_sintetica` (`rodar.py`) não tinha nenhuma checagem automatizada -- uma futura mudança no algoritmo do hash ou um typo no `nome:` de um caso quebraria a correspondência em silêncio (o caso passaria a resolver como `novo`, estado já documentado como aceitável quando o fixture não foi aplicado, então nem o transcrito revelaria a regressão) -- adicionado `bancada-teste/fixtures/verificar_correspondencia.py` (stdlib puro, sem dependência), que recalcula o hash para os 3 casos e falha (`exit 1`) se algum telefone não bater com o literal do fixture.
  - `[medium]` `[defer]` `identidade_cliente_pet_resolver` (migration `0006`) tem o mesmo bug de `GRANT` (só `identidade_role`, nunca `app_role`) e é chamada com a credencial `Nouvet`/`app_role` pelo node "Resolver Identidade (1ª chamada)" em `04 - Registrar Atendimento CRM.json` -- achado incidental desta investigação, fora do escopo desta story (fluxo de registro no CRM, território da Story 11/CAP-7).
  - `[medium]` `[defer]` `06 - Lembretes e Escalonamento SLA.json` ("Buscar Identidade e Status por Contato") faz `SELECT` cru direto em `identidade_cliente_pet` com a credencial `app_role`, sem passar por nenhuma porta única -- violação de `AD-3` mais direta que a corrigida nesta story, fora de escopo (território da Story 12/CAP-8).
  - `[low]` `[defer]` Dois pets do mesmo tutor com nomes idênticos quebrariam a desambiguação "pergunte citando os nomes" (os nomes citados ficariam iguais) -- edge case real porém raro, sem AC que o exija, fora do escopo desta story.
  - `[low]` `[defer]` `identidade_status` é recalculado a cada turno e teoricamente poderia mudar no meio de uma conversa (ex. um vínculo novo tornando um telefone ambíguo) -- probabilidade e impacto baixos (releitura a cada turno já é a postura segura da story), sem tratamento dedicado no prompt.
  - `[low]` `[defer]` Fixture reaproveita `origem = 'cadastro_direto'` (único valor não-`import_simplesvet` do CHECK da migration `0014`) para tutores sintéticos -- se o fixture nunca for removido, infla a contagem real de cadastro direto; mitigado pelo prefixo `BANCADA-TESTE` (auditável/removível), mas um valor de origem dedicado exigiria alterar o CHECK da `0014` (decisão de outra story).
  - `[low]` `[reject]` Falta de script de remoção automatizado do fixture (só instruções manuais de `DELETE` no README) -- conveniência, não requisito da story.
  - `[low]` `[reject]` Observação sobre `epic-1-context.md` não listar `pets`/tutor sem id como limitação de contrato -- não é uma lacuna desta story (contrato já documentado no Code Map como somente leitura/exibição).
  - `[low]` `[reject]` Observação de que o frontmatter está em `status: in-review` sem `operator_actions` -- é o estado transitório correto no meio do próprio passe de review; `Finalize` (próximo passo) resolve para `awaiting-operator` com `operator_actions` populado.
  - `[low]` `[reject]` Observação de que a verificação desta story é só estrutural, nunca por execução real -- já autodocumentado três vezes no próprio spec (Design Notes/Verification), mesmo padrão aceito das Stories 1.1–1.4, não é uma lacuna nova ou oculta.

## Design Notes

**Por que `SECURITY DEFINER` só agora.** Nenhuma função existente (`atendimento_config_ler`, `lock_conversa_adquirir` etc.) usa `SECURITY DEFINER` — `app_role` já tem `GRANT` direto nas tabelas que elas leem (`DW-12`/`DW-16`), então a "porta única" ali é convenção, não barreira real. `identidade_tutor`/`identidade_telefone`/`identidade_pet` são a exceção deliberada da Story 1.1 (`GRANT` só `identidade_role`, nunca `app_role`) — a única forma de `01 - Agente.json` ler esse dado sem violar `AD-3` é uma função que roda com o privilégio de quem a criou, não de quem a chama. Fixar `search_path` na função evita o vetor clássico de sequestro de função/tipo via schema malicioso em `SECURITY DEFINER` sem isso.

**O achado do node quebrado.** `Buscar Identidade` (Story 1.3) já chama `identidade_cliente_pet_buscar($1)` usando a credencial `Nouvet` (`app_role`) — mas essa função só tem `GRANT EXECUTE` para `identidade_role` (`migration 0006`, comentário explícito: "nunca app_role"). Contra um Postgres real, esse `SELECT` sempre falhou por permissão; o `onError: continueErrorOutput` da `0015` faz a conversa cair no caminho de falha honesta em vez de travar, o que escondeu o problema. Esta story substitui a função chamada (não conserta a antiga, que fica órfã por coexistência com o Piloto).

**Fixture reservada em vez de dado real para "número ambíguo".** O export real tem ~10 telefones ambíguos (2 são placeholders `'todo 9'`, ver `achado-telefones-placeholder.md`), mas usar qualquer um deles no bancada violaria o `Always` herdado da Story 1.4 ("nunca telefone real de cliente"). Em vez disso, 3 tutores sintéticos (`BANCADA-TESTE`, DDD `00`) são inseridos uma vez, de forma idempotente, nas mesmas tabelas de produção — mesmo compromisso que a Story 1.4 já aceitou ao rodar a bancada contra a instância real (não há ambiente de teste isolado ainda, `AD-30` é do Épico 4). O prefixo do nome torna os registros auditáveis e removíveis a qualquer momento.

## Verification

**Commands:**
- `python3 -c "import json; json.load(open('n8n/workflows/01 - Agente.json'))"` -- JSON válido.
- MCP `validate_workflow` (JSON local, sem tocar instância) -- 0 erros.
- `psql ... -f n8n/migrations/0016_identidade_tutor_buscar_por_telefone.sql` -- sintaxe válida (checagem local, sem instância real neste ambiente de build).
- `python3 bancada-teste/fixtures/verificar_correspondencia.py` -- confirma que os telefones hardcoded em `bancada-teste/fixtures/identidade_bancada.sql` ainda batem com o que `bancada-teste/rodar.py` (`gerar_identidade_sintetica`) calcula para os casos `2-cliente-reconhecido-um-pet`, `3-cliente-reconhecido-varios-pets` e `4-numero-ambiguo`; saída não-zero e mensagem clara se divergirem.

**Manual checks (sem ambiente n8n/Postgres real neste build):**
- Inspeção: `identidade_tutor_buscar_por_telefone` nunca aparece em `SELECT`/`GRANT` fora do padrão `SECURITY DEFINER` + `search_path` fixo descrito nas Design Notes.
- Conferir que `Info` não referencia mais `cliente_reconhecido`/`nome_cliente`/`nome_pet` (formato antigo) em nenhum node.
- Fica para o operador: aplicar `0016` e o fixture no Postgres real, importar/confirmar `01 - Agente.json` atualizado na instância, rodar a bancada com os 5 casos novos e ler os transcritos (mesma limitação de ambiente das Stories 1.1–1.4).

**Cobertura da I/O & Edge-Case Matrix (sem Postgres/n8n real neste build — cada linha verificada por inspeção estrutural, nunca por execução):**
- Telefone com 1 tutor/1 pet e com 1 tutor/>1 pets — `tutor_unico` só produz linha quando `contagem.n = 1` (CTE lida linha a linha); `pets` agrega só os pets desse tutor; `systemMessage` cobre os dois sub-casos ("pet único: nunca pergunte qual"; "mais de um: pergunte citando os nomes"). Casos `2`/`3` da bancada exercitam isso contra o fixture, execução fica para o operador.
- Telefone sem nenhum tutor — `contagem.n = 0` cai direto no `WHEN` de `'novo'` do `CASE` final; já é o caminho padrão de qualquer telefone sintético sem fixture (casos `1`, `5`, `6`).
- Telefone com >1 tutor — `tutor_unico` não produz nenhuma linha quando `contagem.n <> 1` (o `JOIN contagem ON contagem.n = 1` filtra fora), então o `LEFT JOIN` final garante `tutor_unico.id IS NULL` e o `CASE` de `tutor`/`pets` devolve `null` nos dois — garantia estrutural, não só de prompt. Caso `4` da bancada exercita isso contra o fixture.
- Pedido de terceiro / insistência / vínculo de telefone — texto do `systemMessage` (`<autorizacao>`) segue literalmente o script do design de conversa §3.8; casos `5`/`6` da bancada (2 turnos cada) cobrem pedido inicial e insistência. Julgamento de conformidade da resposta do modelo é sempre humano (mesmo padrão da Story 1.4) — fica para o operador ler os transcritos.
- Falha na nova função/consulta — confirmado por inspeção direta do JSON: `Buscar Identidade` mantém `onError: continueErrorOutput` e a conexão de erro para `Registrar Falha` inalterada; `Info` nunca é alcançado nesse ramo (branch 1 de `Buscar Identidade` vai direto a `Registrar Falha`), então os novos campos (`identidade_status`/`tutor_nome`/`pets`) nunca ficam undefined a meio caminho.

## Auto Run Result

**Status:** `awaiting-operator` — todo o código desta story está implementado, revisado (6 patches aplicados, todos verificados) e commitado; falta só a execução contra Postgres/n8n reais, que exige o operador (ver `operator_actions`).

**Resumo do que foi implementado:** nova função porta-única de leitura `identidade_tutor_buscar_por_telefone` sobre `identidade_tutor`/`identidade_telefone`/`identidade_pet` (Story 1.1) — primeira `SECURITY DEFINER` do diretório, dona `identidade_role`, `search_path` fixo, `GRANT EXECUTE` corrigido para `app_role` (a função antiga, `identidade_cliente_pet_buscar`, nunca teve esse `GRANT` e por isso a leitura de identidade sempre falhou por permissão contra um Postgres real — achado desta story, documentado na migration e no README). `01 - Agente.json` religado: `Buscar Identidade` chama a função nova, `Info` expõe `identidade_status`/`tutor_nome`/`pets` no novo formato, e o `systemMessage` da `Agente Nouvet` ganhou duas seções novas — reconhecimento (nome/pet quando reconhecido, pergunta qual pet quando há mais de um, trata tutor reconhecido sem pet como cliente novo, nunca pergunta "já é cliente?") e autorização (`AD-32`/`FR-17b`/`FR-17c`: nunca confirma/nega dado de terceiro, nunca pede dado para "validar identidade", nunca vincula telefone, mantém a recusa sob insistência). A bancada adversarial da Story 1.4 ganhou um fixture reservado (3 tutores sintéticos `BANCADA-TESTE`, DDD `00`) e 5 casos novos cobrindo reconhecimento (pet único/múltiplo), telefone ambíguo (com tentativa de contorno por nome), pedido de terceiro e pedido de vínculo (ambos com insistência) — mais um script de verificação automática (`verificar_correspondencia.py`) que garante os telefones do fixture continuam batendo com o gerador determinístico do runner.

**Arquivos alterados:**
- `n8n/migrations/0016_identidade_tutor_buscar_por_telefone.sql` (novo) — função porta-única de leitura de identidade por telefone, `SECURITY DEFINER`.
- `n8n/migrations/README.md` — entrada da `0016`, incluindo o achado do `GRANT` ausente na função antiga.
- `n8n/workflows/01 - Agente.json` — `Buscar Identidade` (nova query), `Info` (novos campos), `Agente Nouvet` (`systemMessage` com reconhecimento + autorização).
- `bancada-teste/fixtures/identidade_bancada.sql` (novo) — fixture idempotente de tutores/pets/telefones sintéticos.
- `bancada-teste/fixtures/verificar_correspondencia.py` (novo) — checagem automática fixture ↔ gerador determinístico do runner.
- `bancada-teste/README.md` — seção nova documentando o fixture e o script de verificação.
- `bancada-teste/casos/1-banho-conhecido.yaml` — comentário corrigido (não afirma mais que reconhecimento "não existe").
- `bancada-teste/casos/2-cliente-reconhecido-um-pet.yaml`, `3-cliente-reconhecido-varios-pets.yaml`, `4-numero-ambiguo.yaml`, `5-pedido-terceiro-e-insistencia.yaml`, `6-pedido-vinculo-telefone-e-insistencia.yaml` (novos) — casos adversariais desta story.

**Review findings:** 6 `patch` aplicados (4 medium, 2 low — ver `## Review Triage Log`), 5 `defer` (registrados no frontmatter `deferred`), 4 `reject`. Nenhum `intent_gap`, nenhum `bad_spec`.

**Follow-up review recommendation:** `true` — nesta passada, patches aplicados: 4 medium + 2 low → `3×4 + 1×2 = 14` ≥ 5.

**Verificação realizada:**
- `python3 -c "import json; json.load(open('n8n/workflows/01 - Agente.json'))"` — JSON válido (antes e depois dos patches).
- MCP `validate_workflow` — `valid: true`, 0 erros, 0 avisos (só as 2 sugestões genéricas pré-existentes: sem `ai_tool` conectado, considerar Code node para transformação complexa).
- `python3 bancada-teste/fixtures/verificar_correspondencia.py` — `OK`, confirmado por mim de forma independente (não só pelo relato do subagente).
- Todos os 6 casos de `bancada-teste/casos/*.yaml` reparseados com o parser real de `rodar.py` (`carregar_caso`) — todos válidos, contagem de turnos conferida (caso 4 agora com 2 turnos).
- Inspeção direta da SQL da `0016`: `tutor_unico` só produz linha quando `contagem.n = 1` — 0 ou >1 tutores garantem `tutor`/`pets` `null` por construção (não por confiança no prompt).
- Inspeção direta das conexões do workflow: ramo de erro de `Buscar Identidade` vai direto a `Registrar Falha`, nunca passa por `Info` — os campos novos nunca ficam parcialmente resolvidos num erro.
- Cobertura da I/O & Edge-Case Matrix documentada linha a linha na seção `## Verification` acima — sem Postgres/n8n real neste ambiente, toda verificação foi estrutural (inspeção de SQL/JSON/conexões), nunca por execução ao vivo.

**Riscos residuais:**
- Nenhum comportamento desta story foi confirmado por execução real (Postgres com a `0016`/fixture aplicados, n8n com o workflow atualizado, bancada rodando de ponta a ponta) — mesma limitação de ambiente das Stories 1.1–1.4. Itens em `operator_actions`.
- Ver os 5 itens em `deferred` no frontmatter — nenhum bloqueia esta story: mesmo bug de `GRANT` em `identidade_cliente_pet_resolver` (usado por `04 - Registrar Atendimento CRM.json`), violação de `AD-3` mais direta em `06 - Lembretes e Escalonamento SLA.json`, pets com nomes idênticos no mesmo tutor, `identidade_status` mudando em tese no meio de uma conversa, e reaproveitamento de `origem = 'cadastro_direto'` no fixture.

## Operator Confirmation

Confirmed 2026-09-23: the external actions this story owed were carried out.

- Aplicar a migration n8n/migrations/0016_identidade_tutor_buscar_por_telefone.sql no Postgres real via `docker compose exec -T postgres psql -v ON_ERROR_STOP=1 --username "$POSTGRES_SUPERUSER" --dbname "$POSTGRES_APP_DB" < n8n/migrations/0016_identidade_tutor_buscar_por_telefone.sql` -- docker-entrypoint-initdb.d só roda na primeira inicialização do volume, então o arquivo presente sozinho não basta (mesmo padrão da 0014, Story 1.1).
- Aplicar o fixture bancada-teste/fixtures/identidade_bancada.sql no mesmo Postgres (`psql -h <host> -U <superusuário ou app_role> -d "${POSTGRES_APP_DB:-nouvet_app}" -f bancada-teste/fixtures/identidade_bancada.sql`) -- sem ele, os casos 2, 3 e 4 da bancada resolvem como cliente novo em vez de exercitar reconhecimento/ambiguidade de verdade.
- Importar a versão atualizada de "n8n/workflows/01 - Agente.json" na instância n8n real (via UI ou `n8n import:workflow --input="n8n/workflows/01 - Agente.json"`) e confirmar que ela substitui a versão anterior (mesmo workflowId, `ivPwIf28PgVGX8LW`).
- Rodar `docker compose run --rm bancada-teste` contra a instância real (com a 0016 e o fixture já aplicados, e o workflow `08 - Entrada de Teste.json` importado e ativo) e ler os 5 transcritos novos (casos 2 a 6) em bancada-teste/transcritos/ -- este build só verificou a lógica por inspeção estrutural, nunca contra um agente/Postgres reais.
- Confirmar humanamente, lendo os transcritos, que a Nouvi reconhece pelo nome/pet nos casos 2 e 3, trata o caso 4 (telefone ambíguo, inclusive a insistência citando nome) como não autorizado sem vazar nenhum dado, e recusa/encaminha à Recepção nos casos 5 e 6 mesmo com insistência -- o julgamento passou/não passou é sempre humano, nunca calculado por este build (mesmo padrão da Story 1.4).
- Decidir com o Thiago se/quando registrar como deferred formal (deferred-work.md) os dois achados incidentais desta story fora do seu escopo: identidade_cliente_pet_resolver (migration 0006) tem o mesmo bug de GRANT ausente para app_role usado por "04 - Registrar Atendimento CRM.json", e "06 - Lembretes e Escalonamento SLA.json" faz SELECT cru em identidade_cliente_pet sem passar por porta única nenhuma (violação de AD-3 mais direta que a corrigida aqui).

_Appended by the bmad-loop orchestrator (`bmad-loop confirm`, #335): a human confirmed these external actions out of band, and the story was advanced from `awaiting-operator` to `done`._
