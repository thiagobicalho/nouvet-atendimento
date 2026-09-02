---
title: Review de Viabilidade Técnica — Atendimento Nouvet (Piloto 10 dias)
status: draft
reviewer: revisor técnico ad-hoc (arquiteto de automação n8n)
reviewed_date: 2026-08-31
scope: prd.md + addendum.md (prd-atendimento-2026-08-31)
---

# Review de Viabilidade Técnica — Atendimento Nouvet

## Veredito Geral

O escopo funcional do Piloto é implementável em n8n dentro de ~8-10 dias **somente se** um conjunto pequeno mas crítico de decisões e dependências externas — hoje todas em aberto, algumas com prazo textual futuro ("Thiago vai enviar/providenciar/confirmar") — for fechado nas próximas 24-48h. Nenhum FR individual é tecnicamente inviável; o risco real está concentrado em três lugares: (1) um bloqueador de lançamento explícito ainda sem dono nem mecanismo (FR-41), (2) uma dependência externa de replicação de agenda que hoje não tem processo, dono nem cadência definidos e da qual depende a única promessa de agendamento real já "confirmada" (Care Center), e (3) uma base de conhecimento/RAG tratada como detalhe de arquitetura quando na prática é um subsistema novo com dependência de curadoria de conteúdo do Nouvet. Se essas três pendências não forem resolvidas antes do primeiro dia de desenvolvimento, o atraso não aparece como "risco de FR" — aparece como dias de calendário perdidos que o Piloto não tem.

Uma observação de calendário que merece destaque por ser objetiva, não uma opinião: a data de hoje (31/ago/2026, conforme o próprio PRD) já está dentro da janela do Piloto, e todos os seis itens listados em "Pendências e Próximos Passos" do addendum (acesso à API do RD Station, revisão dos funis, exemplo de agente de agendamento, acesso MCP ao n8n, mecanismo de alerta de emergência, processo de replicação de agenda) seguem em aberto na própria data de criação do documento. Restam algo entre 8 e 10 dias corridos até 08/09/2026 — não há folga para que essas pendências se resolvam "durante" a primeira semana de build.

---

## Riscos Críticos

