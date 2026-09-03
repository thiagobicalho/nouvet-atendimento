---
title: 'Sprint Change Proposal — Correção estrutural pós-Stories 1/2/3/4'
date: '2026-09-02'
prepared_por: Claude (correct-course) + Thiago Bicalho (Btech.Cloud)
status: approved
scope: minor
---

# Sprint Change Proposal — Atendimento Nouvet (Piloto)

## 1. Issue Summary

Durante a review humana das Stories 1, 2, 3 e 4 (já commitadas via `bmad-loop`), Thiago identificou que a arquitetura reaproveitou estrutura do template de referência (`secretariav3-completo`) sem validar se ela fazia sentido pro Nouvet:

- **Nomenclatura:** tabelas/função nomeadas `secretaria_*`, copiadas do template sem nunca ter sido apresentado como decisão a Thiago (`ARCHITECTURE-SPINE.md` linha 130 dizia "reaproveitando os nomes já usados no padrão de referência" — só o naming de *workflow*, não o de tabela, foi de fato confirmado por ele).
- **Tabela órfã:** `secretaria_profissionais` criada na Story 1, nunca lida/escrita por nenhuma das 15 stories planejadas — veio por analogia com os workflows de agendamento real do template `clinica/`, que este Piloto explicitamente não faz (AD-4).
- **Schema chutado:** `identidade_cliente_pet` (Story 1) tinha só 4 colunas de negócio porque o export real do SimplesVet do Nouvet nunca tinha chegado — resolvido silenciosamente com um chute, sem tag `[ASSUMPTION]`/Open Question (diferente do tratamento dado a outras pendências de dado real no projeto).
- **Causa raiz mecânica:** Story 2 e Story 3, em `stories.yaml`, não tinham `spec_checkpoint` nem `done_checkpoint` configurados — rodaram no loop sem nunca pausar pra revisão do Thiago. É por isso que os achados acima só foram vistos depois do loop já ter avançado 4 stories.

Investigação adicional durante a sessão trouxe dado real (export SimplesVet do Nouvet — `_bmad-output/reference/clientes.csv`, print de tela do cadastro) e resolveu duas pendências conexas: a ambiguidade de Consultas/Vacinas como setor único ou distinto (`deferred` da Story 2, DW-13/DW-17), e a estrutura do `systemMessage` do agente (Story 5, ainda não planejada).

## 2. Impact Analysis

**Impacto em Stories** (este projeto usa o fluxo de Spec — `SPEC.md`/`stories.yaml`/stories individuais — não `epics.md`; "story" faz aqui o papel de "epic"):

- Stories 1, 2 e 4 (já commitadas): recebem patch aditivo (migrations novas, nunca edição das já commitadas). Nenhuma vira obsoleta.
- Story 3: sem impacto (debounce/lock não toca nada do achado).
- Stories 5-15 (não iniciadas): checkpoint de review passa a ser obrigatório em todas. Story 5 (CAP-1) e Story 8 (CAP-4) ganham nota de orientação adicional.
- Nenhuma story nova necessária, nenhum resequenciamento.

**Conflito com artefatos:**
- PRD: nenhum — correção de implementação, não de requisito.
- Arquitetura: sim — `ARCHITECTURE-SPINE.md` (naming, tabela de estrutura, Consultas/Vacinas).
- UI/UX: N/A (projeto não tem esse artefato).
- Outros: `stories.yaml`, `deferred-work.md`, migrations SQL, READMEs de `migrations`/`seed`.

**Impacto técnico:** 3 migrations novas (append-only, nunca editando `0002`-`0006` já criadas), 1 arquivo de seed renomeado, sem nenhuma execução contra Postgres real (nada foi deployado ainda — todo o build até aqui rodou em ambiente sem Docker, validado via mirror Python/pglite).

## 3. Recommended Approach

**Opção escolhida: Ajuste Direto (Option 1)**, com uma regra adicional: nunca editar migrations já criadas — sempre migration nova (mesma disciplina que a `0006` já usou sobre a `0003`).

**Por quê:** nada foi deployado a um Postgres real ainda, então o risco de reescrever histórico de migration é baixo, mas a disciplina de "sempre aditivo" evita desincronizar de um eventual ambiente de dev já provisionado. Rollback (Option 2) não se aplica — nada precisa ser revertido, é patch pra frente. Revisão de MVP do PRD (Option 3) não se aplica — é correção de implementação, não mudança de escopo/requisito.

**Esforço:** médio (muitos arquivos, pouca complexidade cada um). **Risco:** baixo.

## 4. Detailed Change Proposals

