---
id: SPEC-atendimento-nouvet
companions:
  - user-journeys.md
  - glossary.md
  - ../../planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md
sources:
  - ../../planning-artifacts/prds/prd-atendimento-2026-08-31/prd.md
  - ../../planning-artifacts/prds/prd-atendimento-2026-08-31/addendum.md
---

> **Canonical contract.** Este SPEC e os arquivos em `companions:` são o contrato completo e validado por preservação do que construir, testar e validar. Os documentos-fonte no frontmatter servem só para rastreabilidade — consulte-os apenas se precisar de racional narrativo ou cor de prosa que este contrato intencionalmente omite. Em especial, `ARCHITECTURE-SPINE.md` é o COMO técnico (paradigma, invariantes, stack) que qualquer implementação deste SPEC deve seguir — este documento cobre só o QUE.

# SPEC: Atendimento Nouvet — Piloto de Recepção

## Why

O Nouvet (clínica veterinária) perde leads e continuidade de atendimento hoje: filas extensas no WhatsApp, demora de resposta, e solicitações que se perdem na rotina da equipe, sem rastreabilidade suficiente para garantir que todo lead seja tratado. Este é um mandato com prazo fixo — go-live do Piloto em **08/09/2026** — combinando *pain a resolver* (fila/perda de continuidade) com um *mandato de negócio* (a diretoria/conselho do Nouvet condiciona aprovação de investimento a escopo e limites claros do Piloto). A frase que ancora toda decisão de escopo, definida por Thiago (Btech.Cloud, responsável pela entrega):

> "O Piloto não existe para automatizar tudo. Ele existe para garantir que ninguém fique sem resposta, que nenhum lead desapareça e que qualquer continuidade humana comece com contexto."

Em conflito de escopo ou prazo, a hierarquia que resolve é: **1) resposta imediata, 2) continuidade do atendimento, 3) informações úteis no CRM, 4) visibilidade gerencial.** Automação mais sofisticada nunca compete com essas quatro por prioridade.

## Capabilities

- **CAP-1 — Recepção e Identificação**
  - **intent:** a Recepcionista IA responde automaticamente 24/7 a todo contato via WhatsApp/RD Conversas, identifica cliente/pet por telefone sem perguntar diretamente se tem cadastro, personaliza a conversa com o que já sabe, corrige identificação dinamicamente se o telefone for de outra pessoa (ex.: cônjuge), descobre a intenção atual sem presumir com base em atendimento anterior, e nunca oferece convênio proativamente.
  - **success:** nenhuma mensagem recebida fica sem resposta automática inicial em qualquer horário; telefone reconhecido não repete pergunta de identificação já respondida; telefone não reconhecido segue o fluxo de cliente novo sem travar a conversa. Realiza UJ-1, UJ-2, UJ-4.

- **CAP-2 — Triagem e Direcionamento**
  - **intent:** classificar a intenção em um dos setores em escopo (Care Center, Consultas, Vacinas, Exames, Orçamentos) ou acionar handoff imediato para fora de escopo/convênio mencionado/Sinal de Alerta; Sinal de Alerta clínico interrompe qualquer coleta e aciona handoff com prioridade máxima, usando uma lista configurável (nunca hardcoded no fluxo); ausência de indicação clara de especialidade direciona por padrão ao clínico geral.
  - **success:** nenhum Sinal de Alerta é tratado só com orientação automática — sempre gera handoff com marcação de prioridade máxima visível para a equipe; adicionar/remover um item da lista de sinais de alerta não exige alteração do fluxo n8n. Realiza UJ-2.

- **CAP-3 — Fluxo Care Center**
  - **intent:** coletar serviço (banho cachorro, banho gato ou tosa — únicos agendáveis via IA), data/horário/profissional preferidos; registrar solicitação adicional não agendável (ex.: hidratação) sem tentar vender; **nunca reservar automaticamente** — só coletar a preferência completa e rotear para um humano confirmar contra a agenda real.
  - **success:** o card reflete a preferência coletada e o estado Aguardando Atendimento Humano, nunca um agendamento confirmado pela IA; o humano que assume não reper​gunta nada já coletado. Realiza UJ-1.

