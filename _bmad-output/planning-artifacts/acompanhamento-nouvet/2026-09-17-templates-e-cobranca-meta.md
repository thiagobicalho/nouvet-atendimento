# Templates do WhatsApp e a cobrança da Meta — o que precisa ser feito

## O prazo que não pode passar

**Até 30/09/2026: meio de pagamento cadastrado na conta WhatsApp Business.** A Meta interrompe a entrega de **mensagens de serviço** quando a cobrança começa, em **01/10** — a mesma data do go-live. Como o Nouvet opera pelo RD Station (que é o BSP), a verificação passa por eles. **Provavelmente já existe**, porque a conta é ativa — mas é confirmação de dois minutos que evita o projeto nascer mudo.

## O que muda na cobrança, e de quem é o custo

A partir de **01/10/2026** a Meta cobra **por mensagem entregue**. **Não há franquia gratuita nem faixa por volume** para mensagem de serviço — confirmado na documentação oficial; a "franquia de 1.000" que circula em resumos de terceiros é resíduo do modelo antigo por conversa. Na mesma data, template de utilidade **dentro** da janela de 24h também passa a ser cobrado.

Separando honestamente o que é de quem:

| Origem do custo | De quem é |
|---|---|
| Respostas que a recepção já manda hoje pelo RD | **Do Nouvet, com ou sem agente** — a tarifa mudou, não o uso |
| Respostas do agente em conversas que hoje já são atendidas | **Substituição**, não adição |
| Respostas do agente em conversas que hoje ficam sem resposta | Adição — mas é o produto funcionando |
| **Lembretes (24h e 2h)** | **Volume novo**, causado pelo projeto |
| **Mensagem de recorrência** | **Volume novo**, causado pelo projeto |

Ordem de grandeza da onda 1: cerca de **450 banhos/mês** × 2 lembretes ≈ **900 templates/mês**, mais a recorrência. A tarifa por mensagem depende do país do destinatário e deve ser confirmada na tabela vigente da Meta no momento do orçamento.

## Como template funciona (para alinhar expectativa)

- **Quem aprova é a Meta, não o cliente.** O template é escrito uma vez, aprovado, e serve para qualquer contato.
- **Dentro da janela de 24h** desde a última mensagem do cliente: texto livre.
- **Fora da janela**: só template aprovado. É por isso que o lembrete de véspera precisa ser template.
- Quando o cliente **responde** ao template, abre nova janela de 24h e a conversa volta a ser livre.

## Onde se cria

**No painel do RD Conversas** — *Contatos de clientes → Mensagens de Template → Criar novo template*. A API do RD **só lista e envia**; não cria, não edita e não consulta status de aprovação. Consequências operacionais:

- A autoria e a aprovação são manuais, com prazo variável da Meta — **precisa começar antes do go-live**.
- O envio retorna `201` significando apenas que o RD recebeu — **não** que foi entregue.
- **Falha de template ou de entrega só aparece na plataforma**, não pela API. Não temos como detectar rejeição programaticamente; é conferência manual.

Existe um template já aprovado na conta (*"Olá! Notamos que seu cadastro está incompleto…"*) — vale revisar se serve ao `FR-4a`.

## Templates que a onda 1 precisa

| # | Template | Categoria esperada | Quando dispara |
|---|---|---|---|
| T1 | **Lembrete de véspera** — *"Lembrete: {serviço} do {pet} amanhã às {hora}. Confirma?"*, com botões Confirmar / Remarcar | Utilidade | 24h antes |
| T2 | **Lembrete do dia** — *"{pet} tem {serviço} hoje às {hora}. Te esperamos!"* | Utilidade | 2h antes |
| T3 | **Aviso de cancelamento pela clínica** — quando o Nouvet precisa desmarcar | Utilidade | sob demanda |
| T4 | **Pós-atendimento** — *"Como foi o {serviço} do {pet}?"* | Utilidade (pesquisa de satisfação) | após o atendimento |
| T5 | **Recorrência** — *"Faz {dias} dias desde o último banho do {pet}. Quer marcar?"* | ⚠️ **provavelmente Marketing** | quando o intervalo típico é ultrapassado |

**Não precisa de template** a confirmação do agendamento em si: ela acontece dentro da janela, porque o cliente acabou de falar.

## O risco do T5, que é o que paga o projeto

A Meta separa **utilidade** (segue uma ação do usuário, sem intenção promocional) de **marketing** (reengajamento, promoção). A mensagem de recorrência **não segue ação nenhuma** — o cliente sumiu. Então tende a ser classificada como **marketing**, o que traz três consequências:

1. **Tarifa maior.**
2. **Limite por usuário** — a Meta capa quantos templates de marketing uma pessoa recebe de qualquer empresa; a nossa mensagem disputa esse teto com todo mundo.
3. **Opt-out próprio** — quem recusar marketing para de receber a recorrência, mas continua recebendo lembrete.

E a Meta **reclassifica sozinha**: se submetermos como utilidade e ela discordar, o template é aprovado como marketing e a cobrança acompanha. Dá para auditar comparando `category` com `correct_category`, mas a mudança vale a partir do primeiro dia do mês seguinte.

**Mitigação possível, não garantia:** escrever o T5 o mais transacional possível, sem oferta, desconto ou linguagem persuasiva. Ainda assim, planejar assumindo marketing.

## Ações

| # | Ação | Quem |
|---|---|---|
| 1 | Confirmar meio de pagamento na WABA **até 30/09** | Nouvet / RD |
| 2 | Escrever e submeter T1 a T5 no painel, com antecedência | Btech |
| 3 | Conferir se o template de cadastro incompleto já existente serve ao `FR-4a` | Btech |
| 4 | Estimar o custo mensal com a tabela vigente da Meta e apresentar ao Nouvet | Btech |
| 5 | Auditar mensalmente `category` × `correct_category` do T5 | Btech |
