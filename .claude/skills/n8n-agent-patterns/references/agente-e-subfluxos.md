# Estrutura do agente e sub-fluxos de agenda

Fonte: `secretariav3-completo/01 - Secretária V3.json` (fluxo principal) e os workflows numerados que ele chama como ferramentas. Ver `config-postgres.md` para onde os dados usados aqui vivem.

## Entrada: debounce + lock antes de chegar no agente

Mensagem recebida não vai direto pro agente. O fluxo:

1. **Webhook** recebe a mensagem (do Chatwoot) e insere na fila (`Enfileirar mensagem` → tabela `n8n_fila_mensagens`, por telefone).
2. Trava a sessão em `n8n_status_atendimento` (`lock_conversa = true`) para essa conversa.
3. Espera alguns segundos (`Wait`).
4. Busca de novo a fila daquele telefone (`Buscar mensagens`) — se chegaram mais mensagens durante a espera, essa execução para (só a execução disparada pela *última* mensagem segue adiante), evitando que o agente responda fragmento por fragmento de uma mensagem picada.
5. A execução que segue agrega todas as mensagens da fila (ordenadas por `timestamp`), manda pro agente como um bloco só, depois limpa a fila (`Limpar fila de mensagens`) e destrava a sessão.

Isso resolve dois problemas ao mesmo tempo: cliente que manda 3 mensagens seguidas não gera 3 respostas desencontradas, e duas execuções não processam a mesma conversa ao mesmo tempo.

## O agente principal

Um nó `@n8n/n8n-nodes-langchain.agent`, com:
- `lmChatOpenAi` (ou `lmChatOpenRouter`, no exemplo mais simples) como modelo.
- `memoryPostgresChat` lendo/gravando em `n8n_historico_mensagens` por `session_id` — memória de conversa persistente entre mensagens.
- `systemMessage` montado com expressões que puxam do node `Info` (ver `config-postgres.md`) — não é texto fixo.
- Um conjunto de `toolWorkflow` — cada um aponta para outro workflow do n8n, que o agente decide chamar como "ferramenta" durante o raciocínio.
- Um `toolThink` ("Refletir") — presente em praticamente todo agente do pacote (principal, interno, lembretes, ligações, leads, divisor de mensagens). É um espaço de raciocínio explícito antes de decidir qual ferramenta chamar, usado de forma consistente no material de referência para tool-calling multi-etapa mais confiável.

## Ações de agenda como sub-workflows (padrão tool-subworkflow)

Cada ação de agenda é um workflow **separado**, acionado via `executeWorkflowTrigger` quando o agente principal o chama como ferramenta — não é lógica inline dentro do agente:

| Sub-workflow | Faz o quê |
|---|---|
| `03 - Buscar Janelas.json` | Consulta disponibilidade de um profissional (usa `n8n-nodes-base.googleCalendar` — no Nouvet, isso vira Microsoft Graph/Calendário Compartilhado). |
| `04 - Criar Evento.json` | Cria o evento na agenda do profissional escolhido. |
| `04.1 - Atualizar Agendamento.json` | Atualiza um agendamento existente. |
| `09 - Desmarcar_Enviar Alerta.json` | Cancela um agendamento e dispara aviso. |
| `10 - Buscar_Criar Contato.json` | Resolve identificação do contato (equivalente ao FR-2 do Nouvet — identificar cliente por telefone). |
| `11 - Lembretes Agendamento.json` | Lembretes automáticos antes do horário marcado. |

Cada um recebe os dados que precisa via input do `executeWorkflowTrigger` (chamado pelo agente com os parâmetros que ele extraiu da conversa) e devolve o resultado para o agente continuar a resposta. Replicar esse padrão no Nouvet significa: um sub-workflow por ação de agenda (buscar disponibilidade, criar, atualizar, cancelar), cada um plugável independente do agente principal — troca-se o node de calendário sem mexer no agente.

`02 - Baixar_Enviar Arquivo.json` segue o mesmo padrão de sub-workflow-como-ferramenta, mas para envio de arquivo (baixa do Google Drive e manda pelo canal) — plausível pro Nouvet no fluxo de Exames (mandar PDF de orçamento ou resultado).

## Agente proativo/agendado (lembretes e follow-up)

Nem todo agente do pacote é chamado sob demanda pelo principal. `11 - Lembretes Agendamento.json` roda como um agente **independente**, com sua própria instância de `agent` + `memoryPostgresChat`, disparada por `scheduleTrigger` (cron) — ele mesmo consulta quais agendamentos estão dentro da janela de `lembretes_horas` (ver `config-postgres.md`) e compõe/envia o lembrete, sem que o agente principal precise pedir isso.

