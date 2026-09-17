# Questionário ao Nouvet — definições para o atendimento automatizado

**De:** Btech.Cloud · **Data:** 15/09/2026 · **Para:** Nouvet Centro Veterinário 24h

## Por que este documento

O atendimento automatizado mudou de objetivo. O modelo anterior recebia o cliente no WhatsApp, entendia o que ele precisava e **passava para uma pessoa concluir**. Como não há equipe disponível para essa continuidade, o novo modelo vai **concluir o agendamento sozinho**, marcando direto na agenda — e só envolver uma pessoa nas exceções.

Isso muda o que o sistema precisa saber. Analisamos a base do SimplesVet (export de 09/09/2026, 66.564 agendamentos desde fev/2023) e várias respostas já saíram de lá. **As perguntas abaixo são as que os dados não respondem** — decisões de operação e de negócio que só o Nouvet pode tomar.

Cada bloco explica **por que** perguntamos e **o que depende** da resposta. Onde já temos um número, ele está aqui: é mais fácil confirmar ou corrigir do que inventar do zero.

---

## Bloco A — Escopo: o que o agente vai atender

Hoje a agenda de vocês se distribui assim (todos os agendamentos da base desde fev/2023). **Nota:** a *Escola Nouvet* aparecia com 14,2% do volume histórico, mas vocês nos informaram que **o serviço foi descontinuado** — por isso está fora da tabela e do escopo.

| Serviço | Agendamentos | % do total | Por mês (aprox.) |
|---|---|---|---|
| Avaliação Check in Pet — Banho e tosa | **19.698** | 29,6% | ~450 |
| Retorno pós Internação | 5.619 | 8,4% | ~130 |
| Ultrassom | 5.528 | 8,3% | ~125 |
| Consulta Geral | 3.482 | 5,2% | ~80 |
| *Almoço* (bloqueio, não é atendimento) | 3.256 | 4,9% | — |
| Transporte — Leva e Traz | 2.835 | 4,3% | ~65 |
| Consulta Especializada | 2.551 | 3,8% | ~58 |
| Coleta de exames (laboratório) | 2.413 | 3,6% | ~55 |
| Raio X | 2.229 | 3,3% | ~50 |
| Cirurgia | 1.558 | 2,3% | ~35 |
| Internamento | 1.164 | 1,7% | ~26 |
| Vacinação | 993 | 1,5% | ~23 |
| Visita — internação | 771 | 1,2% | ~18 |
| Anestesia | 735 | 1,1% | ~17 |
| Consulta Emergencial | 734 | 1,1% | ~17 |
| Tomografia | 397 | 0,6% | ~9 |
| Consulta Oncológica — Novo Caso | 321 | 0,5% | ~7 |
| Retorno Oncológico | 269 | 0,4% | ~6 |
| Consulta Dermatológica | 245 | 0,4% | ~6 |
| Exames Cardiológicos | 227 | 0,3% | ~5 |
| Consulta Odontológica | 190 | 0,3% | ~4 |
| Avaliação — Atestado de Viagem | 187 | 0,3% | ~4 |

**Total: 66.564 agendamentos** entre fev/2023 e set/2026 — hoje cerca de **2.400 por mês**. Sem a Escola (9.452 + 174 registros), sobram **56.938**, e o Banho e tosa passa a representar **34,6%** do que resta.

**A.1 — Transporte (Leva e Traz)**

> **Já decidimos como tratar isso**, e explicamos abaixo o porquê. As perguntas que seguem continuam importantes — elas definem o que o agente pode dizer ao cliente e o que será automatizado depois —, mas **não travam a entrega**.

Hoje o transporte funciona graças a uma negociação humana que um sistema automático não consegue reproduzir.

O que os dados mostram (2.835 transportes, 602 dias):

