---
name: rd-station-api
description: Reference for the RD Station Conversas and CRM REST APIs used by the Atendimento Nouvet Piloto. Use when the user says "RD Station API", "RD Station CRM", or "RD Station Conversas", or is building/reviewing an n8n node that calls RD Station.
---

# rd-station-api

Atua como referência técnica *grounded* na documentação real da RD Station para quem está construindo ou revisando fluxos n8n do Piloto de Atendimento Nouvet. O consumidor é quem está montando um nó HTTP Request contra a API da RD e precisa da URL, do esquema de auth e do formato de payload certos sem adivinhar — um erro aqui não aparece como bug óbvio, aparece três passos depois como "a IA não conseguiu marcar o horário" ou "o card não moveu de etapa".

## Resolution rules

- Bare paths e `{skill-root}` (ex.: `references/crm.md`) resolvem a partir do diretório desta skill.
- `{project-root}` → diretório raiz do projeto.
- `rd-station-api` → nome-base do diretório da skill.

## Antes de tudo: são duas APIs, dois tenants, duas credenciais

RD Station Conversas (mensageria WhatsApp) e RD Station CRM (negociações/funil) são produtos separados na conta do Nouvet, com tenants diferentes na própria RD (o Conversas aparece como "TSL VET CENTER LTDA"; CRM e Marketing aparecem como "Nouvet Centro Veterinário 24h"). Não existe contato ou ID compartilhado entre os dois automaticamente: um contato criado via API do Conversas não existe no CRM até algo criá-lo lá também, tipicamente casando pelo número de telefone. Qualquer fluxo n8n que precise dos dois lados (ex.: responder no WhatsApp **e** mover o card no funil) é sempre duas integrações distintas, com duas credenciais distintas — nunca "a API da RD Station" no singular.

## Roteamento

- Mensagens, contatos de WhatsApp, campos personalizados, funcionários, carteiras do Conversas → `references/conversas.md`
- Negociações (deals), funis/pipelines, etapas, empresas, tarefas do CRM → `references/crm.md`

## Gotchas que não saltam aos olhos lendo a doc

- **Conversas roda em infra própria**: a base URL real é `https://api.tallos.com.br`, não um domínio `rdstation.com` — a RD comprou a Tallos e a v2 do Conversas nunca foi migrada de subdomínio. Configurar o nó do n8n com a URL "óbvia" falha.
- **CRM usa OAuth2 completo com expiração curta**: token dura **2 horas**; renovar com `refresh_token` devolve um **novo** `refresh_token` que substitui o anterior. Guardar o token antigo depois de renovar quebra a próxima renovação silenciosamente.
- **Conversas usa form-urlencoded para enviar mensagem**, não JSON — o padrão de um nó HTTP Request no n8n costuma vir em JSON e falha (ou dá 422) se não for trocado.
- **`pipeline_id` de uma negociação no CRM é somente leitura na atualização** — mover uma negociação de funil para outro não é possível via `PUT /deals/{id}`; só dá para mudar a etapa (`stage_id`) dentro do mesmo funil.
- **Criar contatos em lote no Conversas é assíncrono** (`/v2/contacts/bulk` devolve um `job_id` para consultar depois) e exige plano Advanced.
- **Formato de telefone diverge entre os dois produtos**: o exemplo oficial do CRM usa E.164 limpo (`+5511999999999`); o do Conversas usa espaços e traços (`+55 11 999-888-777`). Ao casar contato pelo telefone entre os dois (ver aviso acima sobre tenants separados), normalizar antes de comparar/filtrar — não assumir que a mesma string funciona nos dois lados.
- **Webhook de mensagem recebida no Conversas não é um endpoint REST** — configura-se pelo painel (Integrações > Webhooks, em `app.tallos.com.br/app/integrations/webhooks`). O CRM, ao contrário, tem uma API REST de webhooks de verdade (`references/crm.md`).
- **Truque útil da própria doc**: qualquer página em `developers.rdstation.com/reference/...` vira markdown puro só acrescentando `.md` no fim da URL — bom para puxar uma página específica sem ruído de navegação.

## Conta Nouvet (confirmado com Thiago, 2026-08-31)

- RD Station Conversas: plano Advanced, 6.000 clientes.
- RD Station CRM: plano Pro Ativo, 5 licenças, conta "Nouvet Centro Veterinário 24h".
