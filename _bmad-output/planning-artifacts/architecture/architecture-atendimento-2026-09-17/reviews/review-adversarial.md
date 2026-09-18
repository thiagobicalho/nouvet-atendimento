---
name: 'Revisão adversária — Architecture Spine (Agente que Agenda)'
type: architecture-review
lens: adversarial
target: 'ARCHITECTURE-SPINE.md (architecture-atendimento-2026-09-17)'
prd: 'prd-atendimento-2026-09-17/prd.md'
created: '2026-09-17'
status: draft
---

# Revisão adversária — o que duas unidades obedientes ainda conseguem quebrar

## Método

O ataque não é procurar erro nos `AD`. É o contrário: **assumir que cada unidade um nível abaixo (épico/feature/story) obedece todos os `AD` à risca** e construir pares de unidades que, obedecendo, ainda assim se constroem de forma incompatível. Cada par abaixo é um buraco: o lugar onde a espinha deixa uma escolha livre que duas pessoas diferentes resolvem de duas formas diferentes — e só descobrem em produção.

Convenção de severidade:

- **Crítica** — quebra requisito funcional do PRD ou corrompe dado de cliente/agenda sem ninguém violar `AD` nenhum.
- **Alta** — retrabalho estrutural quando o segundo lado for construído, ou erro visível para o cliente.
- **Média** — divergência que se resolve com conversa, mas que custa uma rodada de correção.
- **Baixa** — inconsistência de documento, não de construção.

## Veredito

A espinha é forte onde decide **onde a verdade mora** e fraca onde precisa dizer **em que formato a verdade trafega entre duas unidades**. Dos 18 pares encontrados, quatro são críticos e todos os quatro nascem da mesma omissão: `AD-12` declarou que o Postgres não guarda horário, mas três consumidores legítimos (temporizadores, indicadores, recorrência) **precisam de tempo e de histórico** e nada diz de onde tiram. O documento está pronto para virar épicos depois de fechar B-01 a B-04; os demais podem ser apertados nos `AD` existentes.

## Resumo dos buracos

| # | Par de unidades | Severidade | Fechamento |
|---|---|---|---|
| B-01 | Disponibilidade × Agendar — o que é "um horário oferecido" | **Crítica** | `AD` novo (oferta como objeto) + aperto em `AD-14` |
| B-02 | Indicadores/Recorrência × `AD-12`+`AD-21` — fatos sem casa | **Crítica** | `AD` novo (camada de fato derivado) |
| B-03 | Temporizadores × `AD-12` — cron sem horário e ponteiro sem âncora estável | **Crítica** | `AD` novo + aperto em `AD-12` |
| B-04 | Agente escreve × Equipe usa o Outlook — topologia do evento indefinida | **Crítica** | `AD` novo (organizador é o recurso) + aperto em `AD-16` |
| B-05 | Remarcar × Espelho no CRM — cancelar+criar ou `PATCH` | **Alta** | Aperto em `AD-12` + `AD` novo de mutação |
| B-06 | Escala (Nouvet) × Disponibilidade — tabela sem horas e ausência ambígua | **Alta** | Aperto em `AD-14` |
| B-07 | Preço dimensionado × Duração escalar — porte provisório vira duração firme | **Alta** | Aperto em `AD-18` |
| B-08 | Catálogo (Btech) × Escala (Nouvet) — onda liga pela metade | **Alta** | Aperto em `AD-19` |
| B-09 | Temporizadores × Handoff/lock — lembrete atropela humano | **Alta** | `AD` novo (portão único de saída) |
| B-10 | Três donos do estado conversacional + resposta sem alvo | **Alta** | `AD` novo (dono único do estado) |
| B-11 | Tom como dado × template aprovado pela Meta | **Média-alta** | Aperto em `AD-1` e `AD-17` |
| B-12 | Ponteiro chaveado por telefone × identidade chaveada por tutor (1:N) | **Média-alta** | Aperto em `AD-8`/`AD-11` |
| B-13 | Importação × Conversa — ping-pong de `origem` do porte | **Média** | Aperto em `AD-15` |
| B-14 | Transporte e ponto de retirada — entidade sem casa | **Média** | Aperto em `AD-19` ou tabela nova |
| B-15 | Emergência: classificador no ingresso × regra no prompt | **Média** | Aperto em `AD-22` |
| B-16 | Hook só em `updated` — sem `deleted`, sem órfão, e processa a própria escrita | **Média** | Aperto em `AD-16` |
| B-17 | Contabilidade da franquia — o que conta como mensagem | **Média** | Aperto em `AD-17`/FR-40 |
| B-18 | Papel×permissão como dado × App Roles do Entra | **Baixa-média** | Aperto em `AD-23` |

---

## B-01 — "Um horário" não é um dado definido

**Severidade: Crítica**

**As duas unidades.**
Unidade A: *"02 - Buscar disponibilidade"* — implementa `AD-14` ao pé da letra: interseção de escala, janela do recurso, grade e duração do serviço, menos a ocupação lida do calendário. O cálculo existe em um lugar só, como o `AD` manda.
Unidade B: *"03 - Agendar"* — implementa FR-12: cria o evento no calendário do recurso com cliente, pet, serviço e telefone.

**Os dois obedecem.** A não duplica cálculo; B não calcula nada.

**Onde divergem.** A espinha nunca diz **o que A devolve**. Três leituras defensáveis:

1. Lista de horários de início (`["22/09 10:00", "22/09 11:30"]`) — é o que FR-11 sugere ("conjunto pequeno de opções") e é o que o agente precisa para falar com o cliente.
2. Lista de intervalos livres (`09:00–12:00 em Banho1`) — e quem oferece fatia. Isso reimplementa grade+duração fora do dono único: viola o espírito de `AD-14` sem violar a letra.
3. Lista de ofertas com recurso embutido (`{recurso: banho1, inicio, fim}`).

Se A escolher (1) — a leitura mais natural, porque três recursos de banho geram horários repetidos e a unidade vai **deduplicar por horário** para não oferecer "10:00, 10:00, 10:00" —, então **B perde o recurso** e precisa reescolher. B vai reescolher com um critério próprio (primeiro livre, menos carregado, ordem da config). Consequências reais, todas sem violar `AD`:

- B pode escolher um recurso que executa o serviço (`atendimento_servico_recurso` ok) mas **não está na escala do dia**, porque B não consulta escala — escala é assunto de A.
- B pode escolher um recurso em que aquele horário já não está livre.
- O horário oferecido foi calculado com a grade e a duração vigentes no turno; entre a oferta e o "sim" do cliente (que pode levar minutos, e no WhatsApp leva horas) a config mudou (`AD-1`: lida a cada turno, nunca cacheada). B escreve 75′ onde A ofereceu 60′ e encavala o próximo.

