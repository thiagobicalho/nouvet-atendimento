---
title: Atendimento Nouvet
status: draft
created: 2026-08-31
updated: 2026-09-08
---

# PRD: Atendimento Nouvet
*Working title — confirmado pelo Thiago.*

## 0. Documento — Propósito e Escopo

Este PRD serve três leitores: **Thiago Bicalho e a equipe da Btech.Cloud** responsáveis pela implementação em n8n (Thiago é o interlocutor principal e decisor de escopo da entrega), e a liderança do Nouvet (Edson Candido) que vai levar a entrega à diretoria/conselho.

O documento organiza os requisitos por **Feature** (§4), com Requisitos Funcionais (**FR-1** a **FR-51**) numerados globalmente — **FR-1 a FR-43 são o Piloto; FR-44 a FR-51 são escopo pós-Piloto** (§4.13, §6.3) e referenciados por ID onde a cadeia importar. Termos do **Glossário** (§3) são usados de forma verbatim no restante do texto — nenhum sinônimo é introduzido. Pressupostos inferidos durante a elaboração aparecem marcados inline como `[ASSUMPTION]` e estão consolidados na íntegra na Seção 9.

Este PRD parte de um processo de descoberta já avançado: um briefing de descoberta construído com um coach de brainstorming, o resumo e a transcrição completa de uma reunião de processo com o Nouvet (20/ago/2026), e os materiais comerciais da Btech.Cloud — proposta em PDF (`20260814002_PRP-IA_NOUVET.pdf`) e apresentação em PPTX (`Nouvet_Digital_Excellence_2.pptx`). Todos os documentos-fonte estão preservados em `_bmad-output/reference/`; o histórico integral de decisões e questões levantadas durante a construção deste PRD está em `.memlog.md`, na mesma pasta deste arquivo.

**Nomenclatura importante:** a proposta comercial da Btech.Cloud usa "Fase 1" para se referir a um Diagnóstico de 5 dias, dentro de um roadmap de 5 fases somando ~81 dias. O recorte de ~10 dias descrito neste PRD **não é essa Fase 1** — é o que o próprio material comercial chama de **"Piloto da Recepção"**. Para evitar confundir a diretoria do Nouvet, que já viu o material comercial, este PRD usa **"Atendimento Nouvet"** como nome do produto e **"Piloto"** para se referir ao recorte de 10 dias — nunca "Fase 1" isoladamente.

**Prazo:** o go-live do Piloto está fixado em **08/09/2026**. O prazo original de 1º/set/2026, definido na reunião de processo de 20/ago, foi ajustado em função do replanejamento do projeto que gerou este PRD.

## 1. Visão

O Atendimento Nouvet é o agente de inteligência artificial que recebe, em tempo real e inclusive fora do horário comercial, todo contato de clientes do Nouvet pelo WhatsApp/RD Conversas — identifica quem está falando, descobre o que a pessoa precisa, coleta as informações necessárias para aquele pedido, registra tudo no CRM como memória viva do cliente, e garante que a pessoa chegue ao ponto certo de continuidade humana sem nunca desaparecer da operação.

Hoje, clientes do Nouvet enfrentam filas extensas no WhatsApp, demora de resposta e solicitações que perdem continuidade durante a rotina da equipe — a própria operação não tem hoje rastreabilidade suficiente para garantir que todo lead seja tratado. O Piloto documentado aqui ataca esse problema específico, sem depender da integração definitiva com o sistema de gestão da clínica (SimplesVet, que não tem API para agendamento 100% autônomo) nem do futuro ERP (TOTVS, migração prevista para 2027).

A visão completa do produto — descrita na proposta comercial da Btech.Cloud — prevê uma jornada bem mais ampla: integração bidirecional nativa com RD Station CRM, dashboard de BI consolidado, remarketing automático, e três agentes de IA adicionais (Social Selling, Agente Pessoal do Especialista, Agente Interno para Gestores). Essa visão de longo prazo **não faz parte deste projeto** — são possibilidades futuras que exigiriam negociação comercial própria, não uma extensão automática deste Piloto. Este PRD documenta apenas o que o Piloto de 10 dias precisa entregar, e nomeia explicitamente o que fica para depois (§5, §6.2).

A frase que resume o porquê deste Piloto, definida pelo Thiago:

> "O Piloto não existe para automatizar tudo. Ele existe para garantir que ninguém fique sem resposta, que nenhum lead desapareça e que qualquer continuidade humana comece com contexto."

**Hierarquia de prioridades:** quando houver disputa de escopo ou prazo durante a implementação, esta é a ordem que resolve o conflito, definida por Thiago:

1. Resposta imediata
2. Continuidade do atendimento
3. Informações úteis no CRM
4. Visibilidade gerencial

Resposta e continuidade têm precedência sobre automações mais sofisticadas, dashboards avançados ou integrações completas. Esta hierarquia é a base da regra de sequenciamento em §6.1 (o fallback básico vem antes de qualquer aposta em agendamento real).

## 2. Usuário-Alvo

### 2.1 Jobs To Be Done

- **Tutor/cliente do Nouvet** — "Quando eu procuro o Nouvet pelo WhatsApp, quero ser respondido na hora, mesmo fora do horário comercial, e não quero repetir minha situação para várias pessoas diferentes até alguém resolver."
- **Equipe de atendimento do Nouvet** (recepção e setores) — "Quando eu assumo uma conversa, quero já saber o que o cliente precisa e o que já foi coletado, sem ter que começar o atendimento do zero."
- **Gestor do Nouvet** (Edson Candido) — "Quero identificar, em tempo real, quando um atendimento corre risco de ficar sem resposta — não descobrir depois que já deu errado — para poder agir a tempo e, com isso, levar números confiáveis à diretoria e ao conselho, sem prometer mais do que o Piloto realmente entrega."

### 2.2 Não-Usuários do Piloto

- Clientes que buscam **Internação** ou **Oncologia** — setores explicitamente fora do Piloto até que o desempenho em produção seja validado nos setores em escopo (dado do material comercial, slide 10).
- Clientes que preferem canal telefônico/URA tradicional — o Piloto cobre apenas WhatsApp via RD Conversas.
- Clientes de convênio/plano de saúde (Pet Love) que já mencionam o convênio no primeiro contato — vão direto para atendimento humano (verificação de microchip etc.), não passam pelo fluxo automatizado completo.

### 2.3 Jornadas-Chave do Usuário

- **UJ-1. Mariana agenda banho para o cachorro pelo Care Center.**
  - **Persona + contexto:** Mariana, cliente recorrente do Nouvet, já tem cadastro e pet associado ao seu telefone.
  - **Entry state:** manda mensagem no WhatsApp do Nouvet num sábado à noite, fora do horário comercial.
  - **Path:** o sistema identifica Mariana e o cão dela pelo telefone → pergunta diretamente o que ela precisa hoje (sem presumir com base no último atendimento) → ela pede banho → o agente do Care Center coleta serviço (banho cachorro), data e horário preferidos, e profissional de preferência → registra o pedido completo no card e roteia para um humano confirmar o agendamento.
  - **Climax:** o humano que assume já vê serviço, data/horário preferidos e profissional desejado prontos no card — não precisa perguntar nada disso de novo a Mariana, só confirmar contra a agenda real.
  - **Resolution:** card é atualizado com a preferência de agendamento coletada e o estado "Aguardando Atendimento Humano"; card só recebe cadastro definitivo agora que a intenção de agendar foi confirmada.
  - **Edge case:** o Piloto não tenta agendamento automático em nenhum setor (ver §6.1) — mesmo quando o profissional preferido claramente não teria horário, essa checagem e a sugestão de alternativa ficam a cargo do humano que assume o card, não da IA.

- **UJ-2. Carlos, cliente novo, não sabe se quer clínico geral ou especialista.**
  - **Persona + contexto:** Carlos nunca foi cliente do Nouvet; o cão dele está com uma queixa que ele não sabe classificar.
  - **Entry state:** primeira mensagem via WhatsApp, telefone não encontrado na base.
  - **Path:** sistema não encontra cadastro → pergunta diretamente o que ele precisa → Carlos diz que quer "uma consulta" mas não sabe qual especialidade → o agente de Consultas pergunta a queixa e se o pet já é acompanhado por algum especialista → não havendo indicação clara, direciona por padrão ao clínico geral.
  - **Climax:** Carlos recebe a orientação de que o clínico geral vai avaliar primeiro e encaminhar se necessário — sem parecer que está sendo "empurrado" para uma opção genérica.
  - **Resolution:** preferências de data/horário são coletadas; cadastro de Carlos só é criado no CRM neste ponto, porque a intenção de agendar já está confirmada.
  - **Edge case:** se durante a conversa Carlos relatar um sintoma classificado como sinal de alerta (ex.: "ele não para de vomitar há 3 dias"), o fluxo de triagem interrompe a coleta normal e aciona handoff humano imediato com prioridade máxima (realiza FR-8, FR-32).