- **É um adicional de outro serviço**: dos 2.609 dias com transporte, **53% também tinham Banho e tosa** e **40% também tinham Escola Nouvet** (serviço descontinuado). Só 8% foram transporte isolado. **Com o fim da Escola, o transporte passa a ser, na prática, um adicional do Banho e tosa** — o que também significa que o volume histórico de 4,3% deve cair.
- **A área é bem concentrada**: Jardim Paulista 37,9%, Cerqueira César 32,4%, Jardim América 10,4% — **três bairros somam 80,7%**; somando Pinheiros e Consolação chega a 91,4%. Ao todo, 30 bairros.
- **A agenda trabalha em slots fixos de 30 minutos**: 68,6% dos transportes consecutivos do mesmo dia estão exatamente 30 minutos um do outro, quase sempre um por horário.
- **Esses 30 minutos não parecem calibrados por distância**: viagens consecutivas no mesmo bairro e em bairros diferentes têm o mesmo intervalo mediano de 30 minutos.
- **O encaixe informal existe, mas é raro**: só **27 vezes** (1%) houve dois transportes no mesmo horário.
- **Volume**: 2.835 viagens em 602 dias — mediana de 3 por dia, 12 nos dias de pico, máximo de 20.
- **O registro de ida e volta é inconsistente**: 91,8% dos dias têm **um único** registro de transporte para o animal — às vezes é a ida, às vezes a volta. Na mediana, o transporte está 30 minutos antes do serviço, mas 40% dos registros estão *depois*.

**Por que isso trava a automação.** Hoje, se a agenda do motorista está cheia, a recepção conversa com ele: *"você já vai buscar um no Cerqueira César, dá pra encaixar um no Jardim Paulista que é do lado?"* — e normalmente dá. Essa elasticidade não está escrita em lugar nenhum. Se o agente seguir a agenda ao pé da letra, **vai recusar transportes que vocês hoje aceitam**. Se ignorar a agenda, **vai marcar o que o motorista não consegue cumprir**. Precisamos que vocês definam a regra.

**A.1.1** — Existe **área de atendimento definida**, ou o transporte atende quem está perto e a recepção julga caso a caso? Se houver regra, qual é? Se não houver, podemos usar a lista de bairros acima (Jardim Paulista, Cerqueira César, Jardim América, Pinheiros, Consolação) como regra, tratando o resto como exceção que passa por uma pessoa?

**A.1.2** — **É um veículo só?** Os dados sugerem que sim (quase nunca há dois transportes no mesmo horário). Se forem dois ou mais, muda tudo.

**A.1.3** — Os **30 minutos entre uma viagem e outra** são o tempo real necessário, ou é só o espaçamento padrão da agenda e o motorista se vira? Existe trajeto dentro da área que **não** cabe em 30 minutos?

**A.1.4** — Nos dias de pico (20 viagens), como é feito? Entre 8h e 15h cabem 14 intervalos de 30 minutos — então ou o horário estica, ou viagens são combinadas. **Como?**

**A.1.5** — **Ida e volta**: uma solicitação de transporte é sempre ida **e** volta, ou o cliente pode pedir só um dos lados? E na agenda, deve aparecer **um registro ou dois**? (Hoje é inconsistente, e isso faz a agenda do motorista não refletir a ocupação real.)

**A.1.6** — O transporte **tem custo**? Varia com a distância ou é valor único?

**A.1.7** — Para quais serviços o Leva e Traz pode ser pedido — só Banho e tosa, ou qualquer atendimento?

**A.1.8** — O agente deve **oferecer** o transporte quando marca um banho, ou só registrar quando o cliente pedir?

**A.1.9 — Como vamos tratar na primeira versão (decidido).** O agente **agenda o serviço principal normalmente** (banho, consulta) e **registra o pedido de transporte como "a confirmar"**, dizendo ao cliente que a recepção retorna com o horário da busca. O transporte **não será marcado automaticamente na agenda do motorista** nesta fase.

Motivo: a regra que vocês usam hoje para aceitar ou recusar uma viagem não está escrita em lugar nenhum — ela vive na conversa entre a recepção e o motorista. Um sistema que siga a agenda ao pé da letra recusaria viagens que vocês aceitam; um que a ignore prometeria viagens que o veículo não cumpre. Nos dois casos o cliente sai perdendo. Preferimos manter a decisão com vocês e automatizar depois, quando a regra estiver clara.

