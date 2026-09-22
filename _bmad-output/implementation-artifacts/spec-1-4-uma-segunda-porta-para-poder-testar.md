---
title: 'Story 1.4 — Uma segunda porta, para poder testar'
type: 'feature'
created: '2026-09-21'
status: 'draft'
baseline_revision: '71349bc352e45d24097714f05859559396252777'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '_bmad-output/implementation-artifacts/epic-1-context.md'
warnings: ['oversized']
deferred: []
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
