---
title: 'Revisão de rubrica — ARCHITECTURE-SPINE (Agente que Agenda)'
target: '_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-17/ARCHITECTURE-SPINE.md'
reviewed_against:
  - '_bmad-output/planning-artifacts/prds/prd-atendimento-2026-09-17/prd.md'
  - '_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md'
  - 'docker-compose.yml, n8n/migrations/ (estado real do repo)'
reviewer: 'revisão de arquitetura (rubrica de 7 pontos)'
date: '2026-09-17'
verdict: 'REVISAR ANTES DE DESCER PARA ÉPICOS'
---

# Revisão de rubrica — ARCHITECTURE-SPINE (Agente que Agenda)

## Veredito

A espinha é **boa no que decidiu** — AD-12/13/14 resolvem com precisão o problema mais difícil do produto (onde a agenda mora, como se calcula disponibilidade sobre uma escala rotativa que o Exchange não sabe modelar), e AD-17/18/19/22 são invariantes reais, não platitudes. Mas ela **não está pronta para descer para épicos**: a passagem de "o agente coleta" para "o agente escreve" abriu quatro classes de divergência que nenhum `AD` fixa — **a janela de migração do calendário, a integridade da escrita no calendário, o escopo de autoridade das ferramentas de escrita e o envelope operacional inteiro** — e duas decisões do Piloto (`AD-6`, `AD-9`) ficaram sem status.

**Contagem:** 3 críticos · 6 altos · 8 médios · 2 baixos.

---

## 1. Pontos de divergência para o nível abaixo — fixa todos?

**Não.** O que a espinha fixa, fixa bem. O inventário abaixo é do que ela **deixou aberto e que dois épicos vão resolver diferente**.

### Fixado corretamente (não são achados)

| Divergência | Fixada por |
|---|---|
| Onde mora a agenda; ponteiro vs cópia | `AD-12` |
| Modelagem de recurso (sala vs pessoa) | `AD-13` |
| Onde vive a escala e quem calcula disponibilidade | `AD-14` — "um único lugar" é a frase mais valiosa do documento |
| Sincronização com o SimplesVet | `AD-15` |
| Nº de mensagens por turno | `AD-17` |
| Preço como função, não valor | `AD-18` |
| Ondas como dado | `AD-19` |
| Acoplamento ao mecanismo de ingresso | `AD-20` (mesmo aberta, o invariante de substituibilidade é o correto) |
| Segundo ponto de escrita no calendário | `AD-21` |
| Precedência de emergência | `AD-22` |
| Fuso, slug, naming, E.164 | Consistency Conventions |

### F1 — `[CRITICAL]` A janela de migração do calendário não tem invariante, e ela produz double-booking com cliente real

`AD-12` afirma: *"Nenhum componente consulta o SimplesVet em tempo de execução."* Ao mesmo tempo, o Deferred registra que a migração dos **3.119 agendamentos futuros e 6.642 linhas de escala** é "trilha própria, paralela às ondas", com "mecanismo, ordem dos recursos e janela ainda não definidos", e a virada é **por recurso**.

As duas frases juntas descrevem um estado em que, para um recurso ainda não migrado, **a ocupação real está no SimplesVet, o calendário Microsoft está vazio, e `AD-12` proíbe olhar para o SimplesVet**. O motor de disponibilidade vai oferecer, com toda a confiança, um horário que já está ocupado. Não é um risco teórico: a onda 1 (Care Center, 3 recursos nominais, ~450/mês) roda em paralelo à migração dos 18 recursos.

Isso é simultaneamente um achado de **checklist 1** (dimensão não fixada), **checklist 2** (`AD-12` declara prevenir divergência entre aplicação e agente sobre o mesmo horário, e não previne nesta janela) e **checklist 3** (um item do Deferred deixa unidades divergirem).

**O invariante que falta** é de uma linha e pertence à espinha, não a um épico:

> Um recurso só é elegível para o agente depois que sua agenda futura está integralmente no calendário Microsoft. `atendimento_recurso` carrega o estado de migração, e o motor de disponibilidade (`AD-14`) **filtra por esse estado** — não pela onda do serviço. Recurso não migrado se comporta como recurso fora de escala: o agente não oferece, conduz à transferência.

Note que o gate é **por recurso**, enquanto `AD-19` liga escopo **por serviço**. São dois eixos independentes e a espinha só tem o segundo — o que garante que alguém vai confundir os dois.

### F2 — `[CRITICAL]` FR-16 ("nunca marcar dois no mesmo recurso e horário") não tem mecanismo

Detalhado em §2 (é primariamente um achado de enforceability), mas registro aqui porque **é um ponto de divergência não fixado**: sem regra, o épico de agendamento e o épico de remarcação vão implementar commit no calendário de formas diferentes.

### F3 — `[HIGH]` Escopo de autoridade das ferramentas de escrita: nenhum AD delimita sobre *qual* agendamento uma ferramenta pode agir

O Piloto podia ser leviano aqui: a pior consequência de uma injeção de prompt era um card errado no CRM (`AD-4` garantia que o agente não tocava agenda). Agora o agente **cancela e remarca** (`FR-17`), e `FR-32` ("tratar todo texto do cliente como dado, nunca como instrução") virou um requisito com consequência material — um cliente que escreve *"cancele o agendamento de amanhã às 10h da Imagem1"* não deve conseguir cancelar o agendamento de outra pessoa.

Nenhum `AD` diz que as ferramentas de cancelar/remarcar operam **exclusivamente sobre ponteiro cujo telefone normalizado é o da sessão em curso**, nem que o `event_id` é resolvido pelo sub-workflow a partir da sessão em vez de vir como argumento do modelo. Deixado assim, cada ferramenta vai desenhar sua própria assinatura, e ao menos uma vai aceitar `event_id` do LLM.

Este é exatamente o tipo de invariante que a altitude "initiative" existe para fixar: é uma regra sobre **a forma de todas as ferramentas**, não sobre uma delas.

### F4 — `[HIGH]` FR-14 (ciclo de vida no RD CRM) não tem dono entre os três processos independentes