**Agravante técnico.** A e B podem consultar o Graph por caminhos diferentes: `getSchedule` devolve uma *availabilityView* em intervalos discretos (padrão 30 min, mínimo 5) enquanto `calendarView` devolve os eventos com início e fim exatos. Com duração de 75′ (QA-2), a mesma agenda responde "livre" por um caminho e "ocupado" pelo outro. Se A usa `getSchedule` (barato, é o que serve para varrer o dia) e B revalida com `calendarView` (preciso), os dois discordam sistematicamente — e ninguém errou.

**Agravante de corrida.** `AD-5` trava **por sessão/telefone**. Dois clientes diferentes = dois locks diferentes = nenhuma exclusão mútua sobre o recurso. Os dois recebem "10:00" de A e os dois chamam B. E — este é o ponto que costuma passar — **escrita direta na caixa de recurso via permissão de aplicação não passa pelo assistente de reserva do Exchange**: o auto-decline de conflito só atua sobre *convite* de reunião. Quem cria evento direto no calendário da sala cria em cima do que já está lá, sem erro. **FR-16 ("nunca marcar dois atendimentos no mesmo recurso e horário") é violado com todos os `AD` obedecidos.**

**Fechamento proposto — `AD` novo.**
> **Oferta é um objeto, não um horário.** O sub-workflow de disponibilidade devolve **ofertas opacas**: `{recurso, inicio, fim, versao_da_config, expira_em}`. O agente escolhe qual oferecer e verbaliza; **a ferramenta de agendar consome a oferta verbatim** e não reinterpreta nem reescolhe recurso. Agendar é **compare-and-set**: dentro de um lock por `(recurso, janela)` — distinto do lock de sessão do `AD-5` — a ferramenta relê a ocupação daquele intervalo pelo mesmo caminho de API que a disponibilidade usou e só então escreve; oferta expirada ou com versão de config diferente é recusada e o cliente recebe nova oferta. Toda mutação de evento existente vai com `If-Match` do ETag lido.

Apertar `AD-14` com uma linha: *"o dono único do cálculo é também o dono do formato — nenhuma outra unidade constrói, fatia ou reinterpreta horário."*

---

## B-02 — Indicadores e recorrência precisam de fatos que dois `AD` proíbem guardar

**Severidade: Crítica**

**As duas unidades.**
Unidade A: *"Indicadores (FR-39)"* — a aplicação mostra agendamentos pelo agente, taxa de confirmação, comparecimento, transferências por motivo, tempo de resposta. É a régua de O2, O3 e O4.
Unidade B: *"Recorrência (FR-23a)"* — procura o cliente quando o intervalo típico do serviço é ultrapassado (banho: mediana de 14 dias; 208 clientes fora do ritmo).

**Os dois obedecem — e por isso não podem ser construídos.** A pinça:

- `AD-21`: a aplicação lê e escreve **config, escala, catálogo e indicadores no Postgres, e mais nada**. A aplicação não fala com o Graph.
- `AD-12`: o Postgres **não guarda horário**, guarda ponteiro; e o `AD` explicitamente *previne* "tabela local de agendamentos que espelha o calendário e diverge dele".
- `AD-15`: não há rotina periódica de importação; a base do SimplesVet entra uma vez.
- `AD-12` de novo: **nenhum componente consulta o SimplesVet em tempo de execução**.

Então: de onde vem "comparecimento por mês"? Só há três saídas, e **todas quebram alguma coisa**:

1. A aplicação consulta o Graph → quebra `AD-21`.
2. Alguém materializa uma tabela de agendamentos em Postgres → quebra o *Prevents* de `AD-12`.
3. Os indicadores saem do espelho no CRM (FR-14) → mas a convenção diz que a escrita no CRM é **fire-and-forget**, ou seja, é a fonte que declaradamente pode faltar dado. Medir O3/O4 num espelho com perda declarada é medir errado.

Mesmo problema em B, e pior: "último banho do Bidu" é anterior à virada do calendário. Não está no ponteiro (que só tem o que o agente marcou), não está no calendário (a migração é de agendamentos **futuros**, 3.119, não do histórico), e o SimplesVet está fora de alcance em tempo de execução. **FR-23a não tem fonte.** A questão QA-12 do PRD ("frequência do export do SimplesVet para reconciliar comparecimento") pergunta exatamente isso e `AD-15` responde "não há rotina periódica" — ou seja, o PRD e a espinha se cruzam sem se encontrar.

**Como as duas unidades divergem na prática.** A unidade de indicadores inventa `atendimento_evento_fato` alimentada pelo hook de comparecimento. A unidade de recorrência inventa `atendimento_historico_pet` alimentada pela importação. Duas tabelas de fato, populadas por caminhos diferentes, respondendo à mesma pergunta com números diferentes — e a diretoria vendo duas taxas de comparecimento na mesma tela.

**Fechamento proposto — `AD` novo.**
> **Fato derivado é permitido; espelho autoritativo não.** Existe uma tabela **append-only** de fatos (`atendimento_fato`: agendado, remarcado, cancelado, confirmado, compareceu, faltou, transferido — com `event_id`, `recurso`, `servico`, `pet`, `momento`, `origem_do_sinal`). Ela é **derivada e descartável**: nenhuma decisão de agendamento a consulta, e ela pode ser reconstruída do calendário. `AD-12` é apertado de *"o Postgres não guarda horário"* para ***"nenhuma decisão de agenda é tomada a partir de horário guardado no Postgres"*** — que é o que o `AD` realmente quer proteger. Indicadores (FR-39) e recorrência (FR-23a) leem daí e de lugar nenhum mais. A carga inicial do SimplesVet (`AD-15`) semeia o fato histórico **uma vez**, marcado com `origem = importado`, para que FR-23a nasça com os 208 clientes fora do ritmo em vez de nascer vazia.

---

## B-03 — Os temporizadores precisam de hora e o ponteiro não tem âncora estável

**Severidade: Crítica**

**As duas unidades.**
Unidade A: *"Lembrete e confirmação (FR-21, FR-21a, FR-22)"* — cron que acorda e decide a quem mandar lembrete, respeitando as antecedências configuradas por serviço e **suprimindo** o lembrete cujo momento já passou (`AD-17`; 42% dos banhos são marcados com menos de 24h).
Unidade B: *"Agendar / Remarcar"* — escreve o ponteiro.

**Os dois obedecem.** E A fica sem chão: `AD-12` diz que o Postgres **não guarda horário**, e o ponteiro declarado é `event_id + telefone + pet + serviço + estado conversacional`. **Um cron que não sabe quando é o agendamento não consegue decidir quando lembrar.**

As duas construções possíveis, ambas defensáveis:

