# Glossário — Atendimento Nouvet

Termos usados de forma verbatim no SPEC e em qualquer artefato derivado — nenhum sinônimo deve ser introduzido a partir daqui.

- **Lead** — contato feito por um cliente (novo ou existente) via WhatsApp/RD Conversas cuja demanda ainda não foi resolvida ou encaminhada.
- **Card** — registro único no RD Station CRM que concentra todo o histórico de atendimento de um cliente/tutor; funciona como memória operacional (CAP-7).
- **Pipeline** — funil único do CRM que concentra todos os setores e origens de lead (base existente, WhatsApp, campanhas).
- **Recepcionista IA** — papel de primeiro contato: identificação do cliente/pet, descoberta de intenção e direcionamento ao Agente de Setor correspondente. Tecnicamente, é o mesmo nó de agente que o Agente de Setor (ver ARCHITECTURE-SPINE.md, Design Paradigm) — a distinção é de papel/fase da conversa, não de implementação.
- **Agente de Setor** — papel assumido após o direcionamento da Recepcionista IA, responsável por coletar os dados daquele fluxo (Care Center, Consultas, Vacinas, Exames).
- **Handoff** — transferência de atendimento entre papéis de IA, ou entre IA e humano, sempre acompanhada do contexto já coletado — nunca apenas do contato em si.
- **Continuidade Humana** — estado do atendimento em que um humano assume a conversa, porque a IA concluiu sua parte do fluxo ou identificou necessidade de intervenção humana.
- **Piloto** (ou "Piloto de Recepção") — o recorte de ~10 dias que este SPEC descreve. Distinto da "Fase 1" da proposta comercial da Btech.Cloud, que se refere ao Diagnóstico de 5 dias.
- **Setor** — área de atendimento do Nouvet: Care Center, Exames, Consultas, Vacinas, Orçamentos, Internação, Oncologia, Financeiro.
- **Sinal de Alerta** — sintoma ou situação clínica relatada pelo cliente que exige handoff humano imediato e prioritário (ex.: vômito por 3 dias seguidos). Distinto de **Emergência Declarada** (CAP-12): o Sinal de Alerta é inferido pela IA a partir de sintomas; a Emergência é declarada explicitamente pelo próprio cliente.
- **Aguardando Cliente** — estado do card em que o sistema espera resposta do lead; vencimento da tarefa associada é de 5 minutos após a última resposta relevante do lead.
- **Aguardando Atendimento Humano** — estado do card em que o sistema espera ação de um humano do Nouvet; segue SLA e regras de escalonamento próprias (ver SPEC.md, Constraints).
- **Ciclo de Escalonamento** — intervalo de 5 minutos usado para informar progressivamente o gestor a cada rodada de atraso no atendimento humano, com urgência crescente a cada ciclo.
- **Configuração de Personalização** — conjunto de conteúdos (tom de voz, textos, limiares de SLA, regras por setor, dados de plantonistas, lista de sinais de alerta) mantido fora do fluxo de automação do n8n, editável sem alterar a lógica do fluxo (CAP-10). Ver ARCHITECTURE-SPINE.md AD-1 para o mecanismo técnico (config-as-data, lida a cada turno).
- **Fonte Confiável** — base de conhecimento autorizada do Nouvet usada pela IA para responder; a IA não responde com base em informação fora dessas fontes (CAP-9). No Piloto, resolvida tecnicamente como o mesmo dado de configuração já lido a cada turno (ver ARCHITECTURE-SPINE.md AD-1) — sem pipeline de RAG separado.
- **Calendário Compartilhado** — calendário Microsoft usado como fonte provisória de agenda, enquanto não há integração definitiva com o SimplesVet. No Piloto, nenhum setor recebe reserva automática nele — a estrutura de integração é preparada durante o Piloto (somente leitura, ver ARCHITECTURE-SPINE.md AD-9) para suportar agendamento real automático numa fase seguinte.