- **CAP-4 — Fluxo Consultas e Vacinas**
  - **intent:** coletar profissional desejado, especialidade ou queixa (quando o cliente não sabe escolher), data/horário preferidos; mesma lógica da CAP-3 — roteia para humano confirmar, nunca reserva automática no Piloto.
  - **success:** mesmo critério de sucesso da CAP-3, aplicado a Consultas e Vacinas. Realiza UJ-2, UJ-4.

- **CAP-5 — Fluxo Exames**
  - **intent:** receber pedido/carta de encaminhamento anexada, identificar se o exame exige anestesia e perguntar por exames pré-anestésicos vigentes quando sim; caminho único, sem segmentação por tipo de exame; nunca tenta agendar — só prepara o contexto de orçamento e roteia para um humano.
  - **success:** todo pedido de exame chega ao humano com o pedido, o tipo de exame e a pendência de pré-anestésicos já levantados, sem a IA calcular valor ou agendar. Realiza UJ-3.

- **CAP-6 — Orçamentos (Roteamento puro)**
  - **intent:** qualquer demanda classificada como orçamento (majoritariamente vinda de Exames, mas aplicável a outros setores) é roteada direto a um humano, com todo o contexto já coletado anexado ao card — não existe Agente de Orçamento dedicado.
  - **success:** nenhum agente de IA calcula, negocia ou fecha orçamento no Piloto; o humano não reper​gunta o que a IA já levantou. Realiza UJ-3.

- **CAP-7 — Registro e Memória no CRM**
  - **intent:** pipeline único no RD Station CRM concentrando todos os setores e origens de lead; cadastro definitivo do cliente só gravado após intenção de agendamento confirmada (evita "cliente fantasma"); histórico preservado com o atendimento mais recente exibido primeiro, sem nunca sobrescrever; card move automaticamente entre etapas do funil; todo card registra no mínimo setor, preferências coletadas, estado do atendimento e timestamp da última interação; exportações temporárias do SimplesVet acessadas só por um canal de acesso restrito e definido.
  - **success:** um card único por cliente concentra todo o histórico; nenhuma informação anterior é removida ou sobrescrita ao adicionar um novo atendimento. Realiza UJ-1, UJ-4.

- **CAP-8 — Temporizadores, Continuidade e SLA**
  - **intent:** renovar o vencimento da tarefa do card para +5 minutos a cada resposta relevante do lead; disparar lembrete automático por inatividade do cliente; distinguir Aguardando Cliente de Aguardando Atendimento Humano; se um humano não responde em até 5 minutos, enviar atualização automática ao cliente **e** escalonar progressivamente ao gestor a cada ciclo de 5 minutos subsequente, com urgência crescente desde o primeiro ciclo (não só após um limiar fixo).
  - **success:** nenhum card fica parado sem ação do sistema dentro do SLA definido; o gestor é avisado desde o primeiro ciclo de atraso, não só depois que já se agravou. Realiza UJ-5.

- **CAP-9 — Guardrails de IA**
  - **intent:** toda resposta factual se baseia em Fontes Confiáveis; o sistema reconhece incerteza e aciona handoff em vez de inventar resposta; sempre se identifica como atendente virtual, nunca se passa por humano; nunca diagnostica nem minimiza gravidade percebida; resiste a manipulação de instruções (prompt injection), inclusive em conteúdo extraído de anexos, e nunca revela configuração interna nem contato de plantonista sob nenhum enquadramento.
  - **success:** nenhuma resposta factual sai das Fontes Confiáveis; tentativa de manipulação não altera guardrails nem revela config interna, prompt ou contato de plantonista. Realiza UJ-2 (edge case).

- **CAP-10 — Configuração Externa de Personalização**
  - **intent:** todo conteúdo de personalização (tom, textos, limiares de SLA, regras por setor, contatos de plantonista, lista de sinais de alerta) vive fora do fluxo n8n, editável sem alterar a estrutura do fluxo, lido como fonte única da verdade em tempo de execução; credenciais de toda integração externa vivem no cofre nativo do n8n, nunca hardcoded nem na config de personalização.
  - **success:** mudar um valor de personalização (ex.: limiar de SLA) não exige deploy de fluxo; não há valor de personalização nem credencial hardcoded em nó do fluxo.