1. A varre todos os ponteiros abertos a cada ciclo e consulta o Graph por `event_id` para descobrir a hora. Correto e caro: com ~450 banhos/mês na onda 1 ainda passa; com ondas 2 e 3 e recorrência, vira varredura de milhares de eventos por ciclo, e NFR-2 não é o problema — a franquia de chamadas do Graph e o *throttling* são.
2. A grava no ponteiro um `proximo_lembrete_em` (ou o próprio `inicio`). Rápido e é **exatamente o horário guardado que `AD-12` proíbe**.

Se A escolher (2) e B nunca reescrever esse campo — porque B só conhece "ponteiro, não cópia" —, o lembrete é enviado no horário antigo depois de qualquer mudança feita fora do agente.

**E mudanças fora do agente vão acontecer.** É o cenário que o PRD desenha: o Outlook passa a ser a agenda de **todos os setores** (§3), não só do agente. A recepcionista arrasta o evento das 10h para as 11h. Nada avisa o ponteiro exceto o hook — que `AD-16` descreve como ingestão de **comparecimento** e só fala de `updated` por **categoria**.

**Agravante — `event_id` não é âncora.** O identificador de evento do Graph é escopado à caixa de correio e à pasta: mover um item entre caixas ou entre calendários **muda o id**. Se a recepção arrastar o banho de `Agenda - Banho1` para `Agenda - Banho2` (troca de profissional — operação corriqueira), o `event_id` do ponteiro fica pendurado no vazio. A partir daí: o lembrete falha em silêncio ou dispara com a hora velha; a remarcação pelo cliente não encontra o agendamento (UJ-5 quebra); o hook de comparecimento marca um evento que o ponteiro não reconhece. `AD-12` diz "qualquer divergência resolve-se pelo calendário" — mas **o ponteiro é o único índice de telefone → evento**. Quando ele quebra, não há por onde resolver: a unidade que tenta "resolver pelo calendário" teria que varrer 54 caixas procurando um telefone no corpo do evento.

**Fechamento proposto — `AD` novo + aperto em `AD-12`.**
> **O ponteiro é reancorável e o tempo que ele guarda é declaradamente derivado.** O ponteiro carrega, além do `event_id`, uma **chave nossa** gravada no próprio evento (extensão aberta do Graph ou `iCalUId`, a confirmar contra a API) que sobrevive a mover, copiar e recriar. Carrega também `inicio_conhecido` e `recurso_conhecido`, marcados como **cache derivado, nunca autoridade**: nenhuma mensagem sai sem que a unidade reconcilie contra o calendário imediatamente antes de enviar. A assinatura do Graph (`AD-16`) cobre `created`, `updated` e `deleted` e **reconcilia o cache**, não só a categoria.

E apertar `AD-12`: *"o ponteiro pode carregar tempo como cache declarado; o que ele não pode é ser consultado no lugar do calendário para decidir."*

---

## B-04 — "O agente escreve" e "a equipe usa o Outlook" produzem dois calendários diferentes

**Severidade: Crítica**

**As duas unidades.**
Unidade A: *"03 - Agendar"* — `AD-13` manda usar caixa de recurso; `AD-23` dá ao agente `Calendars.ReadWrite` de aplicação restrita por *Application Access Policy*. A construção óbvia é `POST /users/agenda.banho1@nouvet.com.br/events`: escrita direta no calendário do recurso, **o recurso é o organizador**, não há convite, não há aceite.
Unidade B: *"Migração da agenda / operação no Outlook"* — a recepção e os setores usam o Outlook como sempre se usa: criam a reunião na **própria caixa** e adicionam a sala como recurso. O assistente de reserva do Exchange aceita e cria uma **cópia** no calendário da sala.

**Os dois obedecem.** `AD-13` é sobre modelar por recurso, e as duas formas modelam por recurso. `AD-21` é sobre a aplicação web — a recepcionista no Outlook não é a aplicação web. O documento nunca escolhe a topologia.

**Onde isso explode.**

- **Categorias são por caixa.** `AD-16` inteiro se apoia em "quem atende marca o evento com categoria (`Atendido`, `Faltou`)". A propriedade `categories` vive no **item daquela caixa**, e a lista mestra de categorias é por caixa também. Se a recepcionista marcar `Atendido` na cópia que está **na caixa dela**, a caixa de recurso não muda, a *change notification* assinada na caixa de recurso **não dispara** e o comparecimento nunca chega. FR-22a falha de forma completamente silenciosa — e `AD-16` tem o comportamento de degradação certo ("fica desconhecido"), o que significa que o indicador vai reportar cobertura baixa por meses sem ninguém entender por quê.
- **Editar o original reescreve a cópia.** Quando o organizador muda a hora da reunião, a cópia na sala é substituída — outro item, potencialmente outro id. Ver B-03.
- **Duas topologias no mesmo calendário.** Metade dos eventos da sala é "evento próprio do recurso" (escritos pelo agente) e metade é "cópia de reunião de outra caixa" (criados pela equipe). A unidade que lê ocupação vê os dois e funciona. A unidade que **escreve categoria**, a que **cancela**, a que **remarca** e a que **reancora** o ponteiro precisam de caminhos diferentes para cada topologia — e vão ser escritas para uma só.
- **Conflito.** A escrita direta não passa pelo assistente de reserva; o convite passa. Ou seja, as duas topologias têm políticas de conflito **opostas** no mesmo recurso (ver B-01).

**Fechamento proposto — `AD` novo, e ele precisa ser explícito porque muda o treinamento da equipe.**
> **O evento vive na caixa de recurso e o recurso é o organizador.** Nenhum agendamento do Nouvet entra na agenda como reunião de uma pessoa com a sala convidada: a equipe opera **dentro do calendário do recurso** (acesso delegado à caixa, que aparece como calendário adicional no Outlook). Consequências que a migração precisa carregar: a categoria de comparecimento (`AD-16`) só conta quando marcada no calendário do recurso; o cancelamento é remoção do evento do recurso; e a política de conflito é **nossa** (`AD-24`, compare-and-set), não do assistente de reserva. Se a operação exigir a forma "convidar a sala", então `AD-16` precisa assinar a caixa do organizador também — e aí o `AD` deixa de ser trivial.

---

## B-05 — Remarcar: cancelar+criar ou atualizar? Três donos avançando o mesmo card

**Severidade: Alta**

**As duas unidades.**
Unidade A: *"Remarcar (FR-17, UJ-5)"* — o PRD descreve literalmente em UJ-5: *"encontra o agendamento dela, **cancela**, oferece novos horários e remarca"*. A leitura direta é cancelar+criar.
Unidade B: *"Espelho no CRM (FR-14)"* — reflete o ciclo `Solicitado → Agendado → Confirmado → Compareceu/Faltou` num card.

**Os dois obedecem.** E divergem em tudo o que importa:

