---

## title: Acompanhamento Nouvet — Atendimento Nouvet (Piloto) data: 2026-09-01 (atualizado em 2026-09-09) preparado_por: Thiago Bicalho (Btech.Cloud) destinado_a: liderança Nouvet

# Acompanhamento — Atendimento Nouvet (Piloto)

Documento de status para o Nouvet: onde estamos, o que só o Nouvet pode responder, e achados relevantes para a decisão da diretoria. Não substitui o PRD técnico

**Data original de go-live do Piloto: 08/09/2026 (ontem).** A construção do fluxo terminou nessa data — o que muda o marco de "go-live" de "abrir para clientes reais" para "entrar em fase de testes antes de abrir para clientes reais" (ver Seção 4 sobre o novo prazo).

## 1. Onde estamos

**A construção do Piloto está com 14 das 15 entregas planejadas prontas e revisadas; a última — o painel de indicadores e visibilidade gerencial — ainda está em construção.** Já funciona ponta a ponta:

- O atendente virtual **identifica o cliente e entende o que ele precisa** assim que a conversa começa, 24/7, sem perguntar "você tem cadastro?" quando já conhece o telefone.
- Ele **classifica automaticamente** a necessidade do cliente entre Care Center, Consultas, Vacinas, Exames ou Orçamentos.
- Para cada uma dessas frentes, ele **coleta as preferências de agendamento (serviço, data, horário, profissional) e registra tudo pronto no CRM**, notificando a pessoa certa da equipe para confirmar com o cliente. **O Piloto não fecha nenhum agendamento sozinho — nem no Care Center**; quem confirma com o cliente é sempre um humano.
- Ele **encaminha para um humano na hora** quando identifica uma emergência, um assunto fora do escopo do Piloto, quando o cliente menciona convênio por conta própria, ou quando falta informação para responder — com temporizadores de SLA que avisam o gestor desde o primeiro sinal de atraso em assumir o atendimento, não só depois que o problema já cresceu.
- Quando um cliente declara uma emergência com o pet, o alerta vai para todos os profissionais envolvidos naquele atendimento (configurável, sem precisar mexer no sistema para trocar quem recebe).
- Falta fechar o **painel de indicadores e visibilidade gerencial**, que vai permitir acompanhar volume e motivos de encaminhamento para humano durante os testes e depois no dia a dia — ainda em construção, previsão de ficar pronto nos próximos dias.

Com o fluxo praticamente fechado, **o próximo passo é a fase de testes** — ainda não é abertura para clientes reais, e hoje estamos dependendo do retorno do Nouvet para avançar. O mecanismo de encaminhamento para humano já está funcionando tecnicamente, mas para os testes valerem a pena os 3 blocos de dado real da Seção 2 precisam estar confirmados — em especial a lista de destinatários de alerta, que no sistema hoje ainda consta vazia.

## 2. O que precisamos que o Nouvet responda



### Bloqueia o início da fase de testes (não bloqueia mais a construção — ela já terminou)

Três blocos de dado real. A construção está pronta para os três, mas sem eles o sistema entra em teste (e depois em produção) com informação incompleta ou canais de segurança sem destinatário. **Precisamos que vocês confirmem o status de cada um dos três antes de começarmos os testes:**

- **Lista concreta de "sinal de alerta" clínico — as "red-flags" que fazem o agente acionar um humano na hora.** Já decidimos que essa lista fica configurável (não craveja no sistema), e o mecanismo está pronto rodando com uma lista provisória. Mas a lista que efetivamente vai estar ativa nos testes — e depois com clientes reais — precisa ser validada pela equipe clínica do Nouvet antes disso — esse guardrail de segurança é o mais importante do produto, e não dá para deixar uma lista provisória valendo nem nos testes nem no lançamento.
- **Lista de quem recebe o alerta quando o atendente encaminha para um humano** (emergência, assunto fora do escopo do Piloto, ou menção a convênio). O mecanismo já está pronto e funcionando — falta só a lista de destinatários, e **até a checagem de hoje (08/09) ela ainda consta vazia no sistema**. Sem ela, o cliente ouve que "a solicitação está sendo registrada com prioridade", mas hoje ninguém é de fato avisado.
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

