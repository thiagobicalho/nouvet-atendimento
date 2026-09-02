# Addendum — Atendimento Nouvet

Conteúdo que informou o PRD mas não pertence ao documento de produto: contexto operacional atual, mecanismo técnico provisório, alternativas rejeitadas e riscos de alinhamento com o material comercial. Referenciado pelo PRD onde relevante.

## Contexto operacional atual (estado atual, não requisito)

- Divisão atual de atendimento por pessoa: Ailton responde exames de imagem/laboratoriais; Larissa responde agendamento/vacina; Gabriela responde só Care Center.
- "Thay" hoje faz manualmente o acompanhamento pós-alta de internação, ligando um por um no dia seguinte à alta, usando planilha própria de datas de alta.
- Alessandra é responsável por campanhas de marketing (ex.: campanha de tomografia set/out); risco relatado de corte de verba de campanha pelo financeiro se não houver indicadores que justifiquem o investimento.
- Há uma contratação em andamento (pessoa para fazer confirmações) correndo em paralelo ao projeto de IA — Edson questionou a necessidade dela dado que a IA seria 24/7; resposta da Btech: a IA filtra volume, mas ainda sobra demanda que precisa de humano.
- RD Station já possui esteiras pré-configuradas (consultas, tomografia, cirurgias) de um fluxo comercial anterior, hoje paradas por falta de pessoa para alimentar. Fluxo antigo de estágios: "1º contato realizado, tutor não respondeu" → "2º contato" → "3º contato ou encerrado não resolvido" → "resolvido".
- Outros interlocutores Nouvet citados na descoberta: Thiago Teixeira, Wilson (discussão de convênios/repasse Pet Love), Simone Sansi (Btech.Cloud, relação comercial/apresentações).

## Alternativa rejeitada — Agente de Orçamento

O briefing de descoberta (sessão mais recente) tratava a arquitetura do Agente de Orçamento como questão em aberto e delegada ao PRD, oferecendo duas hipóteses:
1. Agente transversal, atendendo diversos setores — risco de precisar conhecer regras demais de todos os setores e virar excessivamente complexo.
2. Agente subordinado a Exames, apenas executando o cálculo e devolvendo o atendimento — risco de aumentar handoffs e perder contexto.

A transcrição da reunião de processo (20/ago) mostra que essa decisão já tinha sido tomada antes do briefing mais recente: o papel de orçamento foi extinto operacionalmente no Nouvet (não existe mais pessoa dedicada). O grupo concluiu que, na prática, o fluxo de orçamento nasce quase sempre de uma solicitação de exame ("é um subsetor do exame... é a mesma pessoa, é o mesmo lead"), tornando a hipótese transversal pouco representativa da operação real. A decisão final, confirmada por Thiago nesta sessão, foi eliminar a ideia de agente de orçamento por completo: qualquer demanda de orçamento é roteada a um humano generalista, sem tentativa de automação no Piloto. Isso está refletido no PRD como FR-19.

## Mecanismo técnico provisório — Calendário Compartilhado e Pega Plantão