| | Cancelar + criar | `PATCH` no mesmo evento |
|---|---|---|
| `event_id` | novo | preservado |
| Ponteiro | linha nova (ou linha velha órfã) | mesma linha |
| Card no CRM | card fechado + card novo, ou card "Cancelado" que nunca mais anda | card muda de etapa |
| FR-39 "agendamentos pelo agente" | conta 2 | conta 1 |
| Evento antigo | sumiu ou ficou como "Cancelado" no calendário? | n/a |

Se A remarca por cancelar+criar e B foi escrita assumindo card único por agendamento, **a taxa de comparecimento cai artificialmente** (cards cancelados no denominador) e O3 — que é medido justamente por "Atrasado + Cancelado sobre o total", linha de base 20,1% — **piora quando a remarcação funciona**. O indicador do sucesso registra o sucesso como fracasso.

**Agravante — três escritores fire-and-forget e sem ordem.** A convenção diz "escrita no CRM sempre *fire-and-forget* com saída de erro registrada; jamais bloqueia o agendamento". Quem move o card? A ferramenta de agendar (→ Agendado), o cron de confirmação (→ Confirmado) e o hook do Graph (→ Compareceu/Faltou). Três processos independentes ("rodam em paralelo, sem se chamar", diz o próprio Design Paradigm), sem ordenação e com perda tolerada. Um card pode ir para `Compareceu` e depois **voltar** para `Confirmado` porque a escrita atrasada chegou depois. Nenhuma unidade está errada.

**Fechamento proposto.** Apertar `AD-12` com a regra de mutação:
> **Remarcar preserva a identidade do agendamento.** Mudança de horário no mesmo recurso é atualização do mesmo evento; mudança de recurso é operação declarada de "mover", que **reancora** o ponteiro e mantém a mesma identidade de negócio. Cancelar é terminal e fecha o ponteiro. O CRM recebe **transições idempotentes e ordenadas por carimbo de tempo do fato** — o espelho nunca anda para trás; uma transição mais velha que a etapa atual é descartada, não aplicada.

---

## B-06 — A escala não consegue expressar o que a operação faz

**Severidade: Alta**

**As duas unidades.**
Unidade A: *"Manter escala (FR-38)"* — tela da diretoria do Nouvet: quais recursos abrem em cada dia. Tabela declarada: `atendimento_escala (recurso, data)`.
Unidade B: *"Disponibilidade (AD-14)"* — `escala do dia ∩ janela do recurso ∩ grade e duração ∩ − ocupação`.

**Os dois obedecem, e a modelagem não fecha:**

- **A escala não tem horas.** A janela vem de `atendimento_recurso`, que tem **uma** janela de funcionamento. Mas a operação é rotativa e o próprio `AD-14` cita os números: 20–22 recursos por dia útil, **17 no sábado, 9 no domingo**. Sábado com horário igual ao de terça é improvável; o banho de sábado quase certamente fecha mais cedo. A unidade A (tela) vai querer campo de horário por dia — porque é o que o usuário pede na primeira semana — e a unidade B vai ler a janela do recurso. Divergem no primeiro sábado.
- **Ausência de linha é ambígua.** Duas leituras igualmente razoáveis: "sem linha = fechado" (fail-closed) ou "sem linha = janela padrão do recurso" (fail-open). A unidade que **importa as 6.642 linhas de escala** da migração vai gravar linhas explícitas, inclusive de dias fechados, com um booleano. A unidade da tela vai gravar só os dias abertos. Se B lê "sem linha" como padrão do recurso, **o agente oferece domingo**.
- **Fim do horizonte.** A escala está planejada até set/2027; FR-15 tem antecedência máxima por serviço. Além do horizonte da escala, B devolve vazio e o agente diz "não tenho horário" em vez de "ainda não há escala publicada". Comportamento aceitável, mas precisa ser escolhido de propósito.
- **`ativo` sobrecarregado.** `atendimento_recurso.ativo` vai significar coisas diferentes para quem constrói a migração ("a caixa existe e o recurso já virou") e para quem constrói a tela ("o recurso está em operação"). Na janela em que `Banho1` migrou e `Banho2` não, B lê o calendário vazio de `Banho2` e **oferece horários que estão ocupados no SimplesVet**. Com clientes reais, na onda 1. Esse é o risco mais caro do documento inteiro e está sob "Deferred" como "mecanismo, ordem e janela ainda não definidos".

**Fechamento proposto.** Apertar `AD-14`:
> A escala é `(recurso, data, abre, fecha, intervalos)` e é **fail-closed**: ausência de linha é recurso fechado, sem exceção. A janela em `atendimento_recurso` é apenas **padrão de preenchimento da tela**, nunca entrada do cálculo. E separar os dois sentidos de "ativo": `ativo` (existe na operação) é distinto de `pronto_para_o_agente` (caixa criada, agenda migrada, escala publicada) — **só o segundo entra no cálculo de disponibilidade**, e é ele que a trilha de migração liga, recurso por recurso.

---

## B-07 — Preço varia por dimensão; duração é um número só

**Severidade: Alta**

**As duas unidades.**
Unidade A: *"Preço (FR-18, `AD-18`)"* — `atendimento_preco` é uma **matriz de variação por dimensão**: espécie, porte, pelagem, plano. O `AD` é explícito que o preço varia por essas dimensões e que porte de origem `cliente` é **provisório** e sai **com ressalva**.
Unidade B: *"Disponibilidade e agendamento (`AD-14`, FR-10, FR-12)"* — usa "duração do serviço", um atributo escalar de `atendimento_servico`.

**Os dois obedecem.** E a realidade do banho não: banhar um gato, um lhasa e um golden não leva o mesmo tempo. As **mesmas dimensões que variam o preço variam a duração** — e só uma delas está modelada como matriz.

**O que quebra.** O porte do Bidu tem `origem = cliente` (provisório, `AD-18` manda pôr ressalva **no preço**). Esse mesmo porte provisório, se um dia a duração for dimensionada, determina um bloco **firme** no calendário — e não existe conceito de "ressalva de duração". Hoje, sem dimensionar, é pior: 75′ de mediana contra 60′ de moda (QA-2) significa que a distribuição é larga; com bloco fixo, o agente sistematicamente encavala os pets grandes e desperdiça capacidade nos pequenos. A unidade de preço vai construir a matriz (35 atributos por serviço, diz o PRD) e a unidade de disponibilidade vai ler `servico.duracao_min`. Ninguém está errado; o dia da operação é que fica errado.

**Agravante — a grade não existe como dado.** `AD-14` fala em "grade e duração do serviço" combinadas, mas nenhuma tabela declara **grade**. Duas unidades vão inventá-la: uma ancora os horários na abertura do recurso com passo = duração (07:40, 08:55, 10:10 com 75′), outra ancora em marcas redondas de 30 min (08:00, 08:30, 09:00). Os dois conjuntos de horários não se encontram, e o cliente que recebeu "10:10" no primeiro turno recebe "10:00" no segundo depois de uma mudança de config.