### 4.1 — Renomear `secretaria_*` → `atendimento_*`
**Arquivo novo:** `n8n/migrations/0007_renomear_atendimento.sql`
```sql
ALTER TABLE secretaria_config RENAME TO atendimento_config;
ALTER TABLE secretaria_profissionais RENAME TO atendimento_profissionais;
ALTER FUNCTION secretaria_config_ler(TEXT, TEXT) RENAME TO atendimento_config_ler;
```
Rationale: nomes reaproveitados do template sem decisão do Thiago. Tabelas `n8n_*` e `identidade_cliente_pet` não mudam.

### 4.2 — Redesenhar `atendimento_profissionais` e conectar na leitura seletiva
**Arquivo novo:** `n8n/migrations/0008_atendimento_profissionais.sql`
- `setor` (coluna única) → `setores TEXT[]` (array — um profissional pode atender mais de um setor) + `UNIQUE (nome)`.
- `atendimento_config_ler`: novo campo `profissionais`, só na fatia `setor` (nunca `triagem`), filtrado por `p_setor = ANY(setores) AND ativo = true`.

Rationale: tabela criada vazia na Story 1, nunca conectada a nada — motivo real de existir é o agente responder "quais profissionais vocês têm?" sem inventar nome (FR-30/31).

### 4.3 — `identidade_cliente_pet` com campos reais
**Arquivo novo:** `n8n/migrations/0009_identidade_cliente_pet_campos_reais.sql`
Novas colunas: `cpf`, `rg`, `data_nascimento_cliente`, `email` (responsável); `endereco`, `bairro`, `cidade`, `uf`, `cep` (endereço); `pelagem_pet`, `esterilizado_pet`, `pedigree_pet`, `microchip_pet`, `vivo_pet`, `data_nascimento_pet`, `simplesvet_codigo_animal` (animal).

Rationale: schema original (Story 1) tinha 4 colunas chutadas — export real do SimplesVet (`_bmad-output/reference/clientes.csv`) nunca tinha chegado. Deliberadamente EXCLUÍDO: campos comerciais/analíticos (NPS, ranking ABC, valores pagos) — papel do RD CRM, não da identidade rápida (AD-6). Excluído também `telefones_adicionais`/`tags_cliente` (propostos e depois cortados nesta mesma sessão por falta de consumidor concreto).

**Gap aberto (DW-43):** `identidade_cliente_pet_resolver` (0006) ainda não escreve os campos novos — precisa ser estendido antes do import real rodar.

### 4.4 — `stories.yaml`
- `spec_checkpoint: true` + `done_checkpoint: true` em todas as stories 5-15 (nenhuma tinha `spec_checkpoint`; a causa raiz de Story 2/3 terem passado sem review).
- Story 2: naming atualizado + decisão Consultas/Vacinas registrada.
- Story 5: nota completa sobre esqueleto de prompt (baseado em `01 - Secretária V3.json`, com divergências obrigatórias documentadas — sem agendamento real, sem Asaas, sem pacing de texto, ramificado por 5 setores, guardrails de alerta/emergência em destaque).
- Story 8: nota reforçando os 2 setores distintos.

### 4.5 — `ARCHITECTURE-SPINE.md`
Naming corrigido (linha 130), diagrama e tabela de "Tabelas do banco dedicado" atualizados com os nomes/papéis reais.

### 4.6 — `deferred-work.md`
DW-13/DW-17 marcados `resolved` (Consultas/Vacinas). Novos: DW-42 (profissionais sem dado real), DW-43 (resolver não escreve campos novos).

### 4.7 — READMEs
`n8n/migrations/README.md` e `n8n/seed/README.md` atualizados; seed renomeado para `0001_atendimento_config.sql`.

## 5. Implementation Handoff

**Classificação: Minor** — patch direto sobre artefatos já existentes, sem mudança de requisito/PRD/escopo. Implementado nesta própria sessão (Claude, papel de Developer neste workflow), com Thiago revisando e aprovando cada proposta em modo Incremental.

**Próximo passo (fora do escopo desta proposta, já combinado com Thiago):** dispatch de 11 runs independentes do `bmad-loop` (`--story 5` até `--story 15`), cada uma parando no `spec_checkpoint` sem nunca ser resumida, até Thiago revisar as 11 stories planejadas de uma vez — só então autorizar builds, uma story por vez.

**Pendências que ficam abertas, não bloqueiam o build (bloqueiam só o go-live de 08/09):**
- DW-42: dado real de profissionais por setor.
- DW-43: `identidade_cliente_pet_resolver` estender pra escrever os campos novos.
- Import real do `clientes.csv` (última ação antes do go-live).
- Decisão de junção/separação — se ainda não fechada — de setores fora do escopo do Piloto (Internação/Oncologia/Financeiro nunca usados como `p_setor`).

**Success criteria:** as 11 runs de Plan produzem stories 5-15 completas (intent-contract, tasks, AC) sem nenhuma ir pro Implement; Thiago revisa o pacote inteiro; só depois disso qualquer `bmad-loop resume` é autorizado.
