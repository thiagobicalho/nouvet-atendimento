# RD Station Conversas — API v2

Base URL: `https://api.tallos.com.br`. Todas as respostas são JSON (upload de arquivo é a exceção). API cobre hoje só canais de WhatsApp.

## Autenticação

Header `Authorization: Bearer <token_jwt>`. O token é estático, gerado manualmente no painel: **Apps e Integrações > API**, copiar o JWT da conta. Não há endpoint de refresh documentado — se expirar ou for revogado, é gerar outro no painel manualmente. `401` = token ausente/inválido, `403` = token válido sem permissão para o recurso.

## Contatos

| Ação | Método | Path | Notas |
|---|---|---|---|
| Criar contato | POST | `/v2/contacts` | Campo obrigatório: `cel_phone`. |
| Criar em lote | POST | `/v2/contacts/bulk` | Body `{"contacts": [...]}`. **Assíncrono** — devolve `{"job": {"id", "status": awaiting\|processing\|completed\|failed", ...}}`; consultar status depois. Exige plano Advanced. |
| Obter por telefone | GET | `/v2/contacts/phone/{phone}` | — |
| Atualizar por telefone | PUT/PATCH | `/v2/contacts/phone/{phone}` | — |
| Obter por CPF | GET | `/v2/contacts/cpf/{cpf}` | — |
| Deletar múltiplos | DELETE | `/v2/contacts` | — |

Campos do objeto de contato (`CreateContactRequest`): `cel_phone` (obrigatório), `full_name`, `email`, `code`, `description`, `cpf`, `cnpj`, `rg`, `birth_date` (`DD/MM/YYYY`), `integration` (default `"integration-1"`), `department_name`, `wallet_name`, `workflow_title`, `workflow_stage_title`, `tags` (array), `address` (`street`, `number`, `complement`, `district`, `city`, `state`, `country`, `zip_code`), `job` (`company`, `title`, `department`, `occupation_area`, `phone`, `email`, `site`, `cnpj`).

`workflow_title` / `workflow_stage_title` são o funil **interno do próprio Conversas** — não é o funil do RD Station CRM. Só usar isso se o fluxo for para organizar o Conversas em si, não para refletir o funil de vendas do Nouvet.

## Enviar mensagem

`POST /v2/messages/{contact_id}/send`, **`Content-Type: application/x-www-form-urlencoded`** (não JSON). Campos: `message` (obrigatório), `sent_by` (obrigatório, enum `bot`\|`operator`), `attach` (arquivo, opcional), `integration` (opcional), `operator` (opcional). Exemplo de corpo: `message=Minha mensagem&sent_by=bot&integration=integration-1`.

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
