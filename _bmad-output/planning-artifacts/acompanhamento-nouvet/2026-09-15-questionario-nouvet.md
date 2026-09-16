# Questionário ao Nouvet — definições para o atendimento automatizado

**De:** Btech.Cloud · **Data:** 15/09/2026 · **Para:** Nouvet Centro Veterinário 24h

## Por que este documento

O atendimento automatizado mudou de objetivo. O modelo anterior recebia o cliente no WhatsApp, entendia o que ele precisava e **passava para uma pessoa concluir**. Como não há equipe disponível para essa continuidade, o novo modelo vai **concluir o agendamento sozinho**, marcando direto na agenda — e só envolver uma pessoa nas exceções.

Isso muda o que o sistema precisa saber. Analisamos a base do SimplesVet (export de 09/09/2026, 66.564 agendamentos desde fev/2023) e várias respostas já saíram de lá. **As perguntas abaixo são as que os dados não respondem** — decisões de operação e de negócio que só o Nouvet pode tomar.

Cada bloco explica **por que** perguntamos e **o que depende** da resposta. Onde já temos um número, ele está aqui: é mais fácil confirmar ou corrigir do que inventar do zero.

---

## Bloco A — Escopo: o que o agente vai atender

Hoje a agenda de vocês se distribui assim (todos os agendamentos da base desde fev/2023). **Nota:** a *Escola Nouvet* aparecia com 14,2% do volume histórico, mas vocês nos informaram que **o serviço foi descontinuado** — por isso está fora da tabela e do escopo.

| Serviço | Fatia da agenda |
|---|---|
| Avaliação Check in Pet — Banho e tosa | **29,6%** |
| Retorno pós Internação | 8,4% |
| Ultrassom | 8,3% |
| Consulta Geral | 5,2% |
| Transporte — Leva e Traz | 4,3% |
| Consulta Especializada | 3,8% |
| Coleta de exames (laboratório) | 3,6% |
| Raio X | 3,3% |
| Cirurgia | 2,3% |
| Internamento | 1,7% |
| Vacinação | 1,5% |
| Demais (oncologia, dermatologia, odonto, cardio, tomografia…) | ~10% |

**A.1 — Transporte (Leva e Traz)**

> **Já decidimos como tratar isso**, e explicamos abaixo o porquê. As perguntas que seguem continuam importantes — elas definem o que o agente pode dizer ao cliente e o que será automatizado depois —, mas **não travam a entrega**.

Hoje o transporte funciona graças a uma negociação humana que um sistema automático não consegue reproduzir.

O que os dados mostram (2.835 transportes, 602 dias):

- **É um adicional de outro serviço**: dos 2.609 dias com transporte, **53% também tinham Banho e tosa** e **40% também tinham Escola Nouvet** (serviço descontinuado). Só 8% foram transporte isolado. **Com o fim da Escola, o transporte passa a ser, na prática, um adicional do Banho e tosa** — o que também significa que o volume histórico de 4,3% deve cair.
- **A área é bem concentrada**: Jardim Paulista 37,9%, Cerqueira César 32,4%, Jardim América 10,4% — **três bairros somam 80,7%**; somando Pinheiros e Consolação chega a 91,4%. Ao todo, 30 bairros.
- **A agenda trabalha em slots fixos de 30 minutos**: 68,6% dos transportes consecutivos do mesmo dia estão exatamente 30 minutos um do outro, quase sempre um por horário.
- **Esses 30 minutos não parecem calibrados por distância**: viagens consecutivas no mesmo bairro e em bairros diferentes têm o mesmo intervalo mediano de 30 minutos.
- **O encaixe informal existe, mas é raro**: só **27 vezes** (1%) houve dois transportes no mesmo horário.
- **Volume**: mediana de 3 transportes/dia, 12 nos dias de pico, máximo de 20.
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

**A.2 — Retorno pós Internação (8,4%).** É o terceiro maior item.
- Quem marca esse retorno hoje — a recepção, o veterinário na alta, ou o cliente liga?
- **O agente deveria entrar em contato proativamente** para marcar o retorno após a alta, ou isso continua manual?

