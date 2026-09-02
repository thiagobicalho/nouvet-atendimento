---
name: n8n-agent-patterns
description: Reference for n8n agent architecture patterns used by the Atendimento Nouvet Piloto (config-in-Postgres, LangChain agent + tool-subworkflows, message debounce/concurrency lock). Use when the user says "n8n", "fluxo do agente", "workflow do Nouvet", or is designing/reviewing the n8n architecture for the AI attendant.
---

# n8n-agent-patterns

Atua como referência técnica *grounded* em dois projetos reais de agente de IA em n8n já construídos pela Btech/Unique, para quem está desenhando ou revisando a arquitetura do Atendimento Nouvet. O consumidor é quem está decidindo como estruturar o fluxo n8n do Nouvet — onde a configuração mora, como o agente lê ela, como a agenda é manipulada — e precisa de um padrão comprovado em vez de reinventar do zero. Um erro de arquitetura aqui não aparece na hora: aparece semanas depois como "não dá pra trocar o tom do agente sem mexer no fluxo" ou "duas conversas simultâneas bagunçaram o mesmo agendamento".

Para dúvidas genéricas de n8n (sintaxe de expression, tipos de node, troubleshooting) — não use esta skill. Use o MCP oficial de docs do n8n (`n8n-docs`, já configurado neste ambiente): ele busca direto na documentação publicada e não fica desatualizado. Esta skill cobre só o que **não** está em nenhuma doc pública — o padrão de arquitetura que a Btech já validou em produção.

## Resolution rules

- Bare paths e `{skill-root}` (ex.: `references/config-postgres.md`) resolvem a partir do diretório desta skill.
- `{project-root}` → diretório raiz do projeto.
- `n8n-agent-patterns` → nome-base do diretório da skill.

## Fonte principal, e um contraexemplo

Ambos estão em `{project-root}/_bmad-output/reference/modelo-n8n/`, como exports `.json` de workflows reais (não hipotéticos):

- **`secretariav3-completo/`** (16 arquivos) é a fonte real desta skill — versão madura, com config e agenda de profissionais vivendo em **Postgres**, lidas em tempo real a cada turno de conversa. É essa versão que resolve o requisito do PRD do Nouvet (FR-34/FR-35: personalização editável sem alterar o fluxo n8n) — ver `references/config-postgres.md` e `references/agente-e-subfluxos.md`.
- **`clinica/`** (9 arquivos) serve só como **contraexemplo**, citado uma vez nos gotchas abaixo: toda a personalização ali fica hardcoded dentro do `systemMessage` do agente (~27KB de texto fixo), o que não permite editar nada sem redeploy — exatamente o que o Nouvet não pode fazer. Não é documentado em paralelo como um segundo padrão de igual peso.

Ambos usam **Chatwoot** como canal de mensageria e **Google Calendar** como agenda — o Nouvet usa RD Conversas e o Calendário Compartilhado (Microsoft). Ao aplicar esses padrões, o que se reaproveita é a **arquitetura** (onde a config mora, como o agente é estruturado, como a agenda é manipulada), não os conectores específicos.

## Roteamento

- Onde a configuração e a memória do agente vivem, e como o agente lê isso em tempo real sem hardcode → `references/config-postgres.md`
- Como o agente principal é estruturado e como cada ação de agenda vira um sub-workflow chamável como ferramenta → `references/agente-e-subfluxos.md`

## Gotchas que não saltam aos olhos lendo os JSONs

- **O exemplo mais simples (`clinica/`) não satisfaz o FR-34/35 do Nouvet.** Se alguém copiar esse padrão sem perceber, a personalização volta a ficar presa no fluxo n8n. O padrão certo a seguir é o de `secretariav3-completo/`.
- **Config fica em uma tabela singleton** (`secretaria_config`, sempre `id = 1`) — não é uma tabela de múltiplos clientes/tenants. Se o Nouvet um dia precisar rodar mais de uma "instância" de agente (ex.: multi-clínica), esse schema precisa de uma coluna de tenant, não existe hoje nos exemplos.
- **A config é lida do banco a cada execução do agente**, via um node Postgres (`Buscar Config`) seguido de um node Set que reshapeia os campos — não é lida uma vez e cacheada. Editar uma linha no Postgres muda o comportamento do agente na próxima mensagem, sem redeploy.
- **Concorrência já tem solução pronta no schema**: a tabela `n8n_status_atendimento` tem um campo `lock_conversa` (boolean) para travar uma conversa enquanto está sendo processada, e a versão v3 acrescenta `aguardando_followup`/`numero_followup`. Isso é relevante para o risco de double-booking já levantado na revisão técnica do PRD do Nouvet (M5) — não precisa inventar esse mecanismo do zero.
- **`secretariav3-completo/` tem workflows fora do escopo do Piloto** (integração de pagamento via Asaas, gestão de ligações via Twilio, recuperação de leads) — são parte de um produto mais amplo ("Secretária V3"), não do Piloto de 10 dias. Não copiar esses sub-fluxos só porque estão no mesmo pacote.
- **O Assistente Interno (`08`) é diferente dos anteriores**: não é Piloto, mas também não é "não copiar" — Thiago confirmou que ele não entra na Fase 1, mas entrará no projeto mais adiante (bate com o "Agente Interno para Gestores" já citado na visão de longo prazo do PRD). Fica documentado como padrão pesquisável para quando essa fase chegar — ver `references/agente-e-subfluxos.md`.
- **O provisionamento de uma nova "instância" de agente é um workflow próprio** (`00 - Configurações.json`), acionado via webhook com um payload de setup (dados do negócio, IDs de sistema, credenciais) — ele cria as tabelas e insere a config e os profissionais. Não é algo que se configura manualmente linha por linha no banco.