### C1 — FR-41 (Emergência declarada pelo cliente): bloqueador de lançamento sem dono nem mecanismo
O próprio PRD marca isso como `[BLOQUEADOR DE LANÇAMENTO]` e afirma "este FR não pode ser considerado implementável até essa resposta" (Questão em Aberto #11). Isso é mais sério do que um FR pendente comum: é a única funcionalidade que o documento admite poder impedir o go-live inteiro. Sem destinatário/canal definidos (celular de plantonista? grupo? ligação automática?), a equipe não pode nem desenhar o nó de notificação, muito menos testá-lo — e testá-lo importa, porque o próprio `[NOTE FOR PM]` alerta para fadiga de alerta se clientes "gritarem emergência" sem necessidade real.
**Recomendação:** tratar como item de dia 0. Se Thiago não confirmar em 24-48h, a equipe de implementação deve propor um mecanismo default de baixo risco (ex.: mensagem simultânea a um grupo de WhatsApp fixo de plantonistas + registro de prioridade máxima no card) e seguir com ele documentado como decisão provisória — não deixar o fluxo de emergência sem nenhum destino até a resposta "definitiva" chegar. O pior cenário não é usar um mecanismo simples demais; é chegar ao dia 8 sem nenhum mecanismo funcionando.

### C2 — Replicação de agenda SimplesVet → Calendário Compartilhado: dependência externa sem processo, dono ou cadência
FR-12 já é tratado como "Confirmado" para Care Center, mas a própria nota do FR-12 admite que depende do "mesmo mecanismo de FR-14" — e a nota de FR-14 diz explicitamente: "o processo de replicação da escala do SimplesVet para o Calendário Compartilhado (frequência, responsável, manual ou semi-automático) ainda não está definido" (Questão em Aberto #12). Isso significa que a única entrega de agendamento real já "garantida" no Piloto depende de um processo operacional que, hoje, não existe — nem como automação, nem como rotina manual documentada. Se a agenda replicada estiver desatualizada ou incompleta quando a equipe testar FR-12, o sintoma não vai parecer um bug de n8n: vai parecer que o agente "erra disponibilidade", e o tempo de debug vai ser gasto no lugar errado.
**Recomendação:** decidir HOJE quem no Nouvet é o dono da replicação (mesmo que seja um processo manual simples: exportar a escala do SimplesVet para uma planilha e alguém colar/atualizar eventos no Calendário Compartilhado, ou um script simples fora do n8n) e testar esse pipeline com dados reais antes do dia 3, independente do avanço do fluxo conversacional. Adicionalmente, construir no n8n uma verificação de "idade" do calendário (ex.: alertar internamente se não há atualização de agenda há mais de X dias) como rede de segurança, já que o sistema não tem como saber sozinho se a fonte está desatualizada.

### C3 — Compressão de calendário: pendências de "antes do desenvolvimento" ainda abertas na data de hoje
Do addendum, seis pendências estão listadas sob "Pendências e Próximos Passos" e nenhuma tem confirmação de conclusão: acesso à API do RD Station (Thiago "vai enviar"), revisão dos modelos de funil (Thiago "vai providenciar"), exemplo de agente de agendamento em n8n (Thiago "vai compartilhar"), acesso MCP ao n8n (a ser concedido), mecanismo de alerta de emergência (C1 acima), e processo de replicação de agenda (C2 acima). Como o go-live é 08/09/2026 e hoje é 31/08/2026, restam ~8 dias corridos — ou seja, esse não é um risco hipotético de "e se atrasar", é a situação já em curso na data do próprio PRD.
**Recomendação:** consolidar essas seis pendências em uma lista única com dono e prazo de 24-48h cada, revisada em uma chamada curta diária (15 min) até que todas fechem. Qualquer pendência sem dono nomeado até amanhã deve ser escalada para Thiago/Edson explicitamente como risco de prazo, não deixada como "a confirmar" dentro do PRD.

---

## Riscos Altos

### A1 — FR-30 / base de conhecimento (RAG) tratada como detalhe de arquitetura, mas é um subsistema novo
Questão em Aberto #7 deixa em aberto se a base será RAG, documentos ou banco estruturado — "decisão técnica a resolver na arquitetura". Isso subestima o esforço real: qualquer opção exige (a) curadoria de conteúdo confiável vindo do Nouvet (o que por si só depende de terceiros e pode atrasar), (b) um pipeline de ingestão/indexação, (c) integração de recuperação dentro do fluxo n8n, e (d) testes de alucinação/guardrail contra essa base — tudo isso sustenta literalmente todo FR que envolve resposta factual (FR-30, FR-31) e o guardrail de segurança que depende de anexos (FR-40). Não é um "nó a mais" no fluxo; é a peça que, se malfeita, compromete o guardrail mais citado do produto.
**Recomendação:** para o Piloto, escolher deliberadamente a opção mais simples que atenda ao guardrail — um documento curado único (FAQ/políticas do Nouvet) com um node de vetor simples no n8n — em vez de desenhar uma arquitetura RAG sofisticada. Iniciar a coleta de conteúdo confiável com o Nouvet em paralelo, imediatamente, independente da decisão técnica de arquitetura.

### A2 — §6.1 (regra de sequenciamento) reduz mas não elimina o risco de vazamento de esforço para agendamento real
A regra protege bem contra um erro específico — a equipe de implementação investir em lógica de agendamento antes do fallback estar pronto em todos os setores. Mas há três brechas que o texto não fecha:
1. FR-12 já é tratado como compromisso confirmado ("Thiago confirmou o Care Center como o setor garantido"), o que na prática cria pressão para tratá-lo como prioridade mesmo que a regra de sequenciamento diga o contrário — a governança do "antes" depende de disciplina de execução, não é auto-aplicável pelo texto do PRD.
2. "Funcionando e testado" não tem critério de aceite objetivo (que teste, com quem, em que volume). Sob pressão de prazo, é fácil declarar o fallback "pronto" prematuramente para liberar o time a trabalhar em agendamento real.
3. A dependência externa de replicação de agenda (C2) roda em paralelo, fora do n8n — ou seja, mesmo seguindo a regra à risca, a equipe pode chegar ao ponto de "agora pode investir em agendamento real" e descobrir que a agenda replicada ainda não existe, empurrando o problema para os últimos dias do Piloto exatamente quando não há mais margem para atraso.
**Recomendação:** transformar a regra em um checkpoint testável e datado (ex.: "até o dia 5, demo do fallback ponta a ponta nos 5 setores em escopo, com aprovação de um humano do Nouvet") em vez de deixá-la como princípio geral. Tratar a preparação da agenda replicada (C2) como trilha paralela desde o dia 1, não como algo que só começa "depois" do fallback.

### A3 — FR-23 / etapas de funil (Questão em Aberto #4): dependência de material que ainda não foi entregue
A movimentação automática de etapa no funil toca praticamente todos os FRs de CRM (FR-20 a FR-24) e os indicadores (FR-36 a FR-39, que leem dessas esteiras). O PRD assume reaproveitar os modelos existentes "até revisão conjunta" com material que "Thiago vai providenciar" — mas o addendum mostra que essas esteiras hoje estão "paradas por falta de pessoa para alimentar", ou seja, são um artefato de um fluxo comercial anterior, não necessariamente desenhadas para o caso de uso do Piloto. Se o material chegar tarde ou revelar que as etapas não servem, a automação de movimentação (que é transversal a quase tudo) precisa ser refeita.
**Recomendação:** prazo de 24h para o material chegar; se não chegar, a equipe segue com o default assumido (reaproveitar etapas existentes) e trata qualquer ajuste posterior como mudança de escopo pós-Piloto, não como retrabalho a absorver dentro dos 10 dias.

### A4 — Credenciais de múltiplas integrações ainda não confirmadas como provisionadas
FR-43 exige que credenciais de RD Station, Microsoft Graph, Pega Plantão e WhatsApp/Meta estejam no cofre do n8n — correto como requisito, mas o addendum indica que o acesso à API do RD Station ainda seria enviado por Thiago, e não há menção de que o registro de aplicativo/consentimento do Microsoft Graph (tipicamente o mais lento dos quatro, por depender de aprovação de administrador de tenant) já esteja feito. Em um projeto de 8-10 dias, esperar por aprovação de admin de Microsoft 365 no meio do sprint é o tipo de atraso que não aparece em nenhum FR mas consome dias reais.
**Recomendação:** validar HOJE que as quatro credenciais existem e fazem uma chamada de teste bem-sucedida (não apenas "a credencial foi criada", mas "uma requisição real funcionou") antes de iniciar os fluxos que dependem delas. Priorizar Microsoft Graph por ser o mais sujeito a aprovação administrativa demorada.

### A5 — Critérios de "Sinal de Alerta" clínico (FR-8, FR-33): dependência não listada nas Questões em Aberto
O texto diz "critérios definidos pela equipe do Nouvet", mas o PRD não deixa claro se essa lista já existe e está em mãos da Btech.Cloud, nem a inclui nas 14 Questões em Aberto — apesar de ser o guardrail de segurança clínica mais citado do documento (§9 Safety, FR-8, FR-33, UJ-2 edge case). Sem essa lista fechada e testável, a classificação de "sinal de alerta" vira um julgamento implícito do modelo de IA, o que é justamente o tipo de ambiguidade que os outros guardrails tentam evitar.
**Recomendação:** confirmar explicitamente se essa lista de critérios já está definida e documentada; se não estiver, elevá-la ao mesmo nível de urgência de FR-41 — é tão bloqueadora quanto o mecanismo de emergência, só que não foi rotulada como tal.

---

## Riscos Médios

### M1 — FR-4 (telefone compartilhado) tem um risco de privacidade reconhecido mas não mitigado
O próprio `[NOTE FOR PM]` identifica o risco real (número reciclado expõe histórico de outro cliente) e propõe mitigação (confirmação leve, ex. nome do pet) mas não a torna FR obrigatório. É uma mitigação barata de implementar dado que a lógica de correção dinâmica de FR-4 já vai existir.
**Recomendação:** incluir a confirmação leve como parte da implementação de FR-4 mesmo sem virar FR numerado — o custo marginal é baixo e o risco de LGPD/reputação de expor histórico ao dono errado do número é desproporcional ao esforço de evitá-lo.

### M2 — FR-2 mistura fonte viva (RD Station) com fonte estática ("exportações pontuais" do SimplesVet)
Não há regra de precedência definida para quando as duas fontes conflitarem (ex.: export desatualizado indica um pet que já morreu ou mudou de dono). Isso é uma fonte plausível de identificação incorreta, que por sua vez alimenta personalização (FR-3) e histórico (FR-22).
**Recomendação:** definir regra simples de precedência (RD Station como fonte de verdade quando houver conflito; export do SimplesVet só preenche o que falta) antes de construir o nó de identificação.

### M3 — FR-15 (parsing de carta de encaminhamento/anexo) é mais complexo do que uma linha de FR sugere
Requer leitura de documento (possivelmente escaneado/manuscrito) para extrair tipo de exame e determinar necessidade de anestesia, e ainda precisa resistir a prompt injection embutido no próprio anexo (FR-40 estende explicitamente a isso). Isso é engenharia de documento/visão computacional, não só "leitura de anexo".
**Recomendação:** para o Piloto, aceitar uma abordagem simples (leitura por modelo com visão + confirmação do dado extraído de volta ao cliente antes de prosseguir) em vez de um pipeline robusto de OCR/classificação — reduz risco de erro silencioso sem exigir uma solução mais cara.

### M4 — FR-22 ("mais recente primeiro") depende de comportamento nativo do RD Station ainda não validado
Marcado como `[ASSUMPTION]` e Questão em Aberto #10. Se a estrutura nativa do card do RD Station não suportar o reposicionamento assumido (nota vs. campo estruturado), o desenho de FR-23 (movimentação de etapa) pode precisar ser ajustado depois de já construído.
**Recomendação:** validar esse comportamento diretamente na conta/API do RD Station no dia 1 (poucas horas de investigação), antes de desenhar a lógica de FR-23 em cima de uma suposição não testada.

### M5 — Concorrência no agendamento real (double-booking) não é endereçada por nenhum FR
FR-12/FR-14 descrevem "tenta reservar" e "sugere alternativa se indisponível", mas não há menção a como o sistema evita que duas conversas simultâneas reservem o mesmo horário entre o momento da checagem de disponibilidade e a efetivação da reserva.
**Recomendação:** adicionar um padrão simples de re-checagem antes de confirmar (check-then-book com nova verificação imediatamente antes de criar o evento) como requisito técnico implícito de FR-12/FR-14, mesmo que não vire um FR numerado novo.

### M6 — Decisão pendente sobre Pega Plantão (Questão em Aberto #9) pode virar escopo tardio
Viabilidade técnica já confirmada, mas se a decisão de incluir uso via API em tempo real vier tarde no cronograma, adiciona uma superfície de integração nova em cima de um sprint já apertado.
**Recomendação:** assumir por padrão que Pega Plantão via API fica fora do Piloto (usar apenas fallback humano para cirurgias/plantonistas) a menos que Thiago confirme a inclusão nos próximos 1-2 dias — não deixar essa decisão em aberto até a segunda metade do sprint.

---

## Riscos Baixos

### B1 — FR-29 (número de ciclos de escalonamento)
Assunção de 2 ciclos é trivial de ajustar depois, pois já vive na Configuração de Personalização (FR-34) — corrigir sem redeploy é o próprio ponto do requisito. Confirmar o número com Thiago é bom, mas não bloqueia nada.

### B2 — NFR-1/SM-2 (meta de 1 minuto de primeira resposta)
Tecnicamente alcançável para uma resposta automática simples; risco baixo a menos que a recuperação RAG (A1) ou a API do WhatsApp introduzam latência inesperada. Vale fechar o número oficialmente para não gerar ambiguidade na aceitação do Piloto, mas não é um risco de engenharia.

### B3 — FR-31 (mensagem exata de reconhecimento de incerteza)
Pendente (Questão em Aberto #6), mas é conteúdo, não lógica — vive na Configuração de Personalização e pode ser ajustado a qualquer momento sem impacto estrutural. Vale fechar cedo para não travar testes de guardrail, mas o custo de atraso é baixo.

### B4 — LGPD: exclusão de dados / opt-out (Questão em Aberto #14)
O próprio PRD já reconhece a tensão com NFR-3 (histórico imutável) e explicitamente adia a decisão sem prometer resolver agora. Adequado para um Piloto de 10 dias — o risco de compliance é real, mas proporcional e já está sinalizado, não escondido.

---

## Resposta direta às perguntas de enquadramento

**Sobre §6.1 (regra de sequenciamento):** protege bem contra o erro de priorização dentro do time de implementação, mas não protege contra vazamento de prazo vindo de fora do n8n — em especial a replicação de agenda (C2), que corre em paralelo e não é acelerada pela regra. Recomenda-se transformar a regra em um checkpoint com critério de aceite e data, e tratar a preparação da agenda replicada como trilha paralela obrigatória desde o dia 1, não como algo que só "vem depois".

**Sobre dependências de decisão humana (funis do RD, mecanismo de emergência, etc.):** o prazo de 10 dias só é realista se essas decisões fecharem nas próximas 24-48h. Nenhuma delas, isoladamente, é grande — mas todas juntas, se resolvidas "durante" em vez de "antes", competem pelos mesmos poucos dias de desenvolvimento restantes.

**Sobre FRs que subestimam complexidade real:** os dois mais subestimados são a replicação de agenda SimplesVet → Calendário Compartilhado (tratada como nota lateral, mas é dependência crítica de uma entrega já "confirmada") e a base de conhecimento/RAG dos guardrails (tratada como decisão de arquitetura a resolver depois, mas é um subsistema novo com dependência de conteúdo do próprio Nouvet).
