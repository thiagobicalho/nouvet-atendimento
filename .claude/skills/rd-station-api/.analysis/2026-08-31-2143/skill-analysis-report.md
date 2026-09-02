# Analysis Report: .claude/skills/rd-station-api

Generated: 2026-08-31T21:55:00-03:00 · Schema: 2

**Grade: Excellent**

> Sólida para o que é: uma skill de referência grounded em documentação real, sem cerimônia desnecessária. Um achado real (high) e um gap estrutural (medium) foram corrigidos nesta mesma sessão; o que resta é oportunidade opcional a revisitar quando os fluxos de n8n correspondentes forem de fato construídos.

As cinco lentes concordam que o conteúdo é enxuto e genuinamente grounded (URLs reais, formatos de payload reais, gotchas com consequência real como token OAuth de 2h e envio de mensagem em form-urlencoded). O achado que importava — CRM ficar raso demais justamente no ponto em que o PRD depende de casar contato por telefone entre Conversas e CRM — já foi expandido e corrigido, revelando de quebra uma divergência real de formato de telefone entre os dois produtos. Dois scanners automáticos de pré-passagem sinalizaram falsos positivos (seções 'Overview'/'On Activation' e local do .memlog.md) que as lentes LLM corretamente descartaram para uma skill deste formato.

| Severity | Count |
| --- | --- |
| Critical | 0 |
| High | 1 |
| Medium | 3 |
| Low | 5 |

## Themes

### 1. Falsos positivos dos scanners automáticos para uma skill de referência sem estado

- Root cause: Os scanners de pré-passagem aplicam um checklist genérico de workflow (seções obrigatórias, .memlog.md sempre em references/) que não se aplica a uma skill estática de lookup sem config, sem resume e sem customização.
- Fix: Nenhuma correção necessária — as lentes já confirmaram que os dois flags não se aplicam a este formato de skill.
- Findings:
  - `architecture-1` Pre-pass 'missing ## Overview / ## On Activation' é falso positivo — `SKILL.md:6-8`
  - `architecture-2` Pre-pass '.memlog.md deveria estar em references/' mal aplica a regra geral de carve-out — `.memlog.md`

### 2. Polimento estrutural padrão

- Root cause: SKILL.md referenciava dois arquivos internos sem o bloco canônico de Resolution rules; a descrição de frontmatter usava condições tópicas em vez de frases entre aspas; dois arquivos de referência tinham ponteiros decorativos cruzados (reference-to-reference e back-reference).
- Fix: Corrigido nesta sessão: bloco de Resolution rules adicionado ao SKILL.md, descrição reescrita com frases entre aspas, ponteiros decorativos removidos (o fato substantivo já estava restatado inline em ambos os casos).
- Findings:
  - `architecture-3` SKILL.md multi-arquivo sem o bloco canônico de Resolution rules — `SKILL.md`
  - `architecture-4` Descrição usava condições tópicas em vez de frases entre aspas — `SKILL.md frontmatter`
  - `architecture-5` Ponteiros decorativos de referência cruzada (reference-to-reference e back-reference) — `references/conversas.md; references/crm.md`

### 3. Assimetria no único join que a arquitetura do PRD realmente usa

- Root cause: Contatos do Conversas ganharam tabela completa de endpoints e schema; o recurso equivalente do CRM — usado para casar o mesmo tutor entre os dois produtos por telefone — ficou como uma linha não expandida, escondendo que o CRM não tem endpoint dedicado de busca por telefone (só filtro RDQL) e que os dois produtos exemplificam o número de telefone em formatos diferentes.
- Fix: Corrigido nesta sessão: seção 'Contatos do CRM' expandida em references/crm.md com endpoints, schema e filtro RDQL por telefone; gotcha de divergência de formato de telefone (E.164 no CRM vs. espaços/traços no Conversas) adicionado tanto em crm.md quanto na lista central de gotchas do SKILL.md.
- Findings:
  - `enhancement-1` Identificação de contato no CRM — o join central do PRD — ficava rasa enquanto o equivalente do Conversas estava completo — `references/crm.md (Contatos do CRM) vs. references/conversas.md (Contatos)`

