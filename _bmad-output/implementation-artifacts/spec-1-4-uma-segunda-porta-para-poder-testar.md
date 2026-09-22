---
title: 'Story 1.4 — Uma segunda porta, para poder testar'
type: 'feature'
created: '2026-09-21'
status: done
baseline_revision: 'a13a9f9531ffbed0b6766980d1b3b1d7edbcdcf5'
review_loop_iteration: 0
followup_review_recommended: true
operator_actions:
  - >-
    Importar n8n/workflows/08 - Entrada de Teste.json na instância n8n real (via UI ou
    `n8n import:workflow --input="n8n/workflows/08 - Entrada de Teste.json"`) e ativá-lo
    (active: true) -- o webhook só responde em /webhook/atendimento-nouvet-teste quando
    ativo; hoje o workflow existe só no repositório.
  - >-
    Rodar `docker compose run --rm bancada-teste` de fato contra a instância real (com
    `08` já importado e ativo) e confirmar que um transcrito do caso
    `1-banho-conhecido` foi gravado em bancada-teste/transcritos/ -- este build só
    verificou o runner contra um servidor HTTP mock local, nunca contra o `01 - Agente`
    de verdade.
  - >-
    Rodar `docker compose config` de verdade (Docker CLI não estava disponível neste
    ambiente de build) para confirmar a sintaxe real do novo serviço `bancada-teste` --
    este build só verificou via parse YAML equivalente (PyYAML), não com o comando real.
  - >-
    Ler o transcrito gerado pelo caso `1-banho-conhecido` e confirmar humanamente que a
    resposta da Nouvi é aceitável para o estágio atual do produto -- o julgamento
    passou/não passou é sempre humano, nunca calculado por este build (ver Design
    Notes desta story sobre por que o caso canônico ainda não deve "passar" por
    completo).
context:
  - '_bmad-output/implementation-artifacts/epic-1-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Nenhuma validação server-side impede que a entrada de teste (`08`) receba um
      telefone real -- a convenção de DDD `00` é aplicada só do lado do cliente, em
      `bancada-teste/rodar.py`.
    evidence: |-
      `n8n/workflows/08 - Entrada de Teste.json` repassa `contact_id`/`telefone`/
      `mensagem_agregada` do corpo da requisição direto para `01 - Agente.json`, sem
      nenhuma validação de formato. Risco baixo: endpoint interno de teste, path
      distinto da entrada de produção (`07`), nunca anunciado como porta pública.
    location: 'n8n/workflows/08 - Entrada de Teste.json'
    severity: low
  - summary: >-
      `01 - Agente.json` hoje não tem nenhuma ferramenta conectada (Story 1.3), então
      rodar a bancada não aciona nenhum efeito colateral real hoje -- mas quando
      ferramentas voltarem (Stories 1.8-1.10), rodar a bancada poderá acionar efeitos
      colaterais reais (ex. registro em CRM) sem que nada nesta story isole isso.
    evidence: |-
      `n8n/workflows/README.md` confirma que `Agente Nouvet` está sem `ai_tool`
      conectado desde a Story 1.3. Nada em `08 - Entrada de Teste.json` ou
      `bancada-teste/` impede que uma ferramenta futura escreva de verdade quando
      chamada pela bancada.
    location: 'n8n/workflows/01 - Agente.json'
    severity: low
  - summary: >-
      O serviço `bancada-teste` roda como root dentro do container
      (`python:3.12-slim`, sem `user:`), então os transcritos gravados no host via
      bind mount ficam com dono root.
    evidence: |-
      `docker-compose.yml`, serviço `bancada-teste`, sem `user:` definido -- fricção
      de desenvolvimento (permissão pra editar/apagar), não risco de dado (transcritos
      são gitignored e não carregam PII real).
    location: 'docker-compose.yml'
    severity: low
  - summary: >-
      O timeout HTTP de 120s em `chamar_entrada_de_teste` é fixo no código-fonte, sem
      variável de ambiente para ajuste.
    evidence: |-
      `bancada-teste/rodar.py`, `urllib.request.urlopen(requisicao, timeout=120)` --
      uma cadeia de agente mais lenta no futuro exigiria editar o código, já que
      `BANCADA_TESTE_URL` estabeleceu a convenção de configuração via variável de
      ambiente, mas o timeout não a segue.
    location: 'bancada-teste/rodar.py'
    severity: low
  - summary: >-
      Se a chamada a `01 - Agente` exceder o timeout de 120s do cliente Python, o n8n
      pode seguir executando no servidor e gravar em `Memory` depois que o runner já
      registrou aquele turno como falha -- o próximo turno da mesma sessão poderia
      refletir uma resposta que o transcrito já marcou como falha.
    evidence: |-
      `chamar_entrada_de_teste` cancela do lado do cliente ao estourar `timeout=120`,
      mas nada em `08 - Entrada de Teste.json` limita a execução do lado do servidor
      -- a chamada a `01` pode terminar depois, gravando em `Memory` (chave `telefone`,
      compartilhada entre turnos da mesma sessão).
    location: 'bancada-teste/rodar.py; n8n/workflows/08 - Entrada de Teste.json'
    severity: low
  - summary: >-
      Ausência de teste automatizado para o parser mínimo de `casos/*.yaml` e para
      `gerar_identidade_sintetica` -- hoje só verificados manualmente nesta story.
    evidence: |-
      `bancada-teste/` não tem uma suíte de testes, diferente de `import/tests/`
      (Story 1.1, pytest) para uma complexidade análoga (parsing + geração
      determinística de identidade sintética).
    location: 'bancada-teste/rodar.py'
    severity: low
