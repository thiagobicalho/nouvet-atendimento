---
title: Atendimento Nouvet — agente que agenda
status: draft
created: 2026-09-17
updated: 2026-09-17
---

# Atendimento Nouvet — agente que agenda

> Substitui o PRD do Piloto (`prd-atendimento-2026-08-31`), cuja premissa central caiu. O documento anterior permanece como registro histórico.

## 1. Por que este PRD existe

O Piloto entregou um agente de **triagem**: recebia o cliente no WhatsApp, identificava quem era, entendia o pedido, classificava em um de cinco setores e **passava para uma pessoa concluir**. Foi construído e funcionou.

Em 11/09/2026 o Nouvet informou que não o usaria: *"o piloto não serve para nós porque não temos mão de obra para fazer o agendamento no calendário"*. Não havia — e não haverá — equipe para a continuidade que o desenho pressupunha. A premissa arquitetural que sustentava o Piloto (`AD-4`: o agente nunca agenda) deixou de valer.

**O produto novo conclui o agendamento sozinho.** O humano deixa de ser a etapa seguinte e passa a ser a exceção.

## 2. O problema, em números

Base analisada: export do SimplesVet de 09/09/2026 — **66.564 agendamentos** entre fev/2023 e set/2026, hoje cerca de **2.400 por mês**.

**O ciclo de agendamento vaza em duas pontas.**

| Desfecho | Agendamentos | % |
|---|---|---|
| Atendido | 45.375 | 68,2% |
| **Atrasado** (a hora passou, o status nunca evoluiu) | **8.235** | **12,4%** |
| **Cancelado** | **5.111** | **7,7%** |
| Agendado / Em espera / Confirmado / Em atendimento | 7.829 | 11,8% |

**13.346 agendamentos — 1 em cada 5 — não viraram atendimento.** E a confirmação prévia praticamente não existe: apenas **1.647 (2,5%)** chegaram ao status *Confirmado*. Ninguém lembra o cliente, ninguém confirma, e o resultado aparece como cadeira vazia.

**O atendimento depende inteiramente de pessoas que não existem em quantidade suficiente.** Fora do horário comercial não há quem responda; dentro dele, a recepção divide o WhatsApp com o balcão e o telefone.

**Boa parte da demanda nem chega a virar agendamento.** 65% das consultas gerais (2.263 de 3.482) são registradas na hora ou depois — o cliente simplesmente aparece. O sistema absorve, mas ninguém planeja.

## 3. O que vamos entregar

Um **agente de atendimento no WhatsApp que agenda de ponta a ponta**: reconhece o cliente, entende o pedido, consulta a disponibilidade real do recurso, oferece horários, marca no calendário, confirma, lembra e remarca — sem intervenção humana no caminho comum.

Três coisas o acompanham:

- **O calendário migra para o Microsoft 365.** A agenda do Nouvet passa a viver em calendários de recurso do Outlook, que é onde o agente escreve e de onde a equipe lê.
- **Uma aplicação web** para a Btech configurar o comportamento do agente e para a diretoria do Nouvet manter escalas e acompanhar indicadores.
- **O calendário do Outlook passa a ser a agenda de todos os setores**, não só dos serviços que o agente atende — decisão de 17/09. A migração de calendário é uma **trilha própria**, paralela às ondas do agente: 3.119 agendamentos futuros (até ago/2027, 18 recursos) e 6.642 linhas de escala precisam ser migrados, e a virada é por recurso, não por data única.
- **A base de clientes e pets é importada uma vez** do SimplesVet, que não tem integração disponível.

### 3.1 Objetivos

