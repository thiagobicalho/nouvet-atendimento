# Analysis Report: .claude/skills/n8n-agent-patterns

Generated: 2026-09-01T16:45:00-03:00 · Schema: 2

**Grade: Fair**

> Os dois padrões mais valiosos (config em Postgres lida em runtime, e o precedente de escalonamento multi-destinatário para o FR-41) estão bem documentados e grounded — mas a lente de enhancement mostrou que a skill sub-documenta o pacote mais maduro (`secretariav3-completo`): faltam o padrão de agente de follow-up/lembrete proativo e o de multimodal (áudio/arquivo), e dois workflows do pacote ficam em limbo (nem documentados, nem listados como fora de escopo). Dois problemas estruturais pequenos (path sem prefixo, exemplo de arquivo inexistente no Resolution rules) já foram corrigidos nesta sessão.

As lentes de leanness, arquitetura, determinismo e customização confirmam que a base é sólida: conteúdo grounded em exports reais, sem cerimônia desnecessária, sem necessidade de customize.toml, sem sequência determinística deixada como prosa. O que pesa a nota é a lente de enhancement: ela fez um passe nó-a-nó pelos 16 arquivos de `secretariav3-completo` e achou padrões reais e relevantes para o Nouvet (agente de lembrete/follow-up disparado por cron ou por mudança de etapa no funil, tratamento de áudio/arquivo) que a skill ainda não cobre, além de duas exclusões que merecem revisão (uma corta um padrão reaproveitável junto com o conector específico; duas outras nem foram documentadas nem listadas como fora de escopo).

| Severity | Count |
| --- | --- |
| Critical | 0 |
| High | 3 |
| Medium | 4 |
| Low | 0 |

## Themes

### 1. Loose ends estruturais — já corrigidos nesta sessão

- Root cause: SKILL.md carregava um exemplo de nome de arquivo desatualizado no Resolution rules (`postgres-schema.md` em vez do nome real `config-postgres.md`) e um path de projeto sem o prefixo `{project-root}/` exigido pela convenção.
- Fix: Corrigido: exemplo do Resolution rules atualizado para o nome real do arquivo; path prefixado com `{project-root}/`. O bloco de Resolution rules em si foi mantido (não removido) porque a lente de arquitetura considerou o bloco estruturalmente correto para um SKILL.md que roteia para múltiplos arquivos em `references/` — a leanness lens tinha proposto remover a seção inteira; a divergência entre as duas lentes foi resolvida a favor da convenção estrutural, já que o defeito real era só o exemplo quebrado, não a existência do bloco.
- Findings:
  - `leanness-1` Resolution rules section carregava exemplo de arquivo inexistente — `SKILL.md:12-16`
  - `architecture-1` Path de projeto sem prefixo {project-root}/ — `SKILL.md:20`

### 2. Padrões reais do pacote maduro ainda não documentados

- Root cause: A skill documenta bem o núcleo (config em Postgres, agente + sub-fluxos de agenda, escalonamento humano), mas um passe nó-a-nó pelos 16 arquivos de `secretariav3-completo` mostra pelo menos dois padrões inteiros com relevância direta para o Nouvet que não aparecem em lugar nenhum: agente de lembrete/follow-up proativo (disparado por cron ou por mudança de etapa) e tratamento multimodal de áudio/arquivo (crítico para uma clínica veterinária, onde cliente manda áudio e foto do pet com frequência). Dois arquivos do pacote (`02 - Baixar_Enviar Arquivo.json`, `08 - Assistente Interno.json`) também ficam em limbo — nem documentados, nem citados como fora de escopo.
- Fix: Decisão pendente, não aplicada nesta sessão — depende também de que escopo o Nouvet fecha para follow-up/lembrete (a proposta de Thiago já fala em '2 ciclos'/'progressivo' para escalonamento ao gestor, mas não fechou se o cliente final recebe lembretes automáticos de retorno) e de custo/complexidade extra de suportar áudio recebido. Levar para avaliação — inclui a decisão em aberto sobre manter os dois pacotes de referência (`clinica/` e `secretariav3-completo/`) ou só o mais maduro.
- Findings:
  - `enhancement-1` Falta o padrão de agente de follow-up/lembrete proativo (disparado por cron ou por etapa do funil) — `references/agente-e-subfluxos.md (tabela de sub-workflows, linha '11 - Lembretes Agendamento.json')`
  - `enhancement-2` Falta o padrão multimodal (áudio de entrada, voz de saída, arquivo como ferramenta) — `references/agente-e-subfluxos.md (seção 'O agente principal')`
  - `enhancement-4` Dois workflows do pacote ficam em status ambíguo (nem documentados, nem listados como fora de escopo) — `references/agente-e-subfluxos.md ('Fora do escopo do Nouvet', lista incompleta)`

