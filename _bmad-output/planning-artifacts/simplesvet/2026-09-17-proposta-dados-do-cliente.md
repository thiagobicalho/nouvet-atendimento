# Proposta — o que fazemos com os dados de cliente, pet e preferência

Responde às perguntas levantadas por Thiago em 17/09 diante da bagunça de tags e observações do SimplesVet: *"o que vamos fazer para resolver isso? analisar variações e criar padrões? levar para a tela de configuração? manter rotina de sincronização? como saber que o cliente foi atendido? mandar mensagem depois de X dias?"*

---

## O princípio que limita o escopo

Toda pergunta acima vira um projeto se a resposta for "espelhar o SimplesVet". A regra que impede isso:

> **Não espelhar. Derivar uma vez, e depois ser dono.**
>
> Importamos uma vez, normalizando **apenas o que muda o comportamento do agente**. A partir daí, a nossa base é a fonte da verdade **das preferências de atendimento**; o SimplesVet segue sendo a fonte da verdade **do registro clínico**. Não existe sincronização.

Três razões:

1. **Não há API.** Qualquer sincronização seria exportação manual recorrente — trabalho humano novo, exatamente o que matou o Piloto.
2. **O SimplesVet sai em cerca de um ano.** Construir ponte para um sistema em substituição é pagar por algo que será demolido.
3. **Duas fontes de verdade para o mesmo dado sempre divergem.** E quando divergem, ninguém sabe qual está certa.

O custo aceito: uma preferência alterada no SimplesVet depois do go-live não chega até nós. Mitigação: **o agente confirma a preferência a cada agendamento**, em uma linha. Se mudou, o cliente corrige na hora — e a correção fica com a gente.

---

## O que normalizamos, e o que deixamos em paz

Hoje as informações vivem em três campos de texto livre, sem padrão:

| Campo | Preenchido | Distintos |
|---|---|---|
| `ani_txt_tag` (animal) | 1.954 de 5.740 (34%) | **1.981 tags diferentes** para 1.954 animais |
| `pes_txt_tag` (tutor) | 2.433 de 4.581 (53%) | idem |
| `age_txt_observacao` (agendamento) | 33.683 de 66.565 (51%) | texto corrido |

O mesmo plano aparece escrito de seis formas: `PETLOVE IDEAL` (378) · `PLANO: PETLOVE IDEAL` (101) · `PETLOVEIDEAL` (80) · `PLANO IDEAL` (70) · `PET LOVE IDEAL` (36) · `PETLOVE` (25).

### O que estruturamos — no pet e no tutor

Critério: **só vira campo o que o agente precisa para decidir**. O resto continua texto livre.

#### Tabela do PET

| Campo | Origem | Por que |
|---|---|---|
| nome, espécie, raça, nascimento | importado (93,8% / 94,1% / 90,7% preenchidos) | identificação e preço |
| **`plano`** — PETLOVE Ideal · Essencial · Completo · nenhum | normalizado das tags (1.146 animais, 20%) | **muda o preço** |
| **`porte`** — P · M · G · GG | **não existe no SimplesVet — o agente coleta** | **muda o preço da tosa** |
| **`tipo_pelo`** — curto · longo | **não existe no SimplesVet — o agente coleta** | **muda o preço da tosa** |
| `perfume_autorizado` — sim · não · perguntar | normalizado de observações | preferência estável |
| `acessorio_autorizado` — sim · não · perguntar | idem | preferência estável |
| `produto_proprio` — texto curto | idem | muda a execução |
| `observacao_pet` — texto livre | importado | **não interpretamos**; o tosador lê |

> **Achado que bloqueia o preço da tosa.** A tabela do Carding cobra por **porte × comprimento de pelo** (8 combinações, R$ 46,00 a R$ 85,00). **Nenhuma das duas dimensões existe no banco**: não há campo de porte, e `pel_var_nome` guarda **cor** (Branca, Preta, Branco e Marrom), não comprimento — e ainda está vazio em 30,6% dos animais. Há peso em apenas 57,8%.
>
> **Consequência:** o agente **consegue informar preço de banho** (depende só de espécie, 93,8% preenchida — Cães R$ 120,00, Gatos R$ 240,00), mas **não consegue calcular preço de tosa** a partir do dado importado. Porte e tipo de pelo passam a ser **campos nossos, coletados uma vez pelo agente na conversa** e reaproveitados depois — exatamente o princípio de "derivar uma vez e ser dono".

#### Tabela do TUTOR

O plano **não** fica aqui — é por animal, como convém a plano de saúde de pet. O que o tutor precisa ter:

| Campo | Preenchido hoje | Por que |
|---|---|---|
| nome | ~100% | identificação |
| **telefones** (vários, com preferencial) | mediana de 2 por pessoa, máximo 10 | **é a chave de reconhecimento do WhatsApp** |
| **endereços** (lista, não campo único) | 87% têm um endereço; **referência só 0,9%** | regra de área do Leva e Traz **e ponto de retirada** |
| `origem_indicacao` — veterinário encaminhante | ~150 pessoas nas tags | comercial; casa com a carteira "Veterinários Encaminhantes" do RD |
| `cadastro_incompleto` | **372 pessoas (8%)** marcadas como *FINALIZAR/COMPLETAR CADASTRO* | **oportunidade** — o agente conversa naturalmente e pode completar |
| `saldo_aberto` | **102 pessoas, R$ 229.897,97** | **decisão de negócio** — o agente agenda para quem tem débito? |