- **UJ-3. Fernanda pede um exame que depende de orçamento.**
  - **Persona + contexto:** Fernanda recebeu uma carta de encaminhamento do veterinário pedindo uma tomografia para o gato dela.
  - **Entry state:** cliente já identificada, envia o documento anexado no WhatsApp.
  - **Path:** o agente de Exames recebe o pedido → verifica que tomografia requer anestesia → pergunta se Fernanda já tem exames pré-anestésicos prontos → ela diz que não → o agente registra que o orçamento precisa incluir os pré-anestésicos → todo o contexto é anexado ao card e roteado para o humano responsável por orçamento.
  - **Climax:** quando o humano assume, ele já vê a carta, o tipo de exame, a pendência de pré-anestésicos e não precisa perguntar nada disso de novo a Fernanda.
  - **Resolution:** atendimento entra em estado "aguardando atendimento humano"; a IA não tenta calcular valores nem agendar — isso depende de aprovação humana do orçamento (realiza FR-17, FR-18, FR-19).
  - **Edge case:** nenhuma segmentação por tipo de exame acontece no Piloto — mesmo um exame simples de laboratório segue o mesmo caminho único até um humano.

- **UJ-4. Retorno de cliente recorrente meses depois.**
  - **Persona + contexto:** Mariana (UJ-1) volta a falar com o Nouvet três meses depois, agora para agendar uma consulta.
  - **Entry state:** telefone já reconhecido, card existente com o histórico do banho anterior.
  - **Path:** sistema identifica Mariana e o pet → pergunta o que ela precisa hoje (não assume que é outro banho) → ela pede consulta → o novo atendimento é adicionado ao card, aparecendo primeiro no histórico, com o registro do banho anterior preservado abaixo.
  - **Climax:** um atendente humano que abrir o card mais tarde vê imediatamente a consulta em andamento no topo, e pode consultar o histórico do banho anterior sem precisar perguntar a Mariana.
  - **Resolution:** card funciona como memória operacional contínua, nunca substituindo registros anteriores.
  - **Edge case `[ASSUMPTION]`:** o mecanismo exato de reposicionamento do card no pipeline quando o cliente retorna (nova etapa? mesma etapa com novo item no topo do histórico?) ainda não está fechado — ver Questão em Aberto #10.

- **UJ-5. Atraso do atendimento humano aciona escalonamento (perspectiva do gestor).**
  - **Persona + contexto:** Edson Candido, gestor Nouvet, precisa garantir que nenhum atendimento fique esquecido em "aguardando humano".
  - **Entry state:** um card está em "aguardando atendimento humano" após handoff da IA.
  - **Path:** passam 5 minutos sem que um humano responda → sistema envia atualização automática ao cliente informando que a solicitação segue em andamento **e**, já neste primeiro ciclo, informa Edson de que aquele atendimento está em atraso → a cada novo ciclo de 5 minutos sem resposta humana, o sistema informa Edson novamente, com o nível de urgência crescendo a cada ciclo — Edson é avisado desde o início do atraso, não só depois que a situação já se agravou.
  - **Climax:** Edson recebe visibilidade do atraso desde o primeiro sinal, a tempo de intervir com a equipe antes que o cliente perceba a demora como abandono — em vez de só ficar sabendo quando o atraso já virou um problema maior.
  - **Resolution:** card retorna a "aguardando atendimento humano" normal assim que alguém assume; o aviso progressivo não substitui o atendimento, só mantém Edson informado enquanto ele durar.

## 3. Glossário

- **Lead** — contato feito por um cliente (novo ou existente) via WhatsApp/RD Conversas cuja demanda ainda não foi resolvida ou encaminhada.
- **Card** — registro único no RD Station CRM que concentra todo o histórico de atendimento de um cliente/tutor; funciona como memória operacional (ver FR-22).
- **Pipeline** — funil único do CRM que concentra todos os setores e origens de lead (base existente, WhatsApp, campanhas). Ver FR-20.
- **Recepcionista IA** — agente de IA responsável pelo primeiro contato: identificação do cliente/pet, descoberta de intenção e direcionamento ao Agente de Setor correspondente.
- **Agente de Setor** — agente de IA especializado que assume a conversa após o direcionamento da Recepcionista IA, responsável por coletar os dados daquele fluxo (Care Center, Consultas, Vacinas, Exames).
- **Handoff** — transferência de atendimento entre agentes de IA, ou entre IA e humano, sempre acompanhada do contexto já coletado — nunca apenas do contato em si.
- **Continuidade Humana** — estado do atendimento em que um humano assume a conversa, porque a IA concluiu sua parte do fluxo ou identificou necessidade de intervenção humana.
- **Piloto** (ou "Piloto de Recepção") — o recorte de ~10 dias documentado neste PRD. Distinto da "Fase 1" da proposta comercial da Btech.Cloud, que se refere ao Diagnóstico de 5 dias.
- **Setor** — área de atendimento do Nouvet: Care Center, Exames, Consultas, Vacinas, Orçamentos, Internação, Oncologia, Financeiro.
- **Sinal de Alerta** — sintoma ou situação clínica relatada pelo cliente que exige handoff humano imediato e prioritário (ex.: vômito por 3 dias seguidos).
- **Aguardando Cliente** — estado do card em que o sistema espera resposta do lead; vencimento da tarefa associada é de 5 minutos após a última resposta relevante do lead.
- **Aguardando Atendimento Humano** — estado do card em que o sistema espera ação de um humano do Nouvet; segue SLA e regras de escalonamento próprias (ver §Operational Requirements).
- **Ciclo de Escalonamento** — intervalo de 5 minutos usado para informar progressivamente o gestor a cada rodada de atraso no atendimento humano, com urgência crescente a cada ciclo (ver FR-29).
- **Configuração de Personalização** — conjunto de conteúdos (tom de voz, textos, limiares de SLA, regras por setor, dados de plantonistas) mantido fora do fluxo de automação do n8n, editável sem alterar a lógica do fluxo (ver FR-33, FR-34).
- **Fonte Confiável** — base de conhecimento autorizada do Nouvet usada pela IA para responder; a IA não responde com base em informação fora dessas fontes (ver FR-29).
- **Painel** (ou "Painel de Operação e Indicadores") — aplicação web da Btech, hospedada na mesma VPS do n8n, pela qual os 5 indicadores mínimos são consultados e a Configuração de Personalização é editada. Escopo pós-Piloto (ver §4.13). Não é um dashboard de BI.
- **Calendário Compartilhado** — calendário Microsoft usado como fonte provisória de agenda, enquanto não há integração definitiva com o SimplesVet. No Piloto, nenhum setor recebe reserva automática nele — a estrutura de integração é preparada durante o Piloto para suportar agendamento real automático numa fase seguinte.

## 4. Features

### 4.1 Recepção e Identificação
**Descrição:** A Recepcionista IA é o ponto de entrada de todo contato. Ela identifica quem está falando sempre que possível, personaliza a conversa, e descobre a intenção do cliente sem presumir com base em atendimentos anteriores. Realiza UJ-1, UJ-2, UJ-4.

#### FR-1: Resposta automática a todo novo contato
A Recepcionista IA responde automaticamente a toda mensagem recebida via WhatsApp/RD Conversas, 24 horas por dia, incluindo fora do horário comercial.

**Consequences (testable):**
- Nenhuma mensagem recebida fica sem resposta automática inicial, independentemente do horário.
- Tempo de primeira resposta é mensurável e reportado (ver FR-39, NFR-1).

#### FR-2: Identificação do cliente por telefone
O sistema consulta o telefone do contato contra a base cadastral disponível (RD Station + exportações do SimplesVet) para identificar cliente e pet associado, sem perguntar diretamente "você tem cadastro?".

**Consequences (testable):**
- Quando o telefone corresponde a um cadastro existente, o sistema não repete perguntas de identificação já respondidas anteriormente.
- Quando não há correspondência, o sistema segue o fluxo de cliente novo sem travar a conversa.

#### FR-3: Personalização com dados identificados
Quando cliente e/ou pet são identificados, o sistema personaliza a conversa usando o nome do cliente e do pet.