O Design Paradigm declara três processos que **"rodam em paralelo, sem se chamar"**: conversa, temporizadores e ingestão de comparecimento. `FR-14` exige refletir no CRM o ciclo `Solicitado → Agendado → Confirmado → Compareceu/Faltou` — e cada um dos quatro estados nasce em um processo **diferente**:

| Estado | Nasce em |
|---|---|
| Solicitado / Agendado | conversa |
| Confirmado | temporizador (lembrete) ou conversa |
| Compareceu / Faltou | ingestão de comparecimento (`AD-16`) |

Nenhum `AD` binda `FR-14`. O Capability Map coloca FR-10–FR-17 sob `AD-12`/`AD-13`/`AD-14`, nenhum dos quais menciona CRM. A única governança é uma linha de convenção (*"escrita no CRM sempre fire-and-forget"*), que diz **como** escrever mas não **quem** escreve nem **qual é o mapa de estágio**.

Agrava: no Piloto isso era coberto por `AD-1` ("mapeamento de `stage_id` por setor é config") e `AD-6` ("o card do CRM é o funil; o Postgres não duplica estágio") — e **`AD-6` não está na lista de herdados** (ver F6). O resultado é que três épicos escreverão no CRM sem uma porta comum e sem ordem definida entre eles (o `Confirmado` do temporizador pode chegar depois do `Compareceu` do webhook).

A analogia existe e está a duas linhas de distância: `AD-11` já é a porta única idempotente para contato/card. Estender o mesmo padrão ao espelho de ciclo de vida é a correção natural.

### F5 — `[HIGH]` FR-24 (autorização da Meta) e a janela de 24h não existem na espinha

`FR-24` — *"Obter e registrar a autorização do cliente para receber mensagens, conforme exigência da Meta para mensagens iniciadas pela empresa"* — não aparece em nenhum `AD`, em nenhuma tabela do Structural Seed, em nenhuma convenção e em nenhum item do Deferred. **A palavra "opt-in" não ocorre no documento.**

Não é um detalhe de build. Os três mecanismos centrais de O3/O4 — lembrete (`FR-21`), confirmação (`FR-22`) e recorrência (`FR-23a`) — são **mensagens iniciadas pela empresa**, sujeitas a consentimento registrado e, fora da janela de 24h da última mensagem do cliente, a template aprovado. `AD-17` cuida do **custo** desses turnos e passa ao largo da **elegibilidade** deles. Sem invariante, cada temporizador decide por conta própria se checa consentimento, se checa a janela e se usa template ou texto livre — e o cenário de `FR-23a` (recorrência: cliente sem contato há 14+ dias, 965 inativos há mais de 180) é *por construção* fora de qualquer janela.

Precisa de: onde o consentimento é gravado (nem `identidade_tutor` nem `atendimento_config` o preveem), quem checa antes de enfileirar, e o que acontece com quem nunca deu opt-in.

### F6 — `[HIGH]` `AD-6` e `AD-9` do Piloto ficaram em limbo

A nota de abertura diz: *"`AD-4` ... está revogado ... Os demais `AD` do Piloto são herdados e não re-decididos (ver Invariantes Herdados)."* Mas a tabela de Invariantes Herdados lista **8** (`AD-1, 2, 3, 5, 7, 8, 10, 11`) e o Piloto tem **11**. Sobram `AD-6` e `AD-9`, que não foram herdados nem revogados.

- **`AD-9`** (credencial Microsoft escopada *somente leitura*; elevação é "ação deliberada e datada") é **materialmente contraditado** por `AD-23`, que concede `Calendars.ReadWrite` de saída. A contradição é *correta* — `AD-9` só existia para servir `AD-4` —, mas precisa ser **declarada revogada junto com `AD-4`**, ou um leitor que abrir as duas espinhas encontra duas regras opostas com o mesmo status.
- **`AD-6`** (o Postgres de identidade é complementar ao card, não substituto; não duplicar estágio de funil) **não foi contraditado por nada** e continua valendo — e é exatamente a regra que faltou em F4. Sumiu por omissão, não por decisão.

O documento acerta ao dizer "IDs nunca são renumerados". Falta a consequência: **todo ID herdado precisa de um status explícito** (herdado / revogado / superseded-por), sem terceira categoria silenciosa.

---

## 2. Cada Rule é aplicável (enforceable) e previne o que declara prevenir?

Rodei cada `AD` contra o teste: *"um dev que leu só esta Rule consegue violar o que ela diz prevenir?"*

| AD | Enforceable? | Nota |
|---|---|---|
| `AD-12` | **Parcial** | A parte "Postgres não guarda horário, guarda ponteiro" é verificável no schema — excelente. A parte "qualquer divergência resolve-se pelo calendário" é **declarativa**: não existe reconciliação, ninguém detecta divergência. E o "nenhum componente consulta o SimplesVet" falha na janela de migração (F1). |
| `AD-13` | **Sim** | "Caixa de recurso" e "vínculo é config 1:N" são checáveis. *(Ver F13: o texto diz 1:N, a tabela `atendimento_servico_recurso` diz N:N — inconsistência menor mas real.)* |
| `AD-14` | **Sim** | Das melhores do documento. "Esse cálculo existe em um único lugar" é auditável por inspeção de workflows. |
| `AD-15` | **Sim** | "Não existe rotina periódica" e "nunca sobrescreve campo de domínio próprio" são ambos falsificáveis. |
| `AD-16` | **Parcial** | Ver F12: fala de "a assinatura" no singular para ~54 caixas, e não existe onde guardar estado de assinatura. |
| `AD-17` | **Sim** | Contável. Mas colide com NFR-2 (ver F9). |
| `AD-18` | **Sim** | `modo_preco` como coluna obrigatória torna a regra estrutural, não uma boa intenção. |
| `AD-19` | **Sim** | Coluna `onda` no catálogo. Mas cobre só o eixo serviço, não o eixo recurso (F1). |
| `AD-20` | **Sim** | O invariante de substituibilidade sobrevive à escolha. Bem construído. |
| `AD-21` | **Sim** | "O único componente que escreve no calendário é o n8n" é verificável por credencial (o app não tem `Calendars.ReadWrite` por `AD-23`) — regra e mecanismo se sustentam mutuamente. |
| `AD-22` | **Parcial** | "Precedência sobre qualquer outra instrução do prompt" é uma afirmação sobre comportamento de LLM, não uma barreira. Aceitável, mas nenhuma verificação é proposta (ver F18). |
| `AD-23` | **Parcial** | A separação de registros é estrutural e sólida. O mecanismo nomeado está desatualizado (F11). |