**A.1.10** — Com isso em mente: o que o agente deve **dizer** ao cliente ao registrar o pedido? (ex.: *"vou registrar o leva e traz e a recepção confirma o horário da busca com você"* — sem prometer horário.) Há algum prazo de retorno que vocês conseguem sustentar?

**A.2 — Retorno pós Internação (5.619 registros, 8,4%, ~130/mês).** É o maior item depois do banho e tosa.
- Quem marca esse retorno hoje — a recepção, o veterinário na alta, ou o cliente liga?
- **O agente deveria entrar em contato proativamente** para marcar o retorno após a alta, ou isso continua manual?

**A.3 — Vacinação (993 registros, 1,5%, ~23/mês).** Estava previsto como um fluxo completo do agente, mas representa pouco volume.
- Faz sentido manter como agendamento pelo agente, ou vacina é sempre encaixe/junto de consulta?

**A.4 — Emergência: o agente não agenda, ele manda vir. ⚡ Vale desde a primeira versão**

Olhando os dados, percebemos que **emergência não é agendamento**. Medimos quanto tempo antes do horário marcado cada registro foi criado:

| Tipo | Registros | Criados na hora ou depois |
|---|---|---|
| Consulta Emergencial | 734 | **98%** |
| Internamento | 1.164 | **81%** |
| Consulta Geral | 3.482 | **65%** |
| Banho e tosa | 19.698 | 18% |
| Cirurgia | 1.558 | 8% |

Ou seja: os 734 atendimentos emergenciais **não foram marcados** — foram registrados depois que o animal já tinha chegado. Não existe "agendar uma emergência".

Por isso o agente terá um **comportamento de emergência** separado do agendamento: ao identificar uma situação grave, ele **não oferece horário** — orienta o cliente a vir imediatamente e avisa a clínica. Esse comportamento vale em qualquer conversa, inclusive no meio de um agendamento de banho, e entra já na primeira versão.

**A.4.1** — Confirmam esse comportamento? **Para quem o agente deve avisar** quando reconhecer uma emergência fora do horário comercial — existe plantão, um número, um grupo?

**A.4.2** — Quais situações vocês consideram emergência que exige vinda imediata? (Temos uma lista inicial, mas precisa ser revisada por um veterinário de vocês.)

**A.4.3** — Já **cirurgia** (1.558 registros, marcados com ~7 dias de antecedência) e **anestesia** (735, ~3 dias) são agendamentos de verdade, mas dependem de avaliação clínica prévia. Confirmam que o agente **não** deve agendá-los, e sim encaminhar?

**A.5 — Internação e visita**

Os 1.164 registros de "Internamento" quase nunca são um cliente pedindo internação: 81% são criados depois do fato. E mesmo os 217 criados com antecedência têm mediana de **apenas 6 horas** — e **161 deles (74%) acontecem na `Sala de Acompanhamento Família`**, junto com exames de animais que já estão internados. Parece ser a clínica se organizando em torno de um animal que já está aí dentro, não um agendamento vindo do cliente.

**A.5.1** — Quando um cliente fala de internação no WhatsApp, **o que ele normalmente quer**: visitar o animal, saber como ele está, ou perguntar se vai precisar internar? (As três coisas têm respostas diferentes e precisamos saber qual é a comum.)

**A.5.2** — **`Visita — internação`** (771 registros, ~18/mês, sala própria, 15 a 30 minutos) parece um bom candidato para o agente agendar: ele não decide nada clínico, só reserva um horário numa sala. Faz sentido? Há regra de horário ou de quantas visitas por dia?

**A.5.3** — Pedidos de **notícia do animal internado** ("como ele está?") devem ir para qual setor?

**A.6 — Internação: o que o cliente costuma querer?**

Os 1.164 registros de "Internamento" quase nunca partem de um pedido do cliente — 81% são criados depois do fato, e mesmo os 217 criados com antecedência têm mediana de **6 horas**, com 74% deles na `Sala de Acompanhamento Família`.