**Fechamento proposto.** Apertar `AD-18` e `AD-14`:
> **Toda dimensão que varia o preço é candidata a variar a duração.** `duracao` mora na mesma matriz dimensional de `atendimento_preco` (podendo ser constante enquanto o Nouvet não diferenciar). **Grade** é dado explícito do serviço: `passo` e `ancora` (abertura do recurso \| marca do relógio). Quando a dimensão que determina a duração for provisória (`origem = cliente`), o bloco escrito no calendário usa o **valor mais conservador da dimensão plausível**, nunca o informado — ressalva de preço vira folga de agenda.

---

## B-08 — Ligar a onda 2 é mudar um campo em uma tabela que dois donos diferentes editam

**Severidade: Alta**

**As duas unidades.**
Unidade A: *"Catálogo (FR-34)"* — Btech, na aplicação, mantém os serviços incluindo o campo `onda` (`AD-19`: "ligar a onda seguinte é mudar dado — nunca publicar versão").
Unidade B: *"Escala e recursos (FR-36, FR-38)"* — o vínculo serviço↔recurso é da Btech (FR-36), a escala é **do Nouvet** (FR-38). Duas telas, dois donos, duas tabelas.

**Os dois obedecem.** E `AD-19` está certo no que decide: onda é dado. O que ele não diz é que **ligar a onda não é um campo, é uma pré-condição**.

**O cenário concreto.** Onda 1 está em produção há três semanas, marcando banhos. A Btech vira `onda = 2` em Ultrassom. A partir do turno seguinte (`AD-1`: config lida a cada turno, nunca cacheada — **a mudança é instantânea e no meio de conversas em andamento**):

- Se `atendimento_servico_recurso` ainda não ligou Ultrassom a `Imagem1`, a disponibilidade devolve vazio. O agente não diz "fora de escopo" (FR-9 só cobre serviço de outra onda) — ele diz **"não encontrei horário"**. Para sempre. É a pior resposta possível: o cliente vai embora achando que a clínica está lotada.
- Se a escala de `Imagem1` nunca foi publicada — e a escala é do **Nouvet**, que não foi avisado de que a onda virou —, mesmo resultado.
- Se `atendimento_preco` não tem a matriz do Ultrassom, o agente marca e não informa valor, ou informa errado (e há QA-8 aberta sobre plano PETLOVE).
- A onda 2 é **Imagem** — ultrassom e raio-X pedem pedido médico e preparo (jejum). O PRD manda "reconhecer que um anexo chegou" (§8) e o Deferred diz **multimodal está fora do escopo das ondas 1 a 3**. A onda 2 liga sem o caminho de anexo existir.

**Fechamento proposto.** Apertar `AD-19`:
> **Onda liga por pré-condição verificada, não por campo solto.** A aplicação só permite ativar um serviço numa onda quando estiverem satisfeitos: ≥1 recurso vinculado, com caixa criada e `pronto_para_o_agente`, com escala publicada cobrindo a antecedência máxima do serviço, matriz de preço resolvida para as dimensões declaradas e regras de preparo cadastradas. A verificação é a mesma que o sub-workflow de disponibilidade usa. Serviço em onda ativa **sem disponibilidade estrutural** nunca é oferecido — cai em FR-9 (fora de escopo, conduz à transferência), nunca em "não encontrei horário".

---

## B-09 — O lembrete não sabe que tem um humano falando com o cliente

**Severidade: Alta**

**As duas unidades.**
Unidade A: *"Silêncio durante o humano (FR-29)"* — o agente cala enquanto um atendente conduz e retoma quando a conversa volta. Máquina `bot | aguardando_humano | humano` em `n8n_status_atendimento`.
Unidade B: *"Temporizadores"* — lembrete, confirmação e recorrência. `AD-17`: "lembretes e mensagens proativas são turnos próprios, contabilizados".

**Os dois obedecem.** E o diagrama de dependência da própria espinha mostra o buraco desenhado: `Cron --> RDC`. O cron fala **direto** com o RD Station Conversas. Não passa pelo `Ingresso`, não passa pelo `Agente`, não consulta `n8n_status_atendimento` e não pega o lock do `AD-5`.

**O que acontece.**

- A recepcionista está negociando um encaixe com o João (UJ-2, a transferência que é exceção). Às 19h o cron dispara o lembrete do banho de amanhã **no meio da conversa humana**. O cliente responde ao lembrete, a resposta cai no atendimento humano, e a confirmação (FR-22) nunca é registrada. O5 ("não aumentar o trabalho da equipe") toma o prejuízo.
- O cliente está no meio de um turno com o agente; o lembrete entra entre a pergunta e a resposta. `AD-17` diz "exatamente uma mensagem por turno" — e o cliente recebe duas, porque são turnos diferentes de processos diferentes. A letra do `AD` é obedecida e o efeito que ele existe para evitar (custo por mensagem a partir de 01/10) acontece.
- A mensagem de recorrência (FR-23a) e o lembrete (FR-21) podem cair no mesmo dia, do mesmo número, para o mesmo cliente. Dois processos, nenhum coordenador.

**Fechamento proposto — `AD` novo.**
> **Toda mensagem ao cliente sai por um portão único.** Não existe caminho do n8n para o RD Conversas que não passe por esse portão, inclusive cron. O portão verifica, em ordem: estado do atendimento (`humano` suprime e reagenda), lock da sessão (`AD-5`), consentimento vigente (FR-24), supressão temporal (`AD-17`/FR-21a), teto de mensagens proativas por contato por janela, e **contabiliza** (FR-40). Reconcilia o cache do ponteiro contra o calendário imediatamente antes de enviar (B-03).

---

## B-10 — Três donos do estado conversacional, e a resposta ao lembrete não tem alvo

**Severidade: Alta**

**As três unidades que se acham donas.**

1. `AD-20` define o contrato de entrada como *"identificação do contato, texto agregado do turno e **estado da conversa**"* — a camada de ingresso carrega o estado.
2. `agendamento_ponteiro` tem a coluna **`estado conversacional`** — o ponteiro carrega o estado.
3. `n8n_status_atendimento` (plumbing herdado, `AD-5`) carrega `bot | aguardando_humano | humano`, e FR-5 exige memória entre sessões, que mora em `n8n_historico_mensagens`.

**Todos obedecem.** E duas unidades vão escrever estados de vocabulários diferentes na mesma coluna: o cron de confirmação grava `aguardando_confirmacao` no ponteiro; o hook de comparecimento grava `compareceu` no mesmo lugar; a ferramenta de remarcar grava `em_remarcacao`. Três máquinas de estado ortogonais — **ciclo de vida comercial** (FR-14: Solicitado→Agendado→Confirmado→Compareceu/Faltou), **estado da conversa** (bot/humano) e **transação em curso** (escolhendo horário, remarcando) — numa coluna só chamada "estado conversacional".