### Duas linhas de WhatsApp cadastradas no RD Conversas

Achado para registro, sem nenhuma decisão tomada até aqui: a conta do Nouvet tem 2 números de WhatsApp ativos no RD Conversas, e um deles está dedicado especificamente ao Care Center. Achamos importante que vocês tenham essa visibilidade porque manter 2 números por setor tem uma implicação de desenho: na prática, o histórico do mesmo cliente fica descentralizado em duas conversas diferentes dentro do Conversas, o que vai contra o ponto de entrada único que orienta todo o desenho do Piloto. Não é algo que trava o Piloto — só registramos o achado para que a diretoria esteja ciente antes de decidirmos juntos o que fazer com a segunda linha.

### Custos e licenciamento do RD Station (Conversas, Marketing e CRM) — para conhecimento da diretoria

Achado para registro, sem pedido de ação associado: levantamento dos custos recorrentes dos 3 produtos RD Station usados hoje (Conversas e CRM na automação do Piloto; Marketing não é usado na automação, mas é custo RD do Nouvet mesmo assim):

- **CRM** (conta "Nouvet Centro Veterinário 24h"): 5 licenças, R$655/mês.
- **Marketing** (não usado na automação do Piloto): R$1.121/mês.
- **Conversas** (conta "TSL VET CENTER LTDA"): média de R$6.700/mês — plano de até 6.000 clientes, com 1 número de WhatsApp extra (a segunda linha do achado acima) e 11 licenças.

**Total RD Station: ~R$8.476/mês** somando os 3 produtos.

## 4. Prazo

A construção terminou dentro do prazo que tínhamos (08/09). O que muda agora é a natureza do marco: **08/09 deixa de ser "abrir para clientes reais" e passa a ser "começar a fase de testes"** — e essa fase só rende o que deveria se os 3 blocos bloqueantes da Seção 2 estiverem confirmados antes de começar (em especial a lista de sinais de alerta validada pela equipe clínica, que é o guardrail de segurança mais importante do produto). Pedimos que o Nouvet confirme com a gente, o quanto antes: (1) status atual de cada um dos 3 blocos da Seção 2, e (2) uma data-alvo para a fase de testes terminar e a abertura para clientes reais acontecer — sugerimos alinharmos isso ainda esta semana. Os itens da seção "Importante, mas não impede" podem ser resolvidos ao longo da fase de testes, mas quanto antes, melhor para a qualidade da entrega.

## 5. Sugestões para a fase de testes

- **Definir um roteiro de teste guiado (UAT) antes de abrir para clientes reais**, cobrindo os principais caminhos: Care Center, Consultas/Vacinas, Exames, Orçamentos, emergência declarada, fora de escopo, e menção a convênio. O ideal é 2-3 pessoas do Nouvet simulando conversas reais pelo WhatsApp, não só revisão de tela.
- **Usar o painel de indicadores (ainda em construção, mas previsto para os próximos dias) para acompanhar os testes em tempo real assim que ficar pronto** — ele vai mostrar volume e motivo de encaminhamento para humano, o que ajuda a enxergar na hora se algo está saindo errado sem esperar reclamação de cliente.
- **Combinar um critério objetivo de "pronto para clientes reais"** (ex.: N conversas de teste sem falha crítica, lista de sinais de alerta validada e ativa) em vez de decidir a abertura só pela data — isso evita abrir sob pressão de calendário com um guardrail de segurança ainda provisório.
- **Aproveitar a fase de testes para fechar as pendências "importante, mas não bloqueia"** da Seção 2 (tom de voz, nome do atendente, quem mantém a agenda dos profissionais) — são rápidas de resolver e melhoram a qualidade percebida desde a primeira conversa real.
- **Alinhar um plano simples de contingência para o Piloto**: se o teste (ou já a operação real) encontrar algo crítico, quem decide pausar o atendente e como isso é comunicado para quem já estiver em conversa.