Quando alguém fala de internação pelo WhatsApp, **o que essa pessoa normalmente quer**: visitar o animal, saber como ele está, ou perguntar se vai precisar internar? As três têm respostas diferentes e precisamos saber qual é a comum.

---

## Bloco C2 — A mudança no preço do banho

Notamos algo na base que precisa de confirmação de vocês.

**Até julho/2026**, o banho era cobrado por **porte e comprimento de pelo** — oito combinações. **A partir de agosto** começou a migração para **valor único por espécie**, e em setembro ela está completa: nenhuma cobrança por porte, só `Banho Nouvet | Cães R$ 120,00` e `| Gatos R$ 240,00`.

Comparando o preço de tabela anterior com o novo:

| Porte / pelo | Antes | Agora | Variação |
|---|---|---|---|
| P — curto | R$ 92,00 | R$ 120,00 | **+30%** |
| P — longo | R$ 104,00 | R$ 120,00 | **+15%** |
| M — curto | R$ 104,00 | R$ 120,00 | +15% |
| M — longo | R$ 120,00 | R$ 120,00 | igual |
| G — curto | R$ 143,00 | R$ 120,00 | −16% |
| G — longo | R$ 176,00 | R$ 120,00 | −32% |
| GG — longo | R$ 202,00 | R$ 120,00 | **−41%** |

**O que nos chama atenção:** entre os animais cuja classificação conseguimos recuperar do faturamento, **68% são porte P**. Ou seja, a maioria dos clientes de banho teve **aumento**, e os poucos donos de cães grandes tiveram queda expressiva.

**C2.1** — O valor único é **definitivo e intencional**, ou é transição?

**C2.2** — Vocês têm acompanhado o efeito disso no volume de banhos? Se houver queda nos próximos meses entre tutores de cães pequenos, é candidato a explicação.

**C2.3** — **Do nosso lado isso simplifica:** com valor único por espécie, o agente informa o preço do banho com segurança, sem precisar saber o porte. Já a **tosa continua por porte × pelo** — e essas duas informações **não existem no cadastro** (o campo de pelagem guarda cor, não comprimento; não há campo de porte). Enquanto não tivermos o porte confirmado, o agente informará o valor da tosa **com ressalva** ("confirmado no check-in, conforme o porte"). Vocês concordam com essa ressalva?

**C2.4** — Se voltarem ao modelo por porte, precisamos saber com antecedência: o agente passará a precisar do porte também para o banho.

---

## Bloco F2 — Mensagem de recorrência

Medimos o intervalo entre banhos: **mediana de 14 dias**. De 1.377 animais que já tomaram banho, **867 (63%) voltaram** pelo menos uma vez, e 59% retornam em até 15 dias. Banho no Nouvet é **rotina quinzenal**, não evento isolado.

Olhando quando cada animal tomou banho pela última vez (referência 09/09/2026):

| Situação | Animais |
|---|---|
| Ativo (menos de 45 dias) | 204 |
| **Atrasado (45 a 90 dias)** | **105** |
| **Sumido (90 a 180 dias)** | **103** |
| Inativo (mais de 180 dias) | 965 |

Os **208 animais nas faixas "atrasado" e "sumido" tinham ritmo e pararam.** A R$ 120,00 o banho, recuperar metade é da ordem de **R$ 12 mil** — e recorrente a cada quinze dias.

**F2.1** — Depois de quantos dias sem banho o agente deve procurar o cliente?

**F2.2** — Ele insiste se não houver resposta, ou fala uma vez só?

**F2.3** — O que fazer com os **965 inativos há mais de 180 dias**? Campanha única de reativação, ou deixar quieto? (Atenção: essa lista tem animais que faleceram ou mudaram de cidade — precisa de cuidado no texto.)

**F2.4** — Vale a pena o agente mandar uma mensagem **depois do atendimento** perguntando como foi? Serve para satisfação e, de quebra, confirma que o cliente compareceu.

---

## Bloco G2 — Exportação eventual do SimplesVet