O exemplo mais simples (`clinica/08. Follow-up qualificados + no-show + lembretes + pós-venda.json`) mostra uma variação do mesmo padrão com gatilho diferente: dispara por **mudança de etapa no Kanban** do Chatwoot (`chatwootTrigger`), com um `switch` roteando pra um agente de follow-up diferente conforme a etapa ("Qualificado"/"No-show" → recuperação, "Agendado" → lembrete, "Compareceu" → pós-consulta).

Os campos de config que alimentam esse padrão (`lembretes_horas`, `follow_ups_horas`, `max_followups`) já estão documentados em `config-postgres.md` — o que faltava aqui era o mecanismo que os consome. Para o Nouvet, a escolha entre gatilho por cron ou por mudança de etapa do funil é uma decisão de arquitetura a fazer, não um detalhe.

## Multimodal: áudio e arquivo

O agente principal (`01 - Secretária V3.json`) tem um `switch` ("Tipo de mensagem") que trata texto, áudio e arquivo separadamente antes de chegar no agente:
- **Áudio de entrada**: baixa o arquivo e transcreve via `@n8n/n8n-nodes-langchain.openAi` antes de virar texto para o agente.
- **Voz de saída**: quando a preferência do contato é áudio (campo já citado em `config-postgres.md`), a resposta passa por `@elevenlabs/n8n-nodes-elevenlabs.elevenLabs` antes de enviar.
- **Arquivo**: enviar um arquivo pro contato é uma `toolWorkflow` chamável (`02 - Baixar_Enviar Arquivo.json`, ver acima) — não lógica inline.

Relevante para o Nouvet porque cliente de clínica veterinária manda áudio de queixa e foto de pet/ferida com frequência — se o Piloto vai aceitar isso ou só texto é decisão de produto, mas o mecanismo pra suportar já existe como referência.

## Escalar para humano — precedente direto do FR-41 do Nouvet

Existem **duas versões** do mesmo workflow:

- `05 - Escalar Humano.json`: lê `id_conversa_alerta` (um único ID) da config e envia o alerta para essa conversa fixa no Chatwoot.
- `05.1 - Escalar Humano Multi.json`: **`id_conversa_alerta` é um array** na config; um node `splitOut` quebra a lista e o node `Enviar alerta` dispara a mesma mensagem para cada destinatário da lista.

Essa é literalmente a arquitetura que o FR-41 do PRD do Nouvet pede (alerta a **todos os profissionais envolvidos**, configurável sem mexer no fluxo): trocar o alvo de um ID fixo para um array de IDs na tabela de config, e colocar um `splitOut` antes do envio. Não é preciso desenhar esse mecanismo do zero — é o mesmo padrão, só trocando Chatwoot pelo canal do Nouvet (RD Conversas ou o mecanismo de notificação escolhido).

## Fora do escopo do Piloto (presentes no pacote, não copiar)

`secretariav3-completo/` é um produto mais amplo que o Piloto do Nouvet precisa. Estes sub-workflows existem no pacote mas não têm equivalente no PRD do Piloto — não replicar só porque estão ali:

- `06 - Integração Asaas.json` — cobrança/pagamento.
- `12 - Gestão de Ligações.json` — ligações via Twilio/Retell (SIP).
- `13 - Recuperação de Leads.json` — réguas de reativação (explicitamente fora do Piloto no PRD, §6.2).

`07 - Quebrar_Enviar Mensagens (Evolution).json` é um caso à parte: as chamadas HTTP finais são específicas do conector Evolution API (o Nouvet envia mensagem via RD Conversas, ver skill `rd-station-api`, não Evolution) — mas o núcleo do arquivo (um agente que divide uma resposta longa em várias mensagens curtas, enviadas com pausa e indicador de "digitando", simulando ritmo humano) é independente do conector. **Não confirmado** se RD Conversas suporta indicador de digitação ou envio pausado — checar a skill `rd-station-api` antes de decidir se vale reaproveitar esse padrão.

## Assistente Interno — não é Piloto, mas entra no projeto depois

`08 - Assistente Interno.json` é um segundo agente, separado do que atende o cliente, voltado à própria equipe: mesmo webhook/config/memória/`toolThink` do agente principal, mas com ferramentas diferentes (Gmail, Google Tasks, Google Calendar, extrato/saldo/estatísticas de cobrança no Asaas, e chama `09 - Desmarcar_Enviar Alerta` como ferramenta). Thiago confirmou que isso não faz parte da Fase 1/Piloto, mas vai entrar no projeto numa fase seguinte — bate com o "Agente Interno para Gestores" já citado na visão de longo prazo do PRD (addendum: "agrega indicadores de todos os serviços e responde perguntas de liderança sob demanda com relatórios automáticos"). Por isso fica documentado aqui como padrão pesquisável, não como "não copiar" — é o mesmo esqueleto de agente do Nouvet, só com outro público e outro conjunto de ferramentas.