### F7 — `[CRITICAL]` `AD-12` declara prevenir double-booking (binda FR-16) e nenhuma Rule o torna impossível

`AD-12` lista `FR-16` entre seus binds. Sua Rule fala de onde a verdade mora e de ponteiro vs cópia — **não diz nada sobre como uma escrita chega ao calendário sem colidir**. Três buracos concretos, cada um suficiente sozinho:

1. **Contenção entre sessões.** O lock de `AD-5` é **por telefone**. Dois clientes diferentes, oferecidos o mesmo horário no mesmo recurso (cenário comum: o motor oferece "as próximas três janelas" a ambos), confirmam com segundos de diferença. Nada serializa. O Piloto **reconheceu explicitamente esse limite** em `AD-11` (*"o lock de `AD-5` é por telefone/sessão e não protege identidade que abrange mais de um telefone"*) e construiu uma porta idempotente para o CRM. A espinha nova herdou `AD-5` e `AD-11` mas **não fez o análogo para o calendário**, que é onde a colisão agora custa uma cadeira dupla real.
2. **Retry.** Timeout do Graph → o agente ou o n8n reexecuta a ferramenta → dois eventos idênticos. `AD-11` resolveu isso para contato/card ("nova invocação da mesma tool ... criando um segundo contato"); a criação de evento não tem equivalente. O Graph oferece `transactionId` justamente para isso e a espinha não o menciona.
3. **A janela entre oferta e confirmação.** O motor lê ocupação, oferece, o cliente pensa 4 minutos, o agente escreve. Ninguém relê. Não há hold, não há re-checagem no commit.

O mecanismo mais barato existe e é do próprio Exchange: caixa de recurso com *calendar processing* em auto-accept e `AllowConflicts = $false` **rejeita** o conflito no servidor. Isso torna `FR-16` uma propriedade da plataforma em vez de uma esperança — e transforma o problema em "a ferramenta trata a recusa e reoferece", que é tratável. A espinha não decide nada sobre calendar processing das caixas, o que é uma omissão de configuração de plataforma no nível certo para a altitude initiative.

**Enquanto isso não for uma Rule, `FR-16` está apenas declarado como coberto.**

### F8 — `[HIGH]` NFR-2 contradiz `AD-17`

- **NFR-2:** *"Quando uma consulta de agenda for demorar, o agente **sinaliza** em vez de silenciar."*
- **`AD-17`:** *"O agente emite **exatamente uma** mensagem por turno."*

Sinalizar "só um instante, estou verificando a agenda" **é** uma segunda mensagem no mesmo turno. Os dois requisitos não podem ser ambos verdadeiros como escritos, e a espinha não registra a tensão — `AD-17` binda NFR-1 e ignora NFR-2, que é o requisito com que ele colide.

Não é acadêmico: o caminho quente agora inclui leitura de ocupação no Graph sobre N recursos mais escrita, exatamente o cenário que NFR-2 antecipa. Dois épicos lendo os dois documentos chegarão a comportamentos opostos.

Resolução possível (e barata): declarar em `AD-17` que a sinalização de espera, quando existir, é feita **fora do canal cobrado** (indicador de leitura/typing, se o RD suportar) ou que NFR-2 cede a NFR-1 e a mitigação é orçamento de latência, não mensagem. Qualquer das duas serve; o silêncio não.

### F9 — `[MEDIUM]` `AD-15` mitiga divergência "na conversa", o que não é enforceable

*"Divergência é mitigada na conversa: o agente confirma a preferência em uma linha a cada agendamento."* É uma boa prática de produto, mas é uma instrução de prompt oferecida como mitigação arquitetural de uma decisão de propriedade de dado. A parte forte de `AD-15` ("não existe rotina periódica", "nunca sobrescreve campo de domínio próprio") se sustenta sozinha; a frase de mitigação deveria virar `FR-5a` puro e sair da Rule, para não dar a impressão de que a divergência está resolvida estruturalmente.

---

## 3. Algo em Deferred pode deixar duas unidades divergirem?

Sim — **três dos sete itens**.

| Item deferido | Deixa divergir? | Severidade |
|---|---|---|
| Forma de entrada pelo RD (`AD-20`) | **Não** — é o item mais bem tratado do documento: invariante de substituibilidade + plano de fundo + consequência mapeada da alternativa. Modelo para os outros. | — |
| **Stack da aplicação web** | **Sim** | `[MEDIUM]` F10 |
| **Migração dos 3.119 agendamentos / 6.642 linhas de escala** | **Sim, gravemente** | `[CRITICAL]` F1 |
| **Backup e restauração** | **Sim, de forma nova** | `[MEDIUM]` F11 |
| Reoferta do horário liberado | Não — escopo adiado, sem efeito estrutural | — |
| Multimodal | Não | — |
| Retenção e exclusão de PII | Não estruturalmente, mas ver F16 (FR-5 depende) | `[LOW]` |

### F10 — `[MEDIUM]` "Stack da aplicação web" deferida, com `FR-34–FR-41` inteiramente pendurados em `AD-21`

Oito requisitos funcionais (catálogo, tom, recursos, destinatários, escala, indicadores, franquia, login) e um `AD` de identidade (`AD-23`, que já assume **App Roles do Entra ID** e permissão delegada `User.Read`) dependem de uma stack marcada `[ASSUMPTION]` com "**Decisão do Thiago, ainda não tomada**".

Dois problemas: (a) `AD-23` já **pressupõe** a decisão — App Roles e OIDC delegado não são neutros em relação à alternativa considerada ("formulário no próprio n8n"), então o Deferred e o `AD` discordam sobre o quão aberta a questão está; (b) `FR-34–FR-37` (config, Btech) e `FR-38–FR-39` (escala e indicadores, Nouvet) são naturalmente épicos separados — sem stack fixada, saem em tecnologias diferentes ou um deles vira formulário n8n enquanto o outro vira Next.js.

