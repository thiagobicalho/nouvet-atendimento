---
title: 'Story 1.2 — A mensagem chega e não se perde'
type: 'feature'
created: '2026-09-21'
status: 'awaiting-operator'
baseline_revision: 'af8f3915815a84ec65e0e8b9884c5bb7a6d22cff'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '_bmad-output/implementation-artifacts/epic-1-context.md'
warnings: ['oversized']
operator_actions:
  - >-
    Reimportar n8n/workflows/01 - Agente.json na instância real por cima do workflow
    "01 - Agente" (id ivPwIf28PgVGX8LW, hoje active=true com o conteúdo antigo/webhook)
    — a instância ainda serve tráfego real com a versão pré-story.
  - >-
    Importar/ativar n8n/workflows/07 - Ingresso e Fila.json na instância real (já
    criado inativo via MCP como id DGXyvswqTtv6JAV8) e só então ativar os dois
    workflows.
  - >-
    Reconfigurar o webhook no painel Tallos (Integrações > Webhooks,
    app.tallos.com.br) para apontar para 07 - Ingresso e Fila.json em vez do endpoint
    antigo de 01, e confirmar que o fluxo legado do Tallos (menu fixo/opt-in) não
    compete pelo mesmo número.
  - >-
    Rodar um teste real com telefone de teste — mandar 3 mensagens picadas em
    sequência e confirmar que chega exatamente 1 resposta; mandar uma mensagem com
    vírgula e confirmar que ela é gravada e respondida normalmente (valida a correção
    do bug de "Enfileirar mensagem"); mandar uma mensagem nova enquanto a anterior
    ainda está sendo processada e confirmar que ela entra em um novo ciclo antes do
    lock liberar (valida o fechamento da janela de corrida).
  - >-
    Decidir o teto de iterações do loop de reconferência de pendências em 07 ("Há
    mensagens pendentes?" -> "Esperar") e o que fazer ao atingi-lo, antes de expor o
    fluxo a tráfego real de alto volume (registrado como deferred, mas é decisão de
    produto, não um patch).
deferred:
  - summary: >-
      A janela de corrida entre reconferir a fila e liberar o lock não é atômica (dois
      statements Postgres sequenciais, não uma única função).
    evidence: |-
      `Buscar mensagens pendentes` (SELECT) e `Liberar Lock` (UPDATE via
      lock_conversa_liberar) são duas chamadas separadas em `07 - Ingresso e Fila.json`.
      Uma mensagem inserida exatamente entre as duas ainda pode ficar sem execução
      agendada para buscá-la — a story reduz a janela de "toda a espera + processamento"
      (bug original) para o intervalo entre dois statements sequenciais, mas não a fecha
      por completo. Fechar de verdade exigiria uma função Postgres nova (ex.
      `lock_conversa_liberar_se_vazio`), fora do escopo desta story.
    location: n8n/workflows/07 - Ingresso e Fila.json (Buscar mensagens pendentes / Liberar Lock)
    severity: low
  - summary: >-
      O loop de reconferência de pendências não tem limite de iterações nem timeout.
    evidence: |-
      Um cliente que mande mensagens continuamente mais rápido que a janela de 8s do
      `Esperar` fecha mantém a mesma execução em loop indefinidamente, seguindo o lock
      aberto sem corte. Definir um teto e o que fazer ao atingi-lo (responder e encerrar?
      escalar?) é decisão de produto, não um patch trivial.
    location: n8n/workflows/07 - Ingresso e Fila.json (Há mensagens pendentes? -> Esperar)
    severity: medium
  - summary: >-
      Nem `Chamar Agente Nouvet` nem `Enviar resposta RD Conversas` têm onError/retry;
      falha em qualquer um deixa o lock preso até o TTL expirar, sem alerta.
    evidence: |-
      Comportamento pré-existente (o `01 - Agente.json` original também não tinha
      onError nesse trecho) só realocado, não introduzido por esta story. Mesma classe
      do DW-52 já registrado (falta de onError/retryOnFail em chamada à API Tallos).
    location: n8n/workflows/07 - Ingresso e Fila.json (Chamar Agente Nouvet / Enviar resposta RD Conversas)
    severity: medium
  - summary: >-
      Fila e lock são chaveados pelo telefone bruto (não normalizado), enquanto a
      identidade usa o telefone normalizado — os dois podem divergir de formatação.
    evidence: |-
      Comportamento pré-existente, só realocado de `01` para `07`. Divergência de
      formatação do mesmo número entre mensagens poderia, em tese, fazer debounce/lock
      tratarem duas mensagens do mesmo cliente como sessões diferentes.
    location: n8n/workflows/07 - Ingresso e Fila.json (Enfileirar mensagem / Adquirir Lock / Liberar Lock)
    severity: low
  - summary: >-
      `Enviar resposta RD Conversas` consome `$json.output` sem checar presença/formato.
    evidence: |-
      Pré-existente (mesma leitura direta já existia no `01 - Agente.json` original).
      Se `Agente Nouvet` (ou uma falha no meio do caminho) não produzir `output`, o
      cliente pode receber texto vazio/"undefined" pelo RD Conversas.
    location: n8n/workflows/07 - Ingresso e Fila.json (Enviar resposta RD Conversas)
    severity: medium
  - summary: >-
      `id_mensagem` pode ficar nulo se nenhum dos campos de fallback do payload existir,
      quebrando o dedup por `ON CONFLICT (id_mensagem)`.
    evidence: |-
      Pré-existente em `Extrair dados da mensagem` (cadeia
      `message_id || id || uuid`), só realocada para `07`, não alterada por esta story.
    location: n8n/workflows/07 - Ingresso e Fila.json (Extrair dados da mensagem)
    severity: medium
  - summary: >-
      Não existe harness de teste de execução real para workflows n8n neste repositório
      (nem para esta story, nem para nenhuma anterior) — toda verificação aqui é
      estrutural (JSON válido, topologia via MCP), nunca uma execução real contra
      Postgres/RD Conversas.
    evidence: |-
      Limitação de ambiente pré-existente e já registrada informalmente (party-mode,
      Murat: "zero harness de teste pros workflows"), não introduzida por esta story;
      aplica-se aos dois defeitos corrigidos aqui (vírgula no Postgres e falta de
      executeOnce) e ao novo loop de reconferência — nenhum dos três tem uma execução
      real comprovando o comportamento, só inspeção de código/estrutura.
    location: n8n/workflows/ (todos os workflows)
    severity: medium
---

<intent-contract>

## Intent

**Problem:** Hoje o webhook do RD Conversas, o debounce/lock/agregação e a lógica de raciocínio do agente vivem no mesmo arquivo (`01 - Agente.json`), violando `AD-20` (camada de ingresso deve ser substituível e separada). Além disso a investigação encontrou dois defeitos reais e já incidentados: `Enfileirar mensagem` ainda quebra com vírgula no texto do cliente (causou perda real de mensagem em 11/09), e `Agregar mensagens` roda uma vez por item da fila em vez de uma vez só, gerando respostas duplicadas quando chegam 2+ mensagens picadas.

**Approach:** Extrair webhook + debounce + lock + agregação para um sub-workflow próprio novo (`07 - Ingresso e Fila.json`, `AD-20`), que chama `01 - Agente.json` (agora um `executeWorkflowTrigger`, sem webhook) passando só o contrato fixo (`contact_id`, `telefone`, `mensagem_agregada`) e recebe de volta o texto da resposta. Corrigir os dois defeitos achados no material movido e fechar a janela de corrida em que uma mensagem chega tarde demais para o lote em processamento mas cedo demais para uma nova execução destravar o lock.

## Boundaries & Constraints

**Always:**
- Toda mensagem que não seja o comando `/resetar` é gravada em `n8n_fila_mensagens` (`ON CONFLICT (id_mensagem) DO NOTHING`) antes de qualquer outro processamento (AC do PRD, já é o comportamento atual) — `/resetar` é um atalho de teste que nunca passou pela fila, preservado como estava.
- Todo `queryReplacement` de node Postgres com mais de um valor usa o formato de array literal `={{ [a, b, c] }}` (padrão já estabelecido em `02`–`06`) — nunca concatenação de expressões separadas por vírgula literal no mesmo campo.
- O node que agrega a fila (`Set`) roda com `executeOnce: true` — nunca produz mais de um item de saída por execução.
- `01 - Agente.json` (agora sub-workflow) recebe só `contact_id`, `telefone`, `mensagem_agregada` — nunca um payload bruto de webhook nem detalhe de transporte.
- Lock só é liberado quando `n8n_fila_mensagens` não tem mais linha `processada = false` para aquele telefone — enquanto houver, o ciclo espera/agrega/responde de novo antes de liberar.
- Comando `/resetar` continua tratado antes da fila (bypass total do agente), preservando o comportamento atual.

**Block If:** Nenhuma decisão bloqueante identificada — a forma de entrada (`AD-20`) já tem plano de fundo adotado (webhook assíncrono, opção A), e a extração usa exclusivamente padrões já validados em `02`–`06`.

**Never:**
- Nunca reintroduzir `queryReplacement` com vírgula separando parâmetros de um mesmo campo.
- Nunca tocar `identidade_cliente_pet_buscar`/`Buscar Identidade` (Story 1.5 é dona da identidade real) — mover os nodes de posição sem alterar sua query.
- Nunca ativar (`active: true`) os workflows no n8n real, nem mexer no fluxo legado do Tallos (menu fixo) ainda ativo em paralelo — fora do alcance deste build.
- Nunca alterar o conteúdo/prompt do `Agente Nouvet` (identidade, tom, tools) — isso é Story 1.3.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Mensagem com vírgula | `mensagem` contém `,` (ex. "Oi, tudo bem?") | `Enfileirar mensagem` grava os 4 campos corretamente, sem desalinhamento de parâmetro | Nenhum erro esperado |
| 3 mensagens picadas | 3 webhooks do mesmo telefone em poucos segundos | Só 1 execução mantém o lock; ao agregar, exatamente 1 item de saída com as 3 mensagens juntas; 1 resposta enviada | As outras 2 execuções não adquirem lock e terminam sem processar |
| Mensagem chega durante o envio da resposta | Nova mensagem grava na fila entre `Buscar mensagens` e `Liberar Lock` | Antes de liberar o lock, nova checagem encontra a mensagem pendente e repete o ciclo (espera → agrega → responde) para ela, sem liberar lock no meio | Nenhuma mensagem fica órfã na fila |
| Falha após enfileirar | Enfileirar mensagem grava, mas o node seguinte falha | Mensagem permanece em `n8n_fila_mensagens` com `processada = false`; nenhuma perda | Próxima execução que adquirir o lock a inclui no lote |
| Lock ocupado | `lock_conversa_adquirir` retorna `false` | Execução termina sem tocar a fila do outro processamento | Nenhum erro — comportamento esperado, não exceção |

</intent-contract>

## Code Map

- `n8n/workflows/01 - Agente.json` -- arquivo atual com 30 nodes; webhook `Mensagem recebida` (path `atendimento-nouvet-recepcao`, `webhookId: 60d6af6c-...`) até `Liberar Lock`. Fluxo completo: `Set Telefone de teste`→`If`(gate de telefone de teste, `AD-30`/`NFR-10`, fora de escopo desta story — Story 1.3 é dona, só relocar)→`Extrair dados da mensagem`→`É comando de reset?`→[`Limpar memória`→`Montar confirmação de reset`→`Enviar confirmação de reset`] ou [`Enfileirar mensagem`→`Buscar Config`→`Adquirir Lock`→`Lock adquirido?`→[`Esperar`→`Buscar mensagens`→`Agregar mensagens`→`Normalizar telefone`→`Buscar Identidade`→`Info`→`Agente Nouvet`→`Enviar resposta RD Conversas`→`Marcar mensagens processadas`→`Liberar Lock`] ou [`Outra execução já está processando`]].
- `n8n/workflows/01 - Agente.json:"Enfileirar mensagem"` -- `queryReplacement: "={{ $json.id_mensagem }},{{ $json.telefone }},{{ $json.mensagem }},{{ $json.timestamp }}"` -- **defeito real confirmado**: `mensagem` é texto livre do cliente e quase sempre contém vírgula; o node Postgres separa parâmetros por vírgula mesmo dentro de uma única expressão resolvida — causou perda real de mensagem em produção (`.claude/skills/n8n-agent-patterns/.analysis` não cobre isso; evidência em `_bmad-output/party-mode/memories/installed/.memlog.md`, linha "morreu no 'Enfileirar mensagem' por virgula", exec 461380, 11/09). Corrigir para `={{ [$json.id_mensagem, $json.telefone, $json.mensagem, $json.timestamp] }}` -- mesmo padrão já usado em `04 - Registrar Atendimento CRM.json` ("Resolver Identidade (1ª chamada)").
- `n8n/workflows/01 - Agente.json:"Adquirir Lock"` -- mesmo formato antigo (`={{ telefone }},{{ lock_ttl_minutos }}`) — telefone raramente contém vírgula mas o padrão é frágil; alinhar ao mesmo formato de array literal por consistência com o `Always`.
- `n8n/workflows/01 - Agente.json:"Marcar mensagens processadas"` -- já foi corrigida uma vez (commit `28292b5`) com `string_to_array($1,';')` + `.join(';')`; ao mover para o novo arquivo, trocar pelo padrão de array literal mais recente (`={{ [...] }}` + `ANY($1::bigint[])`, sem `string_to_array`), igual ao usado em `05 - Gerenciar Task SLA.json`.
- `n8n/workflows/01 - Agente.json:"Agregar mensagens"` -- Set node sem `"executeOnce": true` no nível do node (só tem `parameters`/`type`/`position`/`id`/`name`). **Defeito real confirmado**: com N mensagens em `Buscar mensagens` (retorno `returnAll: true`), o Set roda uma vez por item de entrada e emite N itens idênticos, cada um levando a agregação inteira para a frente — resulta em N chamadas ao agente e N respostas para o mesmo lote (achado do party-mode, memlog "bug de 2 outputs (Agregar mensagens emite 1 item por entrada, sem Execute Once)", 11/09). Corrigir adicionando `"executeOnce": true` ao node.
- `n8n/workflows/02 - Escalar Humano.json:"Normalizar Telefone (Registro CRM)"`, `04 - Registrar Atendimento CRM.json`, `05 - Gerenciar Task SLA.json`, `06 - Lembretes e Escalonamento SLA.json` -- todos usam `queryReplacement` como array literal `={{ [a, b, c] }}` -- é o padrão vigente a seguir, não o formato antigo de `01`.
- `n8n/workflows/02 - Escalar Humano.json:"Receber Solicitação"` -- exemplo do padrão `executeWorkflowTrigger` (nome do node, `workflowInputs.values` com lista de nomes) a replicar no novo `01 - Agente.json` sem webhook.
- `n8n/workflows/04 - Registrar Atendimento CRM.json:"Gerenciar Task SLA (CAP-8)"` -- exemplo do padrão de chamada determinística entre workflows (`n8n-nodes-base.executeWorkflow`, `workflowId.__rl` + `workflowInputs.mappingMode: defineBelow` + `value`/`schema`) — usar esse padrão (não `toolWorkflow`, que é só para chamada decidida pelo agente LangChain) para o novo `07` chamar `01`.
- `n8n/migrations/0005_debounce_lock_ttl.sql` -- `lock_conversa_adquirir(p_session_id, p_ttl_minutos)`/`lock_conversa_liberar(p_session_id)`, coluna `processada` e índice único `idx_n8n_fila_mensagens_id_mensagem` -- contrato Postgres já pronto (Story 3 antiga), reusar sem alterar.
- `n8n/migrations/0010_atendimento_config_ler_lock_ttl.sql` -- `atendimento_config_ler('triagem')` já expõe `lock_ttl_minutos` -- reusar a mesma chamada tanto no novo `07` (para o lock) quanto, separadamente, dentro de `01` (para o restante da config que `Info` usa) — leitura seletiva por componente, `AD-1`.
- `n8n/workflows/README.md` -- documentar o novo `07 - Ingresso e Fila.json` e atualizar a descrição de `01` (deixa de ser o dono do webhook).
- `.claude/skills/rd-station-api/references/conversas.md` -- confirma `POST /v2/messages/{contact_id}/send` (form-urlencoded, base `https://api.tallos.com.br`) e que o webhook de entrada é configurado no painel Tallos, sem schema REST documentado — mesma suposição já aceita desde a Story 5 para o payload de entrada.
- MCP `n8n` (`n8n_list_workflows`, confirmado nesta story) -- instância real multi-tenant (`myeditor.uniqueads.com.br`); workflows `02`/`04`/`05` já existem lá com IDs reais (`FqnT8o7xsNXqqO5f`/`wM1W1HCY5w4aitwS`/`QSZnJJf5zYVP8DQh`) — mesmo mecanismo (criar workflow via MCP para obter um ID real, mantendo `active: false`) se aplica ao novo `07`.

## Tasks & Acceptance

**Execution:**
- `n8n/workflows/07 - Ingresso e Fila.json` -- criar novo workflow: mover `Mensagem recebida` (webhook, mesmo path/`webhookId`), `Set Telefone de teste`, `If`, `Extrair dados da mensagem`, `É comando de reset?`, `Limpar memória`, `Montar confirmação de reset`, `Enviar confirmação de reset`, `Enfileirar mensagem` (corrigida), `Buscar Config`, `Adquirir Lock` (corrigida), `Lock adquirido?`, `Outra execução já está processando`, `Esperar`, `Buscar mensagens`, `Agregar mensagens` (corrigida com `executeOnce`), `Enviar resposta RD Conversas`, `Marcar mensagens processadas` (corrigida) e `Liberar Lock` -- extrai a camada de ingresso para um sub-workflow próprio (`AD-20`).
- `n8n/workflows/07 - Ingresso e Fila.json` -- adicionar node `executeWorkflow` ("Chamar Agente Nouvet") entre `Agregar mensagens` e `Enviar resposta RD Conversas`, apontando para o workflow `01 - Agente.json` (id obtido via MCP na criação), passando `contact_id`, `telefone`, `mensagem_agregada` -- fecha o contrato fixo do `AD-20`.
- `n8n/workflows/07 - Ingresso e Fila.json` -- entre `Marcar mensagens processadas` e `Liberar Lock`, adicionar node `Buscar mensagens pendentes` (mesma query de `Buscar mensagens`, filtrando `processada = false`) e um `If`: se houver linha, voltar para `Esperar` (novo ciclo, lock mantido); se vazio, seguir para `Liberar Lock` -- fecha a janela de corrida em que uma mensagem chega entre a agregação e a liberação do lock.
- `n8n/workflows/01 - Agente.json` -- remover todos os nodes movidos para `07`; substituir `Mensagem recebida` por um `executeWorkflowTrigger` ("Receber Turno") com `workflowInputs.values` = `contact_id`, `telefone`, `mensagem_agregada`; adicionar um node `Buscar Config` próprio (`atendimento_config_ler('triagem')`) logo no início, já que `Info` depende dele e o `07` não repassa mais o config inteiro; manter `Normalizar telefone`, `Buscar Identidade`, `Info`, `Agente Nouvet`, `Memory`, `Refletir`, `Escalar Humano`, `Buscar Info Setor`, `Registrar Atendimento CRM`, `OpenRouter Chat Model` sem alteração de conteúdo -- reduz `01` ao contrato fixo do `AD-20`.
- `n8n/workflows/README.md` -- adicionar entrada para `07 - Ingresso e Fila.json` e atualizar a descrição de `01 - Agente.json` (deixa de ter webhook, vira sub-workflow de raciocínio).

**Acceptance Criteria:**
- Given uma mensagem chegando pelo RD Conversas, when o webhook de `07 - Ingresso e Fila.json` dispara, then a mensagem é gravada em `n8n_fila_mensagens` antes de qualquer outro processamento, mesmo que o texto contenha vírgula.
- Given três mensagens do mesmo cliente em intervalo curto, when a janela de agregação fecha, then exatamente um item agregado é produzido e exatamente uma resposta é enviada (nunca uma por mensagem).
- Given uma conversa já em processamento (lock ativo), when chega nova mensagem do mesmo cliente, then nenhuma segunda execução processa em paralelo, e a mensagem é incluída no lote atual ou em um novo ciclo antes do lock ser liberado — nunca fica pendente sem próximo ciclo agendado.
- Given `01 - Agente.json` como ponto de partida, when esta story é entregue, then a camada de ingresso é um sub-workflow próprio (`07`), `01` só recebe `contact_id`/`telefone`/`mensagem_agregada` via `executeWorkflowTrigger`, e nenhum node Postgres usa vírgula como separador de lista de parâmetros em nenhum dos dois arquivos.
- Given falha depois que a mensagem foi enfileirada (ex.: `Chamar Agente Nouvet` falha), when se inspeciona `n8n_fila_mensagens`, then a mensagem segue com `processada = false`, pronta para ser incluída na próxima execução que adquirir o lock.

## Spec Change Log

_Nenhuma entrada — sem loopback `bad_spec` nesta execução._

## Review Triage Log

### 2026-09-21 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 4 (low 4)
- defer: 7 (medium 5, low 2)
- reject: 2
- addressed_findings:
  - `[low]` `[patch]` A regra "Always" de enfileirar toda mensagem não ressalvava o comando `/resetar` (que sempre pulou a fila, comportamento pré-existente) — reformulada no spec para excluir `/resetar` explicitamente.
  - `[low]` `[patch]` O branch falso do gate de telefone de teste (`If`, em `07`) terminava sem nenhuma anotação explicando que é um dead-end intencional (Story 1.3) — adicionada nota no node.
  - `[low]` `[patch]` `README.md` listava `07 - Ingresso e Fila.json` logo após a descrição genérica de `02+` (sub-workflows chamados por `01`), podendo sugerir que `07` é mais uma ferramenta do agente — reordenado e explicitado que `07` chama `01`, não o contrário.
  - `[low]` `[patch]` A seção de Verificação do spec não cobria explicitamente o `executeOnce` do novo node `Há mensagens pendentes?` (mesma classe de defeito do `Agregar mensagens` original) — adicionado item de checagem manual; conferido agora que o node já tem `"executeOnce": true`.
  - `reject`: sugestão de eliminar a duplicação entre `Buscar mensagens` e `Buscar mensagens pendentes` — duplicação é idiomática do modelo de nodes deste projeto (mesmo padrão já aceito para `Buscar Config`, duplicado entre `01` e `07`).
  - `reject`: sugestão de adicionar validação de tipo/obrigatoriedade nos inputs do `executeWorkflowTrigger` — nenhum trigger existente em `02`–`06` tem essa validação; não é uma inconsistência introduzida por esta story.
  - 6 achados (janela de corrida residual não-atômica, loop sem teto de iterações, ausência de onError em `Chamar Agente Nouvet`/`Enviar resposta`, chave de lock/fila por telefone não normalizado, `$json.output` sem fallback, `id_mensagem` podendo ficar nulo) e 1 achado de lacuna de verificação (ausência de harness de execução real para workflows n8n neste repositório) registrados em `deferred` no frontmatter — a maioria é comportamento pré-existente apenas realocado para `07`, não introduzido por esta story; o teto de iterações do novo loop é a única exceção genuinamente nova, mas depende de decisão de produto (o que fazer ao atingir o teto), não é um patch trivial.

## Design Notes

**Por que dividir em dois arquivos, e não só corrigir os bugs no lugar.** `AD-20` exige que a camada de ingresso seja um sub-workflow substituível, e a Story 1.4 (`AD-20`) precisa de um segundo ponto de entrada chamando "o mesmo sub-workflow" de raciocínio — só é possível se esse sub-workflow (`01`) já existir separado do webhook antes da 1.4 chegar. Por isso a extração é feita agora, não adiada.

**Por que `01 - Agente.json` mantém o nome.** O `workflowId` real (usado por toda referência entre arquivos) não depende do nome do arquivo exportado; renomear traria só custo de revisão sem ganho. `07` foi escolhido por ser o próximo número livre (`01`–`06` já ocupados) — não é chamado como ferramenta pelo agente (por isso não é `toolWorkflow` como `02`/`03`/`04`), é quem chama `01`, então a numeração alta reflete só ordem de criação, não hierarquia.

**Por que `01` volta a ter seu próprio `Buscar Config`.** O contrato do `AD-20` é deliberadamente mínimo (identificação do contato, texto agregado, estado da conversa) — não inclui a config inteira. Repassar a config lida pelo `07` acoplaria o contrato ao que `Info` precisa hoje, quebrando de novo na primeira mudança de prompt (Story 1.3). Duas leituras seletivas (uma em cada arquivo, cada uma só do que aquele arquivo usa) custam uma query Postgres extra por turno e mantêm os dois arquivos genuinamente independentes.

**Por que fechar a janela de corrida entra no escopo desta story, e não fica deferred.** A AC do PRD diz explicitamente "nenhum processamento paralelo é iniciado" e "entra no mesmo lote" — sem o loop de reconferência antes de liberar o lock, uma mensagem que chega entre `Buscar mensagens` e `Liberar Lock` fica na fila sem qualquer execução agendada para buscá-la, e só seria pega na próxima mensagem nova do cliente (que pode nunca vir), violando `NFR-2`. É o mesmo tipo de "achado CRÍTICO" que a `0005` já resolveu para o TTL do lock — aqui é o equivalente para o fechamento do lote.

## Verification

**Manual checks (sem ambiente n8n real neste build):** verificações abaixo executadas nesta story; verificação de execução real fica com o operador (ver `operator_actions`).
- Revisar `07 - Ingresso e Fila.json` e `01 - Agente.json` por inspeção: todo `queryReplacement` multi-valor usa `={{ [...] }}`; `Agregar mensagens` tem `"executeOnce": true`; nenhum node de `07` foi perdido na migração; `01` não tem mais node `n8n-nodes-base.webhook`.
- Conferir que `Há mensagens pendentes?` também tem `"executeOnce": true` (mesma classe de defeito de `Agregar mensagens`: sem isso, N linhas pendentes fariam o `If` rodar N vezes) e que o loop de volta para `Esperar` está de fato conectado — esta é a única parte desta story sem precedente direto no código já existente (o restante são padrões de `02`–`06`), então merece checagem própria, não só herdar a confiança do padrão.
- Conferir com `python3 -c "import json; json.load(open(...))"` que os dois arquivos são JSON válido antes de commitar.
- Confirmar via MCP `n8n_get_workflow` (mode `structure`) que o workflow `07` criado na instância real reflete a mesma topologia do arquivo exportado, e que ambos permanecem `active: false`.
- Importar/ativar de fato no n8n real, configurar o webhook no painel Tallos apontando para `07`, e rodar o roteiro de teste com telefone real fica para o operador (mesma limitação de ambiente da Story 1.1 -- este build não alcança a instância de forma seletiva sem risco a outros tenants).

## Auto Run Result

**Status:** `awaiting-operator` — todo o código desta story está implementado, revisado e commitado; falta só verificação de execução real contra o n8n/Postgres/RD Conversas de verdade, que exige o operador (ver `operator_actions`).

**Resumo do que foi implementado:** extração da camada de ingresso (`AD-20`) do `01 - Agente.json` original para um novo sub-workflow `07 - Ingresso e Fila.json` — webhook, gate de telefone de teste, comando `/resetar`, enfileiramento, lock com TTL, espera, agregação e um novo ciclo de reconferência antes de liberar o lock. `01 - Agente.json` fica reduzido ao raciocínio do agente, recebendo `contact_id`/`telefone`/`mensagem_agregada` via `executeWorkflowTrigger`. Dois defeitos reais e já incidentados foram corrigidos no material movido: `Enfileirar mensagem` (vírgula no texto do cliente quebrava o parâmetro Postgres, causou perda real de mensagem em 11/09) e `Agregar mensagens` (rodava uma vez por item da fila em vez de uma vez só, gerando respostas duplicadas) — ambos usando o padrão de array literal já validado em `02`–`06`. Foi fechada também a janela em que uma mensagem chegada durante o envio da resposta ficava sem próxima execução agendada para buscá-la.

**Arquivos alterados:**
- `n8n/workflows/07 - Ingresso e Fila.json` -- novo sub-workflow de ingresso (23 nodes); criado também na instância real via MCP (`id DGXyvswqTtv6JAV8`, `active: false`).
- `n8n/workflows/01 - Agente.json` -- reduzido a 12 nodes (raciocínio do agente); só o arquivo local mudou, a instância real (`id ivPwIf28PgVGX8LW`) segue com o conteúdo antigo até o operador reimportar.
- `n8n/workflows/README.md` -- documenta `07` e o novo papel de `01`.

**Findings da revisão:** ver `## Review Triage Log` acima — 4 `patch` aplicados (todos baixo: ressalva do `/resetar` na regra "Always", nota explicando o dead-end do gate de telefone de teste, reordenação do README, item de verificação do `executeOnce` em `Há mensagens pendentes?`), 7 `defer` (registrados em `deferred` no frontmatter — a maioria comportamento pré-existente só realocado, exceto o teto de iterações do novo loop, que é decisão de produto), 2 `reject` (duplicação de query entre `Buscar mensagens`/`Buscar mensagens pendentes`, e falta de validação de tipo no `executeWorkflowTrigger` — ambos consistentes com o padrão já aceito no resto do código).

**Verificação realizada:**
- `python3 -c "import json; json.load(open(...))"` -- os dois arquivos são JSON válido.
- Inspeção programática: nenhum node perdido na extração; nenhuma referência de conexão pendurada; `01` sem node `webhook`; `07` com exatamente um; todo `queryReplacement` multi-valor usa `={{ [...] }}` (incluindo o caso `ANY($1::bigint[])`, confirmado contra o precedente real de `06 - Lembretes e Escalonamento SLA.json`); `Agregar mensagens` e `Há mensagens pendentes?` com `"executeOnce": true`; loop `Há mensagens pendentes? -> Esperar` conectado de fato.
- Diff byte-a-byte contra `HEAD` confirmando que `Agente Nouvet` (prompt completo), `Buscar Identidade`, os três `toolWorkflow` e o `OpenRouter Chat Model` não mudaram de conteúdo.
- MCP `n8n_get_workflow` (`structure`/`filtered`) confirmando que o `07` criado na instância real reflete a mesma topologia e os mesmos parâmetros corrigidos do arquivo exportado, e que `ivPwIf28PgVGX8LW` (referenciado por `Chamar Agente Nouvet`) é de fato o id real de `01 - Agente` na instância.
- **Não verificado neste ambiente** (sem n8n/Postgres/RD Conversas real alcançável sem risco a outros tenants): execução real de qualquer um dos três comportamentos corrigidos/adicionados (vírgula no Postgres, `executeOnce`, loop de reconferência) — itens de `operator_actions`.

**Riscos residuais:**
- Ver os 7 itens em `deferred` no frontmatter — nenhum bloqueia esta story, mas o teto de iterações do loop de reconferência (novo, não pré-existente) merece decisão de produto antes de tráfego real de alto volume, e a ausência de onError em `Chamar Agente Nouvet`/`Enviar resposta RD Conversas` (pré-existente) deixa o lock preso até o TTL expirar em caso de falha.
- Nenhum dos três comportamentos corrigidos/adicionados nesta story foi comprovado por execução real — só por inspeção estrutural, mesma limitação de ambiente da Story 1.1.