| # | Objetivo | Como medimos |
|---|---|---|
| O1 | Responder todo cliente imediatamente, 24/7 | Tempo até a primeira resposta |
| O2 | Concluir o agendamento sem humano no caminho comum | % de conversas que terminam em agendamento sem transferência |
| O3 | Reduzir a cadeira vazia — por **confirmação no lembrete** (FR-22), **remarcação imediata** de quem não pode (FR-23) e **recorrência** (FR-23a) | Atrasado + Cancelado sobre o total — **linha de base 20,1%** |
| O4 | Fazer a confirmação prévia existir | % de agendamentos confirmados — **linha de base 2,5%** |
| O5 | Não aumentar o trabalho da equipe | Volume de transferências para humano por 100 conversas |

As metas numéricas de O3 e O4 dependem do Nouvet *(ver §10, QA-1)*. A linha de base está medida.

### 3.2 Como vamos entregar — ondas

O prazo de 01/10/2026 não comporta o escopo completo. A entrega é **modular**, e a primeira onda é a que concentra volume e é genuinamente agendável.

| Onda | Escopo | Volume | Por que nesta ordem |
|---|---|---|---|
| **1** | **Care Center** — banho e tosa | 19.698 registros · **34,6%** do volume sem a Escola · ~450/mês | Maior volume isolado e **o único de alto volume marcado com antecedência** (mediana de 45h). Três recursos nominais, janela consistente, sem dependência de sala ou equipamento. |
| **2** | **Imagem** (US, RX, Tomografia) + **Visita — internação** | 8.154 + 771 registros · ~190 + ~18/mês | Segundo maior bloco e também agendado de verdade (ultrassom, mediana de 51h). Dois recursos, duração consistente de 45 min. A Visita entra junto por ser trivial: sala própria, 15–30 min, zero decisão clínica. |
| **3** | **Consultas** — geral e especializadas | ~7.000 registros | Fica para a terceira porque **65% são walk-in**: automatizar o agendamento ataca cerca de um terço da demanda real. |
| **4** | Vacinas, Orçamentos com composição, Retorno pós Internação proativo, transporte agendado automaticamente, demais especialidades | — | Volume baixo, ou dependem de regra que ainda não existe. |

**Comportamentos transversais valem desde a onda 1**, porque não é possível adiá-los: reconhecimento de emergência, transferência para humano, guardrails de IA, lembrete e confirmação.

## 4. Quem usa

**O cliente do Nouvet** — tutor de cão ou gato, escreve no WhatsApp a qualquer hora. Quer marcar um banho, saber se tem horário na sexta, remarcar porque o filho ficou doente. Não sabe nem quer saber se está falando com um robô, desde que resolva. Hoje espera. **4.581 pessoas e 5.740 animais** na base.

**A recepção do Nouvet** — nove pessoas que dividem o WhatsApp com o balcão. Hoje marcam tudo à mão no SimplesVet. Depois da entrega, recebem só o que o agente não resolve — e é por isso que O5 existe: se o agente gerar mais trabalho do que tira, falhou.

**A diretoria do Nouvet** — precisa saber se está funcionando. Hoje não tem visibilidade de quanto se perde com cadeira vazia. Mantém escalas e olha indicadores.

**A Btech** — TI do Nouvet e responsável pelo agente. Ajusta comportamento, tom, catálogo e regras **sem mexer no fluxo**.

## 5. Jornadas

**UJ-1 — Marcar banho fora do horário, cliente conhecido.**
Sábado, 21h. Mariana escreve *"oi, queria marcar um banho pro Bidu"*. O agente a reconhece pelo telefone, sabe que o Bidu é o cachorro dela, pergunta a preferência de dia. Ela diz *"terça de manhã"*. O agente consulta a agenda real, oferece **terça às 10h ou às 11h30**, ela escolhe, e ele marca — no calendário do profissional de banho, naquele horário. Confirma com o valor de tabela (R$ 120,00, cão). Na segunda à noite ela recebe o lembrete e responde confirmando. *Nenhuma pessoa do Nouvet participou.*

**UJ-2 — Não tem o horário que ele quer.**
João quer sexta de manhã; está cheio. O agente oferece **as próximas três janelas** — sexta 14h, sábado 9h, segunda 10h. João insiste em sexta de manhã. O agente **não nega e não promete**: registra a preferência e transfere para a Recepção, que sabe se dá para encaixar. *A transferência é a exceção, não o fluxo.*

