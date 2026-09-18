---
name: 'Revisão de atualidade técnica — ARCHITECTURE-SPINE (Agente que Agenda)'
type: architecture-review
lens: tech-currency
target: '_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-17/ARCHITECTURE-SPINE.md'
created: '2026-09-17'
method: 'Verificação na web (docs oficiais Microsoft Learn, Meta for Developers, npm/registry) + checagem contra o repositório e a instância n8n real'
---

# Revisão de atualidade técnica — Architecture Spine (Agente que Agenda)

**Pergunta única desta revisão:** toda decisão comprometida na espinha foi *pesquisada* ou *checada contra a realidade*, ou foi *afirmada de memória*?

## Veredito

A espinha está **tecnicamente sólida no núcleo** — o modelo de calendário como sistema de registro, a leitura de que o `event` do Graph não tem estado de conclusão, e a escolha de permissão de aplicação para caixa de terceiro resistem à verificação documental. Mas **três decisões comprometidas foram afirmadas de memória e estão desatualizadas ou erradas**: *Application Access Policy* (legado, substituído por RBAC for Applications), a **franquia de 1.000 mensagens/mês da Meta** (não existe — herdada do PRD e que sustenta FR-40 e NFR-1), e o mecanismo operacional de **categoria por caixa de recurso** (`AD-16`), cuja premissa — "quem atende marca o evento com categoria" — colide com o fato de que categorias do Outlook são **por caixa**, não propagadas entre cópias do mesmo compromisso. Some-se a isso uma **lacuna de currency evitável**: a tabela de Stack diz "confirmar a versão corrente contra a VPS antes de fixar" quando o `docker-compose.yml` do próprio repositório já pina `n8nio/n8n:2.14.2` e `postgres:16.15-alpine3.24` — e o n8n 3.0, com breaking changes, está agendado para **outubro de 2026**, exatamente a janela do prazo.

---

## Achados por severidade

| # | Achado | Severidade | Onde |
| --- | --- | --- | --- |
| A1 | Franquia de 1.000 mensagens de serviço/número/mês da Meta **não existe** | **CRÍTICO** | PRD NFR-1, FR-40 → espinha via `AD-17` e Capability Map |
| A2 | *Application Access Policy* é **legado**; a Microsoft instrui a não criar novas | **ALTO** | `AD-23`, Stack, Envelope de deployment |
| A3 | `AD-16` assume propagação de categoria que **não acontece** entre caixas | **ALTO** | `AD-16` |
| A4 | Stack sem número de versão quando o repo já tem os números; n8n 3.0 (breaking) em out/2026 | **ALTO** | Stack, `AD-10` |
| A5 | Pilha de autenticação Next.js + Entra "corrente" mudou: Auth.js nunca saiu de beta e agora é mantido pelo Better Auth | **ALTO** | Stack (`[ASSUMPTION]`) |
| A6 | Entra ID Gratuito: App Roles funcionam, mas **atribuição por grupo exige P1/P2** | **MÉDIO** | `AD-23` |
| A7 | Restrições operacionais do webhook do Graph (3s, validação, throttling) ausentes | **MÉDIO** | `AD-16`, Envelope de deployment |
| A8 | `AD-14` não nomeia a API que responde "este intervalo está ocupado?" (`getSchedule`) | **MÉDIO** | `AD-14` |
| A9 | Notificação em `updated` dispara nas **nossas próprias escritas** — risco de laço | **MÉDIO** | `AD-16` + diagrama |
| — | `event` sem estado de conclusão; `showAs` = disponibilidade | **CONFIRMADO** | `AD-16` |
| — | Caixa de recurso/equipamento sem licença | **CONFIRMADO** | `AD-13` |
| — | Nomes de permissão (`Calendars.ReadWrite`, `MailboxSettings.Read`, `User.Read`) | **CONFIRMADO** | `AD-23` |
| — | Permissão **de aplicação** é obrigatória (não preferência) para caixa de terceiro | **CONFIRMADO** | `AD-23` |

---

## 1. `event` do Graph: estado de conclusão e `showAs`

**Veredito: CONFIRMADO, com uma correção de redação.**

Puxei a lista completa de propriedades do recurso `event` na v1.0. **Não existem** `status`, `completedDateTime` nem `isCompleted`. A afirmação de `AD-16` está certa.

`showAs` é declarado como *"The status to show"*, com valores `free`, `tentative`, `busy`, `oof`, `workingElsewhere`, `unknown` — ou seja, **disponibilidade**, exatamente como a espinha diz. A preocupação de `AD-16` ("sobrescrevê-lo corromperia a própria consulta de ocupação") é literalmente verdadeira: `getSchedule` deriva o `availabilityView` desses mesmos valores (`free` e `workingElsewhere` → `0`, `tentative` → `1`, `busy` → `2`, `oof` → `3`).

