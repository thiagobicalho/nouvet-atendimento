# Solicitação ao Rui — tenant Microsoft do Nouvet para o agente de agendamento

Tenant: **TSL VET CENTER LTDA** · domínio `nouvet.com.br` · ID `d7d996e7-833a-4815-a7d2-5f03552c3894` · Entra ID Gratuito · 423 usuários.
Objetivo: um agente (n8n) que **lê disponibilidade e cria/atualiza/cancela eventos** em calendários de profissionais do Nouvet, via Microsoft Graph, sem usuário logado (permissão de aplicativo), com acesso restrito só aos calendários necessários. Prazo do spike: começar assim que houver uma caixa de teste.

## 1. Perguntas que decidem o desenho (responder antes de qualquer criação)

| # | Pergunta | Por que importa |
|---|---|---|
| Q1 | O e-mail do Nouvet roda em **Exchange Online** (Microsoft 365)? Ou o domínio usa outro provedor de e-mail? | Calendário do Graph só existe em caixa Exchange Online. Sem Exchange, não há calendário Microsoft para usar. |
| Q2 | Os **veterinários/profissionais** têm licença Microsoft 365 com caixa de correio própria? Quantos? | Define se usamos o calendário pessoal deles ou caixas compartilhadas. |
| Q3 | Podemos criar **caixas de recurso** (*room mailbox* / *equipment mailbox*) e caixas compartilhadas? Há política contra? | **Atualizado em 15/09 após a análise do SimplesVet**: a agenda do Nouvet é por **recurso** (consultórios, salas de imagem, sala de infusão, transporte), não por profissional. Room/equipment mailbox não consome licença e tem reserva automática — é o encaixe exato. |
| Q4 | Quem tem papel de **Exchange Administrator** para rodar PowerShell (`New-ApplicationAccessPolicy`)? | É o que restringe o app a só os calendários certos. |
| Q5 | Política de credencial de app: **certificado** ou client secret? Prazo máximo de validade? | Define como o n8n autentica e a rotina de rotação. |
| Q6 | Alguém já usa **Microsoft Bookings** no tenant? Há licença Business Standard/Premium? | Alternativa a avaliar (ver §4). |
| Q7 | Fuso horário e horário comercial padrão das caixas: `America/Sao_Paulo`, clínica 24h. Ok? | Evita evento marcado em UTC por engano. |

## 2. Cenário ideal (o que pedimos para criar)

1. **App registration** no tenant, single-tenant: nome `Nouvet Atendimento IA (n8n)`. Guardar `Application (client) ID` e `Tenant ID`.
2. **Credencial**: certificado (preferido) ou client secret com validade ≥ 12 meses e data de rotação anotada. Entregar à Btech por canal seguro (não por e-mail/WhatsApp).
3. **Permissões de aplicativo (Microsoft Graph)**, com **admin consent** concedido:
   - `Calendars.ReadWrite` — ler disponibilidade, criar/atualizar/cancelar eventos.
   - `MailboxSettings.Read` — ler fuso horário/horário de trabalho das caixas de agenda.
   - (nada de `Mail.*`, nada de `User.ReadWrite.*`).
4. **Grupo de segurança habilitado para e-mail**: `agendas-ia@nouvet.com.br` — contém **somente** as caixas de agenda.
5. **Application Access Policy** (Exchange Online PowerShell), restringindo o app ao grupo:
   ```powershell
   New-ApplicationAccessPolicy -AppId <client-id> -PolicyScopeGroupId agendas-ia@nouvet.com.br -AccessRight RestrictAccess -Description "Agente IA Nouvet - so calendarios de agenda"
   Test-ApplicationAccessPolicy -Identity <qualquer-caixa-fora-do-grupo> -AppId <client-id>   # esperado: Denied
   ```
6. **Caixas de agenda** (*room/equipment mailbox*, sem licença), **uma por recurso** — a lista real saiu do SimplesVet: ~20 recursos ativos por dia, entre consultórios (`Consult.1 - Dr Jorge`, `Consult.2 - Dr Pedro`, `Consult.3 - Fisioterapia`, `Consul.4 - Especialistas`, `Consult onc-1/2`), salas (`Sala de Infusão`, `Sala de Acompanhamento Família`), imagem (`Imagem1 Usg/Rx/Tomo`, `Imagem2 Rx/Tomog`), `Laboratório`, `Anestesia`, `Cirurgia`, `Transporte` — mais as agendas nominais de ~35 pessoas. Nome padrão `Agenda - <Recurso>`, e-mail `agenda.<slug>@nouvet.com.br`, fuso `America/Sao_Paulo`. A lista final vem do levantamento do SimplesVet; **para o spike, criar hoje uma só**: `agenda.teste.ia@nouvet.com.br`, adicionada ao grupo.
7. Cada profissional recebe **permissão de leitura/edição** no calendário da própria caixa de agenda (para ver no Outlook do celular) — `Add-MailboxFolderPermission` ou compartilhamento pelo Outlook.