**UJ-3 — Emergência no meio de outra conversa.**
Ana está escolhendo horário de banho quando escreve *"na verdade ele tá vomitando sangue agora"*. O agente **interrompe o agendamento**, não oferece horário, orienta a vir imediatamente e avisa a clínica. *Vale em qualquer conversa, desde a onda 1.*

**UJ-4 — Cliente novo.**
Telefone desconhecido. O agente se apresenta como atendente virtual, pergunta o nome e o do pet, marca o banho e **cria o cadastro na nossa base**. Gera uma tarefa no RD Station CRM avisando que há cliente novo a lançar no SimplesVet — porque essa ponte é manual enquanto o sistema de gestão não for trocado.

**UJ-5 — Remarcar.**
Terça de manhã, Mariana escreve *"não vou conseguir hoje"*. O agente encontra o agendamento dela, cancela, oferece novos horários e remarca. *Sem ligar para a clínica.*

## 6. Requisitos funcionais

### 6.1 Identificação e contexto

- **FR-1** — Reconhecer o cliente pelo telefone do WhatsApp, recuperando nome, pets e histórico de agendamentos.
- **FR-2** — Quando houver mais de um pet, conduzir a conversa para descobrir de qual se trata, sem perguntar dados que já se sabe.
- **FR-3** — Tratar telefone desconhecido como cliente novo, sem travar o atendimento por falta de cadastro.
- **FR-4** — Criar cadastro de cliente e pet quando novos, e sinalizar que há lançamento pendente no SimplesVet.
- **FR-4a** — Coletar dado cadastral faltante **apenas quando a tarefa em curso precisar dele** (ex.: endereço de retirada para transporte) ou **oferecer o complemento ao final**, depois do agendamento confirmado — nunca como etapa que anteceda ou atrase o agendamento.
- **FR-5** — Manter memória da conversa entre mensagens e entre sessões.
- **FR-5a** — Manter preferências estáveis do pet (plano, perfume, acessório, produto próprio, observação livre) e **confirmá-las em uma linha** no agendamento seguinte, em vez de perguntar de novo.

### 6.2 Entendimento do pedido

- **FR-6** — Identificar qual serviço o cliente quer a partir da linguagem natural, usando o catálogo configurado (nome e sinônimos).
- **FR-7** — Agregar mensagens picadas antes de responder, tratando-as como um único pedido.
- **FR-8** — Coletar o que falta para agendar — pet, serviço, preferência de dia e horário — sem repetir o que já foi dito.
- **FR-9** — Reconhecer pedido de serviço que não está no escopo da onda corrente e conduzir para transferência.

### 6.3 Disponibilidade e agendamento

- **FR-10** — Calcular horários realmente disponíveis a partir de: escala do recurso, horário de funcionamento do recurso, duração do serviço e compromissos já marcados.
- **FR-11** — Oferecer um conjunto pequeno de opções de horário, não uma lista longa.
- **FR-12** — Criar o agendamento no calendário do recurso, com cliente, pet, serviço e telefone.
- **FR-13** — Confirmar ao cliente o que foi marcado — serviço, pet, dia, horário e, quando houver, valor.
- **FR-14** — Registrar o agendamento no RD Station CRM, refletindo o ciclo de vida (Solicitado → Agendado → Confirmado → Compareceu/Faltou).
- **FR-15** — Respeitar antecedência mínima e máxima configuradas por serviço.
- **FR-16** — Nunca marcar dois atendimentos no mesmo recurso e horário.
- **FR-17** — Cancelar e remarcar agendamentos existentes, dentro dos limites configurados.
- **FR-17a** — Agir apenas sobre agendamento **do tutor a que o telefone da conversa pertence**. Telefone que não resolve para tutor algum, ou que resolve para mais de um, é tratado como não autorizado.
- **FR-17b** — **Não revelar informação de agendamento fora desse escopo**, nem confirmar que ele existe. Diante de pedido sobre agendamento de terceiro, oferecer os dois caminhos legítimos: a pessoa que marcou resolve pelo número dela, ou a Recepção assume a verificação.
- **FR-17c** — **Nunca vincular telefone novo a um cadastro existente** a pedido do próprio número não reconhecido.