#### FR-4: Correção de identificação por telefone compartilhado
Quando o telefone identificado pertence a uma pessoa diferente do titular do cadastro (ex.: cônjuge), o sistema corrige a identificação dinamicamente durante a própria conversa.

**Notes:** `[NOTE FOR PM]` Número reciclado (comum no Brasil — o número muda de dono) é um risco de privacidade não coberto por este FR: alguém pode "herdar" o histórico e nome do cliente/pet anterior sem confirmação. Recomendação de mitigação: uma confirmação leve (ex.: nome do pet) antes de expor histórico sensível baseado só no match de telefone — não implementado como FR obrigatório neste Piloto, registrado como consideração de risco.

#### FR-5: Descoberta direta da intenção
A Recepcionista IA pergunta diretamente o que o cliente deseja no contato atual, sem presumir a intenção com base no último atendimento registrado no card.

**Out of Scope:** Sugestão proativa de reagendamento de um serviço anterior não é feita nesta pergunta inicial.

#### FR-6: Convênio não é oferecido proativamente
O sistema não pergunta proativamente sobre convênio/plano de saúde (Pet Love). Segue-se atendimento particular por padrão; se o próprio tutor mencionar convênio, o sistema aciona handoff humano (verificação de microchip e regras de repasse não são automatizadas no Piloto).

---

### 4.2 Triagem e Direcionamento
**Descrição:** Após identificar a intenção, o sistema classifica a demanda e decide se ela pode seguir com um Agente de Setor ou se precisa de handoff imediato — incluindo o guardrail clínico mais importante do produto. Realiza UJ-2.

#### FR-7: Classificação por setor em escopo
O sistema classifica a intenção do cliente em um dos setores em escopo do Piloto (Care Center, Consultas, Vacinas, Exames, Orçamentos) ou aciona handoff imediato para os setores fora de escopo (Internação, Oncologia, Financeiro) ou situações que exigem humano (convênio mencionado, sinal de alerta). `[RESOLVIDO em 01/set/2026]` Vacinas confirmado dentro do Piloto, Financeiro confirmado fora — ver Questão em Aberto #3.

#### FR-8: Handoff obrigatório por sinal de alerta clínico `[REDEFINIDO em 01/set/2026 — critérios configuráveis, não hardcoded]`
Quando a conversa identifica um sinal de alerta clínico, o sistema interrompe qualquer coleta automatizada e aciona handoff humano imediato com prioridade máxima. A lista de sinais de alerta (sintomas/situações que disparam esse handoff) vive na Configuração de Personalização (§4.10, FR-34) — não é hardcoded no fluxo n8n nem no prompt do agente.

**Consequences (testable):**
- Nenhum sinal de alerta identificado é tratado apenas com orientação automática — sempre gera handoff.
- O card recebe marcação de prioridade máxima visível para a equipe.
- Adicionar, remover ou ajustar um item da lista de sinais de alerta não exige alteração do fluxo n8n, só atualizar a configuração.