### F11 — `[MEDIUM]` Backup deferido tem consequência nova que a espinha não reconhece

Herdado do Piloto como pendência, mas o risco **mudou de natureza** com `AD-12`. Agora:

- `agendamento_ponteiro` é o **único elo** entre 3.119 eventos de calendário e a conversa/cliente. Perdê-lo não perde a agenda (ela está no M365) — **orfana** a agenda: nenhum lembrete, nenhuma remarcação, nenhuma confirmação encontra seu evento, e não há como reconstruir o vínculo a partir do calendário sozinho (a menos que o corpo do evento carregue telefone/pet de forma parseável — decisão que `FR-12` insinua e a espinha não formaliza).
- O calendário Microsoft em si não tem menção de proteção. Um cancelamento em massa acidental por um script de migração (F1) não tem rota de volta declarada.

O Deferred diz apenas *"herdado como pendência do Piloto"*, o que subestima a mudança. Mínimo: registrar que o corpo/extensão do evento carrega os identificadores necessários para reconstruir o ponteiro — o que transforma um backup ausente em um inconveniente em vez de uma perda.

---

## 4. A tecnologia nomeada está verificada/atual?

Verifiquei as afirmações técnicas não triviais. **A maior parte está correta e bem pesquisada** — em particular as afirmações sobre o Graph, que são precisas e raramente ditas:

| Afirmação | Verificação |
|---|---|
| `event` não tem `status` nem `completedDateTime`; `showAs` modela disponibilidade e sobrescrevê-lo corromperia a consulta de ocupação (`AD-16`) | **Correto**, e é uma observação sofisticada. |
| Categoria (`categories`) como portador do sinal de comparecimento | **Correto** — é propriedade do `event`, e alterá-la dispara `updated`. |
| Room/equipment mailbox não consome licença (`AD-13`) | **Correto**. |
| Exchange modela horário comercial como padrão semanal fixo, incompatível com escala rotativa (`AD-14`) | **Correto** — `mailboxSettings/workingHours` é um padrão semanal. `MailboxSettings.Read` está corretamente incluído no escopo de `AD-23`. |
| Assinatura do Graph expira e precisa de renovação por job (`AD-16`) | **Correto** na direção; incompleto na escala — ver F12. |
| Endpoint de webhook precisa ser HTTPS público alcançável pela Microsoft | **Correto**, e bom que esteja explícito no envelope de deployment. |

### F12 — `[MEDIUM]` `AD-23` nomeia um mecanismo que a Microsoft reclassificou como legado

`AD-23` e a linha de Stack nomeiam ***Application Access Policy*** como a forma de restringir a permissão de aplicação ao grupo de caixas de recurso. A documentação oficial hoje intitula essa página **"Application Access Policies (legacy)"** e orienta que *nova configuração de acesso não deve usar Application Access Policies*, porque o recurso terá depreciação anunciada e exigirá migração. O substituto é **RBAC for Applications** no Exchange Online (atribuição de papel de gestão com escopo de recurso, hoje só por PowerShell, limite de 10.000 apps por organização).

Não invalida `AD-23` — a **decisão** (dois registros de aplicativo, permissão de aplicação restrita por escopo, matriz papel→permissão como dado) continua certa. É o **mecanismo nomeado** que está desatualizado, e uma espinha que nomeia tecnologia assume o custo de nomear a corrente. Trocar por RBAC for Applications agora custa uma linha; descobrir na implantação custa um retrabalho de provisionamento de tenant.

Adjacente, com a mesma data do prazo do projeto: **EWS é bloqueado para apps de terceiros a partir de 01/10/2026**. Não afeta a espinha (ela é Graph de ponta a ponta, corretamente), mas vale registrar que não há caminho de fallback por EWS caso o Graph frustre algum caso de uso.

### F13 — `[MEDIUM]` `AD-16` fala de "a assinatura" no singular para ~54 caixas, e não há onde guardar o estado dela

A Rule diz: *"A assinatura **expira e é renovada por job próprio**."* Os números do próprio documento dizem 54 recursos ativos, e assinaturas do Graph para recursos Outlook são **por caixa** — não existe assinatura de tenant para eventos de calendário. Então são ~54 assinaturas, cada uma com:

- teto de expiração de **4.230 minutos** (~2,9 dias) — a renovação precisa rodar em fração disso (24–36h é a prática), não "quando der";
- um `id` e um `expirationDateTime` a persistir — e **o Structural Seed não tem tabela para isso**. Nenhuma das 11 tabelas listadas guarda estado de assinatura, o que quer dizer que o épico que construir `AD-16` vai inventar uma;
- um buraco de cobertura quando uma assinatura morre: notificações perdidas não são reenviadas. `AD-16` diz que o indicador reporta **cobertura** quando a categoria não vem — o que é a decisão certa — mas não distingue "ninguém marcou" de "a assinatura estava morta", e essas duas coisas exigem ações opostas.

Menciono também `subscriptionReauthorizationRequired` (notificação de ciclo de vida) como rede de segurança que o job por si só não cobre — decisão de build, mas a **existência** de estado de assinatura é decisão de espinha.

### F14 — `[HIGH]` A Stack **despina** n8n e Postgres, enfraquecendo `AD-10` — e contradiz o repo real

| Piloto (Stack) | Nova espinha (Stack) |
|---|---|
| `n8n 2.14.2 (pinada — confirmar contra a VPS)` | `pinado por tag completa (AD-10) — confirmar a versão corrente contra a VPS antes de fixar` |
| `PostgreSQL 16.15-alpine3.24` | `pinado por tag completa (AD-10)` |

A tabela nova **cita a política em vez de exercê-la**. `AD-10` existe precisamente para evitar que "a versão" seja uma variável resolvida em tempo de provisionamento; uma Stack que não contém literal não pinou nada. E o `docker-compose.yml` **deste repo já contém os literais** (`postgres:16.15-alpine3.24`, `n8nio/n8n:2.14.2`) — então a espinha nova está menos específica que o artefato que ela governa, o que inverte a relação.