> Duas perguntas novas para o Nouvet saem daqui: **o agente deve agendar normalmente para cliente com saldo em aberto**, avisar, ou transferir? E **o agente pode completar cadastro incompleto** durante a conversa?

#### Endereço é lista, não campo

O SimplesVet guarda **um endereço por pessoa** — não há suporte a segundo endereço. Mas o ponto de retirada do Leva e Traz pode ser outro: segunda portaria do prédio, entrada de serviço, casa de outra pessoa, endereço do trabalho. E o campo `end_var_referencia`, que serviria para isso, está preenchido em **0,9%** (43 de 4.581) — com coisas como *"prédio rosa"*, *"esquina com a Rua Coriolano"*, *"em frente ao shopping"*.

Nosso modelo:

| Campo | Observação |
|---|---|
| `enderecos[]` — **lista** | cada um com rótulo (residencial, retirada, trabalho), CEP, logradouro, número, complemento, bairro |
| `ponto_referencia` por endereço | texto livre — *"portaria de serviço, pela Rua X"* |
| `endereco_retirada_padrao` | qual da lista o motorista usa |

O primeiro endereço vem do import; **os demais o agente coleta quando o cliente pede transporte** — e ficam guardados. Mais uma aplicação de "derivar uma vez e ser dono".

#### Porte e tipo de pelo: derivar do faturamento, não perguntar ao cliente

A objeção é correta — *o critério do cliente pode não ser o do Nouvet*. Testamos a alternativa proposta: **derivar do que foi efetivamente faturado**, cruzando `eco_venda` → `eco_venda_produto` → `eco_produto`, já que os itens de tosa carregam a classificação no nome (*"Carding - Porte M - Longo"*).

**Funciona, com cobertura parcial:**

| Resultado | Números |
|---|---|
| Itens faturados com porte no nome | 2.761 |
| Animais com porte derivável | 568 |
| **Cobertura sobre a base ativa de banho** | **523 de 1.377 (38%)** |
| Distribuição de porte | P 388 (68%) · M 122 (21%) · G 49 (9%) · GG 9 (2%) |
| Distribuição de pelo | longo 296 · curto 143 · indefinido 129 |
| **Animais com porte divergente entre vendas** | **64 (11%)** |

Duas leituras:

1. **Cobre 38% da base ativa** — quem só toma banho (sem tosa) nunca teve item com porte faturado, então não dá para derivar. É semente, não solução completa.
2. **11% divergem internamente.** O mesmo animal foi faturado como portes diferentes em vendas distintas. Ou seja: **não existe critério único nem dentro do Nouvet hoje.** Isso reforça a preocupação e ao mesmo tempo mostra que o problema não nasce com o agente.

**Modelo proposto — quem valida é quem fatura, sem tarefa nova:**

| Etapa | O que acontece |
|---|---|
| **Semente** | Import deriva porte e pelo do faturamento onde existir (523 animais), marcado como `origem: faturamento` |
| **Coleta** | Para os demais, o agente pergunta uma vez e grava como `origem: cliente` — valor **provisório** |
| **Validação** | No check-in, quem atende escolhe o item a faturar — **isso já é a validação**, e acontece hoje sem esforço extra |
| **Correção** | A reconciliação periódica (mesma do comparecimento) corrige o registro e promove para `origem: faturamento` |

Enquanto o porte for `origem: cliente`, o agente **informa o valor com ressalva** — *"o valor da tosa é confirmado no check-in, conforme o porte"* — em vez de afirmar um número que pode mudar. Para **banho não há ressalva**, porque depende só de espécie.

### O que não estruturamos

Comportamento do animal, condição de saúde, nós no pelo, nível de desembolo. Isso exige **ver o animal** e é o que o serviço `Avaliação Check in Pet` já faz — o nome dele é literalmente a avaliação de check-in. Continua com quem recebe o pet.

---

## Regra de conversa: perguntar, herdar ou deixar para o check-in

> **Pergunta o que muda duração ou preço. Herda o que é preferência estável. Deixa para o check-in o que exige ver o animal.**

Aplicada ao que aparece nas 11.373 observações de banho:

| O que aparece | Frequência | Comportamento do agente |
|---|---|---|
| Unha / ouvido / dente | 3.565 (18,1%) | **Pergunta** — é adicional cobrado |
| Tipo de tosa | 1.639 (8,3%) | **Pergunta** — muda duração e preço |
| Perfume / acessório | 780 (4,0%) | **Herda e confirma em uma linha** |
| Produto próprio | — | **Herda** |
| Saúde, comportamento, nós | ~80 | **Não pergunta** — check-in |