---

<intent-contract>

## Intent

**Problem:** Hoje a única forma de ouvir a Nouvi responder é passar pelo fluxo real (`07 - Ingresso e Fila.json` → RD Conversas) — testar qualquer comportamento, ou comparar modelos de LLM mais tarde, exige gastar mensagem real e arriscar tocar em cliente real. Não existe caminho pra rodar um caso, ler a resposta e repetir, sem esse custo/risco.

**Approach:** Criar uma segunda entrada n8n — webhook síncrono (`responseMode: responseNode`) que chama o mesmo sub-workflow `01 - Agente.json` já isolado, pelo contrato fixo de `Receber Turno` — e um programa standalone que dispara casos de teste turno a turno contra essa entrada e grava o transcrito para leitura humana, semeando a bancada com a conversa canônica de banho.

## Boundaries & Constraints

**Always:**
- A nova entrada chama `01 - Agente.json` (workflowId `ivPwIf28PgVGX8LW`, mesmo usado por `07`) pelo contrato exato de `Receber Turno` (`contact_id`/`telefone`/`mensagem_agregada`) — nunca duplica ou reimplementa a lógica do agente.
- Cada caso de teste usa `telefone`/`contact_id` sintético e isolado, nunca um telefone real de cliente nem reaproveitado entre casos — `Memory` usa `telefone` como `sessionKey` (Story 1.2/1.3).
- A bancada nasce com a conversa canônica de banho, cliente conhecido, dos seis turnos (`_bmad-output/planning-artifacts/design-conversa/2026-09-18-design-de-conversa-onda1.md`, seção 2), reproduzida turno a turno na mesma sessão isolada.
- Execução dos casos é automática (dispara e coleta); o veredito passou/não passou é sempre humano, lendo o transcrito — o entregável é o conjunto de transcritos, nunca um resumo verde/vermelho calculado pelo script.

**Block If:** Nenhuma decisão bloqueante — contrato, escopo e formato de entrega já resolvidos pelo epic context e pelas ACs; nada aqui depende de decisão do Thiago.

