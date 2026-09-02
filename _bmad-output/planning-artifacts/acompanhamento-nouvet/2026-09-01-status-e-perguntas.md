---

## title: Acompanhamento Nouvet — Atendimento Nouvet (Piloto) data: 2026-09-01 preparado_por: Thiago Bicalho (Btech.Cloud) destinado_a: liderança Nouvet

# Acompanhamento — Atendimento Nouvet (Piloto)

Documento de status para o Nouvet: onde estamos, o que só o Nouvet pode responder, e achados relevantes para a decisão da diretoria. Não substitui o PRD técnico

**Go-live do Piloto: 08/09/2026 — faltam 7 dias corridos a partir de hoje.**

## 1. Onde estamos

O escopo do Piloto foi revisado nesta semana pela equipe Btech e é importante alinhar a expectativa antes de qualquer conversa com a diretoria:

- **O Piloto de 10 dias não vai fechar nenhum agendamento sozinho — nem no Care Center.** O que ele entrega é: identificar o cliente, entender o que ele precisa, coletar todas as preferências de agendamento (serviço, data, horário, profissional) e registrar tudo pronto no CRM, notificando a pessoa certa da equipe para confirmar com o cliente. 
- Em compensação, dois pontos que geravam insegurança já foram resolvidos: (1) quando um atendimento demora para ser assumido por um humano, o gestor passa a ser avisado desde o primeiro sinal de atraso, não só depois que o problema já cresceu; (2) quando um cliente declara uma emergência com o pet, o alerta vai para todos os profissionais envolvidos naquele atendimento, não para uma pessoa só — e isso é configurável, sem precisar mexer no sistema para trocar quem recebe.



## 2. O que precisamos que o Nouvet responda



### Bloqueia o go-live de 08/09 (não bloqueia o início da construção)

- **Lista concreta de "sinal de alerta" clínico — as "red-flags" que fazem o agente acionar um humano na hora.** Já decidimos que essa lista fica configurável (não craveja no sistema), então já estamos construindo o mecanismo com uma lista provisória, sem esperar. Mas a lista que efetivamente vai estar ativa no dia 08/09, atendendo clientes reais, precisa ser validada pela equipe clínica do Nouvet antes disso — esse guardrail de segurança é o mais importante do produto, e não dá para deixar uma lista provisória valendo no lançamento.



### Importante, mas não impede a data de 08/09

- **Tom de voz da IA quando ela não sabe responder algo.** Hoje isso é ajustável sem mexer no sistema, mas vale alinhar a mensagem com quem cuida da comunicação com o cliente do Nouvet.
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

A construção já está seguindo em frente mesmo sem a lista definitiva de sinais de alerta clínico (ela é configurável, então não trava o início). Ainda assim, pedimos a lista validada pela equipe clínica o quanto antes — idealmente até 03/09/2026 — porque ela precisa estar pronta e revisada antes de ligarmos isso para clientes reais no dia 08/09. Os demais itens da seção 2 podem ser resolvidos ao longo da semana, mas quanto antes, melhor para a qualidade da entrega.