### 4. Oportunidades de script adiadas por falta de necessidade concreta ainda

- Root cause: Duas sequências determinísticas (casar nome de etapa do funil para stage_id; girar refresh_token do CRM preservando o novo e descartando o antigo) e um recurso REST assimetricamente rico (webhooks do CRM) hoje só existem como aviso em prosa, mas nenhum fluxo n8n real ainda precisa deles.
- Fix: Não construir agora. Revisitar cada um quando o fluxo de n8n correspondente for de fato implementado: um script pequeno de lookup de etapa se a lógica for reimplementada em mais de um fluxo; a seção de webhooks do CRM ganha profundidade quando houver um fluxo real de notificação disparado pelo CRM.
- Findings:
  - `determinism-1` Casamento de nome de etapa do funil para stage_id descrito em prosa, não oferecido como script — `references/crm.md (Funis e etapas)`
  - `determinism-2` Rotação do refresh_token do CRM é sequência determinística documentada só como aviso em prosa — `references/crm.md (Autenticação); SKILL.md (gotchas)`
  - `enhancement-2` Webhooks do CRM — único recurso REST de webhook real — recebem o mesmo tratamento raso de recursos periféricos — `references/crm.md (Outros recursos disponíveis)`

## Strengths

- Conteúdo genuinamente grounded na doc real (URLs, headers, payloads, exemplos) em vez de conhecimento genérico do modelo — inclusive achados que a doc pública não deixa óbvios (base URL do Conversas em domínio da Tallos, rotação de refresh_token do CRM, form-urlencoded no envio de mensagem).
- Aviso de dois-tenants-separados corretamente mantido inline no SKILL.md como gotcha, não carveado para uma reference — é exatamente o tipo de regra que o leitor precisa ver antes de decidir que arquivo abrir.
- Nenhuma cerimônia desnecessária: sem customize.toml, sem scripts, sem seções de ativação numeradas para uma skill que não tem config nem estado — confirmado por três lentes independentes.
- Roteamento limpo em dois arquivos carveados por relevância (Conversas vs. CRM), cada um usável de forma independente.

## Recommendations

1. Nenhuma ação pendente para o ship desta versão — os achados high/medium acionáveis já foram aplicados nesta sessão. (resolves: architecture-3, architecture-4, architecture-5, enhancement-1)
2. Quando o fluxo real de agendamento/CRM do n8n for construído, validar ao vivo se o filtro RDQL `phone:` do CRM aceita o mesmo formato de número que o Conversas devolve, em vez de confiar só na normalização documentada aqui. (resolves: determinism-1)

## Experience

- **Construir nó de envio de mensagem no Conversas** — Abrir SKILL.md para o aviso de tenant/gotchas -> references/conversas.md para method/path/body form-urlencoded -> montar o nó.
- **Mover negociação de etapa no funil do CRM** — Abrir SKILL.md para o aviso de pipeline_id read-only -> references/crm.md para GET stages (casar nome->id) e PUT /deals/{id} com stage_id.
- Headless: Não aplicável — skill de referência sem modo headless ou multi-turno.

## Findings

### High (1)

#### enhancement-1 — Identificação de contato no CRM — o join central do PRD — ficava rasa enquanto o equivalente do Conversas estava completo

- Lens: enhancement
- Location: `references/crm.md (Contatos do CRM) vs. references/conversas.md (Contatos)`
- Evidence: Conversas tinha tabela completa de endpoints e schema de contato, incluindo busca dedicada por telefone; CRM tinha só uma linha de slugs sem path, sem schema, sem confirmar se existe busca por telefone — exatamente o recurso do qual depende casar o mesmo tutor entre os dois produtos.
- Recommendation: Corrigido nesta sessão: seção expandida com endpoints reais, schema de `Contact`, o filtro RDQL `phone:` (não existe endpoint dedicado como no Conversas) e o gotcha de formato de telefone divergente entre os dois produtos.

### Medium (3)

#### architecture-3 — SKILL.md multi-arquivo sem o bloco canônico de Resolution rules