**Never:**
- Nunca chamar RD Conversas/Tallos ou qualquer API de mensageria a partir da nova entrada ou do script — zero mensagem real, zero cliente real alcançado (NFR-10).
- Nunca alterar `01 - Agente.json`, `07 - Ingresso e Fila.json` ou o contrato de `Receber Turno` — a nova entrada só chama o sub-workflow existente, verbatim.
- Nunca fazer o script decidir passou/falhou sozinho, nem gerar um agregado verde/vermelho — sem asserção automática de conteúdo da resposta.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Chamada única à entrada de teste | POST com `contact_id`/`telefone`/`mensagem_agregada` sintéticos | Corpo da resposta HTTP traz a fala da Nouvi (`output`) | — |
| Caso multi-turno da bancada | Mesmo telefone sintético em turnos sequenciais | Cada turno reflete o histórico dos turnos anteriores (`Memory` por telefone) | — |
| Dois casos rodando | Telefones sintéticos distintos por caso | Nenhum turno de um caso aparece no transcrito do outro | — |
| Falha real do agente (Postgres/LLM indisponível) durante um caso | Mesmo caminho de falha da Story 1.3 (`onError`→`Registrar Falha`) | Transcrito registra a mensagem de fallback honesta, não erro técnico cru | Execução do caso não trava; script segue pro próximo turno/caso |

</intent-contract>

## Code Map

- `n8n/workflows/01 - Agente.json` -- sub-workflow alvo; contrato fixo `contact_id`/`telefone`/`mensagem_agregada` → `output`; **nunca modificado** nesta story; workflowId real `ivPwIf28PgVGX8LW`.
- `n8n/workflows/07 - Ingresso e Fila.json:"Chamar Agente Nouvet"` -- referência read-only de como um `executeWorkflow` já chama o `01` com esse contrato; a nova entrada replica esse node, nunca toca este arquivo.
- `n8n/workflows/README.md` -- convenção numérica viva dos workflows; documentar a entrada `08` no mesmo padrão.
- `n8n/workflows/08 - Entrada de Teste.json` (novo) -- `Webhook` (`responseMode: responseNode`, path `atendimento-nouvet-teste`) → `executeWorkflow` pro `01` (mesmo workflowId, mesmo mapeamento de `07`) → `respondToWebhook` devolvendo `{ output }` em JSON.
- `bancada-teste/casos/1-banho-conhecido.yaml` (novo) -- primeiro caso: as 4 falas do cliente da conversa canônica de banho, na ordem exata do design de conversa.
- `bancada-teste/rodar.py` (novo) -- standalone (stdlib, sem framework): lê `casos/*.yaml`, gera telefone/contact_id sintético isolado por caso (DDD reservado `00` — não existe no Brasil, nunca colide com telefone real via `telefone_normalizar`), dispara os turnos em sequência contra a URL da entrada de teste, grava um transcrito por caso em `bancada-teste/transcritos/`.
- `docker-compose.yml` -- novo serviço `bancada-teste` (`profiles: ["tools"]`, mesma convenção do `importer` da Story 1.1), roda sob demanda via `docker compose run --rm bancada-teste`.
- `bancada-teste/README.md` (novo) -- como rodar, como ler o transcrito, como um caso novo é acrescentado por story futura.

## Tasks & Acceptance

**Execution:**
- `n8n/workflows/08 - Entrada de Teste.json` -- criar Webhook/executeWorkflow/respondToWebhook -- entrega a segunda porta.
- `bancada-teste/casos/1-banho-conhecido.yaml` -- caso canônico de banho -- semeia a bancada.
- `bancada-teste/rodar.py` -- runner que dispara casos e grava transcrito -- entrega execução automática + isolamento por sessão.
- `docker-compose.yml` -- serviço `bancada-teste` sob profile `tools` -- mantém o padrão de programa executável sob demanda, nunca rotina automática.
- `n8n/workflows/README.md`, `bancada-teste/README.md` -- documentar a nova entrada e a bancada.