Ver também §6: este é o caso mais claro de enfraquecimento de um `AD` herdado.

### F15 — `[MEDIUM]` Nenhum modelo ou provedor de LLM é nomeado em lugar nenhum

A Stack lista "Agente: n8n LangChain (`@n8n/n8n-nodes-langchain.agent`)" — que é o **nó**, não o modelo. Não há provedor, não há modelo, não há credencial de modelo, não há dimensão de custo por token. Isso é notável porque:

- `AD-17` é, na sua justificativa, **uma decisão de custo por turno** — e o custo por turno tem dois componentes, a mensagem da Meta e o token do modelo, dos quais a espinha orça só o primeiro;
- `AD-1` monta `systemMessage` do zero a cada turno, sem cache, sobre config que cresceu muito (catálogo com ~35 atributos por serviço, escala, matriz de preço) — o tamanho de prompt por turno é uma decisão arquitetural com consequência direta em NFR-2 e em custo, e ninguém a tomou;
- a escolha de modelo determina a confiabilidade de tool-calling, que é agora o mecanismo central do produto (era secundário no Piloto).

Uma dimensão inteira em silêncio. Ver também §7.

---

## 5. Cobertura do PRD (FR-1–FR-41, NFR-1–NFR-8)

O Capability Map cobre **por faixa** (`FR-1–FR-5a`, `FR-6–FR-9`, ...), e faixas escondem buracos: dentro de cada faixa há requisitos sem `AD` que os binde. Abaixo, item a item. "Bindado" = aparece no campo **Binds** de algum `AD`.

### FRs sem `AD` que os binde

| FR | Situação | Sev |
|---|---|---|
| **FR-4a** (coletar dado faltante só quando a tarefa precisar / ao final) | Nenhum `AD`. É uma regra de **sequenciamento** que atravessa todos os épicos de conversa — cada um decidirá quando pedir CEP, quando pedir e-mail. A convenção sobre `origem` de campo derivado chega perto mas trata proveniência, não momento de coleta. | `[MEDIUM]` |
| **FR-5** (memória entre mensagens **e entre sessões**) | Nenhum `AD`. A tabela `n8n_historico_mensagens` aparece como "plumbing herdado (`AD-5`)" — mas `AD-5` é debounce e lock, **não memória**. Ninguém define o que é uma sessão, qual o escopo de `session_id`, nem por quanto tempo a memória vive. Colide com o Deferred de retenção de PII: histórico de conversa é PII e é hoje ilimitado. No Piloto, `memoryPostgresChat` por `session_id` estava ao menos explicitado no paradigma. | `[MEDIUM]` F16 |
| **FR-11** (conjunto pequeno de opções) | Nenhum `AD`; comportamental, baixo risco de divergência estrutural. | `[LOW]` |
| **FR-14** (ciclo de vida no CRM) | Nenhum `AD`. Ver **F4** — o mais grave desta lista. | `[HIGH]` |
| **FR-15** (antecedência mínima/máxima por serviço) | Nenhum `AD` explícito. `AD-1`/`AD-18` cobrem por implicação (é atributo de catálogo), mas `AD-14` define disponibilidade como interseção de quatro conjuntos e **não inclui antecedência** — então o filtro fica sem lugar definido e pode acabar no prompt. | `[MEDIUM]` F17 |
| **FR-23a** (recorrência proativa) | Aparece como "temporizadores" no Capability Map e no diagrama; nenhum `AD`. Depende de QA-11 e de F5 (opt-in). | `[MEDIUM]` |
| **FR-24** (autorização Meta) | **Ausente do documento inteiro.** Ver **F5**. | `[HIGH]` |
| **FR-25/FR-26** (transporte) | Mapeados para `AD-19` ("registra, não agenda"), mas a Rule de `AD-19` fala **exclusivamente** de onda como dado e não menciona transporte. É um bind falso: o mapa alega cobertura que o `AD` não dá. O invariante real ("registrar solicitação vinculada sem prometer horário") não está escrito em lugar nenhum. | `[MEDIUM]` F18 |
| **FR-28/FR-29** (transferir preservando histórico; silêncio enquanto humano conduz) | Só existem dentro da cláusula **condicional** de `AD-20`: *"se (B) vencer, a máquina de estados `bot \| aguardando_humano \| humano` deixa de ser necessária"*. Ou seja: o único lugar onde o mecanismo de handoff é mencionado é uma hipótese sobre uma decisão em aberto. Como `AD-20` está OPEN, FR-28/29 estão efetivamente sem decisão. | `[MEDIUM]` F19 |
| **FR-32** (texto do cliente é dado, não instrução) | Mapeado para "Transversais → `AD-22`, `AD-1`, `AD-8`", nenhum dos quais trata injeção. Ver **F3**: com escrita no calendário, isso deixou de ser guardrail de tom e virou controle de autorização. | `[HIGH]` |
| **FR-39** (indicadores) / **FR-40** (franquia Meta) | Mapeados para `AD-21`, que diz onde os indicadores são **lidos** (Postgres) mas não onde são **produzidos**. Ver **F20**. | `[HIGH]` |

### FR-39/FR-40 — F20 `[HIGH]` Não existe registro de eventos; três requisitos não têm fonte

`FR-39` pede: agendamentos pelo agente, taxa de confirmação, comparecimento, **transferências por motivo**, **tempo de resposta**. `FR-40` pede consumo contra a franquia. `NFR-7` pede que todo agendamento, cancelamento e transferência seja **rastreável**.

As 11 tabelas do Structural Seed são todas de **estado corrente**: config, recurso, escala, serviço, preço, identidade, ponteiro, fila, status, histórico de mensagens. **Nenhuma é de fato/evento.** `agendamento_ponteiro` guarda o estado atual de um agendamento — sobrescrever esse estado ao remarcar apaga a própria remarcação que `FR-39` quer contar e que `NFR-7` quer auditar. "Transferências por motivo" e "tempo de resposta" não têm onde nascer. "Turnos proativos contabilizados" (`AD-17`) não diz **onde** se contabiliza.

