# RD Station Conversas — API v2

Base URL: `https://api.tallos.com.br`. Todas as respostas são JSON (upload de arquivo é a exceção). API cobre hoje só canais de WhatsApp.

## Autenticação

Header `Authorization: Bearer <token_jwt>`. O token é estático, gerado manualmente no painel: **Apps e Integrações > API**, copiar o JWT da conta. Não há endpoint de refresh documentado — se expirar ou for revogado, é gerar outro no painel manualmente. `401` = token ausente/inválido, `403` = token válido sem permissão para o recurso.

## Contatos

| Ação | Método | Path | Notas |
|---|---|---|---|
| Criar contato | POST | `/v2/contacts` | Campo obrigatório: `cel_phone`. **Depreciado** — a doc oficial recomenda `POST /v2/contacts/whatsapp-business-by-brokers` no lugar (não usado por nenhum workflow deste projeto hoje, ver Deferred/observação abaixo). |
| Criar em lote | POST | `/v2/contacts/bulk` | Body `{"contacts": [...]}`. **Assíncrono** — devolve `{"job": {"id", "status": awaiting\|processing\|completed\|failed", ...}}`; consultar status depois. Exige plano Advanced. |
| Verificar/obter por telefone | GET | `/v2/contacts/{cel_phone}/exists` | **Corrigido nesta sessão (CAP-8/Story 12)** — a entrada anterior desta tabela apontava `GET /v2/contacts/phone/{phone}`, um path não confirmado contra a doc oficial (possível suposição de uma sessão anterior, nunca antes exercitado por nenhum workflow deste projeto). Confirmado via `developers.rdstation.com/reference/conversas-v2-get-contact-by-phone.md`: apesar do nome ("exists"), devolve o contato completo quando encontrado — é o mecanismo real para resolver `contact_id` a partir de telefone antes de `POST /v2/messages/{contact_id}/send`. Ver formato de telefone e schema da resposta abaixo. |
| Atualizar por telefone | PUT/PATCH | `/v2/contacts/phone/{phone}` | — não reconfirmado nesta sessão (fora do escopo desta story, nenhum workflow chama). |
| Obter por CPF | GET | `/v2/contacts/cpf/{cpf}` | — não reconfirmado nesta sessão. |
| Deletar múltiplos | DELETE | `/v2/contacts` | — não reconfirmado nesta sessão. |

Campos do objeto de contato (`CreateContactRequest`): `cel_phone` (obrigatório), `full_name`, `email`, `code`, `description`, `cpf`, `cnpj`, `rg`, `birth_date` (`DD/MM/YYYY`), `integration` (default `"integration-1"`), `department_name`, `wallet_name`, `workflow_title`, `workflow_stage_title`, `tags` (array), `address` (`street`, `number`, `complement`, `district`, `city`, `state`, `country`, `zip_code`), `job` (`company`, `title`, `department`, `occupation_area`, `phone`, `email`, `site`, `cnpj`).

`workflow_title` / `workflow_stage_title` são o funil **interno do próprio Conversas** — não é o funil do RD Station CRM. Só usar isso se o fluxo for para organizar o Conversas em si, não para refletir o funil de vendas do Nouvet.

### `GET /v2/contacts/{cel_phone}/exists` — contrato confirmado (CAP-8/Story 12)

Usado por `n8n/workflows/06 - Lembretes e Escalonamento SLA.json` para resolver o `contact_id` do Conversas a partir de um telefone (sessão em `n8n_status_atendimento` ou `identidade_cliente_pet.telefone`) antes de enviar lembrete/atualização automática.

- **Path param `cel_phone`**: **dígitos puros**, sem `+`, sem espaços/traços (`[CC][DDD][número]`, ex. `5511999998888`) — formato **diferente** do E.164 com `+` usado internamente pelo projeto (`telefone_normalizar`, AD-8) e diferente também do exemplo com espaços/traços que a doc de `POST /v2/contacts` usa para `cel_phone`. Sempre `String(telefone).replace(/\D/g, '')` antes de montar a URL — nunca reaproveitar a string normalizada (`+55...`) direto.
- **Query params opcionais**: `channel` (default `whatsapp`), `country_code`.
- **Resposta 200**: contato **aninhado em `data`** (não no topo, diferente do padrão de outros produtos deste projeto) — `{"data": {"_id": "...", "full_name": "...", "cel_phone": "...", ...}, "message": "Contact already exists"}`. O campo de id é **`_id`** (não `id`) — é esse valor que vira `{contact_id}` de `POST /v2/messages/{contact_id}/send`.
- **Não encontrado / erro** (`400`\|`401`\|`403`\|`404`\|`500`): schema `Error` (`{"message", "errors": [...]}`) — sem `data`. Checar a presença de `data`/`data._id` (nunca só `message`, que aparece nos dois casos, sucesso e erro) para decidir se o contato foi encontrado.

## Enviar mensagem

`POST /v2/messages/{contact_id}/send`, **`Content-Type: application/x-www-form-urlencoded`** (não JSON). Campos: `message` (obrigatório), `sent_by` (obrigatório, enum `bot`\|`operator`), `attach` (arquivo, opcional), `integration` (opcional), `operator` (opcional). Exemplo de corpo: `message=Minha mensagem&sent_by=bot&integration=integration-1`.

**Resposta de sucesso (200)**: `{"message": "..."}` — **confirmado nesta sessão** (CAP-8/Story 12) que o schema de sucesso e o schema de erro (`Error`, abaixo) compartilham o mesmo campo `message` de nível superior, sem nenhum campo específico de sucesso (sem id de mensagem, sem flag de status). **Nunca decidir sucesso/falha só pela presença de `message`** — o único sinal confiável é o status HTTP (`200` = sucesso; `4xx`/`5xx` = erro). Em n8n, isso exige ligar a opção de resposta completa (`options.response.response.fullResponse`) no node `httpRequest` para expor `statusCode` e então guardar em `statusCode >= 200 && statusCode < 300` antes de qualquer ação que dependa do envio ter de fato ocorrido (ex.: `06 - Lembretes e Escalonamento SLA.json` só renova a janela de espera do cliente depois de confirmar o envio do lembrete por este mecanismo — nunca incondicionalmente após o `httpRequest` com `onError: continueRegularOutput`, que mascararia uma falha de envio como se tivesse renovado a janela sem o cliente ter recebido nada).

Resposta de erro (`Error` schema): `{"message": "...", "errors": [{"field": "...", "message": "..."}]}`.

## Outros recursos disponíveis (não detalhados aqui — puxar a página com `.md` no fim da URL quando for usar)

- Histórico de conversas: `GET /v2/messages/history` (`conversas-v2-list-messages-history`)
- Templates de mensagem: `conversas-v2-list-templates`, `conversas-v2-send-message-template-filled`
- Campos personalizados: `conversas-v2-list-custom-fields`, `create-custom-field`, etc.
- Funcionários (para roteamento/handoff humano): `conversas-v2-list-employees`, `activate-employee`, `deactivate-employee`
- Carteiras (wallets): `conversas-v2-list-wallets`, `create-contact-to-wallet`
- Fluxos configurados no painel: `conversas-v2-list-flows`, `conversas-v2-reset-customers-flow-processes`

## Webhook de mensagem recebida

Não existe como endpoint desta API REST — configura-se no painel do Conversas em **Integrações > Webhooks** (`app.tallos.com.br/app/integrations/webhooks`). É por ali que o n8n recebe o disparo de mensagem nova do WhatsApp.