**Acceptance Criteria:**
- Given `01 - Agente.json` já isolado como sub-workflow, when esta story é entregue, then existe uma segunda entrada com webhook `responseMode: responseNode` chamando o mesmo sub-workflow, e a fala da Nouvi volta no corpo da resposta HTTP, sem alterar o comportamento da entrada de produção.
- Given uma chamada à entrada de teste, when ela é feita, then nenhuma mensagem sai pelo RD nem pela Meta.
- Given vários casos de teste rodando, when cada um dispara, then cada um usa telefone/contact_id isolado e nenhum contamina o outro nem um cliente real.
- Given a bancada adversarial, when ela roda, then a execução é automática e o julgamento passou/não passou é sempre humano sobre os transcritos — o entregável é o conjunto de transcritos.
- Given a entrega desta story, when a bancada nasce, then ela já contém a conversa canônica de banho dos seis turnos rodada de ponta a ponta na mesma sessão isolada.
- Given que a entrada de teste não exercita o envio pelo RD, when isso é considerado, then a limitação fica declarada em `bancada-teste/README.md`.

## Spec Change Log

_Nenhuma entrada — sem loopback `bad_spec` nesta execução._

## Review Triage Log

### 2026-09-22 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 6 (low 6)
- defer: 6 (low 6)
- reject: 11
- addressed_findings:
  - `[low]` `[patch]` `rodar.py` não impedia dois arquivos de caso declararem o mesmo `nome`, o que quebraria o isolamento de telefone/`contact_id` sintético entre casos -- `main()` agora checa duplicidade em todos os arquivos antes de rodar qualquer caso e aborta (exit 1) com mensagem clara se encontrar uma.
  - `[low]` `[patch]` uma exceção não tratada num caso (arquivo não-UTF-8, resposta HTTP não decodificável) derrubava a bancada inteira, perdendo os transcritos de todos os outros casos -- o corpo do loop em `main()` agora está em `try/except`, reporta o erro e segue pro próximo caso.
  - `[low]` `[patch]` `output: null` virava o texto literal `"None"` no transcrito, indistinguível de uma resposta real -- `chamar_entrada_de_teste` agora detecta `None` explicitamente e devolve um marcador diagnóstico.
  - `[low]` `[patch]` `BANCADA_TESTE_URL` malformada repetia a mesma falha opaca em todo turno de todo caso -- `main()` agora valida esquema/host uma vez no início e aborta com mensagem clara antes de rodar qualquer caso.
  - `[low]` `[patch]` falha ao CHAMAR `01 - Agente` (ex. workflow desativado/removido) vazava erro bruto do n8n no corpo da resposta HTTP em vez da fala da Nouvi -- adicionado `onError: continueErrorOutput` no node `Chamar Agente Nouvet` de `08 - Entrada de Teste.json`, convergindo para um corpo JSON estruturado (`output: null`, `erro: <mensagem>`) via novo node `Montar Falha da Chamada de Teste`.
  - `[low]` `[patch]` saída bufferizada escondia o progresso por caso sob `docker compose run` -- adicionado `PYTHONUNBUFFERED: "1"` ao serviço `bancada-teste` em `docker-compose.yml`.
  - 6 achados (validação server-side ausente do DDD sintético, ausência de isolamento de efeito colateral quando ferramentas voltarem a `01` em stories futuras, container rodando como root, timeout de 120s fixo sem variável de ambiente, corrida entre timeout do cliente e execução do servidor podendo vazar entre turnos, e ausência de suíte de testes automatizada para o parser/gerador de identidade) registrados em `deferred` no frontmatter -- nenhum bloqueia esta story.
  - 11 achados rejeitados: alegação de que `.gitkeep` de `bancada-teste/transcritos/` não existia (falsa -- o arquivo foi criado e está no diff); tensão entre o nome "bancada adversarial" e só existir 1 caso não-adversarial (já contextualizado na própria seção "Como um caso novo é acrescentado" do README); `rodar_caso` não interromper os turnos restantes após uma falha de conexão (contradiz a própria AC/matriz da story: "Execução do caso não trava; script segue pro próximo turno/caso"); ausência de checagem automática de que `08` está importado/ativo antes de rodar (mesmo padrão de operador das stories irmãs 1.1-1.3); `contact_id` sintético incompatível com schema downstream (falso -- coluna é `TEXT` sem FK em `atendimento_falha_registro`); ausência de política de retenção/limpeza de transcritos (higiene local sem consequência, diretório já gitignored); bind mount do `bancada-teste` inteiro em vez de mounts mais estreitos (bikeshed, sem modelo de ameaça real para um script local confiável); descrição do escopo duplicada em 3 lugares/sticky note+READMEs (mesma convenção de documentação já estabelecida no projeto); linha `turnos:X` fora do formato exato não suportada pelo parser mínimo (limitação documentada no próprio docstring do parser); extensão `.yml` silenciosamente ignorada (consistente com a convenção documentada `casos/*.yaml`); e o auditor de alinhamento de intenção não levantou achado acionável -- confirmou que a entrega é scaffolding estruturalmente correto e nunca executado contra um n8n real, exatamente a leitura já assumida pela seção de Verificação do próprio spec (mesmo padrão das Stories 1.1-1.3).