**O caso que quebra de verdade.** O cliente tem dois agendamentos: banho na quinta e ultrassom na sexta. Na quarta à noite o cron manda o lembrete do banho e pergunta "confirma?". O cliente responde **"sim"** na quinta de manhã. Esse "sim" entra como mensagem normal pelo ingresso, que entrega ao agente "identificação do contato, texto do turno e estado da conversa". **Nada nesse contrato diz a qual evento o "sim" se refere.** O agente vai resolver por heurística — o ponteiro mais próximo, o mais recente, o último mencionado no histórico — e a unidade do cron vai resolver por outra. FR-22 registra confirmação no agendamento errado, e O4 (a métrica que existe justamente porque hoje só 2,5% confirmam) fica medindo ruído.

**Fechamento proposto — `AD` novo.**
> **Estado tem dono único e pergunta pendente tem alvo.** Separar explicitamente: (a) *estado do atendimento* — dono: ingresso/handoff; (b) *ciclo de vida do agendamento* — dono: os fatos (B-02), derivado, nunca escrito à mão; (c) *transação em curso na conversa* — dono: o agente, numa estrutura própria. O ponteiro guarda **vínculo, não estado**. Toda mensagem proativa que faz uma pergunta cria uma **pergunta pendente com alvo explícito** (`{tipo, event_id, expira_em}`); o ingresso entrega essa pendência junto com o turno, e a resposta só é aplicada ao alvo declarado — na ausência de alvo resolvível, o agente pergunta de qual agendamento se trata, em vez de adivinhar.

---

## B-11 — "Tom é config" e "mensagem proativa é template aprovado pela Meta" não cabem juntos

**Severidade: Média-alta**

**As duas unidades.**
Unidade A: *"Identidade e tom (FR-35, `AD-1`, NFR-8)"* — mudar nome, tom, catálogo, duração, horário ou destinatário **não exige publicar versão**. Tudo é dado em Postgres, lido a cada turno.
Unidade B: *"Lembrete (FR-21, FR-22, FR-24)"* — mensagem **iniciada pela empresa**, fora da janela de 24h. FR-24 existe justamente porque a Meta exige autorização para isso.

**Os dois obedecem.** E colidem: mensagem iniciada pela empresa fora da janela de serviço exige **template aprovado** — conteúdo submetido e homologado, com parâmetros posicionais. Não é texto livre gerado por LLM a partir de um tom configurável. Se a Btech editar o tom no dia seguinte e a unidade B gerar o lembrete pelo agente, ou o envio é rejeitado ou sai conteúdo não aprovado. Se a unidade B usar template fixo, **FR-35 e NFR-8 não valem para lembretes** — e ninguém escreveu isso em lugar nenhum.

O mesmo vale para FR-23a (recorrência: mensagem proativa por definição) e para a mensagem de emergência aos destinatários (`AD-22`), se ela sair pelo WhatsApp.

**Fechamento proposto.** Apertar `AD-1`/`AD-17` com a fronteira:
> **O que é dado, na saída proativa, é a escolha do template e seus parâmetros — não o corpo.** O catálogo de templates aprovados vive como dado (`nome`, `idioma`, `parâmetros`, `categoria`), e mudar tom afeta o caminho reativo (dentro da janela) e a submissão do próximo template, nunca o conteúdo do que já está aprovado. A aplicação deixa isso visível para a Btech, para que "mudar o tom" não gere a expectativa de que o lembrete mudou.

---

## B-12 — O ponteiro é chaveado por telefone; a identidade é chaveada por tutor

**Severidade: Média-alta**

**As duas unidades.**
Unidade A: *"Identidade (FR-1, `AD-11`)"* — `identidade_tutor` tem **"telefones"** (lista) e endereços (lista). Um tutor, N telefones.
Unidade B: *"Ponteiro (`AD-12`)"* — `agendamento_ponteiro` = `event_id + **telefone** + pet + serviço + estado`.

**Os dois obedecem.** E na primeira vez que a Mariana marcar pelo celular dela e o marido escrever do celular dele — mesmo tutor, mesmos pets, mesma casa —, a unidade B não encontra o agendamento (UJ-5 falha: *"encontrei um agendamento seu"* vira *"não encontrei nada em seu nome"*), enquanto a unidade A reconhece perfeitamente quem é. O lembrete vai para o telefone que marcou, não para quem vai levar o pet.

Mesmo problema na direção inversa: um telefone de família com dois tutores. O ponteiro por telefone mistura agendamentos de pessoas diferentes.

**Fechamento proposto.** Apertar `AD-8`/`AD-11`: o ponteiro é chaveado por **`tutor_id` + `pet_id`**, com o telefone de origem guardado como atributo (para saber por onde responder). A resolução telefone → tutor é a mesma porta única e idempotente do `AD-11`, e é o único lugar onde essa tradução acontece.

---

## B-13 — Porte: a importação e a conversa jogam ping-pong com `origem`

**Severidade: Média**

**As duas unidades.**
Unidade A: *"Importação sob demanda (FR-40a, `AD-15`)"* — normaliza uma vez, **nunca sobrescreve campo de domínio próprio**, e serve para "carga inicial **e conferência eventual de porte**".
Unidade B: *"Confirmar preferências (FR-5a)"* — o agente confirma a preferência em uma linha a cada agendamento; `origem = cliente` é provisório e força ressalva (`AD-18`).

**Os dois obedecem — e `AD-15` se contradiz sozinho.** Se `porte` mora em `identidade_pet` (mora: a tabela lista "porte e tipo de pelo **com `origem`**"), então porte **é** campo de domínio próprio, e "nunca sobrescreve campo de domínio próprio" torna a "conferência eventual de porte" um relatório que não pode agir. Duas construções:

- A unidade de importação lê "conferência de porte" como autorização para atualizar quando `origem = cliente` (menor confiança) e mantém quando `origem = faturamento`.
- A unidade de conversa grava `origem = cliente` toda vez que o cliente confirma, **rebaixando** um dado que veio do faturamento.

Resultado: o preço do mesmo banho muda entre dois agendamentos, com ressalva num e sem noutro, sem que ninguém tenha mudado nada. E o cliente nota.

**Fechamento proposto.** Apertar `AD-15` com uma **ordem de precedência explícita** (`faturamento > importado > cliente`), a regra de que **confirmação do cliente não promove nem rebaixa `origem`** (só renova o carimbo de tempo), e a decisão sobre o que a conferência pode fazer: escrever quando a precedência for maior, registrar divergência quando for menor.

---

## B-14 — O pedido de transporte e o ponto de retirada não têm casa

**Severidade: Média**

