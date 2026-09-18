# Pacote para o Nouvet — 17/09/2026

O que levar, em que ordem, e para quem.

## Os documentos

| # | Documento | Para quem | O que é |
|---|---|---|---|
| **1** | `1-questionario-nouvet.md` | Diretoria + coordenação de operação | O documento principal. Sete blocos de decisões que só o Nouvet pode tomar, cada um explicando por que perguntamos e o que trava. |
| **2** | `mapeamento-servicos-onda1.csv` | Quem coordena o Care Center | Planilha com **38 campos** × **6 serviços** (banho, quatro tipos de tosa e desembolo). É o insumo que destrava a construção da primeira entrega. Abre no Excel ou Google Sheets (separador `;`). |
| **3** | `3-anexo-tecnico-rd-conversas.md` | Quem administra o RD Station Conversas | Anexo técnico: setores a criar, ajustes de cadastro e as inconsistências encontradas. **Não circula com a diretoria** — é operacional. |

## A ordem que importa

Se a resposta vier em partes, esta é a ordem de utilidade para nós:

1. **Planilha de banho e tosa (doc 2)** — sem duração e horário, o agente não consegue calcular horário livre. É o único item que bloqueia a construção da primeira entrega.
2. **Bloco E do questionário — setores do RD (doc 1)** — sem isso, a transferência para humano cai numa fila que ninguém acompanha.
3. **Bloco F — a meta (doc 1)** — precisamos de um número para dizer se o projeto funcionou.
4. O restante pode vir depois.

## O que dizer ao apresentar

**O que mudou.** O modelo anterior recebia o cliente e passava para uma pessoa concluir. Como não há equipe para essa continuidade, o novo modelo **conclui o agendamento sozinho** e só envolve uma pessoa nas exceções.

**O que já sabemos.** Analisamos o export do SimplesVet de 09/09: 66.564 agendamentos desde fev/2023, cerca de 2.400 por mês. Boa parte das perguntas que teríamos feito já foi respondida pelos dados — o que sobrou é decisão de operação e de negócio.

**Dois números que valem abrir a conversa:**
- **13.346 agendamentos — 1 em cada 5 — não viraram atendimento** (8.235 ficaram como *Atrasado*, 5.111 foram cancelados).
- **Apenas 1.647 (2,5%) chegaram a ser confirmados.** Hoje ninguém lembra o cliente e ninguém confirma.

É nisso que o agente mexe primeiro.

**Sobre o prazo.** A entrega será **modular**. A primeira onda é o **Care Center — banho e tosa**: 19.698 agendamentos, cerca de 450 por mês, **34,6% de tudo que a clínica marca** — e o único serviço de alto volume que é genuinamente agendado com antecedência (mediana de quase dois dias). As ondas seguintes trazem Imagem, depois Consultas, depois o restante.

**O que pedimos agora.** As respostas da planilha e dos blocos B e E. O resto pode ser respondido enquanto construímos.

## ⚠️ Um prazo que não pode passar — 30/09

A Meta muda a cobrança do WhatsApp em **01/10/2026**, a mesma data prevista para a entrada em produção. Contas **sem meio de pagamento cadastrado até 30/09** têm a entrega de mensagens interrompida quando a cobrança começa. Como vocês operam pelo RD Station, a confirmação passa por eles — provavelmente já está resolvido, mas precisa ser verificado. Detalhes em documento separado.

## O que descobrimos e vale vocês saberem

**O preço do banho mudou em agosto.** Até julho era cobrado por porte e comprimento de pelo; desde setembro é valor único por espécie. O efeito não é uniforme: cães de **porte pequeno — 68% da base** — tiveram aumento de 15% a 30%, enquanto cães grandes tiveram queda de até 41%. Está no Bloco C2, com a tabela comparativa. Se houver queda de volume nos próximos meses, é candidato a explicação.

**Metade dos "cancelamentos" não é cancelamento.** Dos 5.105 registros cancelados, **53% foram marcados depois que o horário já tinha passado** — ou seja, o cliente não apareceu e alguém limpou a agenda. É exatamente esse público que o lembrete com pedido de confirmação ataca.

**Banho é rotina quinzenal, não evento.** O intervalo mediano entre banhos do mesmo animal é de **14 dias**, e 63% dos animais voltam. Hoje há **208 animais que tinham ritmo e pararam** — e ninguém os procurou.

## Duas decisões que já tomamos, e o porquê

**O Leva e Traz não será agendado automaticamente nesta primeira versão.** O agente registra o pedido e a recepção confirma o horário da busca. Motivo: a regra que define se uma viagem cabe ou não vive na conversa entre a recepção e o motorista, não está escrita em lugar nenhum, e um sistema que siga a agenda ao pé da letra recusaria viagens que hoje vocês aceitam.

**Emergência não é agendamento.** Dos 734 atendimentos emergenciais da base, 98% foram registrados na hora ou depois — ninguém marca uma emergência. Por isso o agente terá um comportamento separado: ao reconhecer uma situação grave, **não oferece horário** — orienta a vir imediatamente e avisa a clínica. Isso vale desde a primeira versão, inclusive no meio de uma conversa sobre banho.