## Design Notes

**Por que o caso canônico de banho não vai "passar" nesta story.** O texto do design de conversa (UJ-1) pressupõe reconhecimento por telefone (Story 1.5) e agendamento real com preço (Epic 2) — nenhum dos dois existe ainda; `01 - Agente.json` hoje só entrega identidade/tom/apresentação única (Story 1.3). Rodar o caso agora produz honestamente um transcrito que diverge do texto — e isso é o comportamento correto: a AC pede execução automática + julgamento humano sobre transcritos, nunca um agregado verde, então um transcrito "incompleto" é dado válido, não defeito desta story. Cada story seguinte (1.5, 1.8, Epic 2...) aproxima o transcrito real do texto canônico.

**Por que DDD `00` para telefone sintético.** `telefone_normalizar` (migration `0006`) só valida contagem de dígitos, não faixa de DDD real — qualquer string sintética de 10/11 dígitos normaliza com sucesso. Usar o prefixo `00` (DDD inexistente no Brasil) garante que nenhum telefone de teste jamais bate com um `identidade_cliente_pet` real, sem precisar de dado fixture nem tabela nova.

**Por que `docker compose run --rm bancada-teste` em vez de um script solto.** Mesmo padrão já validado do `importer` (Story 1.1): programa executável sob demanda, nunca rotina periódica, mesma rede compose pra alcançar `n8n:5678` sem porta nova exposta.

## Verification

**Commands:**
- `python3 -c "import json; json.load(open('n8n/workflows/08 - Entrada de Teste.json'))"` -- JSON válido.
- MCP `validate_workflow` (JSON local, sem tocar instância) -- 0 erros.
- `docker compose config` -- sintaxe válida do novo serviço `bancada-teste`.

**Manual checks (sem ambiente n8n/Postgres real neste build):**
- Inspeção: `08 - Entrada de Teste.json` só chama `01` (mesmo workflowId de `07`); nenhum node `httpRequest` para RD/Tallos/Meta em `08` nem em `bancada-teste/rodar.py`.
- Conferir que `bancada-teste/rodar.py` gera um telefone distinto por caso (prefixo `00`) e nunca reaproveita entre casos.
- Fica para o operador: importar `08` na instância real, rodar `docker compose run --rm bancada-teste` de fato e confirmar que o transcrito do caso canônico foi gravado — mesma limitação de ambiente das Stories 1.1–1.3.

## Auto Run Result

**Status:** `awaiting-operator` — todo o código desta story está implementado, revisado (6 patches aplicados, todos baixo) e verificado estruturalmente; falta só a verificação de execução real contra o n8n de verdade, que exige o operador (ver `operator_actions`).