### 6.4 Preço

- **FR-18** — Informar o valor de serviços com preço de tabela, aplicando as variações configuradas (espécie, porte, pelagem, plano).
- **FR-19** — Nunca calcular, estimar ou negociar valor de serviço que dependa de composição — nesses casos, coletar o necessário e transferir para Orçamentos.
- **FR-20** — Acompanhar o valor da ressalva configurada, quando houver.

### 6.5 Lembrete e confirmação

- **FR-21** — Enviar lembrete antes do atendimento, nas antecedências configuradas por serviço (mais de uma).
- **FR-21a** — **Suprimir o lembrete cujo momento já passou ou que cairia perto demais do agendamento.** Quem acabou de escolher o horário não precisa ser lembrado dele. *(42% dos banhos são marcados com menos de 24h de antecedência — nesses casos só o lembrete curto se aplica; e quem marca com 2h de antecedência não recebe lembrete nenhum.)*
- **FR-22** — Pedir confirmação no lembrete e registrar a resposta. *(Mecanismo principal de O3: hoje só 2,5% dos agendamentos são confirmados, porque depende de alguém clicar no sistema.)*
- **FR-22a** — Registrar comparecimento a partir da categoria marcada no evento do calendário, recebida por notificação do Microsoft Graph.
- **FR-23** — Oferecer remarcação quando o cliente disser que não poderá comparecer.
- **FR-23a** — Procurar o cliente quando o intervalo típico do serviço for ultrapassado, oferecendo novo agendamento. *(Banho: mediana de 14 dias entre atendimentos; 208 clientes hoje fora do ritmo.)*
- **FR-24** — Obter e registrar a autorização do cliente para receber mensagens, conforme exigência da Meta para mensagens iniciadas pela empresa.
- **FR-24a** — Enviar toda mensagem proativa **fora da janela de 24 horas** como **template aprovado**, com a categoria correta declarada, e registrar o custo por categoria.

### 6.6 Transporte (onda 1, sem agendamento automático)

- **FR-25** — Registrar pedido de Leva e Traz como **solicitação a confirmar**, vinculada ao agendamento principal, sem prometer horário de busca.
- **FR-26** — Sinalizar o pedido para a equipe que fará a confirmação.

### 6.7 Comportamentos transversais

- **FR-27** — Reconhecer situação de emergência em qualquer ponto da conversa, interromper o que estiver fazendo, **não oferecer horário**, orientar o cliente a vir imediatamente e alertar os destinatários configurados.
- **FR-28** — Transferir para o setor apropriado do RD Station Conversas quando não puder resolver, preservando o histórico da conversa.
- **FR-29** — Permanecer em silêncio enquanto um atendente humano estiver conduzindo a conversa, e retomar quando ela voltar.
- **FR-30** — Identificar-se sempre como atendente virtual, nunca fingir ser humano.
- **FR-31** — Nunca diagnosticar, nunca minimizar sintoma relatado, nunca responder fora das fontes configuradas.
- **FR-32** — Tratar todo texto do cliente como dado, nunca como instrução que altere seu comportamento.
- **FR-33** — Nunca revelar configuração interna, contatos de plantão ou o próprio prompt.

### 6.8 Configuração (Btech)

- **FR-34** — Manter o catálogo de serviços com todos os atributos do modelo de cadastro, sem mexer no fluxo.
- **FR-35** — Manter identidade e tom de voz do agente.
- **FR-36** — Manter recursos, horários de funcionamento e vínculo serviço ↔ recurso.
- **FR-37** — Manter destinatários de emergência e mapeamento de setores de transferência.