- O Calendário Microsoft compartilhado foi adotado como fonte provisória de agenda porque o SimplesVet não tem API para agendamento 100% autônomo (justificativa oficial citada no material comercial da Btech.Cloud). Mitigação proposta pelo próprio material: "solução híbrida utilizando o RD Station CRM como centralizador provisório e calendários compartilhados para evitar conflitos de agenda."
- A Btech.Cloud já tem acesso administrativo confirmado à plataforma Pega Plantão e consegue extrair escalas/dias/horários de especialistas de lá. A viabilidade técnica de extração está confirmada; o que permanece em aberto é apenas se o uso via API em tempo real entra no escopo do Piloto de 10 dias (ver PRD, Questão em Aberto #9) — a viabilidade técnica, por si só, não determina a inclusão no escopo.
- Migração do Nouvet para TOTVS tem previsão de 2027; integrações definitivas de agenda/dados ficam para depois dessa migração.

## Riscos de alinhamento com o material comercial (não são requisitos de produto, mas merecem atenção da equipe comercial/gestão)

- **Contradição interna na proposta em PDF:** a lista "O que está incluído" cita "suporte e manutenção contínua pós-entrega", mas a seção "O que não está incluído" declara que suporte/monitoramento contínuo **não** está incluso (exige proposta de sustentação mensal à parte). Vale alinhar com o time comercial antes de comunicar isso ao Nouvet, para não gerar expectativa de suporte gratuito contínuo.
- **Contradição interna no PPTX sobre cronograma de remarketing:** o slide 12 diz que a equipe comercial do Nouvet será treinada, antes do go-live de 1º de setembro, em "orçamentos automáticos e réguas de remarketing" — mas o roadmap do próprio deck (slide 13) só posiciona remarketing na Fase 5 (15 dias), depois das fases de Configuração/CRM. Risco real de a equipe comercial prometer ao cliente algo que o Piloto de 10 dias não entrega.
- **Reivindicações absolutas de marketing** no slide 6 do PPTX ("24/7, imediata e sem filas", "atualização 100% nativa, automática e em tempo real") são estado final aspiracional do produto completo, não entregável do Piloto — o PRD já registra isso como ressalva explícita (§5 Não-Objetivos), mas vale reforçar na comunicação com a diretoria para não gerar expectativa equivocada de que o Piloto já entrega esse patamar.
- **Nomenclatura "Fase 1":** tanto o PDF quanto o PPTX usam "Fase 1" para o Diagnóstico de 5 dias, dentro de um roadmap comercial de ~81 dias corridos (5 fases). O PRD adota "Piloto" para o recorte de 10 dias exatamente para evitar essa colisão de nomenclatura ao apresentar a entrega para quem já viu o material comercial.

## Precificação (contexto, não repetir com destaque no PRD de produto)

- Proposta em PDF: tabela de investimento por fase (consultoria/implementação), total com desconto de 15%, pagamento em 2x (60%/40%, ato + 30 dias). Manutenção mensal recorrente para "nível avançado" (agente + integração bidirecional CRM + dashboard + réguas de remarketing) + custo de plataforma mensal (VPS), pagos diretamente pelo Nouvet.
- PPTX: total do projeto R$32.667,00 (3x), sustentação mensal R$1.997,00 (manutenção avançada) + R$193,00 (plataforma/VPS).
- Recomendação mantida: o PRD apenas referencia a existência de estrutura de precificação por fase e mensalidade de manutenção definida na proposta comercial, sem repetir valores no documento de produto.

## Pendências e Próximos Passos de Colaboração (fora do PRD, registrado para não perder)

**Estado em 31/ago/2026, fim de sessão:** Thiago vai à Btech.Cloud em 01/set — parte das pendências abaixo será resolvida lá; o que a Btech não souber responder será levado ao Nouvet. Retomar quando Thiago chamar novamente.

| Item | Dono | Status / prazo |
|---|---|---|
| Extrair a agenda/escala do SimplesVet e criar os Calendários Microsoft correspondentes (profissionais da casa — Care Center e Consultas regulares) | Alguém da equipe Btech (a definir quem) | Preparação de base para a fase de agendamento real — não bloqueia mais o Piloto (ver decisão 01/set/2026, §6.1 do PRD) |
| Documentação da API do RD Station (avaliar CLI/MCP, criar skill dedicada) | Thiago | **Concluído em 31/ago/2026** — skill `rd-station-api` criada, cobrindo Conversas e CRM (tenants separados, gotchas de formato de telefone). |
| Documentação do n8n (skill de apoio) + exemplo de agente de agendamento já construído em n8n como referência | Thiago | Em andamento |
| Revisão conjunta dos modelos de funil já existentes no RD Station (reaproveitar ou criar novos por setor) | Thiago, após visita à Btech | A definir — Questão em Aberto #4 |
| Mecanismo e destinatário do alerta de emergência | Thiago, junto à Btech | **Resolvido em 01/set/2026** — alerta vai a todos os profissionais envolvidos no atendimento, configurável. Ver FR-41, Questão em Aberto #11. |
| Critérios/lista concreta de "sinal de alerta" clínico | Equipe clínica do Nouvet, via Thiago | **Redefinido em 01/set/2026** — lista é configurável (FR-34), não hardcoded, então deixou de bloquear o início do build (time já constrói com lista interina). Continua bloqueando o **go-live** de 08/09: a lista real e validada pela equipe clínica precisa estar pronta antes de atender clientes reais. Ver Questão em Aberto #15. |
| Acesso/atualização das exportações do SimplesVet (identificação de clientes, FR-42) | **Btech** (acesso direto à plataforma confirmado) | **Resolvido em 01/set/2026** — Btech mantém as exportações atualizadas, Nouvet não precisa enviar manualmente. Falta só fechar a política formal de retenção (Questão em Aberto #13). |
| Pedido de exclusão de dados/opt-out do tutor (LGPD) | — | **Decidido em 01/set/2026: fora de escopo do Piloto**, considerar em fase seguinte. Ver Questão em Aberto #14. |

**Estado em 01/set/2026:** Reunião da equipe Btech resolveu diversas pendências: JTBD do gestor reformulado para "identificar" em vez de "provar"; escalonamento ao gestor agora progressivo a cada ciclo, não só após 2 ciclos; mecanismo de emergência definido como alerta a todos os profissionais envolvidos, configurável; Vacinas confirmado dentro do Piloto e Financeiro confirmado fora; acesso às exportações do SimplesVet fica com a Btech (acesso direto à plataforma); pedido de exclusão de dados/opt-out (LGPD) decidido como fora de escopo do Piloto. Também mudou o escopo de agendamento: **nenhum setor recebe agendamento real automático no Piloto** — a promessa é entregar a informação completa no CRM e notificar o humano, com a base de integração ao Calendário Compartilhado preparada para uma fase seguinte. Essas mudanças já estão aplicadas ao `prd.md`.

Depois de revisar o painel das duas contas RD Station separadas (Conversas x CRM), Thiago identificou que **ambas estão cadastradas com o mesmo CNPJ** — apesar de serem tenants tecnicamente distintos. Isso não resolve a separação técnica por si só, mas é um dado relevante para uma eventual conversa com o suporte da RD Station sobre consolidação futura. Ver `.claude/skills/rd-station-api/` para o detalhe técnico.

Correções propostas pelo Reviewer Gate que **não** foram tratadas nesta rodada (críticos/altos que dependem de resposta do Nouvet, não da Btech) continuam pendentes no `prd.md`: critérios de "Sinal de Alerta" clínico sem dono nem Questão em Aberto (FR-8, crítico), NFRs com adjetivo sem limiar de aceitação (NFR-4, NFR-5), FR-36/FR-38 mais rasos que seus vizinhos, e o tratamento proporcional de LGPD (Questão #14). Ver `review-rubric.md` para a lista completa.

## Correção de contexto — papel do Thiago no projeto

Thiago Bicalho é membro da equipe **Btech.Cloud** responsável por este projeto (não um funcionário do Nouvet). Ele é o interlocutor principal e decisor de escopo do lado da entrega, trabalhando ao lado de Luis Niel Matt. O gestor do lado do cliente (Nouvet) é Edson Candido, que leva a entrega à diretoria/conselho. O PRD (§12) reflete essa estrutura.

## Visão de longo prazo (contexto, não é obrigação do Piloto)

- Slide 15/16 do PPTX: três agentes de IA adicionais planejados sobre a mesma infraestrutura — Agente de Social Selling (Marketing, detecta interesse espontâneo em redes sociais e conduz para agendamento), Agente Pessoal do Especialista (gerencia agenda do veterinário, resume histórico clínico pré-consulta, envia lembretes de retorno), Agente Interno para Gestores (agrega indicadores de todos os serviços e responde perguntas de liderança sob demanda com relatórios automáticos).
- Dashboard de BI unificado consolidando métricas de todos os serviços da clínica em tempo real — explicitamente rotulado como "PROTÓTIPO ILUSTRATIVO" no próprio material (não construído). KPIs ilustrativos mostrados: 348 atendimentos/mês, 64% taxa de conversão em agendamento, 2 min tempo médio de 1ª resposta, NPS 4,8/5.
- "Reactivation Loop": motor de remarketing que detecta clientes inativos além de um período definido e dispara réguas de reativação nativas no WhatsApp, sem custo extra de mídia.