**As duas unidades.**
Unidade A: *"Registrar Leva e Traz (FR-25, FR-26)"* — "solicitação a confirmar, **vinculada ao agendamento principal**, sem prometer horário".
Unidade B: *"Agendar / Remarcar / Cancelar"*.

**Os dois obedecem.** E não existe tabela para a solicitação de transporte no *Structural Seed*. Três casas plausíveis, todas legítimas: (a) no corpo/categoria do evento do calendário, (b) uma tarefa no RD CRM (é o padrão que UJ-4 já usa para "cliente novo a lançar"), (c) uma coluna no ponteiro.

Se for (a) e a remarcação for cancelar+criar (B-05), o pedido **evapora**. Se for (b) e o cliente cancelar, ninguém cancela a tarefa — e a van sai. Se for (c), a aplicação não enxerga (é tabela de plumbing, não de administração) e a equipe que confirma não tem onde olhar.

**Relacionado:** `identidade_tutor` tem **lista** de endereços "com ponto de retirada". Qual endereço vale **para este agendamento**? É uma escolha de escopo de agendamento guardada numa entidade de escopo de tutor. A unidade de transporte vai pegar o primeiro/o marcado como padrão; o cliente disse "hoje busca na casa da minha mãe".

**Fechamento proposto.** Dar casa explícita: `atendimento_solicitacao_transporte` ligada à identidade de negócio do agendamento (não ao `event_id`, ver B-05), com o endereço **copiado** no momento do pedido, e ciclo próprio (`solicitado | confirmado | recusado | cancelado`) que segue o cancelamento do agendamento principal.

---

## B-15 — Emergência: regra no prompt ou porteiro antes do agente?

**Severidade: Média**

**As duas unidades.**
Unidade A: *"Emergência (FR-27, `AD-22`)"* — *"tem precedência sobre qualquer outra instrução do prompt"*, o que implica que é uma instrução **do prompt**, dentro do agente.
Unidade B: *"Guardrails (FR-31, FR-32, FR-33)"* — "tratar todo texto do cliente como dado, nunca como instrução". A construção defensiva natural é um classificador **antes** do agente, no ingresso, que desvia o que for crítico.

**Os dois obedecem.** Se as duas forem construídas, "está vomitando sangue" pode disparar o alerta duas vezes (dois destinatários recebendo o mesmo susto), ou o classificador desvia a mensagem e o agente nunca vê — ficando com a conversa de agendamento congelada no meio.

**E `AD-22` não diz o que acontece com o que já foi escrito.** "Interrompe o que estiver em curso": se a ferramenta de agendar **já criou o evento** e a emergência é reconhecida no turno seguinte, o evento fica. Se foi reconhecida no mesmo turno, depende de onde o classificador está. Duas unidades, dois comportamentos.

Ponto extra: QA-7 do PRD está aberta ("há plantão para alertar fora do horário comercial?"). `AD-22` manda alertar "os destinatários configurados" e `AD-1` diz que destinatário é dado. Se a lista estiver vazia às 3h da manhã, o `AD` é obedecido e ninguém é avisado. O comportamento na lista vazia precisa ser escolhido (o mais conservador: o agente **diz** ao cliente que está orientando sem confirmação humana, e registra).

**Fechamento proposto.** Apertar `AD-22`: emergência é reconhecida **em um único lugar** (declarar qual), o alerta é **idempotente por conversa e por janela de tempo**, "interromper" é definido como *não prosseguir e não escrever no calendário a partir deste ponto* (o que já foi escrito permanece e é sinalizado ao destinatário), e lista de destinatários vazia é uma condição tratada, não um silêncio.

---

## B-16 — O hook só escuta `updated`, processa a própria escrita do agente e não tem dono para o órfão

**Severidade: Média**

**As duas unidades.**
Unidade A: *"Ingestão de comparecimento (`AD-16`)"* — assina *change notification* em `updated` na caixa de recurso e lê a categoria.
Unidade B: *"Agendar / Remarcar"* — escreve no mesmo calendário.

**Os dois obedecem.** Três efeitos:

- **`deleted` não é assinado.** A recepção apaga o evento no Outlook; o ponteiro fica pendurado e o lembrete do dia seguinte é enviado para um agendamento que não existe. Ninguém é dono do órfão.
- **O hook processa as próprias escritas do agente.** Todo `POST`/`PATCH` da unidade B gera notificação para a unidade A. Benigno se A só lê categoria; **não benigno** se A for construída com a leitura natural de `AD-12` ("qualquer divergência entre ponteiro e calendário resolve-se pelo calendário") e virar uma unidade de *reconciliação*. Aí há corrida: a notificação pode chegar **antes** de a unidade B ter gravado o ponteiro, A conclui que é evento criado por humano, e as duas unidades disputam a mesma linha.
- **A janela de renovação.** `AD-16` acerta em dizer que a renovação é do sistema. Falta dizer o que acontece **no buraco**: assinatura de evento no Graph tem vida curta (ordem de poucos dias) e uma falha de renovação perde notificações **silenciosamente**. Sem uma varredura de recuperação por `delta`/`calendarView` no intervalo perdido, o indicador de comparecimento cai e `AD-16` reporta "cobertura baixa" sem que ninguém saiba que a causa foi técnica.

**Fechamento proposto.** Apertar `AD-16`: assinar `created, updated, deleted`; toda escrita do agente carrega marca de origem para o hook ignorar o próprio eco; a reconciliação é **varredura por `delta`** com marca d'água, e o hook é só o gatilho rápido; e falha de renovação é incidente visível, com recuperação retroativa da janela perdida antes de qualquer indicador ser publicado.

---

## B-17 — Ninguém definiu o que conta como mensagem

**Severidade: Média**

**As duas unidades.**
Unidade A: *"Consumo da franquia (FR-40)"* — acompanha o consumo contra a franquia mensal da Meta.
Unidade B: *"Tudo que envia"* — agente (uma por turno, `AD-17`), lembrete, confirmação, recorrência, alerta de emergência aos destinatários (`AD-22` + `AD-7`: canal único é o RD Conversas).

**Os dois obedecem.** `AD-17` define a regra no caminho do cliente e diz que lembretes são "turnos próprios, contabilizados". Não define o que entra na conta da unidade A. A unidade A vai contar respostas ao cliente; o alerta de emergência a três destinatários internos, enviado pelo mesmo canal, some da conta — e some justamente no dia em que mais mensagens saem. Com franquia de **1.000 por número por mês** e ~2.400 agendamentos/mês na operação inteira, a margem não é grande: só a onda 1 (~450 banhos/mês) com um lembrete e uma confirmação por agendamento já consome perto de metade, antes das respostas de conversa.