### 3. Exclusão em bloco descarta um padrão reaproveitável

- Root cause: O workflow `07 - Quebrar_Enviar Mensagens (Evolution)` foi listado inteiro como fora de escopo por usar o conector Evolution API — mas o núcleo do arquivo (split de resposta longa em várias mensagens curtas + envio pausado simulando digitação humana) é independente do conector e pode valer a pena sobre RD Conversas.
- Fix: Não aplicado — depende de confirmar se RD Conversas suporta indicador de 'digitando' ou envio pausado (não confirmado na skill `rd-station-api` hoje). Fica registrado como possibilidade, não como fato a documentar sem essa confirmação.
- Findings:
  - `enhancement-3` Exclusão do workflow Evolution descarta também um padrão de pacing de mensagens reaproveitável — `references/agente-e-subfluxos.md ('Fora do escopo do Nouvet', item Evolution)`

## Strengths

- Os dois exemplos reais (`clinica/` vs `secretariav3-completo/`) são apresentados com o estágio de maturidade certo — a skill não trata os dois como equivalentes, e usa a diferença entre eles (hardcode vs config em Postgres) como o próprio ensinamento central.
- O achado do padrão de escalonamento multi-destinatário (`05.1 - Escalar Humano Multi.json`) é citado explicitamente como precedente direto do FR-41 do PRD do Nouvet — é o tipo de conexão entre a doc técnica e o requisito de produto que evita reinventar a roda.
- Nenhuma das lentes de customização ou determinismo encontrou problema algum: sem customize.toml desnecessário, sem sequência determinística deixada como prosa para o consumidor repetir.
- As exclusões explícitas (Asaas, Twilio, leads) evitam que a skill infle com conteúdo de um produto mais amplo que não pertence ao Piloto do Nouvet — mesmo que uma dessas exclusões (Evolution) mereça revisão parcial.

## Recommendations

1. Antes de expandir o conteúdo, decidir a questão de escopo dos dois pacotes de referência (manter `clinica/` e `secretariav3-completo/`, ou só o mais maduro) — isso muda o que faz sentido documentar a seguir.
2. Se o Nouvet confirmar que quer lembretes automáticos de retorno/no-show, documentar o padrão de agente proativo (enhancement-1) e decidir o status de `02` e `08` (enhancement-4) no mesmo passe. (resolves: enhancement-1, enhancement-4)
3. Documentar o padrão multimodal (áudio/arquivo) assim que houver decisão sobre se o Piloto aceita áudio do cliente — item de produto, não só de doc. (resolves: enhancement-2)

## Experience

- **Desenhar onde a Configuração de Personalização do Nouvet vai morar** — Abrir SKILL.md para o aviso clinica-vs-secretaria -> references/config-postgres.md para o schema e o padrão de leitura em runtime -> aplicar no desenho do Nouvet trocando Chatwoot/Google Calendar pelos conectores certos.
- **Desenhar o mecanismo de alerta de emergência (FR-41)** — Abrir references/agente-e-subfluxos.md, seção 'Escalar para humano' -> usar o padrão Multi (array + splitOut) como base.
- Headless: Não aplicável — skill de referência sem modo headless ou multi-turno.

## Findings

### High (3)

#### leanness-1 — Resolution rules section carregava exemplo de arquivo inexistente

- Lens: leanness
- Location: `SKILL.md:12-16`
- Evidence: O exemplo citava `references/postgres-schema.md`, mas o arquivo real se chama `references/config-postgres.md`. A lente propôs remover a seção inteira, já que os tokens `{skill-root}`/`{project-root}` não eram usados em nenhum outro lugar da skill.
- Recommendation: Corrigido nesta sessão: exemplo do arquivo atualizado. Seção mantida (não removida) — ver nota de reconciliação com a lente de arquitetura no tema correspondente.

#### enhancement-1 — Falta o padrão de agente de follow-up/lembrete proativo (disparado por cron ou por etapa do funil)