### 6.9 Operação e visibilidade (Nouvet)

- **FR-38** — Manter a escala dos recursos — quais estão abertos em cada dia.
- **FR-39** — Acompanhar indicadores: agendamentos pelo agente, taxa de confirmação, comparecimento, transferências por motivo, tempo de resposta.
- **FR-40** — Acompanhar o **custo** de mensagens enviadas, por categoria de cobrança (serviço, utilidade, autenticação) — não há franquia contra a qual comparar; o indicador é gasto, não saldo.
- **FR-40a** — Importar exportação do SimplesVet **sob demanda** (carga inicial e conferências eventuais de porte), sem sobrescrever campos de domínio próprio. **Não há rotina periódica**: comparecimento vem da categoria no calendário e da confirmação do cliente; histórico de agendamento vem do próprio calendário.
- **FR-41** — Acessar a aplicação com a conta Microsoft do Nouvet, com permissão por papel.

## 7. Requisitos não funcionais

- **NFR-1 — Uma resposta por turno.** A partir de 01/10/2026 a Meta cobra **por mensagem de serviço entregue**, à tarifa de utilidade/autenticação do país do destinatário. **Não há franquia gratuita e não há faixas por volume** — confirmado na documentação da Meta; a "franquia de 1.000" que circula em resumos de terceiros é resíduo do modelo antigo por conversa, já aposentado. Toda resposta do agente custa. O agente responde uma vez por turno; dividir resposta em várias mensagens é proibido.
- **NFR-1a — Pré-requisito operacional com data.** É preciso haver **meio de pagamento cadastrado na conta WhatsApp Business até 30/09/2026**. Sem isso, a Meta **interrompe a entrega de mensagens de serviço** quando a cobrança começa, em 01/10 — a mesma data do go-live.
- **NFR-2 — Tempo de resposta.** O cliente recebe resposta em poucos segundos. Quando uma consulta de agenda for demorar, o agente sinaliza em vez de silenciar.
- **NFR-3 — O calendário é a fonte da verdade.** Se o CRM e o calendário divergirem, o calendário está certo. Escrita no CRM nunca bloqueia o agendamento.
- **NFR-4 — Falha não vira silêncio.** Qualquer falha técnica no caminho do agendamento resulta em mensagem honesta ao cliente e registro para a equipe — nunca em conversa abandonada.
- **NFR-5 — Privilégio mínimo.** O agente acessa apenas os calendários dos recursos que precisa, com credencial de aplicação restrita.
- **NFR-6 — Dado de cliente não sai do ambiente.** Base importada e conversas permanecem na infraestrutura do projeto; nada de PII em repositório.
- **NFR-7 — Auditabilidade.** Todo agendamento, cancelamento e transferência feito pelo agente é rastreável a partir do registro de fatos.
- **NFR-9 — Nenhum indicador sem cobertura.** Todo número apresentado vem acompanhado da fração da base sobre a qual foi medido. Ausência de sinal é reportada como desconhecida, nunca convertida em desfecho.
- **NFR-10 — Ambiente de desenvolvimento não alcança cliente nem agenda real.**
- **NFR-8 — Configuração é dado, não código.** Mudar nome, tom, catálogo, duração, horário ou destinatário não exige alterar fluxo nem publicar versão.

## 8. Fora de escopo

- **Agendar cirurgia e anestesia** — são agendamentos reais (mediana de 7 e 3 dias de antecedência), mas dependem de avaliação clínica prévia.
- **Agendar internação** — 81% dos registros são criados depois do fato; não é um pedido que chega pelo WhatsApp.
- **Interpretar pedido médico ou documento clínico.** O agente reconhece que um anexo chegou e o encaixa na solicitação; a conferência é humana.
- **Qualquer decisão clínica** — triagem de gravidade além do reconhecimento de emergência, indicação de exame, orientação de tratamento.
- **Lançar atendimento no SimplesVet.** Quem atende faz isso, como hoje.
- **Substituir o SimplesVet.** A troca do sistema de gestão é assunto do Nouvet, com horizonte próprio.
- **Rota e otimização de transporte** *(ver §10, QA-4)*.