Note que o Piloto **reconheceu isso** e o registrou no Deferred: *"Mecanismo/fonte de serving dos 5 indicadores mínimos — FR-36/38/39 ainda não têm fonte/mecanismo de leitura nomeado"*. A espinha nova **não** o registra — o Capability Map afirma cobertura via `AD-21`. Um problema conhecido foi promovido de "deferido" para "resolvido" sem que nada o resolvesse; essa é a regressão mais insidiosa do documento, porque é invisível.

### Cobertura de NFRs

A espinha do Piloto tinha uma **tabela dedicada "Cobertura de NFRs"**. A nova **não tem** — os NFRs só aparecem espalhados em campos `Binds`. Resultado:

| NFR | Bindado por | Situação |
|---|---|---|
| NFR-1 (uma resposta por turno) | `AD-17` | Coberto |
| NFR-2 (tempo de resposta) | **nenhum** | Sem `AD`, **e em contradição com `AD-17`** — F8 |
| NFR-3 (calendário é a verdade) | `AD-12` + convenção CRM | Coberto |
| NFR-4 (falha não vira silêncio) | convenção apenas | `[MEDIUM]` F21 — é o único NFR cuja governança é uma linha de tabela de convenções. Com três processos independentes e chamadas ao Graph sujeitas a throttling, "erro vira mensagem honesta" precisa de dono: quem trata 429/503, quantas tentativas, o que o cliente ouve, onde fica o registro. Nenhum `AD` diz. |
| NFR-5 (privilégio mínimo) | `AD-23` | Coberto |
| NFR-6 (dado não sai do ambiente; nada de PII em repo) | **nenhum** | `[MEDIUM]` F22 — e o Structural Seed introduz **dois** vetores novos: `import/` (rotinas que processam o export do SimplesVet com 4.581 pessoas) e `seed/` (config e catálogo iniciais). O Piloto dizia "credenciais nunca entram neste repo"; ninguém disse o análogo para o export. |
| NFR-7 (auditabilidade) | **nenhum** | `[HIGH]` — ver F20 |
| NFR-8 (config é dado) | `AD-1`, `AD-19` por implicação | Coberto de fato |

**Três de oito NFRs sem `AD`, um deles em contradição direta com um `AD` existente.** Restaurar a tabela de cobertura de NFRs teria exposto isso sozinho.

---

## 6. Algum `AD` novo enfraquece ou contradiz um herdado?

Testei os 12 `AD` novos contra `AD-1, 2, 3, 5, 7, 8, 10, 11`.

**Contradição direta: nenhuma.** As decisões novas são consistentes com as herdadas no mérito. Mas há **três enfraquecimentos**, um deles textual e inequívoco.

### F14 (repetido) — `[HIGH]` A Stack enfraquece `AD-10`

Já descrito em §4. É o caso mais claro: a tabela herdada **reafirma** `AD-10` ("stack pinada por tag completa, sem drift"), e a tabela de Stack do mesmo documento **remove os literais** que o Piloto tinha. A política sobrevive; a prática que ela existia para forçar, não. E o repo real já está mais pinado que a espinha.

### F23 — `[MEDIUM]` As tabelas de identidade enfraquecem `AD-3`

`AD-3` (herdado) exige: *"dentro do banco da aplicação, a tabela de identidade cliente/pet usa um papel Postgres próprio, mais restrito que o papel usado pelas tabelas de fila/lock/config"*. O repo implementa isso a sério — `n8n/migrations/0001` cria `n8n_role`, `app_role` e `identidade_role`, e a `0003` documenta que `identidade_role` **nunca** é concedida a `app_role`.

Na espinha nova:

1. A tabela do Structural Seed **perdeu a coluna "Privilégio"** que o Piloto tinha. Nenhuma das 11 linhas diz qual papel a acessa.
2. `identidade_cliente_pet` virou **duas** tabelas (`identidade_tutor`, `identidade_pet`), ambas com PII, sem dizer se ambas ficam sob `identidade_role`.
3. **`AD-21` cria um consumidor novo do banco que `AD-3` não previa.** A aplicação web "lê e escreve config, escala, catálogo e indicadores". Com qual papel? Se `app_role`, o desenho de `AD-3` se mantém — mas então os indicadores de `FR-39` (comparecimento por cliente, confirmação) não podem cruzar identidade, o que provavelmente vai empurrar alguém a conceder `identidade_role` à aplicação e colapsar a separação. **Este é o ponto em que `AD-3` vai ser silenciosamente violado durante o build**, e a espinha é o único lugar onde dá para preveni-lo.

### F24 — `[MEDIUM]` `AD-1` ("nunca cacheada") ficou mais caro sem revisão

`AD-1` foi escrito para uma config pequena (tom, dados institucionais, limiares). O produto novo acrescenta catálogo com ~35 atributos por serviço, matriz de preço por variação, escala recurso×dia, vínculo serviço↔recurso e destinatários — lidos **a cada turno, sem cache**, e montados num `systemMessage`. A montagem seletiva de `AD-1` foi desenhada por **setor**; a espinha nova não diz qual é o eixo de seletividade agora (serviço? onda? etapa da conversa?). Combinado com NFR-2 e com a ausência de modelo nomeado (F15), `AD-1` é herdado sem que ninguém verifique se sua premissa de custo ainda vale.

Não é contradição — é um herdado cujo contexto mudou e que foi carimbado "não re-decidir".

### Também aqui: F6 — `AD-6` e `AD-9` sem status `[HIGH]`

Já descrito em §1. Formalmente é um defeito de **bookkeeping** de herança, mas tem consequência material via F4.

---

## 7. Toda dimensão da altitude "initiative" está decidida, adiada ou aberta?

Esta é a seção com o resultado pior. A rubrica diz que **uma dimensão inteira em silêncio é achado**, e o envelope operacional é nomeado explicitamente.

