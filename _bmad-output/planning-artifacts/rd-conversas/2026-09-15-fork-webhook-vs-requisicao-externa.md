# Fork arquitetural: webhook (assíncrono) vs. requisição externa no fluxo do RD (síncrono)

Levantado por Thiago em 15/09 ao ver a ação **"Mensagem de Requisição Externa"** na doc de fluxos do RD Conversas. **Decisão pendente** — entra na arquitetura do produto novo, não no Piloto.

## O que a ação faz (doc oficial "Fluxos de Atendimento")

> *"por aqui podemos fazer com que o fluxo do RD Station Conversas se comunique com algum sistema externo, através de chamadas de sistema via API. Tudo o que precisamos é que esse sistema possua uma API que possa ser consumida."*

- Método **GET/POST/PUT/DELETE**, URL livre, **cabeçalhos** customizados (ex. `content-type: application/json`), **corpo JSON**.
- Propriedades do corpo em 5 tipos: Texto, Número, **Dinâmico**, Lista, Objeto. O tipo **Dinâmico** injeta no corpo *"alguma resposta requisitada pelo nosso fluxo"* — ou seja, o texto que o cliente acabou de mandar.
- Checkbox **"Usar o JSON da resposta"**: *"Caso a sua requisição feita via API possua algum tipo de retorno, o fluxo (…) poderá capturar esse retorno para realizar alguma ação com o mesmo."* Define-se a propriedade do JSON em **`@VALOR`** e a ação **"Texto seguido do @VALOR"**, que concatena e **exibe ao cliente**.
- **Caminho de Sucesso e caminho de Erro**, com campo "Status Code do Erro".

E o bloco **Interceptação** (fim de fluxo) já entrega o handoff nativo: *"Apenas finalizar"*, *"Encaminhar para fila de espera"* (com escolha de setor), *"Encaminhar para fila de espera sequencialmente"* (rodízio), *"Encaminhar para fila de espera da carteira"*.

## Opção A — webhook (o que o Piloto faz)

RD dispara webhook a cada mensagem → n8n enfileira, debounce, agrega, chama o agente → n8n responde via `POST /v2/messages/{id}/send`.

**A favor**: assíncrono (sem timeout); debounce/agregação de mensagens picadas funciona; multi-turno natural; controle total.
**Contra**: o payload não diz o setor nem o estado real → precisamos da máquina de estados `bot | aguardando_humano | humano` no nosso Postgres; dispara em todos os estados (risco de responder por cima de humano); handoff exige `forward-to-customer` + fluxos auxiliares.

## Opção B — requisição externa (fluxo do RD chama o n8n)

Fluxo: `Começo → opt-in → [loop] Mensagem de requisição (captura o texto do cliente) → Requisição externa (POST para o n8n, corpo Dinâmico com o texto) → exibe @VALOR (resposta do agente) → volta ao loop`; saída por **Interceptação** quando o agente pede handoff.

**A favor**: determinístico — só executa onde o fluxo manda, acaba a adivinhação de `action`; o RD passa a ser dono do estado da conversa (transferiu via Interceptação → fluxo acaba → bot está fora **por construção**, sem máquina de estados nossa); dispensa o `/send` separado e o `forward-to-customer`; caminho de erro nativo para falha do n8n.
**Contra / a verificar**:
1. **Timeout** (bloqueante): é síncrono. Execuções reais do agente em 11/09: **12,8 s / 13,4 s / 17,5 s** — e isso *antes* de existir tool de agenda (Graph) na cadeia. Qual é o timeout da requisição externa? **Não documentado.**
2. **Debounce**: "Mensagem de requisição" espera **uma** resposta. Cliente que manda 3 mensagens picadas — o que acontece com a 2ª e a 3ª enquanto a requisição roda? **Não documentado.** O padrão fila+lock+agregação que já temos não encaixa igual.
3. **Loop multi-turno**: o editor permite ciclo (voltar ao nó de requisição) ou só sequência linear? Se não permitir, seria preciso encadear N blocos — inviável para conversa aberta. **Não documentado.**
4. Resposta ao cliente é concatenação de texto (`Texto seguido do @VALOR`) — formatação limitada; e **uma mensagem por turno** (o que, com a cobrança da Meta a partir de 01/10, é vantagem, não defeito).

## Opção C — híbrida

Fluxo do RD só no **handshake de entrada**: opt-in → requisição externa avisando o n8n ("conversa X começou, contato Y") → Interceptação para o setor `Atendimento IA`. Daí em diante, conversa por **webhook** como na opção A. Dá o sinal de início determinístico e o handoff nativo, sem colocar o agente no caminho síncrono.

## Como decidir

**Decisão de 15/09 (Thiago): não bater o martelo internamente — levar o fork para a reunião com o RD** e perguntar qual é a forma recomendada por eles (pergunta 12 da lista do roteiro). O spike abaixo só roda se a resposta deles não for conclusiva, e **não** em número conectado a produção.


Spike curto (mesmo formato do spike Microsoft), **antes de fechar a arquitetura de entrada**:
- **S1 — timeout**: fluxo com requisição externa apontando para um n8n que dorme 5 s, 15 s, 30 s. Medir onde corta e o que o cliente vê.
- **S2 — loop**: tentar ligar a saída da requisição externa de volta ao nó de requisição. Ciclo é permitido?
- **S3 — mensagens picadas**: com a requisição rodando, mandar 2 mensagens seguidas. São enfileiradas, descartadas, ou tratadas depois?

Se S1 e S2 passarem, **B é arquitetura superior** — elimina a máquina de estados, o `forward-to-customer` e a adivinhação de `action`. Se qualquer um falhar, **C** é o melhor dos dois mundos e **A** continua sendo o plano de fundo seguro.