Não precisaremos de uma rotina periódica. O acompanhamento do dia a dia virá do próprio calendário e das confirmações do cliente. A exportação fica como recurso **eventual**, para dois usos pontuais:

1. **Carga inicial** — clientes, pets e contatos, uma vez, na entrada em produção.
2. **Conferência ocasional** de porte e tipo de pelo — quando o check-in fatura a tosa, a classificação escolhida é a correta; um export esporádico permite corrigir nosso cadastro. Não é urgente, porque o agente sempre informa o valor da tosa com a ressalva de confirmação no check-in.

**G2.1** — Quem consegue gerar esse export quando pedirmos? (Precisamos apenas de agenda, vendas, itens de venda, pessoas, contatos e animais — não do banco inteiro.)

**G2.2** — Há alguma restrição para gerá-lo, ou é uma exportação simples do sistema?

---

## Bloco B — Duração dos atendimentos e horário dos recursos

**Esta é a lacuna mais importante.** O SimplesVet **não guarda a duração de um atendimento** — a tabela de tipos de atendimento tem apenas nome e status. Na prática, quem marca escolhe o horário na grade e deixa o espaço que julga necessário. Funciona porque é uma pessoa decidindo.

O agente precisa desse número explícito: sem duração, ele não sabe quantos atendimentos cabem no dia nem quando o próximo horário está livre.

Medimos o **espaçamento real** entre agendamentos consecutivos no mesmo recurso ao longo de 2026. Não é a duração declarada, é o que a operação pratica:

| Serviço | Mediana praticada | Mais comum | Duração a adotar |
|---|---|---|---|
| Avaliação Check in Pet — Banho e tosa | 75 min | 60 min | ☐ |
| Ultrassom | 45 min | 45 min | ☐ |
| Retorno pós Internação | 45 min | 45 min | ☐ |
| Raio X | 45 min | 45 min | ☐ |
| Consulta Geral | 60 min | 60 min | ☐ |
| Consulta Especializada | 60 min | 60 min | ☐ |
| Consulta Emergencial | 60 min | 60 min | ☐ |
| Coleta de exames (laboratório) | 30 min | 15 min | ☐ |
| Vacinação | 45 min | 45 min | ☐ |
| Tomografia | 45 min | 45 min | ☐ |
| Exames Cardiológicos | 45 min | 45 min | ☐ |
| Transporte — Leva e Traz | 45 min | 30 min | ☐ |
| Visita — internação | 30 min | 15 min | ☐ |

**B.1** — Confirmam ou ajustam a coluna "duração a adotar"? Para banho e tosa, a diferença entre 60 e 75 minutos muda em ~2 atendimentos por dia por profissional.

**B.2** — A duração de banho e tosa varia por **porte do animal** ou tipo de tosa? Se sim, precisamos das faixas.

**B.3** — A grade hoje é de 30 em 30 minutos (68% dos agendamentos caem na hora cheia, 25% na meia hora). **Mantemos grade de 30 minutos?**

**B.4 — Horário de funcionamento por recurso.** Também não existe no sistema; deduzimos do uso:

| Recurso | Janela praticada em 2026 |
|---|---|
| Imagem1 (Usg/Rx/Tomo) | 9h–20h |
| Imagem2 (Rx/Tomog) | 9h–12h |
| Consult.1 — Clínica Dra Érika | 8h–19h |
| Consult.1 — Clínica Dr Jorge | 8h–19h |
| Consult.2 — Clínica Dr Pedro | 8h–16h |
| Consult.3 — Fisioterapia + Especialistas | 9h–18h |
| Consul.4 — Especialistas | 8h–18h |
| Consult onc-1 | 8h–14h |
| Sala de Infusão | 8h–16h |
| Sala de Acompanhamento Família | 11h–17h |
| Laboratório Nouvet | 9h–20h |
| Anestesia Nouvet | 9h–17h |
| Transporte Nouvet | 8h–15h |