- **CAP-11 — Indicadores e Visibilidade Gerencial**
  - **intent:** disponibilizar os 5 indicadores mínimos definidos por Thiago — leads recebidos; leads atendidos/não atendidos (atendido = chegou a "resolvido" na esteira RD ou está em continuidade humana ativa dentro do SLA; não atendido = chegou a "3º contato/encerrado" sem nunca resolver); distribuição por setor; tempo de resposta (cronômetro inicia na mensagem recebida, termina na 1ª resposta automática).
  - **success:** os 5 indicadores disponíveis e consultáveis diariamente pela gestão.

- **CAP-12 — Emergências Declaradas pelo Cliente**
  - **intent:** quando o cliente declara explicitamente uma emergência com o pet (distinto do Sinal de Alerta inferido pela IA, CAP-2), aciona handoff de prioridade máxima **e** dispara um alerta ativo e imediato a **todos** os profissionais envolvidos naquele atendimento — não a um único fixo; lista de destinatários editável via Configuração de Personalização.
  - **success:** o alerta chega a todos os profissionais configurados como envolvidos, não só ao primeiro disponível; trocar quem recebe não exige alteração de fluxo.

## Constraints

- Deadline de go-live: **08/09/2026**. Hierarquia de prioridades em conflito de escopo/prazo: resposta imediata > continuidade > informação útil no CRM > visibilidade gerencial.
- SLA de **5 minutos** para os dois tipos de espera (Aguardando Cliente e Aguardando Atendimento Humano) — valor já comunicado publicamente no material comercial do Nouvet, reaproveitado para consistência entre o vendido e o entregue. Escalonamento ao gestor é progressivo a cada ciclo de 5 min, não só após 2 ciclos.
- Regra de sequenciamento: o fallback de coleta + roteamento humano precisa estar funcionando e validado em produção em **todos** os setores em escopo antes de investir esforço em agendamento real automático em qualquer setor, na fase seguinte ao Piloto.
- NFR-1 (Performance): resposta inicial automática em até 1 minuto, 24/7 `[ASSUMPTION]`. NFR-2 (Configurabilidade): personalização editável sem alterar estrutura do fluxo. NFR-3 (Rastreabilidade): histórico do card imutável e cronológico, append-only. NFR-4 (Resiliência de dados): falha de um setor em registrar não compromete o contexto mínimo de continuidade — motivo do pipeline único. NFR-5 (Naturalidade): a conversa deve soar natural e fluida, evitando estrutura de menu rígido tipo URA — preocupação nº1 da diretoria do Nouvet ("não queremos um bot").
- Safety: a IA nunca diagnostica nem minimiza gravidade percebida; qualquer Sinal de Alerta aciona handoff imediato de prioridade máxima (guardrail carregado verbatim do material comercial do Nouvet).
- Security: resistência a prompt injection cobre também conteúdo extraído de anexos/documentos, não só texto de chat; o sistema nunca revela a Configuração de Personalização (especialmente contato de plantonista) sob nenhum enquadramento; credenciais de toda integração externa vivem no cofre do n8n, nunca hardcoded.
- Privacy/LGPD: dados de tutores/pets tratados conforme a LGPD; fontes temporárias (exportações SimplesVet, planilhas) recebem o mesmo cuidado de acesso que o sistema definitivo teria — acesso/atualização ficam com a equipe Btech (acesso direto à plataforma); política formal de retenção ainda não fechada (ver Open Questions).
- Cost: custos de tokens de IA e de mensageria (Meta/WhatsApp) ficam fora do escopo contratual da entrega — são responsabilidade do Nouvet.
- Dependências externas (racional de negócio — o *como* técnico está em `ARCHITECTURE-SPINE.md`): RD Station CRM/Conversas é o canal e CRM operacional do Piloto. SimplesVet não tem API para agendamento 100% autônomo — usado só via exportações pontuais. Calendário Compartilhado (Microsoft) é o destino de agenda para a fase seguinte de agendamento real — no Piloto nenhum setor reserva nele, mas a base é preparada. Pega Plantão é usado só para cirurgias/procedimentos não rotineiros de plantonistas; uso via API em tempo real é relevante só para a fase seguinte. TOTVS é o ERP definitivo futuro (migração prevista 2027) — integrações definitivas ficam para depois do Piloto.