- Lens: enhancement
- Location: `references/agente-e-subfluxos.md (tabela de sub-workflows, linha '11 - Lembretes Agendamento.json')`
- Evidence: Esse workflow roda por `scheduleTrigger` (cron), com sua própria instância de agente + memória — não é chamado sob demanda pelo agente principal como as outras linhas da tabela, e a tabela não deixa essa diferença clara. O exemplo mais simples (`clinica/08`) mostra a mesma família disparada por mudança de etapa no Kanban do Chatwoot. Os campos de config (`lembretes_horas`, `follow_ups_horas`, `max_followups`) já estão documentados em config-postgres.md, mas o mecanismo que os consome nunca é explicado.
- Recommendation: Adicionar uma subseção própria para o padrão de 'agente proativo/agendado', distinta do padrão de ferramenta sob demanda, citando os dois gatilhos possíveis (cron vs. mudança de etapa) como decisão de design para o Nouvet.

#### enhancement-2 — Falta o padrão multimodal (áudio de entrada, voz de saída, arquivo como ferramenta)

- Lens: enhancement
- Location: `references/agente-e-subfluxos.md (seção 'O agente principal')`
- Evidence: `secretariav3-completo/01` tem um switch de tipo de mensagem que trata texto, áudio (transcrição via nó OpenAI) e arquivo separadamente, mais síntese de voz (ElevenLabs) condicionada à preferência do contato. config-postgres.md só cita a preferência de áudio/texto como campo, sem explicar o mecanismo. Relevante para o Nouvet porque cliente de clínica veterinária manda áudio e foto do pet com frequência.
- Recommendation: Adicionar subseção documentando o switch de tipo de mensagem, transcrição de áudio de entrada, síntese de voz de saída condicionada à preferência salva, e envio de arquivo como ferramenta chamável.

### Medium (4)

#### architecture-1 — Path de projeto sem prefixo {project-root}/

- Lens: architecture
- Location: `SKILL.md:20`
- Evidence: "_bmad-output/reference/modelo-n8n/" citado sem o prefixo `{project-root}/` exigido pela convenção de paths (o scanner automático não pega esse caso porque seu regex só reconhece `_bmad/` literal, não `_bmad-output/`).
- Recommendation: Corrigido nesta sessão: path prefixado com `{project-root}/`.

#### enhancement-3 — Exclusão do workflow Evolution descarta também um padrão de pacing de mensagens reaproveitável

- Lens: enhancement
- Location: `references/agente-e-subfluxos.md ('Fora do escopo do Nouvet', item Evolution)`
- Evidence: O núcleo do arquivo `07 - Quebrar_Enviar Mensagens (Evolution)` — um agente que divide uma resposta longa em várias mensagens curtas, enviadas com pausa e indicador de 'digitando' — é independente do conector Evolution; só as chamadas HTTP finais são específicas dele.
- Recommendation: Manter a exclusão das chamadas específicas do Evolution, mas nomear separadamente o padrão de divisão/pacing de mensagens como algo a avaliar para RD Conversas, se o canal suportar indicador de digitação ou envio pausado (verificar na skill `rd-station-api`).

#### enhancement-4 — Dois workflows do pacote ficam em status ambíguo (nem documentados, nem listados como fora de escopo)

- Lens: enhancement
- Location: `references/agente-e-subfluxos.md ('Fora do escopo do Nouvet', lista incompleta)`
- Evidence: `02 - Baixar_Enviar Arquivo.json` (enviar arquivo como ferramenta, ex.: PDF de orçamento) e `08 - Assistente Interno.json` (agente interno voltado à equipe, com ferramentas de Gmail/Tasks/Asaas) existem no pacote de 16 arquivos, mas não aparecem nem na tabela de padrões nem na lista explícita de exclusões (que só cita 06/07/12/13).
- Recommendation: Decidir e registrar o status de cada um: `02` é plausivelmente útil para o Nouvet (enviar PDF de orçamento/exame); `08` é candidato a fase futura ou exclusão explícita com motivo, no mesmo padrão já usado para 06/07/12/13.

#### enhancement-5 — Nó de raciocínio (think-tool), presente em todo agente maduro do pacote, não é mencionado

- Lens: enhancement
- Location: `references/agente-e-subfluxos.md ('O agente principal')`
- Evidence: `@n8n/n8n-nodes-langchain.toolThink` aparece em praticamente toda instância de agente madura do pacote (principal, interno, lembretes, ligações, leads, divisor de mensagens), mas a lista de componentes do agente principal na skill não o cita.
- Recommendation: Adicionar como um quinto componente do agente principal, com uma linha explicando que é usado de forma consistente no material de referência para tool-calling multi-etapa mais confiável.