**Resumo do que foi implementado:** uma segunda porta de entrada n8n (`08 - Entrada de Teste.json`) — `Webhook` síncrono (`responseMode: responseNode`, path `atendimento-nouvet-teste`) que chama `01 - Agente.json` pelo contrato exato de `Receber Turno` (mesmo `workflowId` e mapeamento de campos que `07 - Ingresso e Fila.json` já usa em produção) e devolve a fala da Nouvi no corpo da resposta HTTP, sem enfileirar, travar conversa, agregar mensagens ou chamar RD Conversas/Tallos/Meta. Uma falha ao *chamar* `01` (workflow desativado/removido) agora converge para um corpo JSON honesto (`output: null`, `erro: <mensagem>`) em vez de vazar um erro bruto do n8n. Complementando, um programa standalone (`bancada-teste/rodar.py`, stdlib puro) lê casos em `bancada-teste/casos/*.yaml`, gera telefone/`contact_id` sintéticos isolados por caso (DDD `00`, determinístico, nunca reaproveitado — com checagem ativa contra duplicidade entre arquivos), dispara os turnos em sequência contra a entrada de teste e grava um transcrito por caso em `bancada-teste/transcritos/` para leitura humana — nunca calculando um veredito passou/falhou. A bancada nasce semeada com a conversa canônica de banho (UJ-1, 4 falas do cliente, mesma sessão isolada), documentada como esperada a divergir do texto canônico nesta fase (reconhecimento por telefone e agendamento real ainda não existem). Um novo serviço `docker-compose.yml` (`bancada-teste`, profile `tools`, mesmo padrão on-demand do `importer` da Story 1.1) e os READMEs (`n8n/workflows/README.md`, `bancada-teste/README.md`) documentam a nova porta e a bancada, incluindo a limitação declarada de que esta entrada nunca exercita o envio real pelo RD Station.

**Arquivos alterados:**
- `n8n/workflows/08 - Entrada de Teste.json` (novo) — Webhook → executeWorkflow (com `onError: continueErrorOutput` + branch de fallback) → Respond to Webhook.
- `bancada-teste/rodar.py` (novo) — runner stdlib puro; parser mínimo de `casos/*.yaml`; geração determinística de telefone/`contact_id` sintéticos com checagem de duplicidade; chamada HTTP com tratamento de falha de transporte e de `output` nulo; execução por caso isolada em `try/except`.
- `bancada-teste/casos/1-banho-conhecido.yaml` (novo) — caso canônico de banho, 4 falas do cliente.
- `bancada-teste/README.md` (novo) — como rodar, como ler transcrito, como acrescentar caso, limitação do RD Station.
- `bancada-teste/transcritos/.gitkeep` (novo) — mantém o diretório versionado; conteúdo gerado é gitignored.
- `docker-compose.yml` — novo serviço `bancada-teste` (profile `tools`, `PYTHONUNBUFFERED: "1"`).
- `n8n/workflows/README.md` — documenta `08` na convenção numérica existente.
- `.gitignore` — ignora transcritos gerados (`bancada-teste/transcritos/*`, exceto `.gitkeep`).

**Findings da revisão:** ver `## Review Triage Log` acima — 6 `patch` aplicados (todos baixo: guarda de nome de caso duplicado, isolamento de falha por caso no runner, tratamento de `output` nulo, validação de `BANCADA_TESTE_URL`, `onError` estruturado em `08`, saída não-bufferizada), 6 `defer` (registrados em `deferred` no frontmatter — nenhum causado bloqueia esta story), 11 `reject` (ver lista completa no Triage Log, incluindo duas alegações verificadas como falsas).

**Follow-up review recommendation:** `true` — 6 achados `patch` nesta passada, todos severidade baixa: 3×0 (medium) + 1×6 (low) = 6, ≥ 5.