**Fechamento proposto.** Apertar `AD-17`/FR-40: a conta é **por número emissor e por categoria de mensagem**, feita no portão único de saída (B-09), e inclui tudo o que sai pelo RD Conversas — resposta de agente, proativa e alerta interno. Alerta interno deveria sair por canal que não consome franquia; se sair pelo WhatsApp, entra na conta.

---

## B-18 — Papel→permissão como dado, num app onde papel é claim do token

**Severidade: Baixa-média**

**As duas unidades.**
Unidade A: *"Autenticação (FR-41, `AD-23`)"* — App Roles do Entra (`btech-admin`, `nouvet-diretoria`), papel vem no token.
Unidade B: *"Autorização"* — `AD-23` diz que a matriz papel → permissão **vive como dado, não como código**; `AD-1` diz que config é lida a cada turno e nunca cacheada.

**Os dois obedecem.** E a matriz como dado, numa aplicação cuja função é editar dados, significa que **um administrador pode editar a própria matriz de permissões** — ou conceder a um papel uma permissão que o Entra não pretendia dar. A separação de identidade que `AD-23` conquista (dois registros de aplicativo, raio de vazamento menor) é parcialmente devolvida pela porta dos fundos.

**Fechamento proposto.** Apertar `AD-23`: o conjunto de papéis e o **teto** de cada papel são código/configuração de implantação; o que é dado é a atribuição de pessoas a papéis e refinamentos **dentro** do teto. A edição da própria matriz é privilégio separado e auditado (NFR-7).

---

## Inconsistências menores do documento

- **`AD-15` × FR-40a × QA-12.** `AD-15` diz "não há rotina periódica"; QA-12 do PRD pergunta "frequência do export do SimplesVet para reconciliar comparecimento". Ou a questão está resolvida pelo `AD` (e deveria sair do PRD), ou o `AD` decidiu uma questão que o PRD ainda considera aberta. Hoje o leitor não sabe qual.
- **Multimodal × onda 2.** *Deferred* coloca áudio e imagem fora das ondas 1 a 3; a onda 2 é Imagem, que na prática chega com pedido médico anexado. O PRD §8 já prevê "reconhecer que um anexo chegou". Vale declarar que "reconhecer anexo" (não interpretar) **está dentro** das ondas 1–3.
- **Fuso.** A convenção manda `America/Sao_Paulo` em toda leitura e escrita de calendário. Falta estender ao **cron**: o gatilho de agenda do n8n usa o fuso da instância, e o cálculo de "24h antes" feito em UTC com supressão comparada em horário local (`AD-17`/FR-21a) erra na borda. Baixo risco no Brasil (sem horário de verão), custo zero de fechar.
- **Ciclo de vida do ponteiro.** Nada diz quando uma linha de `agendamento_ponteiro` fecha. Se nunca fecha, o cron varre um conjunto que só cresce; se o hook de comparecimento a apaga, a recorrência (FR-23a) perde a entrada. Resolvido de graça se B-02 entrar (o fato guarda a história; o ponteiro só serve ao que está aberto).
- **`AD-20` (B) e o custo real.** A nota "é simplificação, não retrabalho estrutural" vale para o handoff. Mas na opção (B), síncrona, o agente responde **dentro** do timeout do fluxo do RD — e a consulta de disponibilidade contra o Graph é a operação mais lenta do sistema. NFR-2 ("quando a consulta for demorar, o agente sinaliza em vez de silenciar") pressupõe poder mandar uma mensagem intermediária, o que é um **segundo envio** e colide com `AD-17`. Vale registrar como consequência da opção (B), junto com a simplificação.

---

## Fechamentos propostos, consolidados

Cinco `AD` novos e sete apertos. Numeração sugerida seguindo a série (IDs nunca renumerados):

| ID | Título | Fecha |
|---|---|---|
| `AD-24` | Oferta é objeto opaco com validade; agendar é compare-and-set sob lock por recurso×janela | B-01 |
| `AD-25` | Fato derivado é permitido; espelho autoritativo não — camada `atendimento_fato` append-only e reconstruível | B-02 |
| `AD-26` | Ponteiro reancorável por chave própria; tempo no ponteiro é cache declarado, reconciliado antes de cada envio | B-03 |
| `AD-27` | O evento vive na caixa de recurso e o recurso é o organizador; a equipe opera dentro dela | B-04 |
| `AD-28` | Portão único de saída — nenhuma mensagem ao cliente escapa dele, inclusive cron | B-09, B-17 |
| `AD-29` | Estado tem dono único; pergunta pendente tem alvo explícito | B-10 |
| aperto `AD-12` | Remarcar preserva identidade; cancelar é terminal; CRM recebe transições idempotentes e ordenadas | B-05 |
| aperto `AD-14` | Escala com horas, fail-closed; `pronto_para_o_agente` separado de `ativo`; dono do cálculo é dono do formato | B-01, B-06 |
| aperto `AD-18` | Duração na mesma matriz dimensional do preço; grade e âncora explícitas; dimensão provisória vira folga | B-07 |
| aperto `AD-19` | Onda liga por pré-condição verificada; serviço sem disponibilidade estrutural cai em FR-9 | B-08, B-14 |
| aperto `AD-15` | Precedência de `origem` explícita; confirmação do cliente não promove nem rebaixa | B-13 |
| aperto `AD-16` | `created/updated/deleted`, eco próprio ignorado, reconciliação por `delta` com marca d'água | B-16 |
| aperto `AD-1`/`AD-17` | Em saída proativa, dado é a escolha do template e seus parâmetros, não o corpo | B-11 |
| aperto `AD-8`/`AD-11` | Ponteiro chaveado por tutor+pet; telefone é atributo | B-12 |
| aperto `AD-22` | Reconhecimento em um lugar só; alerta idempotente; "interromper" definido; lista vazia tratada | B-15 |
| aperto `AD-23` | Teto de papel é implantação; só a atribuição é dado | B-18 |

## O que a espinha acerta e não deve ser mexido

Registrado porque uma revisão adversária que só ataca engana sobre o estado do documento:

- **`AD-14` — "escala é nossa, ocupação é do calendário"** é a decisão mais valiosa do documento. Reconhecer que o Exchange não modela escala rotativa evitou uma classe inteira de retrabalho.
- **`AD-19` — onda como dado** elimina a pior armadilha de uma entrega modular sob prazo (branch por onda). O que falta é pré-condição, não o princípio.
- **`AD-16` — comparecimento por categoria**, com o degradê honesto ("desconhecido", indicador reporta cobertura, nunca presume). É a postura certa para um sinal que depende de humano.
- **`AD-20` — ingresso substituível** está bem construído: separa o que está em aberto (a forma) do que já é invariante (nada abaixo depende dela).
- **`AD-18` — preço é função, com ressalva quando a dimensão é provisória.** A crítica em B-07 é que o mesmo raciocínio não foi estendido à duração, não que o raciocínio esteja errado.