Para pet conhecido, isso vira **uma frase**: *"Do mesmo jeito da última vez — banho com corte de unhas, sem perfume e sem enfeite?"* Uma pergunta, uma resposta.

Efeito colateral relevante: a partir de 01/10 a Meta cobra por mensagem enviada. Um agente que interroga em dez mensagens custa dez vezes mais que um que herda e confirma em uma.

**Regra permanente:** o que o cliente disser espontaneamente vai para `observacao` do agendamento, sem interpretação. É o campo que o tosador lê.

---

## Como saber que o cliente foi atendido

O agente não tem como saber em tempo real: quem marca presença é a recepção, dentro do SimplesVet (botão *"Informar chegada do cliente"*), e não temos leitura de lá.

**Proposta em três camadas, do barato ao caro:**

1. **Não precisa em tempo real.** Nada no fluxo do agente depende de saber se o cliente compareceu. Só as **métricas** dependem.
2. **Reconciliação periódica.** O Nouvet já produziu um export completo uma vez. Um export mensal das mesmas tabelas permite cruzar o que agendamos com o que foi atendido e alimentar os indicadores. Não é tempo real, e não precisa ser.
3. **Confirmação pelo próprio cliente.** A mensagem de acompanhamento pós-atendimento (*"como foi o banho do Bidu?"*) confirma comparecimento de graça — e ainda serve de satisfação.

**No CRM não lançamos atendimento.** O funil do RD Station guarda o ciclo **comercial** — Solicitado → Agendado → Confirmado → Compareceu/Faltou. O registro **clínico** continua só no SimplesVet. Misturar os dois cria a terceira fonte de verdade que o princípio acima proíbe. O estado `Compareceu` vem da reconciliação da camada 2.

---

## A recorrência — e por que ela muda a conversa

Foi a última pergunta: *"mandar mensagem depois de X dias perguntando se quer marcar outro banho?"* Medimos.

**1.377 animais** já tiveram banho atendido. **867 (63%) voltaram pelo menos uma vez.**

| Intervalo entre banhos | Ocorrências | % |
|---|---|---|
| até 15 dias | 8.231 | **59,4%** |
| 16 a 30 dias | 2.800 | 20,2% |
| 31 a 45 dias | 1.167 | 8,4% |
| acima de 45 dias | 1.670 | 12,0% |

**Mediana de 14 dias.** Banho no Nouvet não é evento — é **rotina quinzenal**. E rotina quebrada é receita perdida silenciosamente.

Olhando quando cada animal tomou banho pela última vez (referência 09/09/2026):

| Situação | Animais | % |
|---|---|---|
| Ativo (menos de 45 dias) | 204 | 14,8% |
| **Atrasado (45 a 90 dias)** | **105** | 7,6% |
| **Sumido (90 a 180 dias)** | **103** | 7,5% |
| Perdido (mais de 180 dias) | 965 | 70,1% |

Os **965 "perdidos"** exigem cautela: a base começa em 2023, e ali dentro há animais que morreram, mudaram ou foram clientes de uma vez só. Não é lista de reativação confiável.

Mas os **208 animais nas faixas "atrasado" e "sumido" são outra coisa**: tinham ritmo e pararam. A um valor de tabela de R$ 120,00 por banho de cão, recuperar metade deles é da ordem de **R$ 12 mil**, recorrente a cada quinze dias.

**Proposta:** o lembrete de recorrência **não é escopo novo — é a justificativa econômica do projeto**, e deveria ser tratado como parte da onda 1, não como ideia futura. O mecanismo já existe no desenho (o agente manda lembrete de agendamento; aqui é outro gatilho). O que precisa do Nouvet é decidir a janela e o tom.

**Perguntas para eles:** depois de quantos dias sem banho o agente deve procurar o cliente? Uma vez ou insiste? E o que fazer com os 965 perdidos — campanha única de reativação, ou deixa quieto?

---

## Resumo do que isso significa de trabalho

| Pergunta do Thiago | Resposta |
|---|---|
| Analisar variações e criar padrões? | **Sim, uma vez**, na importação. 1.981 tags → 4 valores de plano + 3 campos |
| Levar para a tela de configuração? | **Não.** Isso é dado de cliente, não configuração do agente. Vai para a base, editável na ficha do pet |
| Tabelas de preferência de animal e tutor? | **Sim, enxutas** — 8 campos no pet (2 deles **coletados pelo agente**, porque não existem no SimplesVet: porte e tipo de pelo) e 6 no tutor. O **plano fica no pet**, não no tutor |
| Manter o padrão do SimplesVet e sincronizar? | **Não.** Import único, sem sincronização. O agente confirma a preferência a cada agendamento |
| Como saber que foi atendido? | Reconciliação por export periódico + confirmação pelo cliente. Não precisa ser tempo real |
| Lançar atendimento no CRM? | **Não.** CRM guarda o ciclo comercial; o clínico fica no SimplesVet |
| Mensagem de recorrência? | **Sim, na onda 1** — mediana de 14 dias entre banhos e 208 clientes recuperáveis |