## 3. Segundo app (mais tarde, não bloqueia o spike)

Login da aplicação web (métricas, escalas, config) com conta Microsoft do Nouvet: app registration separado, tipo Web/SPA, permissão **delegada** `User.Read`, claims de grupos ou **App Roles** (`btech-admin`, `nouvet-diretoria`) para autorização. Entra Gratuito suporta App Roles e claims de grupo de segurança. Pedimos só quando a app existir.

## 4. Se o ideal não for possível — alternativas, na ordem

| Situação | Alternativa |
|---|---|
| Sem Exchange Online no domínio (Q1 = não) | Licenciar **N contas "agenda"** com Microsoft 365 Business Basic (menor custo) só para os calendários; ou reavaliar Google Calendar se o e-mail do Nouvet for Google. Decisão de produto, não técnica. |
| Profissionais sem caixa própria (Q2 = não) | Caixas compartilhadas (§2.6) — é o cenário ideal mesmo assim. |
| Sem Exchange Admin para a Access Policy (Q4) | Aceitar temporariamente `Calendars.ReadWrite` sem restrição de escopo, com secret sob custódia estrita e rotação curta; **não recomendado para produção** — agendar a policy antes do go-live. |
| Certificado inviável (Q5) | Client secret com validade 6 meses + lembrete de rotação no calendário da Btech. |
| Bookings disponível (Q6 = sim) | Avaliar no spike **Microsoft Bookings via Graph** (`bookingBusinesses`, staff, services, availability): já modela serviços, durações, equipe e disponibilidade com UI da Microsoft para o Nouvet editar. Limite conhecido: disponibilidade de equipe é semanal — escala rotativa 24h encaixa mal. Só vale se a escala do SimplesVet for majoritariamente semanal fixa. |

## 4b. Saber que o atendimento aconteceu — o que o Graph oferece

Precisamos saber se o cliente compareceu, para medir redução de faltas. Verificamos o que existe de nativo:

- **O `event` do Graph não tem estado de conclusão.** Não há `status` nem `completedDateTime` — isso só existia no antigo `outlookTask`, descontinuado em 2022. `showAs` modela **disponibilidade** (free/busy/tentative), não ciclo de vida; usá-lo para "concluído" corrompe a consulta de livre/ocupado.
- **Existe webhook.** O Graph tem *change notifications*: assina-se `users/{id}/events` com `changeType: created,updated,deleted` e recebe-se aviso num endpoint HTTPS público. Limites: assinatura expira e precisa de renovação; máximo de 1.000 assinaturas por caixa; permissão de aplicação (não delegada) para caixa de terceiro.
- **O caminho viável é categoria.** Quem atende marca o evento com uma categoria (`Atendido`, `Faltou`) — um clique no Outlook —, o webhook dispara em `updated` e nós lemos. É visível na interface, colorido e filtrável.
- **Alternativa para estado só nosso**: *open extensions*, para dado que o app grava e ninguém precisa ver.

**Q8** — Há alguma política contra usar **categorias de calendário** padronizadas nas caixas de recurso? Precisamos criar as categorias `Atendido` e `Faltou` em cada caixa.

**Q9** — O endpoint de webhook do n8n já é HTTPS público. Há restrição de rede ou de Conditional Access que impeça o Graph de chamá-lo?

## 5. O que a Btech devolve depois do spike (2 dias)

- Prova: autenticou com o app, listou `calendarView` da `agenda.teste.ia`, criou e cancelou um evento, `Test-ApplicationAccessPolicy` negando caixa fora do grupo, **e recebeu uma notificação de webhook ao marcar o evento com categoria**.
- Decisão registrada: caixa pessoal vs compartilhada; Bookings sim/não.
- Doc de operação para o suporte da Btech: como criar uma nova caixa de agenda e incluí-la no grupo quando entrar um profissional novo.