Confirmam esses horários? Há intervalo de almoço fixo por recurso? (Hoje "Almoço" aparece como bloqueio na própria agenda, 4,9% dos registros.)

---

## Bloco C — Preço: o que o agente pode informar e o que vira orçamento

Encontramos na base **3.132 itens com preço cadastrado**, distribuídos em **32 categorias ativas** (serviços e produtos, com tabela de preço e status). Isso permite uma separação que antes não era possível:

- **Tabela de preço** — serviço com valor fechado e previsível (ex.: banho de porte P, consulta geral, uma vacina). **O agente informa o valor na hora.**
- **Orçamento** — precisa compor: depende de avaliação, de porte, de quantidade de itens, de exames prévios, de material. **O agente coleta as informações e encaminha para a equipe de Orçamentos.**

**C.1** — Concordam com essa separação?

**C.2** — **Quais categorias podem ter valor informado direto pelo agente?** Marquem:

☐ Banho ☐ Tosa ☐ Consultas ☐ Consulta Especializada ☐ Vacinas ☐ Transporte Pet ☐ Laboratório ☐ Imagem (RX/USG/Tomo) ☐ Fisioterapia ☐ Procedimentos Ambulatoriais ☐ Pet Shop ☐ Plano de saúde ☐ Black Pet

E quais **nunca** — sempre orçamento? (nossa suposição: Cirurgias, Internamento, Oncologia, Células Tronco, Anestesia)

**C.3** — A tabela de preço do SimplesVet está **atualizada e confiável** para ser dita ao cliente? Quem mantém e com que frequência?

**C.4** — O valor informado pelo agente deve vir com alguma ressalva ("valor sujeito a confirmação", "não inclui medicação")?

**C.5** — Existe diferença de preço por **convênio / plano de saúde**? Se sim, o agente informa o valor de tabela ou não informa quando há convênio?

---

## Bloco D — Agenda, escala e a mudança para o calendário Microsoft

A análise mostrou que a agenda de vocês é organizada **por recurso**, não por pessoa: além das agendas nominais, existem consultórios (Consult.1 a 4, onc-1, onc-2), salas (Infusão, Acompanhamento Família), equipamentos (Imagem1, Imagem2), Laboratório, Anestesia, Cirurgia e Transporte. Cerca de **20 a 22 recursos ativos por dia útil**, 17 no sábado e 9 no domingo.

A escala (quem/o quê está aberto em cada dia) está lançada até **setembro de 2027**.

**D.1** — Confirmam que essa lista de recursos está atual? Algum deve sair ou entrar?

**D.2** — **Quem mantém a escala hoje** (nome e função)? Com que antecedência e em que frequência?

**D.3** — A escala hoje é **por dia** (o recurso está aberto ou fechado naquela data). Existe caso de recurso que funciona **só parte do dia** — meio período, plantão noturno? Se sim, precisamos representar isso.

**D.4** — Quando a agenda migrar para o calendário Microsoft, **quem vai olhar/editar**: cada profissional no próprio Outlook, ou uma pessoa central mantém tudo?

**D.5** — Existe algum recurso cuja agenda **não pode** ser exposta ao agendamento automático?

---

## Bloco E — Atendimento humano e transferências

Quando o agente não puder resolver, ele transfere a conversa **dentro do RD Station Conversas**, para um setor — e o próprio RD distribui entre as pessoas do setor.

> **Divisão de responsabilidade.** O agente transfere a conversa **para um setor** do RD Station Conversas — nunca para uma pessoa específica. Quem recebe é definido pelo próprio RD, pela configuração do setor. Portanto: **manter os setores criados e com os funcionários corretos é responsabilidade do Nouvet**; a obrigação do sistema que estamos construindo termina na transferência para o setor certo.

**E.1 — Setores que precisam existir.** Para a entrega funcionar, o RD Station Conversas precisa ter configurados:

| Setor | Para quê | Pessoas indicadas por vocês |
|---|---|---|
| **Orçamentos** | Pedidos de valor que exigem composição | Letícia Mota, Simone Costa, Danielle Alves, Edson Candido |
| **Recepção** | Demais transferências (dúvida clínica, fora de escopo, convênio, cliente insistindo) | Kátia Valéria, Gabriela, Airton, Larissa, Marcela, Giovanna, Suzany, Zeila, Gislane |
| **Atendimento IA** | Fila exclusiva do agente — **sem nenhum atendente humano** | — |

**E.1.1** — Confirmam essa estrutura e as pessoas de cada setor?

**E.2 — Ajustes necessários no cadastro do RD (responsabilidade do Nouvet).** Ao conferir o cadastro atual, encontramos **contas duplicadas e e-mails inconsistentes** entre as pessoas indicadas — casos em que existe mais de uma conta para o mesmo nome, ou variações de grafia, sem que seja possível saber de fora qual é a ativa. Enviamos o levantamento detalhado em separado, para quem administra a ferramenta.

**Por que isso importa:** se o setor for montado com uma conta inativa ou duplicada, a conversa transferida pelo agente entra numa fila que ninguém acompanha — e o cliente fica esperando um atendimento que não vai acontecer. O sistema não tem como detectar isso.

**E.2.1** — Quem no Nouvet fica responsável por revisar e manter o cadastro de usuários e setores do RD daqui em diante?

**E.2.3** — Contas genéricas (Marketing, Internação, Financeiro, Veterinários, Gestão TI) devem receber transferência do agente? Nossa premissa é que **não**.

**E.3 — Oncologia.** Existem dois consultórios de oncologia na agenda (onc-1 e onc-2) e foi mencionado que, em alguns casos, após a consulta o atendimento é encaminhado para a **"Rose"**. Não há ninguém com esse nome no RD Station.
- Quem é a Rose e qual conta ela usa?
- **Qual é o critério** que define que um caso vai para ela?

**E.4 — Horário do atendimento humano.** A clínica é 24h, mas o agente responde a qualquer hora. Se ele precisar transferir às 3h da manhã, **tem alguém?** Se não, o que ele deve dizer ao cliente?

**E.5** — Quando o atendente humano termina, a conversa volta para o agente transferindo de volta ao setor "Atendimento IA" no painel. **Vocês aceitam esse procedimento** como rotina da recepção?

---

## Bloco F — Confirmação e lembretes

Hoje, dos **66.564 agendamentos** da base:

- **45.375 (68,2%)** terminam como *Atendido*
- **8.235 (12,4%)** ficam como *Atrasado* (a hora passou e o status nunca evoluiu)
- **5.111 (7,7%)** *Cancelado*
- **apenas 1.647 (2,5%)** chegam a ser marcados como *Confirmado*

Ou seja: **13.346 agendamentos — cerca de 1 em cada 5 — não viraram atendimento**, e a confirmação prévia praticamente não acontece.

**F.1** — Vocês reconhecem esse número? "Atrasado" significa mesmo falta/abandono, ou é só status que ninguém atualiza?

**F.2** — **Qual seria uma melhora relevante** para vocês? (ex.: reduzir falta de 20% para 15%; elevar confirmação de 2,5% para 40%.) Precisamos de uma meta para medir o sucesso do projeto.

**F.3 — Quando lembrar.** Medimos quando os cancelamentos acontecem hoje, e o resultado sugere uma resposta:

| Quando o cancelamento foi registrado | Todos | Só banho |
|---|---|---|
| **Depois do horário já ter passado** | **53,4%** | **59,0%** |
| Menos de 2h antes | 5,0% | 5,5% |
| Entre 2h e 24h antes | 26,3% | 21,8% |
| Mais de 24h antes | 15,2% | 13,7% |

**Mais da metade dos "cancelamentos" não são cancelamento — são falta, registrada depois.** O cliente simplesmente não apareceu e alguém limpou a agenda. E entre os que avisam, a maioria avisa **entre 6 e 24 horas antes** — é a janela em que a pessoa realmente decide. (As confirmações de hoje confirmam o padrão: 66% acontecem entre 6 e 24h antes.)

**Nossa proposta, baseada nisso:**