| Dimensão | Estado |
|---|---|
| Paradigma / decomposição | **Decidida** — bem |
| Modelo de dados e propriedade | **Decidida** (`AD-12`, `AD-14`, `AD-15`) — bem |
| Integrações externas | **Decidida** (`AD-16`, `AD-20`, `AD-8`) |
| Identidade e autorização | **Decidida** (`AD-23`), mecanismo desatualizado (F12) |
| Modularidade de entrega | **Decidida** (`AD-19`) |
| Custo operacional | **Parcial** — mensagem sim (`AD-17`), token não (F15) |
| **Ambientes e promoção** | **SILÊNCIO** — F25 `[CRITICAL]` |
| **Observabilidade e operação** | **SILÊNCIO** — F26 `[HIGH]` |
| **Hospedagem da aplicação web** | **SILÊNCIO** — F27 `[MEDIUM]` |
| **Estratégia de teste / validação** | **SILÊNCIO** — F28 `[MEDIUM]` |
| Deployment (topologia) | **Decidida** — o diagrama existe e é bom até onde vai |
| Backup / DR | **Adiada** (com subestimação, F11) |
| Retenção / LGPD | **Adiada** |

### F25 — `[CRITICAL]` Não existe decisão de ambientes, e o caminho de teste escreve em caixa de recurso real

O envelope de deployment mostra **uma** VPS. A espinha do Piloto mostrava **duas** (`DevVPS`, `ProdVPS`) e discutia explicitamente a promoção entre elas. A nova não diz se há dev e produção, se são a mesma máquina, ou como um workflow vai de uma para outra. O Piloto tinha isso no Deferred ("processo exato do corte dev→produção"); a nova **não menciona o assunto em lugar nenhum** — nem decidido, nem adiado, nem aberto.

E o produto mudou de tal forma que isso deixou de ser higiene e virou risco de dano externo:

> O Piloto **não escrevia em lugar nenhum fora do nosso banco e do CRM**. O produto novo **escreve no calendário do tenant de produção do Nouvet** e **manda WhatsApp para cliente real**. Um ambiente de dev apontando para as mesmas caixas de recurso de `AD-13` cria compromissos reais em agendas que a equipe usa. Uma caixa de recurso com auto-accept ligado **responde** ao organizador; um evento de teste numa agenda real é visto pela recepção como agendamento verdadeiro.

Nada na espinha diz se existe tenant de teste, caixas de recurso de teste, um número de WhatsApp de teste, ou um modo em que as ferramentas de escrita são no-op. **Esta é a decisão de nível initiative mais importante que falta**, porque cada épico de ferramenta de escrita vai precisar da resposta e nenhum pode inventá-la sozinho com segurança.

Relacionado: `D1` do PRD ("Tenant Microsoft com Exchange Online e caixas de recurso — Btech/Rui") fala de **um** tenant. Se a resposta for "só existe um", isso precisa estar escrito como decisão consciente, com a consequência declarada.

### F26 — `[HIGH]` Observabilidade e operação: silêncio total

Nenhuma menção a log, métrica, alerta, health check, ou a quem descobre que algo quebrou. O documento inteiro não contém as palavras *monitoramento*, *alerta* (fora do contexto de emergência clínica) ou *log*.

O Piloto **tratava disso**: dizia explicitamente que *"monitoramento de saúde do n8n/Postgres ... segue sem mecanismo definido"* e o listava no Deferred. A nova espinha regrediu de "pendência nomeada" para "assunto inexistente".

Os modos de falha novos são silenciosos por natureza, o que torna a ausência mais séria:

- assinatura do Graph expirada → comparecimento simplesmente para de chegar, e `AD-16` reporta isso como "cobertura baixa", indistinguível de "ninguém marcou a categoria" (F13);
- cron de lembrete que não rodou → ninguém reclama; o efeito aparece como cadeira vazia semanas depois, exatamente na métrica de O3 que o projeto promete melhorar;
- token do CRM expirado com escrita *fire-and-forget* → o espelho comercial drena em silêncio, por design da convenção;
- throttling do Graph no horário de pico → NFR-2 degrada sem sinal.

Um produto cuja proposta de valor é "funciona às 21h de sábado sem ninguém olhando" não pode ter zero linhas sobre como se descobre que ele parou. Mínimo aceitável para a altitude: nomear **onde** os erros dos três processos aterrissam e **quem** os vê.

### F27 — `[MEDIUM]` A aplicação web não tem lugar no envelope de deployment

No diagrama de deployment, `App["Aplicação web"] --> P` flutua **fora de qualquer subgraph** — não está na VPS, não está no M365, não está em lugar nenhum. Some com ela: onde roda, como alcança o Postgres (mesma VPS? rede pública? túnel?), quem a publica, qual o certificado. Se for Next.js hospedado fora da VPS, o Postgres precisa de exposição de rede que `AD-3` não previu — o que reabre uma decisão de segurança já tomada.

### F28 — `[MEDIUM]` Nenhuma estratégia de validação, num produto cujo comportamento é config + prompt

`AD-1` e `AD-19` tornam o comportamento do agente **editável em produção por dado**: mudar uma linha de `atendimento_config` muda o que o agente faz, sem deploy e sem revisão de código. É uma escolha excelente e é exatamente por isso que a pergunta "como se sabe que uma mudança de config não quebrou o agente?" é uma pergunta de arquitetura, não de QA.

Nada na espinha responde. Não há noção de conjunto de conversas de regressão, de ambiente onde exercitar uma config nova (ver F25 — não há ambiente), nem de revisão para mudanças de config feitas pela Btech via `FR-34–FR-37`. `AD-21` até garante que a aplicação não derruba o agente se cair — mas não impede que uma edição na aplicação o quebre, que é o modo de falha mais provável.

---

## Registro de achados