**Verificação realizada:**
- `python3 -c "import json; json.load(open('n8n/workflows/08 - Entrada de Teste.json'))"` — JSON válido (confirmado após os 6 patches).
- MCP `validate_workflow` (JSON local, sem tocar a instância) — `valid: true`, 0 erros, 0 avisos, 4 nós, 5 expressões validadas (confirma o novo branch de erro).
- `docker-compose.yml` reanalisado com PyYAML (Docker CLI indisponível neste ambiente) — sintaxe válida, 4 serviços, `bancada-teste` com `PYTHONUNBUFFERED` e `BANCADA_TESTE_URL` corretos.
- `bancada-teste/rodar.py` rodado de ponta a ponta contra um servidor HTTP mock local: confirmado o corpo `contact_id`/`telefone`/`mensagem_agregada` enviado, o mesmo telefone sintético reutilizado nos 4 turnos de um caso (isolamento de sessão), acentuação UTF-8 preservada, e o formato do transcrito.
- Confirmado que dois nomes de caso diferentes geram telefones sintéticos distintos, ambos DDD `00`.
- Confirmado (mock) que uma falha de rede não derruba o script (exit 0, transcrito com nota de falha honesta por turno) e que a execução segue por todos os turnos restantes, conforme a AC exige.
- Confirmado (mock) que dois arquivos de caso com `nome:` duplicado abortam a execução (exit 1) antes de rodar qualquer caso.
- Confirmado (mock) que uma `BANCADA_TESTE_URL` malformada aborta (exit 1) com mensagem clara antes de rodar qualquer caso.
- Confirmado (mock) que um `output: null` no corpo da resposta gera um marcador diagnóstico no transcrito, nunca o texto literal `"None"`.
- Inspeção: `08 - Entrada de Teste.json` e `bancada-teste/rodar.py` não têm nenhum node/chamada `httpRequest` para RD/Tallos/Meta — só a URL local da entrada de teste.
- `git diff` em `01 - Agente.json` e `07 - Ingresso e Fila.json` vazio — nenhum dos dois foi tocado.

**Riscos residuais:**
- Ver os 6 itens em `deferred` no frontmatter — nenhum bloqueia esta story: validação server-side ausente do DDD sintético em `08`, ausência de isolamento de efeito colateral quando ferramentas voltarem a `01` (Stories 1.8-1.10), container `bancada-teste` rodando como root, timeout de 120s fixo sem variável de ambiente, corrida entre timeout do cliente e execução do servidor podendo vazar estado entre turnos, e ausência de suíte de testes automatizada para o parser/gerador de identidade.
- Nenhum comportamento desta story (chamada real à entrada de teste, transcrito gravado, isolamento de sessão contra um agente de verdade) foi comprovado por execução real — só por inspeção estrutural e mock local, mesma limitação de ambiente das Stories 1.1-1.3. Itens de `operator_actions`.
- `docker compose config` real não pôde ser executado (Docker CLI indisponível neste ambiente de build) — só verificado via parse YAML equivalente.

## Operator Confirmation

Confirmed 2026-09-22: the external actions this story owed were carried out.

- Importar n8n/workflows/08 - Entrada de Teste.json na instância n8n real (via UI ou `n8n import:workflow --input="n8n/workflows/08 - Entrada de Teste.json"`) e ativá-lo (active: true) -- o webhook só responde em /webhook/atendimento-nouvet-teste quando ativo; hoje o workflow existe só no repositório.
- Rodar `docker compose run --rm bancada-teste` de fato contra a instância real (com `08` já importado e ativo) e confirmar que um transcrito do caso `1-banho-conhecido` foi gravado em bancada-teste/transcritos/ -- este build só verificou o runner contra um servidor HTTP mock local, nunca contra o `01 - Agente` de verdade.
- Rodar `docker compose config` de verdade (Docker CLI não estava disponível neste ambiente de build) para confirmar a sintaxe real do novo serviço `bancada-teste` -- este build só verificou via parse YAML equivalente (PyYAML), não com o comando real.
- Ler o transcrito gerado pelo caso `1-banho-conhecido` e confirmar humanamente que a resposta da Nouvi é aceitável para o estágio atual do produto -- o julgamento passou/não passou é sempre humano, nunca calculado por este build (ver Design Notes desta story sobre por que o caso canônico ainda não deve "passar" por completo).

_Appended by the bmad-loop orchestrator (`bmad-loop confirm`, #335): a human confirmed these external actions out of band, and the story was advanced from `awaiting-operator` to `done`._