- Lens: architecture
- Location: `SKILL.md`
- Evidence: SKILL.md roteia por caminho relativo para dois arquivos em references/ sem o bloco padrão que skill-quality-principles.md exige nesse caso.
- Recommendation: Corrigido nesta sessão: bloco de Resolution rules adicionado logo após o parágrafo de abertura.

#### determinism-1 — Casamento de nome de etapa do funil para stage_id descrito em prosa, não oferecido como script

- Lens: determinism
- Location: `references/crm.md (Funis e etapas)`
- Evidence: É uma busca determinística de duas chamadas (listar etapas, casar por `name`) com uma única resposta correta — exatamente o tipo de plumbing que o teste de determinismo atribui a um script.
- Recommendation: Não construir agora (não é reimplementado em nenhum fluxo ainda). Se a lógica for reimplementada em mais de um fluxo n8n, valer a pena um helper pequeno de lookup.

#### enhancement-2 — Webhooks do CRM — único recurso REST de webhook real — recebem o mesmo tratamento raso de recursos periféricos

- Lens: enhancement
- Location: `references/crm.md (Outros recursos disponíveis)`
- Evidence: O CRM tem API REST completa de webhooks (ao contrário do Conversas, que é só configuração via painel), mas hoje aparece como a mesma lista de slugs dada a recursos secundários como tarefas ou empresas.
- Recommendation: Adiado por design: promover para uma subseção com tabela de endpoints e formato de evento/payload quando um fluxo real de notificação disparado pelo CRM (ex.: mudança de etapa) for de fato construído.

### Low (5)

#### architecture-1 — Pre-pass 'missing ## Overview / ## On Activation' é falso positivo

- Lens: architecture
- Location: `SKILL.md:6-8`
- Evidence: O parágrafo de abertura já cumpre o papel de Overview (o que é, quem consome, o que está em jogo); a skill não tem config, resume nem customize.toml para justificar passos numerados de ativação.
- Recommendation: Descartar o flag do pré-passe para esta skill; não adicionar cabeçalhos cerimoniais.

#### architecture-2 — Pre-pass '.memlog.md deveria estar em references/' mal aplica a regra geral de carve-out

- Lens: architecture
- Location: `.memlog.md`
- Evidence: O memlog é trilha de decisão da construção, não conteúdo de prompt carveado — o próprio build-process.md do builder instrui escrevê-lo exatamente em `{target-skill-path}/.memlog.md`.
- Recommendation: Manter .memlog.md na raiz da skill; não mover para references/.

#### architecture-4 — Descrição usava condições tópicas em vez de frases entre aspas

- Lens: architecture
- Location: `SKILL.md frontmatter`
- Evidence: O formato padrão pede '[resumo]. [Use when user says "frase" ...]' com frases citadas; a versão original descrevia contextos, não frases.
- Recommendation: Corrigido nesta sessão: descrição reescrita com frases entre aspas ('RD Station API', 'RD Station CRM', 'RD Station Conversas').

#### architecture-5 — Ponteiros decorativos de referência cruzada (reference-to-reference e back-reference)

- Lens: architecture
- Location: `references/conversas.md; references/crm.md`
- Evidence: conversas.md apontava para crm.md e crm.md apontava de volta para SKILL.md, violando a regra de references ficarem a um nível só e não se referenciarem entre si — ainda que o fato substantivo já estivesse restatado inline em ambos.
- Recommendation: Corrigido nesta sessão: os dois ponteiros parentéticos foram removidos, mantendo só a frase substantiva.

#### determinism-2 — Rotação do refresh_token do CRM é sequência determinística documentada só como aviso em prosa

- Lens: determinism
- Location: `references/crm.md (Autenticação); SKILL.md (gotchas)`
- Evidence: Descartar o token antigo e persistir o novo a cada renovação é comportamento determinístico cuja violação causa falha silenciosa — mas o n8n nativo já automatiza isso na maioria dos casos via seu tipo de credencial OAuth2.
- Recommendation: Não construir agora. Só vale um helper se algum fluxo precisar gerenciar o token manualmente fora do tipo de credencial nativo do n8n.