## 9. Dependências

| # | Dependência | De quem | Bloqueia |
|---|---|---|---|
| D1 | Tenant Microsoft com Exchange Online e caixas de recurso | Btech (Rui) | Todo o agendamento |
| D2 | Respostas do questionário — duração, horário, catálogo | Nouvet | Motor de disponibilidade |
| D3 | Setores do RD Conversas configurados corretamente | Nouvet | Transferência para humano |
| D4 | Forma de integração com o RD — webhook ou requisição externa | RD Station | Arquitetura de entrada |
| D5 | Meta de O3 e O4 | Nouvet | Critério de aceite |

## 10. Questões abertas

| # | Questão | Dono | Efeito se não resolvida |
|---|---|---|---|
| QA-1 | Metas de redução de cadeira vazia e de confirmação | Nouvet | Sucesso vira opinião |
| QA-2 | Duração do banho — medido 75' de mediana, 60' de moda | Nouvet | Erra a capacidade do dia em ~2 atendimentos por profissional |
| QA-3 | Banho exige vacinação em dia? Há restrição de porte? | Nouvet | Agente marca o que a operação recusaria |
| QA-4 | Regra de área e capacidade do Leva e Traz | Nouvet | Mantido como "registrar, não prometer" |
| QA-5 | O que o cliente quer quando fala de internação | Nouvet | Define o comportamento do agente no tema |
| QA-6 | Quem é a "Rose" da oncologia e qual o critério | Nouvet | Onda 4 |
| QA-7 | Há plantão para alertar em emergência fora do horário comercial | Nouvet | FR-27 fica sem destinatário |
| QA-8 | Preço quando há plano **PETLOVE** (Ideal, Essencial, Completo) — o agente informa? | Nouvet | Agente informa valor errado para quem tem plano |
| QA-11 | Janela e tom da mensagem de recorrência; o que fazer com os 965 clientes inativos há mais de 180 dias | Nouvet | FR-23a sem parâmetro |
| QA-12 | Frequência do export do SimplesVet para reconciliar comparecimento | Nouvet | Indicadores de O3 sem fonte |
| ~~QA-9~~ | **Resolvida em 17/09**: Visita — internação entra na **onda 2** | Thiago | — |
| QA-10 | `[ASSUMPTION]` Care Center abre com banho e tosa; demais serviços de estética ficam para depois | Nouvet | Escopo da onda 1 |

## 11. Riscos

**O prazo não comporta o escopo completo, e isso precisa estar combinado antes de 29/09.** A entrega em ondas é a mitigação; a conversa com o Nouvet sobre isso é o que falta.

**O agente pode ser mais rígido que a operação atual.** Hoje a recepção encaixa: 2,2% dos horários da agenda têm mais de um atendimento. Um agente que respeite a grade ao pé da letra vai recusar o que hoje se aceita. Mitigação: nunca negar — oferecer alternativa e, na insistência, transferir.

**A configuração é maior do que parecia.** O modelo de cadastro tem ~35 atributos por serviço, com matriz de preço. Mitigação: a onda 1 exige mapear **dois** serviços, não quarenta.

**A cobrança da Meta muda no dia da entrega.** Resposta de agente passa a ser paga, sem franquia. Mitigação: NFR-1, NFR-1a e acompanhamento de custo (FR-40).

**Lembretes são mensagens fora da janela de 24h.** Uma mensagem avulsa só pode sair fora da janela como **template aprovado**. Templates de utilidade **dentro** de uma janela aberta seguem gratuitos, mas o lembrete de véspera quase sempre cai fora dela — logo é template, e é cobrado. Os templates precisam ser criados e aprovados antes do go-live.