**Correção de redação:** o texto de `AD-16` diz *"o recurso `event` não possui `status`"*. Existe uma propriedade chamada **`responseStatus`** (tipo `responseStatus`) e uma **`isCancelled`** (Boolean). Nenhuma das duas é estado de comparecimento — `responseStatus` é a resposta ao convite (aceito/recusado/tentativo), e numa caixa de recurso ela reflete o auto-accept do Calendar Attendant, não se o pet veio. Vale trocar *"não possui `status`"* por *"não possui estado de conclusão — `responseStatus` é resposta ao convite, `isCancelled` é cancelamento"*, para que ninguém no futuro "descubra" `responseStatus` e ache que a espinha errou.

`categories` existe como `String collection`, e a doc é explícita: *"Each category corresponds to the **displayName** property of an `outlookCategory` defined for the user"* — o que nos leva direto ao achado A3.

- Fonte: [event resource type — Microsoft Graph v1.0](https://learn.microsoft.com/en-us/graph/api/resources/event?view=graph-rest-1.0)

## 2. Change notifications para eventos de calendário

**Veredito: EXISTEM e a escolha de permissão está certa — mas os números e as restrições de endpoint não estão na espinha.**

Confirmado ponto a ponto:

- **Existem.** `event` é um dos três recursos do Outlook (junto com `contact` e `message`) que suportam assinatura, com ou sem dados do recurso no payload. Caminho de recurso: `/users/{id}/events`.
- **Permissão de aplicação vs delegada — não é preferência, é obrigação.** A doc é categórica: *"Delegated permission supports subscribing to items in folders in only the signed-in user's mailbox. For example, you can't use the delegated permission `Calendars.Read` to subscribe to events in another user's mailbox."* E adiante: *"Use the corresponding application permission to subscribe to changes of items in a folder or mailbox of any user in the tenant"*, com a ressalva de que as permissões `.Shared` (`Calendars.Read.Shared` etc.) **não** funcionam para assinatura. A escolha de `AD-23` (permissão de aplicação para o agente) é portanto forçada pela plataforma — vale registrar isso na regra, porque hoje ela parece uma escolha de segurança quando é também uma restrição técnica.
- **Permissão mínima:** `Calendars.Read` (aplicação). `Calendars.ReadWrite`, que `AD-23` já pede para escrever, é superconjunto — nenhuma permissão adicional é necessária para `AD-16`.
- **Duração e renovação:** máximo de **4.230 minutos** (pouco menos de 3 dias) para assinatura **sem** dados do recurso; **1 dia** se `includeResourceData: true`. Pedidos abaixo de 45 minutos são elevados a 45. Renovação é `PATCH /subscriptions/{id}` com novo `expirationDateTime`. Existe **lifecycle notification** (`lifecycleNotificationUrl`) que avisa quando o token de acesso ou a assinatura está por expirar e quando o admin revoga a permissão — é o mecanismo correto de recuperação, e a espinha não o menciona.
- **Limite:** 1.000 assinaturas ativas por caixa, somando todas as aplicações. Sem risco aqui.

**Lacuna (A7) — o que não foi pesquisado e devia ter sido.** A espinha diz apenas: *"O endpoint de webhook do Graph precisa ser HTTPS público e alcançável a partir da Microsoft"*. A doc impõe bem mais:

- **Validação na criação:** o Graph faz `POST {notificationUrl}?validationToken=...` e exige resposta **200, `text/plain`, com o token *URL-decoded* em texto puro, em até 10 segundos**. Se falhar, a assinatura não é criada.
- **Entrega:** 2xx em **3 segundos**, senão retry com backoff por até 4 horas (timeout de 10s nos retries). A recomendação oficial é **enfileirar e devolver `202 Accepted` dentro dos 3s**.
- **Throttling que perde notificação para sempre:** endpoint é marcado "slow" quando >10% das respostas passam de 3s numa janela de 10 minutos (novas notificações atrasam 10 min); e marcado "drop" quando >15% passam de 10s — aí **notificações são descartadas de forma irrecuperável**.

Isso é material para `AD-16`: um webhook do n8n na mesma VPS que roda o agente, sob carga de conversa, precisa responder em 3 segundos consistentemente. O padrão correto (enfileirar e responder 202, processar depois) é justamente o padrão de ingresso que `AD-5` já estabelece — mas para a conversa, não para o Graph. A espinha deveria dizer que a ingestão de comparecimento **também** enfileira antes de processar.

**Escala não dimensionada.** São ~54 recursos ativos (`AD-13`). Isso é **~54 assinaturas**, cada uma renovada em cadência inferior a 3 dias. A espinha diz "a renovação é parte do sistema, não uma tarefa manual" — correto, mas o job precisa iterar caixas, tolerar falha parcial e reconciliar (assinatura morta = comparecimento silenciosamente perdido, e `AD-16` já prevê "desconhecido", então a falha é silenciosa por design). Vale um ponteiro de assinatura por recurso no Postgres.

- Fontes: [Change notifications for Outlook resources](https://learn.microsoft.com/en-us/graph/outlook-change-notifications-overview) · [Receive change notifications through webhooks](https://learn.microsoft.com/en-us/graph/change-notifications-delivery-webhooks) · [subscription resource type](https://learn.microsoft.com/en-us/graph/api/resources/subscription?view=graph-rest-1.0)

### A9 — laço de realimentação não considerado

Não é um erro factual, é uma lacuna de desenho que a pesquisa expõe. A assinatura em `updated` dispara em **qualquer** mudança de propriedade do evento — incluindo as escritas do próprio agente (remarcar, cancelar, ajustar). O diagrama mostra `Cal --> Hook --> Cfg` como se o único gatilho fosse "categoria alterada", mas o Graph não filtra por propriedade nesse caminho (o `$filter` de assinatura é documentado para `message`; não há garantia documental de filtro por `categories` em `event`). Consequência: a ingestão de comparecimento receberá ruído proporcional ao volume de escrita do agente e precisa de idempotência e de um "de quem veio esta mudança?" — o `changeKey`/`lastModifiedDateTime` ajuda, mas o desenho precisa dizer isso.

## 3. Caixa de recurso e Application Access Policy

**3a. Licença: CONFIRMADO.** A FAQ oficial diz, sem rodeios, que *"while most users in your organization need a license to use Microsoft 365, you don't need to assign a license for a room mailbox or equipment mailbox"*. `AD-13` está correto.

Duas ressalvas que valem virar nota (não invalidam nada):
- Caixa acima de 50 GB, ou sob Litigation Hold, exige **Exchange Online Plano 2**. Com ~3.119 agendamentos futuros e anos de histórico migrado, 50 GB não é um risco próximo, mas retenção/LGPD (já listado em *Deferred*) pode arrastar a caixa para Litigation Hold e, aí, para licença.
- Teams Rooms exige licença própria — irrelevante aqui, mas é a fonte da confusão mais comum sobre "caixa de sala precisa de licença".

- Fonte: [Room and equipment mailboxes FAQ](https://learn.microsoft.com/en-us/microsoft-365/admin/manage/room-equipment-mailboxes-faq?view=o365-worldwide)

**3b. Application Access Policy: ACHADO A2 — ALTO. É o mecanismo *legado*.**

A espinha nomeia *Application Access Policy* em **três lugares** (`AD-23`, tabela de Stack, envelope de deployment) como **o** mecanismo de restrição. A documentação da Microsoft hoje classifica Application Access Policies como **legado**, diz que foram **substituídas por RBAC for Applications**, e instrui explicitamente a **não usar App Access Policies para novas configurações**, porque a depreciação será anunciada e exigirá migração. O próprio `New-ApplicationAccessPolicy` abre com esse aviso.

O mecanismo correto hoje é **RBAC for Applications no Exchange Online**: `New-ServicePrincipal` para o service principal do app, `New-ManagementRoleAssignment` com um *management scope* (ou unidade administrativa) que delimita as caixas alcançáveis. Diferença conceitual relevante para `AD-23`: a App Access Policy **restringe** uma permissão já consentida no Entra; o RBAC for Applications **concede** permissão delimitada dentro do Exchange — são modelos aditivos, e confundi-los produz um app que parece restrito e não está.

Caveats verificados: RBAC for Applications é **somente PowerShell** (sem UI de portal até meados de 2026), e role groups aceitam usuários ou service principals como membros, mas não permitem aplicar management scopes a aplicações via grupo.

**Recomendação:** trocar as três menções por *"RBAC for Applications (escopo de gerenciamento restrito ao grupo das caixas de recurso)"*, mantendo a intenção de `AD-23` intacta — a regra ("o app do agente só enxerga as caixas de recurso") continua certa; só o mecanismo mudou.

Nota adjacente: a aposentadoria do EWS em **01/10/2026** não afeta esta arquitetura (tudo é Graph), mas é a mesma data do prazo do projeto e aparece em todo material de referência do tema — vale saber que não nos atinge, para não ser surpresa numa conversa com o Nouvet.

- Fontes: [Application Access Policies (legacy)](https://learn.microsoft.com/en-us/exchange/permissions-exo/application-access-policies) · [Role Based Access Control for Applications in Exchange Online](https://learn.microsoft.com/en-us/exchange/permissions-exo/application-rbac) · [New-ApplicationAccessPolicy](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/new-applicationaccesspolicy?view=exchange-ps)

## 4. Nomes de permissão

**Veredito: CONFIRMADO. Os quatro nomes existem exatamente como escritos.**

- `Calendars.ReadWrite` — existe, delegada e de aplicação.
- `Calendars.Read` — existe, delegada e de aplicação (é a mínima para assinar `event`).
- `MailboxSettings.Read` — confirmado na tabela de permissões de `GET /users/{id}/mailboxSettings`: menos privilegiada tanto em **Delegated (work or school)** quanto em **Application**, com `MailboxSettings.ReadWrite` como superior.
- `User.Read` — delegada, é a permissão padrão de sign-in; usada exatamente como `AD-23` propõe para a aplicação web.

**Adendo útil:** `mailboxSettings` entrega `workingHours` (`daysOfWeek`, `startTime`, `endTime`, `timeZone`) e `timeZone` da caixa. Isso **confirma a premissa de `AD-14`**: o Exchange modela horário de trabalho como **um padrão semanal fixo** — dias da semana + uma faixa de horas — sem nenhum conceito de "neste dia específico o recurso está aberto". A escala rotativa do Nouvet (20–22 recursos por dia útil, 17 no sábado, 9 no domingo) realmente não cabe nesse modelo. `AD-14` não é opinião; é leitura correta da API.

- Fontes: [Get user mailbox settings](https://learn.microsoft.com/en-us/graph/api/user-get-mailboxsettings?view=graph-rest-1.0) · [Change notifications for Outlook resources](https://learn.microsoft.com/en-us/graph/outlook-change-notifications-overview)

## 5. Entra ID Gratuito e App Roles — ACHADO A6 (MÉDIO)

**App Roles funcionam no tier gratuito?** Sim, com uma restrição que muda o desenho operacional de `AD-23`.

- **Definir app roles** no registro de aplicativo e receber a claim `roles` no token: não é recurso premium. Funciona no Gratuito.
- **Atribuir usuários individualmente** a um app role: funciona no Gratuito (`New-MgUserAppRoleAssignment` / portal).
- **Atribuir um *grupo* a uma aplicação empresarial ou a um app role: exige Microsoft Entra ID P1 ou P2.** A doc oficial lista, entre os pré-requisitos, *"Microsoft Entra ID P1 or P2 for group-based assignment"*, e no corpo: *"Group-based assignment requires Microsoft Entra ID P1 or P2 edition. Nested group memberships aren't currently supported."*

`AD-23` diz que a aplicação web *"autoriza por papel (`btech-admin`, `nouvet-diretoria`), com a matriz papel → permissão vivendo como dado"*. No tenant Gratuito do Nouvet isso continua válido — **desde que a atribuição seja usuário a usuário**, não por grupo. Como são poucas pessoas (Btech + diretoria), o custo operacional é baixo, mas precisa estar escrito: senão alguém vai tentar criar um grupo `nouvet-diretoria` no Entra, atribuí-lo ao app e bater num erro de licença.

**Duas correções acessórias:**

1. Atenção ao homônimo: o "grupo das caixas de recurso" de `AD-23` é um **grupo de segurança habilitado para email no Exchange**, usado como escopo da política/RBAC — isso é Exchange, não atribuição de app no Entra, e **não** exige P1. Os dois "grupos" da espinha vivem em planos diferentes e vale distingui-los no texto para não contaminar um com a restrição do outro.
2. O envelope de deployment alerta que *"restrição de rede ou Conditional Access que o bloqueie inviabiliza `AD-16`"*. **Conditional Access exige Entra ID P1.** Num tenant Gratuito esse risco específico não existe; o risco real é firewall/proxy na frente do webhook. Vale corrigir para não desenhar uma mitigação contra uma ameaça que o tenant não tem.

- Fonte: [Manage users and groups assignment to an application](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/assign-user-or-group-access-portal)

## 6. Next.js com autenticação Entra ID — ACHADO A5 (ALTO)

A espinha marca a aplicação web como `[ASSUMPTION]` e diz *"Next.js com autenticação Entra ID e App Roles. Decisão do Thiago, ainda não tomada."* Marcar como suposição foi o certo. Mas a pesquisa muda o conteúdo da decisão a ser tomada:

**Versão do Next.js.** A estável corrente é **16.3.5** (11/09/2026). O Next.js 16 é **Active LTS** (lançado em 22/10/2025, suporte de segurança até 22/10/2027); o **Next.js 15 chega ao EOL em 21/10/2026** — três semanas depois do prazo do projeto. Ou seja: se a aplicação nascer, nasce no **16**, e não há decisão a tomar aí. Vale fixar isso na Stack em vez de deixar "Next.js" sem número, pelo mesmo princípio de `AD-10`.

**A abordagem de autenticação mudou, e este é o achado.** A resposta reflexa para "Next.js + Entra ID" é `next-auth`/Auth.js v5 com o provider `microsoft-entra-id` (renomeado de `azure-ad`; callback passa a `/api/auth/callback/microsoft-entra-id`). Verificando o registro:

- **`next-auth` v5 nunca saiu de beta.** A tag `latest` no npm continua em **4.24.15**; a tag `beta` está em **5.0.0-beta.32**. Não existe `next-auth@5.0.0`.
- **O projeto mudou de mãos.** Auth.js passou a ser mantido pelo time do **Better Auth** (anúncio de set/2025; existe guia oficial de migração em `authjs.dev/getting-started/migrate-to-better-auth`, e o rodapé do site já diz "Auth.js © Better Auth Inc."). Em 2026, **o Better Auth passou a fazer parte da Vercel**. A orientação dos próprios mantenedores para quem já roda v5 é **pinar um beta específico** em vez de acompanhar `latest`; para projeto novo, a recomendação é Better Auth.

Consequência prática para a decisão do Thiago: escolher `next-auth@beta` hoje é adotar, num produto com prazo e sem equipe de manutenção do lado do cliente, uma biblioteca em beta perpétuo e em regime de caretaker. As alternativas correntes são **Better Auth** (provider Microsoft/OIDC genérico) ou **MSAL Node** direto. Nenhuma das três foi considerada na espinha — o `[ASSUMPTION]` cobre "Next.js", não cobre "com o quê se autentica".

Observação de coerência interna: o `AD-23` exige App Roles na claim `roles` do token; qualquer das três opções entrega isso, mas o caminho é diferente em cada uma (Auth.js/Better Auth exigem ler a claim do `id_token` no callback e propagá-la para a sessão; MSAL entrega direto). É detalhe de implementação, mas é o tipo de detalhe que decide entre "1 dia" e "1 semana" num prazo de 13 dias.

- Fontes: [Next.js support policy](https://nextjs.org/support-policy) · [Next.js blog](https://nextjs.org/blog) · [Auth.js — Microsoft Entra ID provider](https://authjs.dev/getting-started/providers/microsoft-entra-id) · [next-auth no npm (versões)](https://www.npmjs.com/package/next-auth?activeTab=versions) · [Auth.js is now part of Better Auth](https://better-auth.com/blog/authjs-joins-better-auth) · [Better Auth is joining Vercel](https://better-auth.com/blog/better-auth-joins-vercel)

## 7. Stack "pinada por tag completa" sem número — ACHADO A4 (ALTO)

**Sim, é lacuna — e é a mais evitável de todas, porque a resposta está no próprio repositório.**

A tabela de Stack diz:

> n8n (self-hosted) | pinado por tag completa (`AD-10`) — **confirmar a versão corrente contra a VPS antes de fixar**
> PostgreSQL | pinado por tag completa (`AD-10`)

Checando a realidade (`/home/thiago/projetos/nouvet/atendimento/docker-compose.yml`), os números já existem e já estão pinados:

- `image: n8nio/n8n:2.14.2`
- `image: postgres:16.15-alpine3.24`

Ou seja: `AD-10` foi **cumprido no código** e **não foi lido pela espinha**. Uma espinha que existe para ser substrato de construção não deveria delegar ao futuro uma checagem de 30 segundos. Três consequências concretas da verificação:

1. **n8n 2.14.2 está bem atrás.** A linha corrente em set/2026 é **2.39.x** (2.39.2 em 10/09/2026). Há uma linha de manutenção 1.123.x ainda ativa, o que confirma que 2.x é a principal.
2. **n8n 3.0 está agendado para outubro de 2026, com breaking changes** anunciadas em segurança, simplificação de configuração e remoção de recursos legados — exatamente a janela de entrega do produto (prazo 01/10/2026). Isso **é uma decisão a tomar agora**, não um detalhe: ou o projeto congela em 2.x e declara a política de upgrade, ou avalia 3.0 antes de construir em cima de algo que muda embaixo. A espinha silencia.
3. **Postgres 16.15 está correto e atual.** É o minor corrente da linha 16 (lançado em 13/08/2026, corrige entre outras coisas o CVE-2026-19385 no `pg_dump`); o próximo minor sai em 12/11/2026. Nada a fazer além de registrar o número.

**Checagem positiva contra a instância real:** consultei a instância n8n do ambiente e o nó `nodes-langchain.agent` existe, com **typeVersion corrente 3.1**. O paradigma de `AD-1`/`AD-17` (agente único LangChain com `systemMessage` montado da config) continua suportado pelo produto — isso não é suposição, foi verificado. Vale a espinha registrar a `typeVersion` alvo junto com a tag do n8n, pelo mesmo motivo que registra a tag.

- Fontes: [n8n release notes](https://docs.n8n.io/release-notes) · [n8n v3.0 breaking changes](https://docs.n8n.io/changelog/v30-breaking-changes) · [PostgreSQL 16.15 released](https://www.postgresql.org/about/news/postgresql-186-1711-1615-1519-1424-and-19-beta-3-released-3365/) · `docker-compose.yml` do repositório · instância n8n (`nodes-langchain.agent`, v3.1)

## 8. Cobrança da Meta a partir de 01/10/2026 — ACHADO A1 (CRÍTICO)

**A data e o fato da cobrança estão certos. A franquia de 1.000 não existe.**

Verificado na documentação oficial da Meta (*Upcoming pricing updates for Meta Business Agent, service and utility messages*):

**O que está correto na espinha (`AD-17`):**
- *"Effective October 1, 2026, Meta will charge service messages"* — mensagens não-template enviadas dentro da janela de 24h de atendimento, que eram gratuitas desde novembro/2024, passam a ser **cobradas por mensagem**. A premissa de `AD-17` ("a partir de 01/10/2026 multiplica o custo por turno") está certa, e a regra "exatamente uma mensagem por turno" é a resposta arquitetural correta.
- Adicional que a espinha **não** captou: **templates de utilidade** dentro da janela de 24h, gratuitos desde julho/2025, **também passam a ser cobrados em 01/10/2026**. Isso atinge lembretes e confirmações (`FR-21`–`FR-24`) mesmo quando enviados como template — ou seja, a supressão de lembrete de `AD-17` fica ainda mais valiosa do que o texto sugere.

**O que está errado (herdado do PRD):**
- O documento da Meta **não contém nenhuma menção a franquia gratuita por número, por mês, nem por conversa**. A única linguagem de gratuidade é sobre **janelas de tempo** (as 72h do *free entry point* de Click-to-WhatsApp continuam gratuitas para entrega), não sobre **cota**.
- A franquia de 1.000 é resíduo do **modelo antigo baseado em conversas** (pré-2024/2025), aposentado quando a Meta migrou para cobrança **por mensagem**. Não sobreviveu.
- Confirmação adicional: *"Meta does not offer volume tiers for service messages"* — as faixas por volume continuam existindo para **utility** e **authentication**, mas **não** para service. Portanto não existe nem franquia nem desconto por volume no que o agente mais envia.
- Tarifa: a mensagem de serviço custa **a mesma tarifa por mensagem que utility/authentication no mercado**, variável por país. As tarifas vigentes em 01/10 seriam publicadas até 01/09/2026.

**Onde isso aterrissa no material:**
- `PRD NFR-1`: *"a Meta cobra por mensagem de serviço enviada, **com franquia de 1.000 por número por mês**"* — a segunda metade é falsa.
- `PRD FR-40`: *"Acompanhar o consumo de mensagens **contra a franquia mensal da Meta**"* — este FR mede contra um referencial inexistente. Precisa ser reescrito para **custo acumulado** (mensagens × tarifa do mercado) e não "quanto falta para estourar a franquia".
- Espinha: `AD-17` **binds NFR-1**, e a Capability Map liga *Operação e visibilidade (FR-38–FR-41)* a `AD-21`/`AD-16`. A regra de `AD-17` sobrevive intacta — na verdade ela fica **mais** justificada sem franquia, porque não há nenhum colchão gratuito absorvendo mensagens picadas. Mas a espinha está ancorada num NFR cuja justificativa numérica é falsa, e o indicador de FR-40 mudaria de forma (de "consumo vs. cota" para "custo acumulado no período").

**Dois fatos novos que ninguém considerou:**
1. **Meta Business Agent**: modelo de cobrança paralelo, já em vigor desde **01/08/2026**, precificado **por token** — US$ 2,00 por 1M tokens, ~20–25 mil tokens por mensagem, ≈ **4–5 centavos de dólar por mensagem**, cobrança única que cobre uso de IA + entrega. Só se aplica se a mensagem for gerada pela plataforma de agente da Meta (não é o nosso caso — nosso agente é n8n/LangChain, então caímos em *service*). Vale saber que existe, porque é a alternativa que a Meta está empurrando e pode aparecer numa conversa comercial. Regra útil: **uma cobrança por mensagem** — nunca Business Agent *e* service na mesma mensagem.
2. **Prazo operacional imediato:** a Meta orienta **adicionar método de pagamento à WABA até 30/09/2026** para não interromper mensagens de serviço. Isso é daqui a 13 dias e é responsabilidade do Nouvet/RD, não nossa — mas se ninguém avisar, o agente para no dia 1.

- Fontes: [Upcoming pricing updates for Meta Business Agent, service and utility messages](https://developers.facebook.com/documentation/business-messaging/whatsapp/pricing/non-template-messages) · [Pricing on the WhatsApp Business Platform](https://developers.facebook.com/documentation/business-messaging/whatsapp/pricing)

## 9. `AD-16` e a categoria por caixa — ACHADO A3 (ALTO)

Este é o achado que a lista de perguntas não previa, e é o mais caro de descobrir tarde.

`AD-16` diz: *"quem atende marca o evento com **categoria** (`Atendido`, `Faltou`); uma change notification do Graph em `updated` traz o sinal."* O mecanismo do Graph existe e funciona. O que não foi pesquisado é **onde a pessoa marca**.

Fatos verificados:

- **Categorias são por caixa de correio.** A *Master Category List* vive numa mensagem oculta na pasta Calendar **de cada caixa**. A cópia do compromisso na caixa de recurso, a cópia no calendário do organizador e a cópia de cada participante são **itens distintos em caixas distintas**.
- **Categoria não propaga entre as cópias.** Há um caso no Q&A da Microsoft praticamente idêntico ao nosso: alguém usando um **calendário de equipment** como calendário mestre justamente porque equipment auto-aceita, definindo `categories` e `showAs` ao criar o evento — e essas propriedades **não** acompanharam as cópias dos participantes.
- **Delegado não gerencia categorias alheias.** Há artigo de suporte específico: *"You cannot change a user's categories when you work as a delegate in Outlook."* Com permissão de *Reviewer* numa pasta compartilhada, só é possível aplicar/remover categorias **já existentes na lista**; criar categoria nova na pasta exige *Owner*; e renomear, só o dono da caixa.

**O que isso significa para `AD-16`, concretamente:**

1. A assinatura está na **caixa de recurso**. Logo, a categoria precisa ser aplicada **ao item que está dentro da caixa de recurso** — não ao item que está na agenda pessoal de quem atendeu. Se a recepcionista abrir o *seu* Outlook e categorizar a *sua* cópia, **nada acontece**: nenhuma notificação, comparecimento eterno "desconhecido", e o indicador de cobertura de `AD-16` cai sem que ninguém entenda por quê.
2. Para marcar na caixa de recurso, a pessoa precisa **abrir o calendário da caixa de recurso** (acesso Full Access / calendário adicionado no Outlook) — e as categorias `Atendido` e `Faltou` precisam **existir na Master Category List daquela caixa**. Com ~54 caixas, isso é **provisionamento**: criar as categorias em cada caixa (via Graph `outlookCategory` ou PowerShell), como parte do mesmo passo que cria a caixa. `AD-13` diz "um recurso novo entra criando caixa e linha de config" — falta "e as categorias de desfecho".
3. Nuance técnica que ajuda: pela API, `categories` é uma `String collection` e o Graph aceita escrever nomes arbitrários, mesmo sem `outlookCategory` correspondente — o nome persiste, só a **cor** se perde. Isso torna viável um caminho alternativo, e provavelmente melhor: **não depender do Outlook**. Marcar desfecho por um caminho que já é nosso (um comando no WhatsApp da equipe, um botão na aplicação de `AD-21`, um link por evento) e que escreve via Graph. Mas atenção: isso **colide frontalmente com `AD-21`** (*"a aplicação não escreve no calendário; o único componente que escreve no calendário é o n8n"*) — então o caminho teria de passar pelo n8n, o que é perfeitamente compatível, mas precisa estar desenhado.

**Recomendação:** não revogar `AD-16` — a leitura sobre o `event` não ter estado de conclusão continua correta e é o cerne da decisão. Mas `AD-16` precisa **nomear a caixa onde a categoria é aplicada** e **incluir o provisionamento das categorias por caixa**, ou escolher explicitamente o caminho alternativo de marcação. Do jeito que está, a regra descreve um gesto humano (*"quem atende marca o evento"*) que, na ferramenta real, exige um treinamento e um acesso que ninguém dimensionou — num cliente que, segundo o próprio pivô, **não tem equipe para continuidade humana**.

- Fontes: [Why are Categories and showAs not propagated to Attendee's calendars?](https://learn.microsoft.com/en-us/answers/questions/1286312/why-are-categories-and-showas-not-propagated-to-at) · [You cannot change a user's categories when you work as a delegate in Outlook](https://support.microsoft.com/en-us/topic/you-cannot-change-a-user-s-categories-when-you-work-as-a-delegate-in-outlook-d84fb858-e896-e173-845f-a1902bd8bc72) · [Outlook Categories and Color Categories — Slipstick](https://www.slipstick.com/outlook/outlook-categories-and-color-categories/) · [event resource type (`categories`)](https://learn.microsoft.com/en-us/graph/api/resources/event?view=graph-rest-1.0)

## 10. `AD-14` não nomeia a API de ocupação — ACHADO A8 (MÉDIO)

`AD-14` diz: *"O calendário responde apenas 'este intervalo está ocupado?'"* e exige que o cálculo de disponibilidade tenha **um dono único**. A regra é boa; falta dizer com o quê o calendário responde — e a escolha não é neutra.

Existe uma API feita exatamente para essa pergunta: **`POST /users/{id}/calendar/getSchedule`**. Verificado:

- Faz *free/busy* **"for a collection of users, distribution lists, or resources (rooms or equipment)"** — caixas de recurso são caso de uso de primeira classe.
- Aceita uma **coleção de endereços SMTP numa única chamada** — relevante quando `AD-13` liga um serviço a N recursos e é preciso varrer todos.
- Permissão mínima: **`Calendars.ReadBasic`** (aplicação), bem abaixo do `Calendars.ReadWrite` que já teremos.
- Retorna `availabilityView` (um caractere por slot de `availabilityViewInterval`, mínimo 5 min, máximo 1440) **e** os `workingHours` da caixa.
- `Prefer: outlook.timezone` controla o fuso da resposta — casa com a convenção `America/Sao_Paulo` da espinha e evita o "UTC implícito" que a própria espinha proíbe.
- Limite: erro `5006` se um slot contiver mais de 1.000 entradas de calendário. Irrelevante no nosso volume.

**O trade-off que precisa ser decidido em um lugar só:** `getSchedule` é mais barato e mais direto para "está ocupado?", mas **não devolve `id` do evento nem `categories`** — devolve status, e `subject`/`location` apenas quando o item não é privado. Já `calendarView` devolve os eventos completos (incluindo `categories` e `id`, que `AD-12` usa como ponteiro). A tendência natural é: **`getSchedule` para oferecer horário** e **`calendarView`/`GET event` para confirmar e para reconciliar ponteiro**. Isso é coerente com `AD-14`, desde que a regra "o cálculo existe em um único lugar" seja lida como "um único sub-workflow", e não como "uma única chamada de API". Vale explicitar, senão duas implementações nascem — que é exatamente o que `AD-14` existe para prevenir.

**Lacuna correlata, não pesquisada:** escrever o evento **diretamente** na caixa de recurso via Graph não passa pelo Calendar Attendant da sala (que é quem aplica `AutomateProcessing`, `AllowConflicts`, `BookingWindowInDays` etc.). A consequência é que **a proteção contra double-booking passa a ser inteiramente nossa** — não há rede de segurança do Exchange sob o sub-workflow de agendamento. Não encontrei documentação conclusiva sobre esse comportamento em todos os cenários; registro como **pergunta aberta a validar em teste no tenant**, não como fato. Mas é uma pergunta que precisa de resposta antes de `AD-14` virar código, porque toda a integridade da agenda depende dela.

- Fonte: [calendar: getSchedule](https://learn.microsoft.com/en-us/graph/api/calendar-getschedule?view=graph-rest-1.0)

---

## Resumo: pesquisado vs. afirmado de memória

| Decisão | Status |
| --- | --- |
| `event` sem estado de conclusão; `showAs` = disponibilidade (`AD-16`) | **Pesquisado e correto** (ajuste de redação sobre `responseStatus`) |
| Change notifications existem para `event` (`AD-16`) | **Pesquisado e correto**; faltam limites (4.230 min / 1 dia, 3s, validação 10s, throttling) |
| Permissão de aplicação para caixa de terceiro (`AD-23`) | **Pesquisado e correto** — e é obrigação da plataforma, não preferência |
| Caixa de recurso sem licença (`AD-13`) | **Pesquisado e correto** |
| Nomes das permissões (`AD-23`) | **Pesquisado e correto** |
| Exchange modela horário semanal fixo (`AD-14`) | **Pesquisado e correto** (`mailboxSettings.workingHours`) |
| Application Access Policy como mecanismo (`AD-23`, Stack) | **Afirmado de memória — desatualizado** (legado; usar RBAC for Applications) |
| Franquia de 1.000 mensagens/mês (PRD NFR-1, FR-40) | **Afirmado de memória — falso** (não existe; modelo antigo por conversa) |
| "Quem atende marca o evento com categoria" (`AD-16`) | **Afirmado de memória — operacionalmente inviável como escrito** (categoria é por caixa) |
| App Roles no Entra Gratuito (`AD-23`) | **Parcialmente correto** — funciona por usuário; por grupo exige P1 |
| Versões de n8n e Postgres (Stack) | **Não checado contra a realidade** — o repo já tem os números; n8n 3.0 (breaking) em out/2026 |
| Next.js + Entra (Stack, `[ASSUMPTION]`) | **Não pesquisado** — Next 16.3.5; Auth.js nunca estabilizou e migrou para Better Auth |
| API de ocupação (`AD-14`) | **Não nomeada** — `getSchedule` existe e é a resposta |
| Double-booking sem Calendar Attendant (`AD-14`) | **Pergunta aberta** — validar em teste no tenant |

## Ações sugeridas, em ordem de urgência

1. **Corrigir PRD NFR-1 e FR-40**: remover a franquia de 1.000; reescrever FR-40 como **custo acumulado**. Avisar o Nouvet/RD sobre o método de pagamento até **30/09/2026**. Incluir em `AD-17` que **templates de utilidade** na janela de 24h também passam a ser cobrados em 01/10/2026.
2. **Trocar Application Access Policy por RBAC for Applications** nas três menções (`AD-23`, Stack, envelope de deployment). A intenção de `AD-23` não muda.
3. **Reescrever a regra operacional de `AD-16`**: nomear a caixa onde a categoria é aplicada, incluir o provisionamento das categorias por caixa em `AD-13`, ou escolher explicitamente o caminho alternativo de marcação (via n8n, preservando `AD-21`).
4. **Fixar os números da Stack** a partir do `docker-compose.yml` (`n8n 2.14.2`, `postgres 16.15-alpine3.24`, `nodes-langchain.agent` v3.1) e **decidir a postura frente ao n8n 3.0** (out/2026, breaking).
5. **Decidir a biblioteca de autenticação** da aplicação web com o dado correto: Auth.js v5 nunca estabilizou; alternativas correntes são Better Auth ou MSAL Node. Fixar Next.js 16.
6. **Acrescentar a `AD-16`** as restrições reais do webhook: enfileirar e responder 202 em 3s, eco do `validationToken` em texto puro em 10s, `lifecycleNotificationUrl`, renovação < 3 dias por caixa (~54 assinaturas), e idempotência contra as notificações geradas pelas nossas próprias escritas.
7. **Nomear `getSchedule`** em `AD-14` e registrar o limite entre `getSchedule` (oferecer) e `calendarView` (confirmar/reconciliar). **Validar em teste** se a escrita direta na caixa de recurso dispensa o Calendar Attendant e, portanto, toda a proteção contra double-booking.
8. **Anotar em `AD-23`**: no tenant Gratuito, atribuição de app role é **por usuário**; e corrigir a nota de Conditional Access no envelope de deployment (CA exige P1 — o risco real é firewall/proxy).