**A.3 — Vacinação (1,5%).** Estava previsto como um fluxo completo do agente, mas representa pouco volume.
- Faz sentido manter como agendamento pelo agente, ou vacina é sempre encaixe/junto de consulta?

**A.4 — Fora de escopo.** Confirmam que o agente **não** deve agendar: Cirurgia, Internamento, Anestesia, Consulta Emergencial? (A nossa premissa é que esses sempre passam por avaliação humana.)

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

Encontramos na base **3.132 itens com preço cadastrado** (serviços e produtos, com tabela de preço e status). Isso permite uma separação que antes não era possível:

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

**E.1 — Setor Orçamentos.** Vocês indicaram: Letícia Mota, Simone Costa, Danielle Alves, Edson Candido. Confirmam?

**E.2 — Setor Recepção.** Vocês indicaram: Kátia Valéria, Gabriela, Airton, Larissa, Marcela, Giovanna, Suzany, Zeila, Gislane. Encontramos **ambiguidades no cadastro do RD** que precisam ser resolvidas antes, senão a transferência cai na conta errada:
- **Zeila**: existem *Zêila Moreira* (zeila.moreira@) e *Zélia Moreira* (zelia.moreira@) — qual é a correta? A outra deve ser desativada?
- **Larissa**: existem *Larissa Costa* e *Larissa Araújo* — qual atende o RD?
- **Débora Oliveira**: existem **cinco** contas, incluindo uma com e-mail terminado em `.com.bt` (erro de digitação) e outra `recepcao_1andar@`. Qual é a válida?
- Contas genéricas (Marketing, Internação, Internação 2, Financeiro, Veterinários, Gestão TI) devem receber transferência do agente? Nossa suposição: **não**.

**E.3 — Oncologia.** Existem dois consultórios de oncologia na agenda (onc-1 e onc-2) e foi mencionado que, em alguns casos, após a consulta o atendimento é encaminhado para a **"Rose"**. Não há ninguém com esse nome no RD Station.
- Quem é a Rose e qual conta ela usa?
- **Qual é o critério** que define que um caso vai para ela?

**E.4 — Horário do atendimento humano.** A clínica é 24h, mas o agente responde a qualquer hora. Se ele precisar transferir às 3h da manhã, **tem alguém?** Se não, o que ele deve dizer ao cliente?

**E.5** — Quando o atendente humano termina, a conversa volta para o agente transferindo de volta ao setor "Atendimento IA" no painel. **Vocês aceitam esse procedimento** como rotina da recepção?

---

## Bloco F — Confirmação e lembretes

Hoje, dos 66.564 agendamentos da base:

- **68,2%** terminam como *Atendido*
- **12,4%** ficam como *Atrasado* (a hora passou e o status nunca evoluiu)
- **7,7%** *Cancelado*
- **apenas 2,5%** chegam a ser marcados como *Confirmado*

Ou seja: **cerca de 1 em cada 5 agendamentos não vira atendimento**, e a confirmação prévia praticamente não acontece.

**F.1** — Vocês reconhecem esse número? "Atrasado" significa mesmo falta/abandono, ou é só status que ninguém atualiza?

**F.2** — **Qual seria uma melhora relevante** para vocês? (ex.: reduzir falta de 20% para 15%; elevar confirmação de 2,5% para 40%.) Precisamos de uma meta para medir o sucesso do projeto.

**F.3** — Quando o agente deve **lembrar** o cliente — 24h antes, 2h antes, os dois?

**F.4** — O lembrete deve **pedir confirmação** ("responda SIM para confirmar") e **oferecer remarcação** se o cliente não puder?

**F.5** — Se o cliente não responder ao lembrete, o que acontece? Mantém, cancela, avisa a recepção?

**F.6** — Vocês aceitam que a primeira mensagem do atendimento peça **autorização para enviar avisos por WhatsApp** (exigência da Meta para mensagens iniciadas pela empresa)?

---

## Bloco G — Cadastro de clientes e a fronteira com o SimplesVet

Como o SimplesVet não tem integração disponível, a base de clientes e pets será **importada uma única vez** na entrada em produção (4.581 pessoas, 5.740 animais, 9.504 contatos). A partir daí, as duas bases seguem separadas até a troca de sistema.

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