| # | Achado | Rubrica | Sev |
|---|---|---|---|
| F1 | Janela de migração sem invariante: agente opera recurso cuja agenda ainda está no SimplesVet → double-booking com cliente real | 1, 2, 3 | **CRITICAL** |
| F7 | `AD-12` binda FR-16 mas nenhuma Rule torna o double-booking impossível (contenção entre sessões, retry, janela oferta→commit; `calendar processing` não decidido) | 2 | **CRITICAL** |
| F25 | Ambientes não decididos nem adiados; caminho de teste escreve em caixa de recurso e WhatsApp reais | 7 | **CRITICAL** |
| F3 | Nenhum AD delimita sobre qual agendamento as ferramentas de escrita podem agir (FR-32 com consequência material) | 1, 5 | **HIGH** |
| F4 | FR-14 (ciclo de vida no CRM) sem dono entre os três processos independentes | 1, 5 | **HIGH** |
| F5 | FR-24 (opt-in Meta) e janela de 24h ausentes do documento inteiro; bloqueiam os três mecanismos de O3/O4 | 5 | **HIGH** |
| F6 | `AD-6` e `AD-9` do Piloto sem status (nem herdados, nem revogados); `AD-9` é contraditado de fato por `AD-23` | 6 | **HIGH** |
| F14 | A Stack despina n8n/Postgres, enfraquecendo `AD-10` e ficando atrás do `docker-compose.yml` real | 4, 6 | **HIGH** |
| F20 | Nenhuma tabela de evento/fato: FR-39, FR-40 e NFR-7 sem fonte; o Piloto registrava isso no Deferred e a nova espinha alega cobertura | 5 | **HIGH** |
| F26 | Observabilidade/operação em silêncio total; regressão em relação ao Piloto; modos de falha novos são silenciosos | 7 | **HIGH** |
| F8 | NFR-2 ("sinaliza em vez de silenciar") contradiz `AD-17` ("exatamente uma mensagem por turno") | 2, 5 | **HIGH** |
| F10 | Stack da aplicação web deferida com FR-34–FR-41 pendurados; `AD-23` já pressupõe a decisão | 3 | MEDIUM |
| F11 | Backup deferido subestima a consequência nova: `agendamento_ponteiro` é o único elo com 3.119 eventos | 3 | MEDIUM |
| F12 | `AD-23` nomeia Application Access Policy, hoje documentada como legada; substituto é RBAC for Applications | 4 | MEDIUM |
| F13 | `AD-16` fala de "a assinatura" no singular para ~54 caixas; teto de 4.230 min; sem tabela de estado de assinatura | 4 | MEDIUM |
| F15 | Nenhum modelo/provedor de LLM nomeado, apesar de `AD-17` ser decisão de custo por turno e `AD-1` montar prompt grande sem cache | 4, 7 | MEDIUM |
| F16 | FR-5 (memória entre sessões) sem AD: escopo de sessão e retenção indefinidos; `n8n_historico_mensagens` atribuída a `AD-5`, que trata de lock | 5 | MEDIUM |
| F17 | FR-15 (antecedência) fora da interseção de quatro conjuntos de `AD-14`; filtro sem lugar definido | 5 | MEDIUM |
| F18 | FR-25/26 mapeados para `AD-19`, cuja Rule não menciona transporte — bind falso | 5 | MEDIUM |
| F19 | FR-28/29 (handoff) existem apenas dentro da cláusula condicional de `AD-20`, que está OPEN | 5 | MEDIUM |
| F21 | NFR-4 governado só por uma linha de convenção; tratamento de erro/throttling do Graph sem dono | 5 | MEDIUM |
| F22 | NFR-6 sem AD, com dois vetores novos de PII em repo (`import/`, `seed/`) | 5 | MEDIUM |
| F23 | Estrutura de identidade enfraquece `AD-3`: coluna de privilégio removida, PII em duas tabelas, papel da aplicação indefinido | 6 | MEDIUM |
| F24 | `AD-1` herdado sem revisar sua premissa de custo, com config muito maior e eixo de seletividade indefinido | 6 | MEDIUM |
| F27 | Aplicação web fora de qualquer subgraph no envelope de deployment | 7 | MEDIUM |
| F28 | Nenhuma estratégia de validação para mudanças de config, num produto cujo comportamento é config | 7 | MEDIUM |
| F9 | `AD-15` oferece mitigação conversacional como resolução de divergência de dado | 2 | LOW |
| F13b | `AD-13` diz "1:N"; `atendimento_servico_recurso` diz "N:N" | 1 | LOW |

---

## O mínimo para liberar a descida para épicos

Na ordem em que eu resolveria:

1. **Um `AD` novo de integridade de escrita no calendário** (F7 + F1): elegibilidade do recurso por estado de migração, serialização/rejeição de conflito no commit, idempotência de retry. É o único conjunto capaz de causar dano visível ao cliente.
2. **Um `AD` novo de ambientes** (F25): tenant/caixas/número de teste, ou a declaração consciente de que não existem e o que decorre disso.
3. **Um `AD` novo de registro de eventos** (F20 + F4 + NFR-7): a tabela de fatos que sustenta indicadores, auditoria e a porta única de espelho no CRM.
4. **Consentimento e janela da Meta** (F5), ao menos como decisão de onde o dado vive e quem o checa.
5. **Escopo de autoridade das ferramentas** (F3): uma frase na seção de convenções já resolveria.
6. **Correções de bookkeeping**: status de `AD-6`/`AD-9` (F6), repinagem da Stack (F14), Application Access Policy → RBAC for Applications (F12), restaurar a tabela de cobertura de NFRs (que exporia F8, F21, F22 sozinha).

Os itens 1, 2 e 3 são os que um épico **não pode** decidir sozinho sem que dois épicos decidam diferente. O resto é higiene, mas barata.

---

### Fontes consultadas (verificação de tecnologia)

- [Application Access Policies (legacy) — Microsoft Learn](https://learn.microsoft.com/en-us/exchange/permissions-exo/application-access-policies)
- [Role Based Access Control for Applications in Exchange Online — Microsoft Learn](https://learn.microsoft.com/en-us/exchange/permissions-exo/application-rbac)
- [Microsoft Launches RBAC for Applications for Exchange Online — Practical365](https://practical365.com/rbac-for-applications/)
- [subscription resource type — Microsoft Graph v1.0](https://learn.microsoft.com/en-us/graph/api/resources/subscription?view=graph-rest-1.0)
- [Change notifications for Outlook resources in Microsoft Graph](https://learn.microsoft.com/en-us/graph/outlook-change-notifications-overview)
- [Set up notifications for changes in resource data — Microsoft Graph](https://learn.microsoft.com/en-us/graph/change-notifications-overview)
