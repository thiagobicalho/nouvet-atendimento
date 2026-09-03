---

## title: Acompanhamento Nouvet — Atendimento Nouvet (Piloto) data: 2026-09-01 (atualizado em 2026-09-03) preparado_por: Thiago Bicalho (Btech.Cloud) destinado_a: liderança Nouvet

# Acompanhamento — Atendimento Nouvet (Piloto)

Documento de status para o Nouvet: onde estamos, o que só o Nouvet pode responder, e achados relevantes para a decisão da diretoria. Não substitui o PRD técnico

**Go-live do Piloto: 08/09/2026 — faltam 5 dias corridos a partir de hoje (03/09).**

## 1. Onde estamos

Atualização de progresso desde o último status (01/09): a construção segue em ritmo bom, com 6 das 15 entregas do Piloto já prontas — a base técnica inteira (infraestrutura, configuração dinâmica, fila de mensagens) e as duas primeiras capacidades do atendente já estão no ar:

- O atendente virtual já **identifica o cliente e entende o que ele precisa** assim que a conversa começa, 24/7, sem perguntar "você tem cadastro?" quando já conhece o telefone.
- O atendente já **classifica automaticamente** a necessidade do cliente entre Care Center, Consultas, Vacinas, Exames ou Orçamentos — e já sabe encaminhar para um humano na hora quando é uma emergência, um assunto fora do escopo do Piloto, ou quando o cliente menciona convênio por conta própria.
- **O Piloto de 10 dias não vai fechar nenhum agendamento sozinho — nem no Care Center.** O que ele entrega é: identificar o cliente, entender o que ele precisa, coletar todas as preferências de agendamento (serviço, data, horário, profissional) e registrar tudo pronto no CRM, notificando a pessoa certa da equipe para confirmar com o cliente.
- Em compensação, dois pontos que geravam insegurança já foram resolvidos: (1) quando um atendimento demora para ser assumido por um humano, o gestor passa a ser avisado desde o primeiro sinal de atraso, não só depois que o problema já cresceu; (2) quando um cliente declara uma emergência com o pet, o alerta vai para todos os profissionais envolvidos naquele atendimento, não para uma pessoa só — e isso é configurável, sem precisar mexer no sistema para trocar quem recebe.

O mecanismo de encaminhamento para humano (emergência, fora de escopo, convênio) já está funcionando tecnicamente — mas hoje ele não tem para quem enviar o alerta, porque a lista de contatos ainda não foi fornecida (ver Seção 2).



## 2. O que precisamos que o Nouvet responda



### Bloqueia o go-live de 08/09 (não bloqueia o início da construção)

Três blocos de dado real, todos com o mesmo prazo abaixo — sem eles, o sistema já construído vai ao ar com informação incompleta ou canais de segurança sem destinatário:

- **Lista concreta de "sinal de alerta" clínico — as "red-flags" que fazem o agente acionar um humano na hora.** Já decidimos que essa lista fica configurável (não craveja no sistema), então já estamos construindo o mecanismo com uma lista provisória, sem esperar. Mas a lista que efetivamente vai estar ativa no dia 08/09, atendendo clientes reais, precisa ser validada pela equipe clínica do Nouvet antes disso — esse guardrail de segurança é o mais importante do produto, e não dá para deixar uma lista provisória valendo no lançamento.
- **Lista de quem recebe o alerta quando o atendente encaminha para um humano** (emergência, assunto fora do escopo do Piloto, ou menção a convênio). O mecanismo já está pronto e funcionando — falta só a lista de destinatários. Sem ela, o cliente ouve que "a solicitação está sendo registrada com prioridade", mas hoje ninguém é de fato avisado.
- **Dados institucionais e lista de profissionais**, hoje usados diretamente nas respostas do atendente e ainda não preenchidos: endereço, telefone, WhatsApp, e-mail, site, horário de funcionamento, formas de pagamento, convênios aceitos, e a lista de profissionais por setor (nome/especialidade). Sem isso, um cliente que pergunta o endereço da clínica ou quais profissionais atendem hoje não recebe uma resposta real.



### Importante, mas não impede a data de 08/09

- **Tom de voz da IA quando ela não sabe responder algo.** Hoje já existe um rascunho nosso no ar (acolhedor, natural, nunca estruturado como menu) para não travar a construção, mas vale alinhar a mensagem final com quem cuida da comunicação com o cliente do Nouvet.
- **Nome pelo qual a IA se apresenta ("atendente virtual do Nouvet").** Também já é um default nosso, nunca confirmado formalmente — vale um "OK" rápido da equipe de comunicação.
- **Quem, do lado do Nouvet, vai manter a agenda dos profissionais atualizada** (mesmo que manualmente, por planilha) até que o agendamento automático de fato exista na próxima fase? Isso não trava o Piloto atual, mas é o alicerce da fase seguinte.



### Já resolvido, só para registro

- Vacinas entra no Piloto; Financeiro fica fora — confirmado.
- Acesso e atualização das exportações do SimplesVet (para identificação de clientes) ficam com a Btech, que já tem acesso direto à plataforma — o Nouvet não precisa enviar arquivos manualmente.
- Pedido de exclusão de dados/opt-out de mensagens automáticas (direito da LGPD): **não entra no Piloto**. É algo que devemos considerar, mas fica para uma fase seguinte.



## 3. Achados que vale a pena o Nouvet conhecer



### RD Station Conversas e RD Station CRM são duas contas separadas

Ao revisar a documentação e o painel da conta, identificamos que o WhatsApp/Conversas do Nouvet roda em uma conta ("TSL VET CENTER LTDA") diferente da conta do CRM/Marketing ("Nouvet Centro Veterinário 24h") — embora ambas estejam cadastradas com o mesmo CNPJ. Na prática, isso significa que não existe um "mesmo cadastro" automático entre os dois produtos — o sistema vai casar o cliente pelo número de telefone entre um produto e outro. Por conta dessa separação, é possível que a gente esbarre em alguma limitação técnica ao longo da implementação; assim que tivermos uma conclusão mais fechada sobre isso, avisamos com mais clareza. Por ora, não é algo que trava o Piloto.

### Duas linhas de WhatsApp cadastradas no RD Conversas — vamos usar só uma

A conta do Nouvet tem 2 números de WhatsApp ativos no RD Conversas, com um custo adicional de aproximadamente R$559/mês pela segunda linha, e um desses números está dedicado especificamente ao Care Center. **Do nosso lado, a decisão técnica é usar apenas 1 número ativo no Piloto.** Manter 2 números por setor significa, na prática, 2 integrações separadas para manter, e o histórico do mesmo cliente fica descentralizado em duas conversas diferentes dentro do Conversas — o que vai direto contra o ponto de entrada único que é a base de todo o desenho do Piloto. O segundo número pode continuar existindo como backup (caso o principal caia), mas não como canal dedicado a um setor.

## 4. Prazo

A construção já está seguindo em frente mesmo sem os 3 blocos bloqueantes da Seção 2 (são configuráveis, então não travam a construção). O prazo que pedimos para a lista de sinais de alerta validada pela equipe clínica — **03/09/2026 — é hoje**; se ainda não temos retorno, precisamos alinhar um novo prazo que ainda caiba antes do dia 08/09, já que essa lista precisa estar pronta e revisada antes de ligarmos isso para clientes reais. Pedimos que os outros dois blocos (contatos de emergência e dados institucionais/profissionais) sigam o mesmo prazo — são igualmente necessários para o cliente ter uma experiência real no lançamento. Os itens da seção "Importante, mas não impede" podem ser resolvidos ao longo da semana, mas quanto antes, melhor para a qualidade da entrega.