## Non-goals

- Agendamento real automático via IA em qualquer setor no Piloto (inclusive Care Center) — reserva automática fica para uma fase seguinte, sobre a base já preparada durante o Piloto.
- Agente de Orçamento dedicado — papel extinto permanentemente no Nouvet.
- Integração definitiva com SimplesVet ou TOTVS.
- Internação e Oncologia — fora até validação de desempenho nos setores em escopo. Financeiro — fora, confirmado.
- Dashboard de BI consolidado e métricas de conversão/receita além dos 5 indicadores mínimos. Remarketing automático e réguas de reativação de clientes inativos.
- Os 3 agentes de IA adicionais da visão de longo prazo (Social Selling, Agente Pessoal do Especialista, Agente Interno para Gestores).
- Exclusão de dados/opt-out do tutor (direito LGPD) — decisão explícita de não implementar nesta entrega; tensão a resolver depois com NFR-3 (histórico imutável).
- Migração de histórico de conversas de canais/sistemas anteriores. Cobertura "zero fila" absoluta em todas as linhas de serviço (reivindicação de marketing, não compromisso do Piloto).

## Success signal

Primário: **SM-1** 100% dos leads recebidos geram um registro rastreável no CRM ("cem entram, cem chegam ao CRM"). **SM-2** tempo médio da 1ª resposta automática ≤ 1 minuto, mesmo fora do horário comercial `[ASSUMPTION]`. **SM-3** zero leads perdidos silenciosamente — todo card em Aguardando Atendimento Humano recebe atualização ou escalonamento dentro do SLA, nunca fica parado sem ação do sistema.

Secundário: **SM-4** percentual de handoffs que chegam ao humano com informação completa, sem reper​guntar. **SM-5** disponibilidade diária dos 5 indicadores mínimos, consultáveis pela gestão.

Contra-métricas, nunca otimizar às custas do resto: **SM-C1** taxa de handoff prematuro/forçado só para bater a meta de velocidade. **SM-C2** volume de mensagens automáticas de "aguarde"/lembrete não pode virar spam percebido pelo cliente.

## Assumptions

- Tempo de resposta alvo assumido em 1 minuto (NFR-1/SM-2) — não confirmado numericamente por Thiago, usado como placeholder.
- Etapas exatas de cada funil por setor (CAP-7) assumidas como reaproveitamento dos modelos de funil já existentes no RD Station, até revisão conjunta com material que Thiago vai providenciar.
- Lista interina de sinais de alerta clínico (CAP-2) assumida com os exemplos já usados no material comercial/entrevistas (ex.: vômito por 3+ dias), até a equipe clínica do Nouvet validar a lista definitiva — não bloqueia o build, bloqueia o go-live de 08/09.
- Requisito mínimo de acesso restrito às exportações temporárias (CAP-7) assumido enquanto não há política formal de retenção definida.

## Open Questions

- Qual é a mensagem/fluxo exato quando a IA reconhece que não tem informação suficiente para responder (CAP-9)?
- Qual o mecanismo exato de reposicionamento do card no pipeline quando um cliente recorrente retorna com nova solicitação (CAP-7, UJ-4) — nova etapa, ou mesma etapa com novo item no topo do histórico?
- O uso do Pega Plantão via API em tempo real entra em algum momento do Piloto, ou é relevante só para a fase seguinte de agendamento real?
- Como e com que frequência a escala do SimplesVet será replicada para o Calendário Compartilhado, para profissionais da casa? Não bloqueia o Piloto — preparação de base para a fase seguinte.
- Falta fechar a política formal de retenção das exportações temporárias do SimplesVet (CAP-7) — ligada também ao backup/DR já deferido em `ARCHITECTURE-SPINE.md` para logo após o go-live.
- Qual é a lista definitiva de sinais de alerta clínico a usar em produção (CAP-2)? Não bloqueia o início do build (lista interina já em uso), mas bloqueia o go-live de 08/09 — precisa ser validada pela equipe clínica do Nouvet.