**Notes:** Decisão de Thiago (01/set/2026): tratar essa lista como configurável, não hardcoded, desbloqueia o **início da construção** — o time implementa o mecanismo já com uma lista interina (ver Questão em Aberto #15, §14 Índice de Suposições). Isso não elimina a necessidade de validação: a lista que efetivamente entra em produção no go-live (08/09) ainda precisa ser revisada e aprovada pela equipe clínica do Nouvet antes de atender clientes reais.

#### FR-9: Direcionamento padrão para clínico geral
Quando o cliente não sabe escolher entre clínico geral e especialista, o sistema pergunta a queixa e, na ausência de indicação clara, direciona por padrão ao clínico geral — verificando também se o pet já é acompanhado por algum especialista (interno ou externo).

---

### 4.3 Fluxo Care Center
**Descrição:** Atende banho e tosa (nome interno em transição para "Care Center"). Realiza UJ-1.

#### FR-10: Coleta de dados do Care Center
O Agente do Care Center coleta: nome do cliente, nome do pet, serviço desejado (banho cachorro, banho gato ou tosa — únicos três serviços agendáveis via IA), preferência de data, horário e profissional.

#### FR-11: Registro de solicitações adicionais sem venda automática
Quando o cliente solicita um serviço adicional não agendável via IA (ex.: hidratação, escovação de dentes), o sistema registra a solicitação no card sem tentar vender ou confirmar — esses itens são oferecidos e fechados presencialmente pela equipe.

#### FR-12: Coleta de preferência de agendamento e roteamento para confirmação humana `[REDEFINIDO em 01/set/2026 — ver decisão em §6.1]`
O Agente do Care Center coleta a preferência completa de agendamento (serviço, data, horário, profissional) e roteia o card para um humano confirmar contra a disponibilidade real — o Piloto **não** tenta reservar automaticamente no Calendário Compartilhado nesta entrega.

**Consequences (testable):**
- O card reflete a preferência de agendamento coletada e o estado "Aguardando Atendimento Humano", nunca um agendamento confirmado pela IA.
- O humano que assume o card recebe toda a preferência já coletada e não precisa reperguntar nada disso ao cliente — só confirmar ou ajustar contra a agenda real.

**Notes:** Decisão confirmada por Thiago em reunião com a equipe Btech (01/set/2026): o Piloto de 10 dias **não entrega agendamento real automatizado em nenhum setor**, incluindo Care Center — a promessa é entregar a informação completa no CRM e notificar o humano. A base de dados e a estrutura de integração com o Calendário Compartilhado devem, ainda assim, ser construídas durante o Piloto de forma que a evolução para agendamento real automático (reserva direta contra a disponibilidade do profissional, com sugestão de alternativa se indisponível) seja um próximo passo natural, não um retrabalho. Isso substitui a decisão anterior deste FR (agendamento real confirmado para Care Center); ver também §6.1 e §6.2.

---

### 4.4 Fluxo Consultas e Vacinas
**Descrição:** Atende consultas com profissionais e, por analogia direta (mesma lógica de agendamento final), vacinas. Realiza UJ-2, UJ-4.

#### FR-13: Coleta de dados de Consultas
O Agente de Consultas coleta: profissional desejado, especialidade (ou queixa, quando o cliente não sabe escolher — ver FR-9), preferência de data e horário.

#### FR-14: Coleta de preferência de agendamento em Consultas/Vacinas `[REDEFINIDO em 01/set/2026 — ver decisão em §6.1]`
O Agente de Consultas/Vacinas coleta a preferência de agendamento (profissional, especialidade/queixa, data, horário) e roteia o card para um humano confirmar — mesma lógica de FR-12, sem tentativa de reserva automática no Piloto.

**Consequences (testable):**
- Para profissionais **da casa** (a maioria das especialidades de Consultas, e todos os profissionais do Care Center), a agenda de origem continua sendo a escala já existente no SimplesVet — a **replicação** dessa escala para o Calendário Compartilhado deixa de ser bloqueadora do Piloto (não há reserva automática a fazer contra ela agora), mas segue como preparação de base para a fase seguinte.
- Para **cirurgias e procedimentos não rotineiros** conduzidos por profissionais plantonistas (não da casa), a fonte de escala é o **Pega Plantão** — mesma observação: relevante para a fase seguinte, não para confirmação automática neste Piloto.

**Notes:** Mesma decisão de FR-12 se aplica aqui — nenhum setor recebe agendamento real automatizado nesta entrega. `[NOTE FOR PM]` O processo de replicação da escala do SimplesVet para o Calendário Compartilhado (frequência, responsável, manual ou semi-automático) segue relevante como preparação de base para a fase de agendamento real, mas não é mais um bloqueador de lançamento do Piloto — ver Questão em Aberto #12.

---

### 4.5 Fluxo Exames
**Descrição:** Único fluxo do Piloto que nunca tenta agendar — sempre para no orçamento e depende de aprovação humana. Realiza UJ-3.

#### FR-15: Recebimento do pedido de exame
O Agente de Exames recebe o pedido/carta de encaminhamento (anexo) enviado pelo cliente e identifica se o exame requer anestesia.

#### FR-16: Verificação de exames pré-anestésicos
Quando o exame requer anestesia (ex.: tomografia), o agente pergunta se o cliente já possui exames pré-anestésicos vigentes; se não, o escopo do orçamento a preparar já inclui esses exames.

#### FR-17: Caminho único, sem segmentação por tipo de exame
Todos os pedidos de exame seguem o mesmo caminho no Piloto — sem segmentação por tipo laboratorial, de imagem ou de procedimento: recebe pedido → prepara contexto para orçamento → roteia para o humano responsável.

**Out of Scope:** Segmentação por complexidade de exame foi cogitada e descartada explicitamente para o Piloto.

#### FR-18: Sem tentativa de agendamento automático
O Agente de Exames não tenta agendar. A marcação definitiva do exame depende de aprovação humana do orçamento e é conduzida por um humano.

---

### 4.6 Orçamentos (Roteamento)
**Descrição:** O Nouvet extinguiu o papel dedicado de orçamento — no Piloto, não existe Agente de Orçamento; toda demanda desse tipo vai direto para humano. Realiza UJ-3.

#### FR-19: Roteamento direto de qualquer demanda de orçamento
Qualquer solicitação classificada como "orçamento" (majoritariamente originada de Exames, mas também aplicável a outros setores) é roteada diretamente para o humano responsável, com todo o contexto já coletado anexado ao card.

**Consequences (testable):**
- Nenhum agente de IA calcula, negocia ou fecha orçamentos no Piloto.
- O humano que assume não precisa perguntar novamente o que já foi levantado pela IA (realiza a regra de handoff — ver FR-8 e §Operational Requirements).

---

### 4.7 Registro e Memória no CRM
**Descrição:** O card funciona como histórico vivo do cliente, dentro de um pipeline único que concentra todos os setores. Realiza UJ-1, UJ-4.

#### FR-20: Pipeline único
O sistema usa um único pipeline no RD Station CRM para concentrar todos os setores e origens de lead (base existente, WhatsApp, campanhas) — não um pipeline por setor.

#### FR-21: Cadastro definitivo só após intenção confirmada
O sistema cria um novo card quando o telefone do contato não corresponde a nenhum cliente existente. O cadastro definitivo do cliente só é gravado após confirmada a intenção real de agendamento — não no primeiro contato — para evitar registros de "cliente fantasma" que nunca fecha.

#### FR-22: Histórico preservado com atendimento mais recente primeiro
Quando um cliente com card existente retorna com nova solicitação, o sistema adiciona o novo atendimento ao histórico do card preservando os registros anteriores, com o atendimento mais recente exibido primeiro.

**Notes:** `[ASSUMPTION]` O mecanismo exato de exibição "mais recente primeiro" dentro da estrutura nativa do RD Station Card (nota mais recente no topo vs. campo estruturado) e o comportamento de reposicionamento no pipeline (ver UJ-4, Questão em Aberto #10) ainda precisam de validação técnica.

#### FR-23: Movimentação automática de etapa no funil
O agente move automaticamente o card entre etapas do funil no CRM, além de preencher os campos e anotar o histórico.

**Notes:** `[ASSUMPTION — default até revisão]` Etapas exatas de cada funil por setor assumidas como reaproveitamento dos modelos de funil já existentes no RD Station (ver Addendum), até revisão conjunta. Thiago já vai providenciar o material disponível dos funis atuais para essa revisão — ver Questão em Aberto #4.

#### FR-24: Campos mínimos por atendimento
Todo card registra, no mínimo: setor procurado, preferências coletadas (data/horário/profissional/serviço), estado do atendimento (Aguardando Cliente / Aguardando Atendimento Humano / Concluído), e timestamp da última interação relevante.

#### FR-42: Acesso restrito a exportações temporárias
O sistema — e qualquer processo ou pessoa que o alimente — acessa exportações temporárias do SimplesVet e planilhas de clientes apenas por um canal de acesso restrito e definido, sem redistribuição não controlada dos arquivos originais.

**Notes:** Canal de acesso definido: a equipe Btech mantém as exportações do SimplesVet atualizadas diretamente, via acesso próprio à plataforma — o Nouvet não precisa fornecer os arquivos manualmente. Falta apenas fechar a política formal de retenção (por quanto tempo os dados ficam guardados) — ver Questão em Aberto #13.

---

### 4.8 Temporizadores, Continuidade e SLA
**Descrição:** Garante que nenhum lead fique esperando silenciosamente — nem o cliente, nem a equipe. Realiza UJ-5.

#### FR-25: Renovação do vencimento a cada resposta do lead
A cada resposta relevante do lead, o sistema atualiza o vencimento da tarefa associada ao card para 5 minutos à frente.

#### FR-26: Lembrete automático por inatividade do cliente
Se o lead não responder até o vencimento da tarefa, o sistema dispara a ação de lembrete definida para aquele estado (ex.: mensagem de acompanhamento automática).

#### FR-27: Dois estados de espera distintos
O sistema distingue "Aguardando Cliente" de "Aguardando Atendimento Humano" usando etiquetas/estados dedicados no CRM (ver Glossário).

#### FR-28: Atualização automática ao cliente em atraso humano
Quando o atendimento está em "Aguardando Atendimento Humano" e nenhum humano responde em até 5 minutos, o sistema envia uma atualização automática ao cliente informando que a solicitação segue em andamento.

#### FR-29: Escalonamento progressivo ao gestor `[REDEFINIDO em 01/set/2026]`
A cada ciclo de 5 minutos sem resposta humana em "Aguardando Atendimento Humano", o sistema informa o gestor responsável sobre o atendimento em atraso — a visibilidade começa já no primeiro ciclo, com o nível de urgência aumentando a cada ciclo subsequente, em vez de um único alerta disparado só depois que o atraso já se agravou.

**Notes:** O valor-base de 5 minutos reaproveita o compromisso já comunicado publicamente no material comercial do Nouvet (slide 7 do PPTX), reaplicado aqui tanto para Aguardando Cliente quanto para Aguardando Atendimento Humano (confirmado pelo Thiago). Decisão de Thiago junto à equipe Btech (01/set/2026) substitui o modelo anterior de "escalona só após 2 ciclos": agora o gestor é informado a cada ciclo, não apenas ao ultrapassar um limiar fixo — ver Questão em Aberto #2 (resolvida).

---

### 4.9 Guardrails de IA
**Descrição:** Garante que a IA nunca alucine, nunca minimize risco clínico, e nunca se passe por humano. Realiza UJ-2 (edge case).

#### FR-30: Respostas baseadas em fontes confiáveis
O sistema nunca responde com base em informação não verificada; toda resposta factual se baseia em Fontes Confiáveis do negócio.

**Notes:** `[ASSUMPTION]` A arquitetura da base de conhecimento (RAG, documentos, banco estruturado) ainda não está definida — decisão técnica a resolver na arquitetura (ver Questão em Aberto #7).

#### FR-31: Reconhecimento de incerteza
Quando o sistema não possui informação suficiente ou confiança adequada para responder, ele reconhece a limitação ao cliente e aciona handoff humano em vez de inventar uma resposta.

**Notes:** `[ASSUMPTION]` A mensagem exata e o fluxo de "não sei" ainda não foram validados com o Thiago — ver Questão em Aberto #6.

#### FR-32: Transparência de identidade
O sistema sempre se identifica explicitamente como atendente virtual (ex.: "Eu sou o atendente virtual do Nouvet, estou aqui para te ajudar") e nunca se passa por humano.

#### FR-33: Nunca diagnostica, nunca minimiza gravidade
O sistema nunca fornece diagnóstico clínico nem minimiza a gravidade percebida de um sintoma relatado pelo cliente — qualquer sinal de alerta segue a regra de FR-8.

#### FR-40: Resistência a manipulação de instruções (prompt injection)
O sistema resiste a tentativas de manipulação da conversa que buscam alterar suas instruções, extrair sua configuração/prompt interno, ou fazê-lo agir fora dos guardrails definidos (ex.: mensagens do tipo "ignore as instruções anteriores", fingir ser administrador do sistema, pedir para revelar o prompt).

**Consequences (testable):**
- Tentativas identificadas de manipulação de instruções não alteram o comportamento guardrail do sistema (FR-30 a FR-33 continuam valendo).
- O sistema não revela sua configuração interna, prompt de sistema ou regras de negócio internas quando solicitado diretamente pelo cliente.
- O sistema **nunca revela valores da Configuração de Personalização** (§4.10) — em especial dados de contato de plantonistas — sob nenhum enquadramento de pergunta, direto ou indireto.
- A resistência a manipulação de instruções se estende a **conteúdo extraído de anexos/documentos** recebidos (ex.: cartas de encaminhamento no fluxo de Exames, FR-15), não apenas a texto digitado no chat.

---

### 4.10 Configuração Externa de Personalização
**Descrição:** Requisito arquitetural definido pelo Thiago nesta sessão: toda personalização do agente deve viver fora da lógica do fluxo, para não exigir alteração do fluxo n8n a cada ajuste de tom, texto ou limiar.

#### FR-34: Personalização versionada fora do fluxo
Todo conteúdo de personalização do agente — tom de voz, textos de saudação/mensagens padrão, apelido/nome do agente, limiares de SLA e temporizadores (ex.: os 5 minutos), regras específicas por setor, dados de contato de plantonistas, **lista de sinais de alerta clínico que disparam handoff obrigatório (FR-8)** — reside em configuração externa ao fluxo, editável sem alterar a estrutura do fluxo do n8n.

**Consequences (testable):**
- Alterar um valor de personalização não exige republicar ou modificar nós do fluxo n8n, apenas atualizar a configuração correspondente.
- Um novo limiar de SLA (ex.: mudar de 5 para 3 minutos) é aplicado sem deploy de fluxo.

#### FR-35: Configuração como fonte única da verdade
Toda referência a valores de personalização dentro do fluxo (n8n) lê da configuração externa em tempo de execução — não há valores de personalização hardcoded em nós do fluxo.

#### FR-43: Credenciais de integração seguras
Credenciais de todas as integrações externas (RD Station, Microsoft Graph/Calendário Compartilhado, Pega Plantão, WhatsApp/Meta) vivem no cofre de credenciais do n8n — nunca hardcoded em nós do fluxo nem na Configuração de Personalização.

**Notes:** Mesma lógica de não-hardcode do FR-34/35, estendida a segredos de integração (ver também §9 Constraints and Guardrails, Security).

---

### 4.11 Indicadores e Visibilidade Gerencial
**Descrição:** Os 5 indicadores mínimos definidos pelo Thiago, essenciais para a defesa do investimento perante a diretoria/conselho.

#### FR-36: Leads recebidos
O sistema disponibiliza a contagem de leads recebidos no período.

#### FR-37: Leads atendidos e não atendidos
O sistema disponibiliza a contagem de leads atendidos e de leads não atendidos/perdidos no período.

**Consequences (testable):**
- **Atendido** = o lead avançou até o estado "resolvido" da esteira do RD Station, ou está em continuidade humana ativa dentro do SLA definido (§10) — recebeu direcionamento e não ficou sem retorno.
- **Não atendido / perdido** = o lead chegou ao estado "3º contato ou encerrado não resolvido" da esteira sem nunca alcançar "resolvido" — esgotou as tentativas de contato sem entrega de continuidade.

**Notes:** Definição fechada por Thiago em 31/ago/2026, reaproveitando a esteira já existente no RD Station (ver Addendum) em vez de criar uma taxonomia nova.

#### FR-38: Distribuição por setor
O sistema disponibiliza a distribuição de leads por setor/tipo de atendimento procurado.

#### FR-39: Tempo de resposta
O sistema disponibiliza o tempo de resposta por lead.

**Consequences (testable):**
- O cronômetro inicia no timestamp da mensagem recebida do lead (mesmo evento de FR-1).
- O cronômetro termina no timestamp da primeira resposta automática enviada pelo sistema (mesma métrica de NFR-1/SM-2) — não no fechamento completo do atendimento.

**Notes:** Definição fechada por Thiago em 31/ago/2026.

---

### 4.12 Emergências Declaradas pelo Cliente
**Descrição:** Distinto do Sinal de Alerta identificado pela triagem clínica da IA (FR-8) — aqui o próprio cliente declara explicitamente que há uma emergência com o pet. Esse relato exige uma ação ativa e imediata de alerta a um humano disponível, não apenas a marcação passiva do card como prioritário.

#### FR-41: Alerta imediato em emergência declarada `[RESOLVIDO em 01/set/2026]`
Quando o cliente declara explicitamente que há uma emergência com o pet, o sistema aciona handoff humano com prioridade máxima (mesma regra de FR-8) **e** dispara um alerta/notificação ativa e imediata a **todos os profissionais envolvidos** naquele atendimento (ex.: plantonistas do setor correspondente), não a uma única pessoa fixa.

**Consequences (testable):**
- O alerta chega a todos os profissionais configurados como "envolvidos" para aquele contexto de emergência, não apenas ao primeiro disponível.
- A lista de profissionais envolvidos por setor/contexto é editável via Configuração de Personalização (§4.10, FR-34) — trocar quem recebe o alerta não exige alteração do fluxo n8n.

**Notes:** Mecanismo e destinatário definidos por Thiago junto à equipe Btech (01/set/2026), resolvendo o bloqueador de lançamento anterior — ver Questão em Aberto #11 (resolvida). `[NOTE FOR PM]` Ao implementar, considerar que "emergência" tende a ser usada por clientes exagerando a urgência, não só em casos reais — o desenho precisa tolerar isso sem gerar fadiga de alerta nos plantonistas, especialmente porque agora o alerta vai a todos os envolvidos, não a uma única pessoa.

### 4.13 Painel de Operação e Indicadores `[ESCOPO PÓS-PILOTO — DECISÃO 08/set/2026]`
**Descrição:** Aplicação web própria que dá superfície de uso a duas capacidades que hoje só existem dentro do banco de dados: a **leitura dos 5 indicadores mínimos** (§4.11 — entregues no Piloto como funções no banco, sem nenhum consumidor) e a **escrita da Configuração de Personalização** (§4.10 — hoje editável apenas por SQL direto pela equipe Btech). Promove a "UI de autoatendimento da Configuração de Personalização", registrada como *Deferred* na arquitetura em 02/set/2026, a escopo real e datado.

**Delimitação:** o Painel **não é** o dashboard de BI da visão de longo prazo, que segue fora de escopo (§5, §6.2). A distinção não é de grau, é de natureza: BI é análise livre de conversão e receita com recortes arbitrários; o Painel expõe exatamente os indicadores já fechados em FR-36 a FR-39, mais um editor de configuração. Nenhum indicador novo nasce aqui.

**Contexto de entrega:** o Painel é o primeiro incremento pós-Piloto (§6.3). A entrega do Piloto está pausada aguardando assinatura de contrato pelo Nouvet — o Painel é construído nessa janela, sobre a VPS que já está no ar.

#### FR-44: Acesso autenticado com dois papéis
O Painel exige autenticação e distingue dois papéis: **Visualizador** e **Operador**.

**Consequences (testable):**
- O papel **Visualizador** acessa a visualização de indicadores (FR-45, FR-46) e não acessa nenhuma tela ou operação de escrita de configuração (FR-47, FR-49).
- O papel **Operador** acessa tudo que o Visualizador acessa, mais a edição de configuração (FR-47) e o histórico/reversão (FR-48, FR-49).
- Nenhuma tela do Painel é acessível sem autenticação.
- O conjunto inicial de usuários é de 3 pessoas — 1 do Nouvet (Visualizador) e 2 da Btech (Operadores) — criados por seed; não há tela de auto-cadastro.

**Notes:** Autenticação própria (e-mail + senha), não federada — decisão de Thiago em 08/set/2026, para não criar dependência de tenant Microsoft por causa de 3 usuários. `[ASSUMPTION]` O usuário do Nouvet é **Visualizador** e não enxerga a Configuração de Personalização: Thiago disse "1 usuário Nouvet que verá tudo", mas na mesma sessão havia declarado que configuração é "somente Btech, a princípio" — prevalece a leitura restritiva até confirmação. Ver Questão em Aberto #16.

#### FR-45: Visualização dos 5 indicadores mínimos
O Painel exibe os indicadores de FR-36 a FR-39, lendo do banco da aplicação.

**Consequences (testable):**
- Os quatro indicadores aparecem no Painel: leads recebidos, leads atendidos/não atendidos, distribuição por setor e tempo de resposta.
- Os valores exibidos vêm das funções de indicador já existentes no banco — o Painel não reimplementa nenhuma regra de cálculo.

**Notes:** Cumprir FR-45/FR-46 é o que torna SM-5 verificável na prática; até aqui os indicadores existiam sem nenhuma superfície de consulta.

#### FR-46: Recorte temporal e comparação entre períodos
O Painel permite escolher o período dos indicadores e comparar dois períodos entre si.

**Consequences (testable):**
- Ao abrir o Painel sem escolha explícita, o período exibido é **hoje**.
- O usuário altera o período para um intervalo de datas de sua escolha.
- O usuário coloca dois períodos lado a lado e vê os mesmos indicadores para ambos.

**Notes:** Definido por Thiago em 08/set/2026. A comparação existe porque o uso previsto pelo Nouvet é defesa de investimento perante a diretoria — número isolado não sustenta esse argumento, variação sustenta.

#### FR-47: Edição da Configuração de Personalização pelo Painel
Usuários com papel Operador editam os valores da Configuração de Personalização (§4.10, FR-34) pelo Painel, sem acesso direto ao banco.

**Consequences (testable):**
- Uma alteração salva pelo Painel passa a valer para o fluxo n8n na leitura seguinte, sem republicar nem alterar nós (mesma garantia de FR-34/FR-35).
- O Painel grava na mesma configuração que é fonte única da verdade (FR-35), nunca em uma cópia própria.
- Credenciais de integração (FR-43) continuam fora do Painel — vivem no cofre do n8n e não são editáveis nem exibíveis aqui.

#### FR-48: Histórico append-only de alterações de configuração
Toda alteração de configuração feita pelo Painel gera um registro histórico que não é sobrescrito nem removido.

**Consequences (testable):**
- Cada registro identifica **quem** alterou, **quando**, **qual valor** passou a valer e **qual era o valor anterior**.
- Nenhuma operação do Painel atualiza ou apaga registros históricos já gravados (mesma lógica append-only do NFR-3).

**Notes:** Requisito levantado por Thiago em 08/set/2026. FR-34 já exigia personalização "versionada"; enquanto só a Btech editava via SQL, esse versionamento era implícito no conhecimento de quem editava. Com uma UI, deixa de ser.

#### FR-49: Reversão a uma versão anterior da configuração
A partir do histórico (FR-48), um Operador restaura um valor de configuração para uma versão anterior.

**Consequences (testable):**
- Restaurar uma versão anterior gera um novo registro no histórico — não apaga nem reescreve os registros intermediários.

#### FR-50: Ausência de exclusão física
Nenhuma operação do Painel apaga dados fisicamente; exclusão é marcação lógica (soft delete).

**Consequences (testable):**
- Um item "excluído" pelo Painel deixa de ser aplicado pelo fluxo n8n, mas continua existindo no banco e permanece recuperável.
- Não existe operação no Painel que resulte em remoção física de linha de configuração ou de histórico.

**Notes:** Decisão de Thiago em 08/set/2026 ("nunca delete... para caso necessário possamos voltar versões"). Coerente com o NFR-3 já vigente para o card do CRM.

#### FR-51: Implantação aditiva sobre a stack existente
O Painel é implantado na VPS que já roda o n8n **sem recriar, reconfigurar ou derrubar** os serviços de n8n e Postgres já em operação.

**Consequences (testable):**
- Subir ou derrubar o Painel não recria nem reinicia os containers de n8n e Postgres.
- O Painel se conecta ao Postgres já existente; nenhuma segunda instância de Postgres ou de n8n é provisionada.
- Qualquer mudança de schema que o Painel exija é aplicada ao banco já em operação por processo explícito — o mecanismo de migrations por inicialização de volume vazio não cobre uma VPS que já está no ar.
- O Painel acessa o banco com privilégio próprio e mínimo, sem reutilizar o papel de aplicação usado pelo fluxo n8n.

**Notes:** Restrição levantada explicitamente por Thiago em 08/set/2026 ("já estamos com a VPS com n8n no ar e só precisaríamos subir essa aplicação — pense direitinho aí pra não subir n8n e Postgres de novo"). O ponto sobre migrations foi verificado nesta sessão: o `docker-compose.yml` monta as migrations em `docker-entrypoint-initdb.d`, que o Postgres executa **apenas** na inicialização de um volume vazio — numa VPS já no ar, uma migration nova não roda sozinha.

## 5. Não-Objetivos (Explícitos)

- O Piloto **não substitui** atendentes humanos — reduz fila e tempo de resposta, mas conclusões clínicas, orçamentos complexos e negociação continuam humanas por definição (FR-8, FR-19).
- O Piloto **não inclui Agente de Orçamento** dedicado — o Nouvet decidiu extinguir esse papel e rotear toda demanda de orçamento a humano (FR-19).
- O Piloto **não depende de integração definitiva** com o sistema de gestão clínica (SimplesVet) nem com o futuro TOTVS — usa o Calendário Compartilhado e exportações pontuais como contorno temporário.
- O Piloto **não é** o "ambiente 100% nativo" prometido na visão de longo prazo (IA conduzindo até o fechamento da venda) — ele vai até o ponto de continuidade humana com contexto completo, não até o fechamento.
- O Piloto **não entrega dashboard de BI** consolidado nem métricas de conversão/receita além dos 5 indicadores mínimos (§4.11). Isso continua valendo mesmo depois do Painel (§4.13): o Painel expõe exatamente FR-36 a FR-39 e o editor de configuração — não é análise livre de conversão/receita.
- O Piloto **não inclui remarketing automático** nem réguas de reativação de clientes inativos — isso é tratado como Fase 5 no roadmap comercial da Btech.Cloud.
- O Piloto **não cobre** Internação nem Oncologia — ambos ficam de fora até que o desempenho em produção seja validado nos setores em escopo.
- O Piloto **não garante** cobertura "zero fila" absoluta em todas as linhas de serviço — reivindicações desse tipo no material comercial (§Constraints and Guardrails) são estado final aspiracional, não compromisso do Piloto.
- O Piloto **não migra histórico de conversas** de canais/sistemas anteriores — item explicitamente excluído também na proposta comercial da Btech.Cloud.

## 6. Escopo do Piloto (MVP)

### 6.1 Em Escopo

- Setores: **Care Center**, **Consultas**, **Vacinas** `[CONFIRMADO 01/set/2026]`, **Exames** (até o orçamento), **Orçamentos** (roteamento puro, sem agente dedicado).
- Identificação de cliente e pet por telefone, com personalização e correção dinâmica de titularidade.
- Descoberta direta de intenção, sem presumir com base em atendimento anterior.
- Coleta de dados específica por setor (§4.3 a §4.6).
- Registro e atualização de card único por cliente no pipeline único do CRM, incluindo movimentação automática de etapa no funil (etapas exatas por definir — ver Questão em Aberto #4), com histórico preservado (§4.7).
- Temporizadores e estados de espera diferenciados (Aguardando Cliente / Aguardando Atendimento Humano), com SLA de 5 minutos e escalonamento ao gestor (§4.8).
- Guardrails de veracidade, transparência, resistência a manipulação de instruções (prompt injection) e triagem clínica de sinal de alerta, incluindo alerta imediato em emergências declaradas pelo cliente (§4.9, §4.12).
- Configuração externa de toda personalização, sem hardcode no fluxo n8n (§4.10).
- Os 5 indicadores mínimos definidos pelo Thiago (§4.11).
- **Coleta completa de preferência de agendamento + roteamento para confirmação humana, em todos os setores em escopo** (FR-12, FR-14) — a promessa do Piloto é entregar a informação completa no CRM e notificar o humano, não confirmar o agendamento automaticamente.
- **Base preparada para agendamento real futuro:** a estrutura de dados e a integração com o Calendário Compartilhado são construídas durante o Piloto para que a evolução para reserva automática (fase seguinte) não exija retrabalho — mas a reserva em si não é entregue nesta janela de 10 dias.

`[DECISÃO 01/set/2026]` O Piloto não entrega nenhuma forma de agendamento real automático — nem em Care Center, nem em Consultas/Vacinas. Isso substitui o escopo anterior ("Care Center confirmado, 2 a 3 setores no total"), registrado em decisão de Thiago junto à equipe Btech. Ver §6.2 e revisão de FR-12/FR-14.

**Regra de sequenciamento (proteção da promessa mínima), revisada:** com o agendamento real inteiramente fora do Piloto, a regra deixa de ser "fallback antes de agendamento real" dentro desta entrega e passa a valer para a transição à fase seguinte — o fallback de coleta + roteamento humano precisa estar funcionando e validado em produção em **todos** os setores em escopo antes de investir esforço em agendamento real automático em qualquer setor, na próxima fase.

### 6.2 Fora de Escopo do Piloto

- **Agendamento real automático via IA, em qualquer setor** `[DECISÃO 01/set/2026]` — inclui Care Center, que antes era tratado como "confirmado". O Piloto coleta a preferência completa e roteia para um humano confirmar contra a agenda real (FR-12, FR-14); a reserva automática fica para uma fase seguinte, sobre a base de dados/integração já preparada durante o Piloto. Automação de acompanhamento pós-atendimento (lembrete pós-consulta, checagem pós-alta) também fica fora, por depender diretamente de agendamento real existir.
- **Internação e Oncologia** — fora até validação de desempenho nos setores em escopo (dado explícito do material comercial). *Deferido para expansão pós-Piloto.*
- **Financeiro** `[CONFIRMADO 01/set/2026]` — fora do Piloto, confirmado por Thiago.
- **Exclusão de dados/opt-out do tutor (direito da LGPD)** `[DECISÃO 01/set/2026]` — decisão explícita de não implementar isso nesta entrega; fica para uma fase seguinte. Ver Questão em Aberto #14.
- **Agente de Orçamento dedicado** — papel extinto no Nouvet; decisão permanente, não é só um corte temporário do Piloto.
- **Integração definitiva com SimplesVet ou TOTVS** — depende de disponibilidade de API que hoje não existe (SimplesVet) ou de migração futura (TOTVS, previsão 2027).
- **Dashboard de BI consolidado**, métricas de conversão/receita além dos 5 indicadores mínimos. O Painel de Operação e Indicadores (§4.13) **não** é este item — é escopo pós-Piloto próprio, delimitado em §6.3.
- **Remarketing automático** e réguas de reativação de clientes inativos.
- Os três **agentes de IA adicionais** da visão de longo prazo (Social Selling, Agente Pessoal do Especialista, Agente Interno para Gestores) — dependeriam de negociação comercial própria e futura, não são uma extensão automática deste Piloto.
- **Uso do Pega Plantão via API em tempo real** — viabilidade técnica já confirmada (acesso administrativo existente), mas entrada no Piloto é uma decisão de escopo em aberto, não automática (ver Questão em Aberto #9).

### 6.3 Escopo Pós-Piloto — Incremento 1: Painel `[DECISÃO 08/set/2026]`

Primeiro recorte de trabalho depois do Piloto, decidido por Thiago em 08/set/2026 enquanto a entrega do Piloto está pausada aguardando a assinatura do contrato pelo Nouvet. Não altera nada do que o Piloto entregou nem do que ele deixou de fora — acrescenta uma superfície de uso sobre o que já existe no banco.

**Em escopo:**
- Painel de Operação e Indicadores (§4.13, FR-44 a FR-51).
- Aplicação web própria na mesma VPS que já roda o n8n, implantada de forma aditiva (FR-51).
- 3 usuários criados por seed: 1 Visualizador (Nouvet), 2 Operadores (Btech).
- Histórico append-only de configuração, reversão de versão e soft delete (FR-48 a FR-50).

**Fora de escopo deste incremento:**
- Dashboard de BI e qualquer indicador novo além de FR-36 a FR-39 (§5, §6.2).
- Autoatendimento de configuração pelo Nouvet — o Nouvet lê indicadores; quem edita configuração é a Btech (FR-44, Questão em Aberto #16).
- Edição ou exibição de credenciais de integração, que seguem no cofre do n8n (FR-43, FR-47).
- Backup/DR e teste de restore — também *Deferred* na arquitetura junto com a UI de config, mas tratados como trabalho próprio, fora deste incremento.
- Provisionamento da VPS de produção e o corte dev→produção, que seguem pendentes de contrato assinado.

## 7. Métricas de Sucesso

*Cada métrica referencia o(s) FR(s) que valida.*

**Primárias**
- **SM-1**: 100% dos leads recebidos geram um registro rastreável no CRM (card criado ou atualizado) — meta quantitativa definida pelo Thiago ("100 leads entram, 100 chegam ao CRM"). Valida FR-20, FR-21, FR-22.
- **SM-2**: Tempo médio da primeira resposta automática ≤ 1 minuto `[ASSUMPTION — valor não confirmado numericamente pelo Thiago]`, mesmo fora do horário comercial. Valida FR-1, NFR-1.
- **SM-3**: Zero leads "perdidos silenciosamente" — todo card em Aguardando Atendimento Humano recebe atualização automática ou escalonamento dentro do SLA definido, nunca fica parado sem ação do sistema. Valida FR-25 a FR-29.

**Secundárias**
- **SM-4**: Percentual de handoffs que chegam ao humano com informação completa, sem precisar reperguntar o que o cliente quer. Valida FR-8, FR-18, FR-19.
- **SM-5**: Disponibilidade diária dos 5 indicadores mínimos, atualizados e consultáveis pela gestão. Valida FR-36 a FR-39. Só passa a ser verificável de ponta a ponta com o Painel (§4.13, FR-45/FR-46), que é a superfície de consulta — no Piloto os indicadores existem, mas sem tela onde a gestão os consulte.

**Contra-métricas (não otimizar)**
- **SM-C1**: Taxa de handoff prematuro/forçado apenas para cumprir a meta de velocidade de resposta — a IA não deve encerrar a coleta de dados incompleta só para bater o SLA. Contrabalança SM-2.
- **SM-C2**: Volume de mensagens automáticas de "aguarde"/lembrete não deve virar spam percebido pelo cliente (ex.: repetir a mesma mensagem sem novidade a cada ciclo). Contrabalança SM-3.

## 8. Cross-Cutting NFRs

- **NFR-1 (Performance):** resposta inicial automática em até 1 minuto após qualquer mensagem recebida, 24/7, incluindo fora do horário comercial. `[ASSUMPTION: valor de 1 minuto não confirmado numericamente pelo Thiago]`
- **NFR-2 (Configurabilidade):** toda personalização (FR-34, FR-35) é editável sem alteração da estrutura do fluxo de automação.
- **NFR-3 (Rastreabilidade):** todo card mantém histórico imutável e cronológico de atendimentos; nenhuma informação anterior é sobrescrita ou removida ao adicionar um novo atendimento (mesma lógica de log append-only). A mesma lógica se estende ao histórico de alterações da Configuração de Personalização feito pelo Painel (FR-48).
- **NFR-4 (Resiliência de dados):** se um setor falhar em registrar uma informação no card, os demais registros ainda garantem contexto mínimo de continuidade — motivo declarado da escolha de pipeline único (FR-20).
- **NFR-6 (Implantabilidade aditiva):** componentes novos entram numa VPS já em operação sem recriar nem interromper os serviços que já rodam nela (FR-51). Mudanças de schema em ambiente já no ar são aplicadas por processo explícito, não pelo mecanismo de inicialização de volume vazio do Postgres.
- **NFR-5 (Naturalidade da conversa):** a conversa deve soar natural e fluida, evitando estrutura de menu rígido (tipo URA, "digite 1 para X"). Esta é a preocupação nº1 relatada pela diretoria do Nouvet ao avaliar o projeto ("não queremos um bot") — trata da qualidade da interação, distinta do guardrail de transparência de identidade (FR-32, que exige que a IA se identifique como virtual sem, por isso, soar como um menu robotizado).

## 9. Constraints and Guardrails

**Safety**
- A IA nunca diagnostica, nunca minimiza a gravidade percebida de um sintoma, e aciona handoff imediato com prioridade máxima a qualquer sinal de alerta clínico (FR-8, FR-33). Guardrail carregado verbatim do próprio material comercial do Nouvet.
- Emergências declaradas explicitamente pelo cliente geram, além do handoff, um alerta ativo e imediato a todos os profissionais envolvidos naquele atendimento, configurável via Configuração de Personalização (FR-41, Questão em Aberto #11 — resolvida em 01/set/2026).

**Security**
- O sistema resiste a tentativas de manipulação de instruções (prompt injection) que tentem alterar guardrails, extrair configuração interna ou fazer a IA agir fora das regras definidas — incluindo conteúdo extraído de anexos, e nunca revelando dados da Configuração de Personalização como contatos de plantonistas (FR-40).
- Credenciais de todas as integrações externas vivem no cofre de credenciais do n8n, nunca hardcoded em nós de fluxo ou na Configuração de Personalização (FR-43).
- O Painel (§4.13) exige autenticação e separa papel de leitura (Visualizador) de papel de escrita (Operador), de forma que quem consulta indicadores não altere o comportamento do agente em produção (FR-44). Credenciais de integração não são editáveis nem exibíveis pelo Painel (FR-43, FR-47), e ele acessa o banco com privilégio próprio e mínimo (FR-51).

**Privacy**
- Dados de tutores e pets (nome, telefone, histórico) devem ser tratados conforme a LGPD. Fontes de dados temporárias (exportações do SimplesVet, planilhas) precisam do mesmo cuidado de acesso que o sistema definitivo teria — acesso e atualização ficam com a equipe Btech, que tem acesso direto ao SimplesVet (FR-42); falta apenas fechar a política formal de retenção (Questão em Aberto #13).

**Cost**
- Custos de tokens de IA e de mensageria (Meta/WhatsApp) ficam fora do escopo contratual da entrega e são de responsabilidade do Nouvet, conforme a proposta comercial da Btech.Cloud.

## 10. Operational Requirements (SLA)

- **Aguardando Cliente:** vencimento da tarefa do card renovado para +5 minutos a cada resposta relevante do lead; sem resposta até o vencimento aciona lembrete automático (FR-25, FR-26).
- **Aguardando Atendimento Humano:** se o humano não responder em até 5 minutos, o sistema envia atualização automática ao cliente **e** já informa o gestor sobre o atraso; a cada novo ciclo de 5 minutos sem resposta humana, o sistema informa o gestor novamente, com urgência crescente a cada ciclo — não há mais um limiar fixo de ciclos antes do primeiro aviso (FR-28, FR-29).
- **Origem destes limiares:** o valor de 5 minutos já é um compromisso comunicado publicamente no material comercial do Nouvet (slide 7 do PPTX: "follow-up automático da IA caso o atendente humano demore mais de 5 minutos") — reaproveitado aqui para manter consistência entre o que já foi vendido e o que o Piloto entrega.

## 11. Integration and Dependencies

- **RD Station CRM / RD Conversas** — canal de atendimento e CRM operacional do Piloto; pipeline único (FR-20).
- **SimplesVet** — sem API para agendamento 100% autônomo (justificativa técnica oficial do projeto, citada no material comercial); usado apenas via exportações pontuais (clientes, pets, valores).
- **Calendário Compartilhado (Microsoft)** — destino da agenda para uma fase seguinte de agendamento real; no Piloto, nenhum setor reserva automaticamente nele (`[DECISÃO 01/set/2026]`, ver §6.1/§6.2), mas a integração e a estrutura de dados são preparadas durante o Piloto. Para profissionais **da casa** (maioria de Consultas e todo o Care Center), a escala de origem é o SimplesVet e precisaria ser replicada para este calendário quando a reserva automática entrar em produção (processo e frequência ainda a definir — Questão em Aberto #12, não bloqueadora do Piloto).
- **Pega Plantão** — usado apenas para **cirurgias e procedimentos não rotineiros** conduzidos por profissionais plantonistas (não da casa). Acesso administrativo já confirmado para extração de escalas; uso via API em tempo real é relevante para a fase de agendamento real, não para o Piloto atual (Questão em Aberto #9).
- **TOTVS** — sistema de gestão definitivo futuro (migração prevista para 2027); integrações definitivas ficam para depois do Piloto.

## 12. Stakeholders and Approvals

- **Btech.Cloud** (equipe de implementação, inclui **Thiago Bicalho** — interlocutor principal deste PRD e decisor de escopo do lado da entrega — e Luis Niel Matt) — responsável pela implementação técnica do Piloto em n8n.
- **Edson Candido** — gestor do Nouvet (cliente); leva a entrega à aprovação da diretoria/conselho; condiciona aprovação de investimento a escopo e limites claros do Piloto ("se não atender o investimento não vai ser aprovado").
- **Equipe de recepção e setores do Nouvet** (Débora e outras fontes de mapeamento de processo) — usuárias indiretas que assumem a continuidade humana quando o Piloto faz handoff.

## 13. Questões em Aberto

1. Qual o valor exato do alvo de tempo de primeira resposta (NFR-1, SM-2)? Usado 1 minuto como placeholder.
2. **[RESOLVIDO em 01/set/2026]** Não há mais um número fixo de ciclos antes do escalonamento — o gestor é informado a cada ciclo de 5 minutos, com urgência crescente desde o primeiro. Ver FR-29.
3. **[RESOLVIDO em 01/set/2026]** Vacinas entra no Piloto; Financeiro fica fora — confirmado por Thiago.
4. **[Default assumido: reaproveitar modelos de funil existentes até revisão]** Quais são as etapas exatas de cada funil por setor (FR-23)? O RD Station já tem modelos de funil usados anteriormente (ver Addendum). Thiago vai providenciar o material disponível para revisão conjunta antes da implementação.
5. **[RESOLVIDO em 31/ago/2026]** Definições operacionais dos indicadores — fechadas reaproveitando as esteiras já existentes no RD Station. Ver FR-37, FR-39.
6. Qual é a mensagem/fluxo exato quando a IA não tem informação suficiente para responder (FR-31)?
7. Qual arquitetura de base de conhecimento a IA vai usar (RAG, documentos, banco estruturado) para cumprir o guardrail de Fontes Confiáveis (FR-30)? Decisão técnica a resolver na arquitetura.
8. **[RESOLVIDO em 01/set/2026]** Não há mais setores adicionais de agendamento real a definir — nenhum setor recebe agendamento real automático no Piloto (FR-12, FR-14). Fica para uma fase seguinte.
9. O Pega Plantão via API em tempo real entra no Piloto? Com a decisão de não entregar agendamento real em nenhum setor, este item deixa de ser relevante para o Piloto atual e passa a dizer respeito apenas à fase seguinte de agendamento real.
10. Qual o mecanismo exato de reposicionamento do card no pipeline quando um cliente recorrente retorna com nova solicitação (FR-22, UJ-4)?
11. **[RESOLVIDO em 01/set/2026]** Mecanismo e destinatário do alerta imediato para emergências declaradas pelo cliente (FR-41): alerta vai a todos os profissionais envolvidos naquele atendimento, configurável via Configuração de Personalização. Bloqueador de lançamento removido.
12. Como e com que frequência a escala do SimplesVet será replicada para o Calendário Compartilhado, para os profissionais da casa (Consultas regulares e Care Center — FR-12, FR-14)? Processo manual ou semi-automático, responsável pela atualização, ainda não definidos. Com a decisão de não entregar agendamento real no Piloto (§6.1), este item deixa de ser bloqueador da entrega atual — relevante como preparação de base para a fase seguinte.
13. **[PARCIALMENTE RESOLVIDO em 01/set/2026]** Acesso e atualização das exportações do SimplesVet ficam com a equipe Btech, que já tem acesso direto à plataforma — não depende do Nouvet enviar arquivos manualmente. Falta só fechar por quanto tempo esses dados ficam retidos (política formal de retenção, FR-42).
14. **[RESOLVIDO em 01/set/2026 — fora de escopo do Piloto]** Atendimento a pedido de exclusão de dados/opt-out do tutor (direito da LGPD): decisão explícita de Thiago de não implementar isso nesta entrega — fica para uma fase seguinte, não é um corte por omissão. `[NOTE FOR PM]` Tensão a observar quando isso for retomado: o histórico imutável do card (NFR-3) pode conflitar com um pedido de eliminação.
15. **[NÃO bloqueia o início do build — bloqueia o go-live]** Qual é a lista definitiva de sinais de alerta clínico a usar em produção (FR-8)? Decisão de 01/set/2026: os critérios são configuráveis (FR-34), então o time já pode construir o mecanismo com uma lista interina — mas a lista real, validada pela equipe clínica do Nouvet, precisa estar pronta antes do go-live de 08/09.

16. O usuário do Nouvet no Painel enxerga apenas os indicadores, ou também a Configuração de Personalização (FR-44)? Thiago disse "1 usuário Nouvet que verá tudo" em 08/set/2026, mas na mesma sessão havia declarado que configuração é "somente Btech, a princípio". O PRD assume a leitura restritiva — só indicadores — até confirmação, porque o erro na direção oposta daria a alguém de fora da Btech o poder de mudar o comportamento do agente em produção. Não bloqueia o início da construção do Painel.

## 14. Índice de Suposições

- **§4.7 (FR-22):** mecanismo exato de exibição "mais recente primeiro" no card do RD Station a confirmar com o time técnico.
- **§4.7 (FR-23):** etapas exatas de cada funil assumidas como reaproveitamento dos modelos já existentes no RD Station, até revisão conjunta com material que Thiago vai providenciar.
- **§4.7 (FR-42):** requisito mínimo de acesso restrito a exportações temporárias assumido enquanto não há política formal de retenção definida.
- **§4.2 (FR-8):** lista interina de sinais de alerta clínico assumida com os exemplos já usados no material comercial/entrevistas (ex.: vômito por 3+ dias seguidos), até a equipe clínica do Nouvet validar a lista definitiva — ver Questão em Aberto #15.
- **§4.9 (FR-30, FR-31):** arquitetura da base de conhecimento e mensagem exata de reconhecimento de incerteza ainda não definidas.
- **§8 (NFR-1) / §7 (SM-2):** alvo de tempo de primeira resposta assumido em 1 minuto.
- **§4.13 (FR-44):** papel do usuário do Nouvet no Painel assumido como Visualizador — só indicadores, sem acesso à Configuração de Personalização — ver Questão em Aberto #16.
