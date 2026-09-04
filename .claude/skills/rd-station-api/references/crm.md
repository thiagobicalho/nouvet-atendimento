# RD Station CRM — API v2

Base URL: `https://api.rd.services/crm/v2`. Tenant separado do Conversas — credenciais próprias, não reaproveitar as do Conversas.

## Autenticação (OAuth2, authorization code)

Cada conjunto de credenciais (`client_id`/`client_secret`/`access_token`) dá acesso a **um produto só**. Fluxo:

1. Criar um aplicativo na RD Station App Store → gera `client_id` e `client_secret`.
2. Trocar por um `code` de uso único, que autoriza a conexão à conta específica do CRM.
3. Trocar o `code` por `access_token` + `refresh_token` (endpoint em `https://api.rd.services/oauth2/`).
4. Usar `access_token` no header `Authorization` das requisições.
5. **`access_token` expira em 2 horas (7200s).** Renovar com `refresh_token` antes de expirar; cada renovação devolve um **novo `refresh_token`** — descartar o antigo e persistir o novo, ou a próxima renovação falha.

No n8n isso normalmente vira um fluxo/credencial de refresh automático, não um token fixo salvo uma vez.

## Negociações (Deals)

| Ação | Método | Path | Notas |
|---|---|---|---|
| Listar | GET | `/deals` | Paginado (`page[number]`, `page[size]`, default 25). |
| Criar | POST | `/deals` | Body `{"data": {...Deal}}`. |
| Obter | GET | `/deals/{id}` | `id` = hex 24 chars. |
| Atualizar | PUT | `/deals/{id}` | Body `{"data": {...campos a mudar}}`. |

Campo para **mover etapa do funil**: `stage_id` (hex 24 chars) dentro do `data` do PUT. `pipeline_id` é **somente leitura** — não dá para mudar o funil de uma negociação por este endpoint, só a etapa dentro do funil atual. Outros campos editáveis do `Deal`: `name`, `recurrence_price`, `one_time_price`, `expected_close_date`, `rating`, `status` (`won`\|`lost`\|`ongoing`\|`paused`), `owner_id`, `source_id`, `campaign_id`, `lost_reason_id`, `organization_id`, `contact_ids`, `custom_fields`, `distribution_settings`.

Erros: `400`, `401`, `403`, `404`, `422`, `429`, `500` — schema `{"errors": [{"detail": "..."}]}`.

## Funis e etapas (Pipelines / Stages)

| Ação | Método | Path |
|---|---|---|
| Listar funis | GET | `/pipelines` |
| Criar funil | POST | `/pipelines` |
| Listar etapas de um funil | GET | `/pipelines/{pipeline_id}/stages` |
| Criar etapa | POST | `/pipelines/{pipeline_id}/stages` |
| Atualizar etapa | PUT | `/pipelines/{pipeline_id}/stages/{id}` |

Objeto `Stage`: `id`, `name`, `description`, `objective`, `order` (posição no funil), `created_at`, `updated_at`. Para mover uma negociação de etapa por nome (não por ID cru), primeiro listar as etapas do funil e casar pelo `name` — os IDs são hex opacos, não previsíveis.

## Contatos do CRM

Schema **diferente** dos contatos do Conversas — não é o mesmo objeto, mesmo quando é a mesma pessoa.

| Ação | Método | Path | Notas |
|---|---|---|---|
| Listar/buscar | GET | `/contacts` | Filtro via RDQL: `?filter=phone:+5511999999999` (também dá para filtrar por `email`, `name`, `whatsapp_username`, `organization_id`, campo customizado via `@slug`). Paginado. |
| Criar | POST | `/contacts` | Body `{"data": {...Contact}}`. |
| Atualizar | PUT | `/contacts/{id}` | Idem. |

Campos do `Contact`: `name`, `job_title`, `emails` (array de `{"email": "..."}`), **`phones` (array de `{"phone": "...", "type": "work"\|"fax"\|"home"\|"mobile"}`)**, `whatsapp_username`, `birthday` (`YYYY-MM-DD`), `social_profiles`, `organization_id`, `legal_bases`, `custom_fields`. Nenhum campo aparece como estritamente obrigatório no schema.

Não existe endpoint dedicado de "buscar por telefone" como no Conversas (`GET /v2/contacts/phone/{phone}`) — aqui é sempre `GET /contacts?filter=phone:<numero>`. **O formato do número pode não bater entre os dois produtos**: o exemplo oficial do CRM usa E.164 limpo (`+5511999999999`), enquanto o exemplo oficial do Conversas usa o número com espaços e traços (`+55 11 999-888-777`). Ao casar contato por telefone entre Conversas e CRM, normalizar o número (remover espaços/traços, garantir `+55`) antes de comparar ou filtrar — não assumir que o mesmo string funciona nos dois lados.

## Tarefas (Tasks)

| Ação | Método | Path | Notas |
|---|---|---|---|
| Criar | POST | `/tasks` | Body `{"data": {...Task}}`. |

Campos do `Task`: `name`, `description`, `type`, `status` (**só aceita `"open"` na criação** — não dá para criar uma Task já concluída/atrasada por este endpoint), `due_date`, `deal_id` (associa a Task a um card específico), `owner_ids` (array de responsáveis). `deal_id` é o vínculo relevante para o Piloto — a Task de cadastro pendente no SimplesVet e/ou alerta de duplicidade familiar (AD-11, CAP-7/Story 11) é criada com `deal_id` do card do cliente, `status="open"`, sem `type`/`due_date`/`owner_ids` (nenhum desses campos tem dado configurado/confirmado com o Nouvet ainda — mesmo padrão "não inventa" já usado em outras integrações deste projeto).

## Notas (Notes)

| Ação | Método | Path | Notas |
|---|---|---|---|
| Criar | POST | `/deals/{deal_id}/notes` | Body `{"data": {...Note}}`. |

Campos do `Note`: `description` (texto da nota), `user_id` (autor da nota, opcional). **Não existe endpoint de edição/atualização de nota** — toda chamada cria uma nota nova; o histórico de notas de um deal é append-only por natureza da API (nunca sobrescreve uma nota anterior). É o mecanismo usado pelo Piloto (CAP-7/Story 11) para registrar o histórico de atendimentos de um card ao longo do tempo (setor + preferências coletadas + estado + timestamp), enquanto o `stage_id` do deal reflete só o setor do atendimento corrente.

## Outros recursos disponíveis (puxar a página com `.md` no fim da URL quando for usar)

- Empresas: `crm-v2-organizations` e variantes list/create/get/update
- Webhooks — aqui **existe** API REST de verdade (ao contrário do Conversas): `crm-v2-webhooks`, `list-webhooks`, `create-webhook`, `update-webhook`, `delete-webhook`