| Lembrete | Quando | Para quê |
|---|---|---|
| **1º** | **24h antes** | Pega a janela em que o cliente decide, pede confirmação e — se ele não puder — **ainda dá tempo de remarcar e de oferecer o horário liberado a outra pessoa** |
| **2º** | **2h antes** | Não serve para recuperar o horário (a essa altura ninguém mais ocupa), mas combate o **esquecimento puro** — que é o que explica os 53% que somem sem avisar |

**F.3.1** — Concordam com 24h e 2h? Preferem só um dos dois?

**F.3.1a** — E quando o cliente marca **em cima da hora**? Se ele agenda às 15h de hoje para as 10h de amanhã, o lembrete de 24h já não faz sentido — ele acabou de escolher esse horário. Nossa regra: **o lembrete é suprimido quando o momento dele já passou ou cairia perto demais do agendamento**; nesse exemplo, só o de 2h seria enviado. E quem marca com 2h de antecedência não recebe lembrete nenhum. Concordam?

> Isso é comum: **42% dos banhos são marcados com menos de 24 horas de antecedência**, e 18% com menos de uma hora.

**F.3.2** — A cadência será **configurável por serviço** — banho pode ter lembrete diferente de exame. Há algum serviço que precise de antecedência maior?

**F.4** — O lembrete deve **pedir confirmação** ("responda SIM para confirmar") e **oferecer remarcação** se o cliente não puder?

> **É este o principal mecanismo contra a cadeira vazia.** Hoje apenas 1.647 agendamentos (2,5%) chegam a ser confirmados, porque confirmar depende de alguém clicar no sistema. Com o agente, a confirmação passa a acontecer na conversa — e quem responde que não pode é **remarcado na hora**, em vez de virar falta.

**F.5** — Se o cliente não responder ao lembrete, o que acontece? Mantém, cancela, avisa a recepção?

**F.6** — Vocês aceitam que a primeira mensagem do atendimento peça **autorização para enviar avisos por WhatsApp** (exigência da Meta para mensagens iniciadas pela empresa)?

---

## Bloco G — Cadastro de clientes e a fronteira com o SimplesVet

Como o SimplesVet não tem integração disponível, a base de clientes e pets será **importada uma única vez** na entrada em produção (**4.581 pessoas, 5.740 animais, 9.504 contatos**). A partir daí, as duas bases seguem separadas até a troca de sistema.

**G.1** — Quando o agente atender um cliente **novo**, ele será cadastrado na nossa base. **Quem do Nouvet vai lançar esse cliente no SimplesVet?** Nossa proposta é gerar uma tarefa no RD Station CRM avisando que há cadastro pendente.

**G.2** — Quem transforma o agendamento em atendimento/prontuário no SimplesVet continua sendo quem atende, como hoje. Confirmam que isso **está fora** da nossa entrega?

**G.3** — Há previsão para a **troca do sistema de gestão**? Já existe candidato? (Isso muda o que faz sentido construir agora.)

**G.4** — Muitos clientes têm **mais de um telefone** cadastrado (média de 2 por pessoa). O agente vai reconhecer o cliente pelo número que ele usar no WhatsApp. Há algum caso em que isso seja um problema — tutores diferentes do mesmo animal, telefone comercial compartilhado?

---

## O que depende destas respostas

| Bloco | Trava o quê |
|---|---|
| A | Escopo do projeto — quantos fluxos serão construídos. (A.1/transporte deixou de ser bloqueante: na v1 o agente registra o pedido, não agenda.) |
| B | O agente conseguir calcular horário livre. **Sem isso não há agendamento automático.** |
| C | O que o agente fala sobre preço |
| D | Estrutura dos calendários Microsoft e a tela de escalas |
| E | Para onde vão as conversas que o agente não resolve |
| F | A meta de sucesso do projeto e o fluxo de lembretes |
| G | Importação e a fronteira de responsabilidade |

Os blocos **B** e **E** são os mais urgentes: sem duração e horário, o agendamento automático não existe; sem o cadastro correto do RD, as transferências caem no vazio.
