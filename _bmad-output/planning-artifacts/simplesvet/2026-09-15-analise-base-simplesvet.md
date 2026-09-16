# Análise da base do SimplesVet — export de 2026-09-09

Fonte: `_bmad-output/reference/simplesvet/banco/` (fora do versionamento). **65 CSVs, 1,3 GB** (não 18 GB). Prefixos: `adm_` administração, `glo_` pessoas/contatos, `vet_` clínico/agenda, `eco_` comercial, `fin_` financeiro, `vw_` views.

Objetivo do recorte: responder o que estava travando a arquitetura — **como a agenda e a escala existem hoje**, e o que precisa ir para a interface.

---

## 1. O modelo de agenda (a descoberta que muda a arquitetura)

Três tabelas sustentam tudo:

| Tabela | Linhas | O que é |
|---|---|---|
| `vet_fila` | 113 (54 ativas) | Uma **agenda**. Colunas: código, nome, usuário vinculado, status, permanente. |
| `vet_filaescala` | 31.193 | **A escala**: `(fes_dat_data, fil_int_codigo)` — uma linha = "esta agenda está aberta neste dia". |
| `vet_agenda` | 66.564 | **O compromisso**: data + hora + fila + tipo de atendimento + pessoa + animal + telefone + status. |

### 1.1 "Fila" não é profissional — é recurso

As 54 filas ativas misturam três naturezas:

- **Consultórios**: `Consult.1 - Clínica Dr Jorge`, `Consult.1 - Clínica Dra Érika`, `Consult.2 - ClÍnica Dr Pedro`, `Consult.3 - Fisioterapia + Especialistas`, `Consul.4 - Especialistas`, `Consult onc-1`, `Consult onc-2`
- **Salas e equipamentos**: `Imagem1 Nouvet (Usg/Rx/Tomo)`, `Imagem2 (Rx/Tomog)`, `Sala de Infusão`, `Sala de Acompanhamento Família`, `Laboratório Nouvet`, `Anestesia Nouvet`, `Cirurgia Nouvet`, `Clinica Nouvet`, `Especialistas Nouvet`, `Escola Nouvet`, `Transporte Nouvet`
- **Pessoas nominais**: ~35 (Marcele Carvalho, Kaio Silva da Costa, Patrícia Colfera, Eduarda Araujo Silva, Jorge Vilela, Erika Ricci, …)

E os recursos de **maior volume são salas, não pessoas** — `Imagem1` sozinho tem 4.406 compromissos em 2026, mais que qualquer pessoa.

> **Consequência direta**: a premissa "um calendário Outlook por profissional" está errada. É **um calendário por recurso**. A Microsoft tem exatamente esse conceito — *room mailbox* e *equipment mailbox* (resource mailboxes), que não consomem licença e suportam reserva automática. Isso **substitui** a ideia de caixa compartilhada por profissional na solicitação ao Rui.

### 1.2 A escala é por DIA, sem hora

`vet_filaescala` tem só data + fila. Não existe hora de início/fim, nem turno.

- Período: **2022-10-20 → 2027-09-09**; **6.642 linhas futuras** — a escala é planejada com até um ano de antecedência.
- Recursos fixos ficam abertos todos os dias (Anestesia, Cirurgia, Clinica, Consul.4, Consult.3, Imagem1, Sala de Acompanhamento: 62/62 dias no período analisado).
- Pessoas **rodam**: 53, 53, 52, 50, 47, 46, 44, 43, 35, 30 dias em 62. É rotativo, não semana fixa.
- Por dia: **20–22 recursos** em dia útil, **17** no sábado, **9** no domingo.

**O horário real é emergente, não declarado** — deriva do uso da agenda. Janela efetiva por recurso em 2026 (percentis 5–95):

| Recurso | Janela | Compromissos |
|---|---|---|
| Imagem1 Nouvet (Usg/Rx/Tomo) | 9h–20h | 4.406 |
| Marcele Carvalho | 10h–17h | 1.456 |
| Consult.1 - Clínica Dra Érika | 8h–19h | 1.423 |
| Patrícia Christina Saggiona Colfera | 9h–16h | 1.332 |
| Eduarda Araujo Silva | 11h–20h | 1.307 |
| Kaio Silva da Costa | 10h–17h | 1.283 |
| Consult.2 - ClÍnica Dr Pedro | 8h–16h | 1.264 |
| Consult.1 - Clínica Dr Jorge | 8h–19h | 1.129 |
| Imagem2 (Rx/Tomog) | 9h–12h | 1.008 |
| Consult.3 - Fisioterapia + Especialistas | 9h–18h | 951 |
| Consult onc-1 | 8h–14h | 632 |
| Clinica Nouvet | 0h–23h | 610 |
| Transporte Nouvet | 8h–15h | 405 |

A clínica é 24h, mas a agenda vive entre **8h e 18h** (pico 9h–11h e 14h–16h). Fora disso é internação/emergência.

### 1.3 Não existe duração

Nem `vet_agenda` nem `vet_tipoatendimento` têm campo de duração. A grade é convenção:

| Minuto | % |
|---|---|
| `:00` | 67,6% |
| `:30` | 25,5% |
| `:45` | 3,7% |
| `:15` | 3,2% |

Ou seja: **grade de 30 minutos**, com exceções de 15.

**Como funciona hoje, então?** A recepção escolhe um horário livre na grade e deixa o espaço que julga necessário — é julgamento humano, não regra de sistema. Duas evidências:

- **97,8% dos slots (recurso + data + hora) têm exatamente 1 compromisso** — 2,2% têm 2 (encaixe) e 0,02% têm 3. Então a grade é respeitada na prática, mesmo sem o sistema impor.
- `age_int_ordem` é um contador sequencial do dia por recurso (1, 2, 3…), não ordenação dentro do mesmo horário.

A **duração praticada** dá para medir pelo intervalo até o compromisso seguinte no mesmo recurso (é duração + folga, então é teto, mas a moda aproxima bem o slot pretendido):

| Serviço | Mediana | Moda | n |
|---|---|---|---|
| Avaliação Check in Pet — Banho e tosa | 75' | 60' | 3.476 |
| Ultrassom | 45' | 45' | 2.873 |
| Retorno pós Internação | 45' | 45' | 1.288 |
| Raio X | 45' | 45' | 1.133 |
| Consulta Geral | 60' | 60' | 954 |
| Coleta de exames (laboratório) | 30' | 15' | 729 |
| Almoço | 60' | 60' | 708 |
| Cirurgia | 60' | 60' | 613 |
| Consulta Especializada | 60' | 60' | 579 |
| Visita — internação | 30' | 15' | 526 |
| Internamento | 60' | 60' | 337 |
| Transporte — Leva e Traz | 45' | 30' | 229 |
| Consulta Emergencial | 60' | 60' | 218 |
| Vacinação | 45' | 45' | 201 |
| Exames Cardiológicos | 45' | 45' | 153 |
| Tomografia | 45' | 45' | 142 |

Isso muda a pergunta ao Nouvet: em vez de pedir que inventem durações, pedimos que **confirmem ou ajustem** esta tabela.

---

## 2. Volume e desfecho (os números que faltavam)

**~2.400 agendamentos/mês** (2.403 em jul/2026, 2.356 em ago/2026). Base total: 66.564 compromissos, 2023-02-02 → 2027-08-30.

| Status | Qtd | % |
|---|---|---|
| Atendido | 45.375 | **68,2%** |
| Atrasado | 8.235 | **12,4%** |
| Cancelado | 5.111 | **7,7%** |
| Agendado | 3.175 | 4,8% |
| Em espera | 1.695 | 2,5% |
| Confirmado | 1.647 | **2,5%** |
| Em atendimento | 1.312 | 2,0% |

Três leituras:

1. **Não existe status "Faltou"**. `Atrasado` é o desfecho de compromisso cuja hora passou sem evolução — é o proxy de no-show/abandono. **Atrasado + Cancelado = 20,1%** dos agendamentos não viram atendimento.
2. **Só 2,5% chegam a "Confirmado"** — confirmação prévia praticamente não acontece hoje. É exatamente o que um lembrete automático ataca, e é o indicador mais defensável de sucesso do produto.
3. ~7 linhas do export estão corrompidas (texto de observação vazou para colunas de status por quebra de linha dentro de campo). Irrelevante para análise, **relevante para o importador**: o parser precisa aguentar CSV com quebras dentro de aspas.

---

## 3. Mix de serviços — recalibra o escopo do agente

Top do que efetivamente ocupa a agenda (66.564 compromissos):

| Tipo de atendimento | % |
|---|---|
| **Avaliação Check in Pet - Banho e tosa** | **29,6%** |
| ~~Chamada Escola Nouvet~~ | ~~14,2%~~ — **serviço descontinuado** (informado por Thiago em 15/09) |
| Retorno pós Internação | 8,4% |
| Ultrassom | 8,3% |
| Consulta Geral | 5,2% |
| *Almoço* (bloqueio) | 4,9% |
| **Transporte - Leva e Traz** | **4,3%** |
| Consulta Especializada | 3,8% |
| Coleta de exames (laboratório) | 3,6% |
| Raio X | 3,3% |
| Cirurgia | 2,3% |
| Internamento | 1,7% |
| **Vacinação** | **1,5%** |
| Visita - internação | 1,2% |
| Anestesia | 1,1% |
| Consulta Emergencial | 1,1% |
| Tomografia | 0,6% |
| Consulta Oncológica - Novo Caso | 0,5% |
| Retorno Oncológico | 0,4% |
| Consulta Dermatológica | 0,4% |
| Exames Cardiológicos | 0,3% |
| Consulta Odontológica | 0,3% |

**O que isso obriga a rever no escopo dos 5 setores:**

- **Care Center (banho e tosa) é 29,6% da agenda** — quase um terço. Era o setor que o bot levaria até o fim; o dado confirma que é a aposta certa, e por larga margem.
- **Vacinas é 1,5%.** Era um dos 5 setores com fluxo próprio. O custo de construir não se paga pelo volume — reavaliar prioridade, não necessariamente cortar.
- **Imagem (Ultrassom + Raio X + Tomografia) = 12,2%**, o segundo maior bloco clínico, e hoje tratado só como "Exames → Orçamentos".
- **"Chamada Escola Nouvet" era 14,2% da agenda histórica, mas o serviço não existe mais** (informado por Thiago em 15/09). Consequências: o segundo maior item do histórico sai do escopo; a fila `Escola Nouvet` e o tipo `Avaliação Comportamental - Escola` não entram na migração; e **as fatias relativas dos demais serviços aumentam** — Banho e tosa passa de 29,6% para ~34,5% do volume remanescente. Também derruba parte do transporte (40% dos dias com transporte envolviam a Escola).
- **"Transporte - Leva e Traz" é 4,3%**, com fila `Transporte Nouvet` (8h–15h) e categoria comercial `Transporte Pet`. Também não foi mencionado. **Pergunta aberta.**
- **"Retorno pós Internação" é 8,4%** — é agendamento de retorno, disparado pela alta. Fluxo proativo, não reativo.
- **"Almoço" ocupa 4,9% da agenda** como bloqueio. Qualquer leitura de disponibilidade tem que entender bloqueios, não só compromissos.

---

## 4. Especialidades e catálogo — são dois catálogos, não um

- **`vet_tipoatendimento`** (49 ativos): o que a **agenda** usa. Inclui bloqueios (`Almoço`).
- **`eco_tipoproduto`** (32 ativos, hierárquico): o catálogo **comercial**. Raiz → filhos:
  - `Black Pet` · `Transporte Pet` · `Pet Shop` (Coleiras e Guias, Higiene e Beleza, Rações, Roupas) · `Plano de saúde` (Internação e procedimentos correlacionados)
  - `Centro de estética` → **Banho**, **Tosa**
  - `Clinica` → Aluguel de Centro Cirúrgico e Taxas, Anestesia, **Cardiologia - Exames**, Células Tronco, **Cirurgias**, **Consulta Especializada**, **Consultas**, **Dermatologia**, Destino do paciente, Farmácia, **Fisioterapia**, **Imagem - Raio X, Ultrassom, Tomografia**, Internamento, **Laboratório**, Laboratório de Apoio, **Oncologia**, Procedimentos Médicos Ambulatoriais, Serviços Diversos, **Vacinas**
- **`eco_produto`**: **3.132 itens com preço** (`pro_dec_preco`, `pro_dec_custo`, lista de preço, status).

> As "20+ especialidades" que o Thiago citou são essa hierarquia comercial. **E existe tabela de preços.** Isso reabre uma decisão de produto: o setor Orçamentos foi desenhado como "nunca informa valor". Com `eco_produto` importado, informar preço de itens simples (banho, tosa, consulta) passa a ser tecnicamente possível. **Decisão de produto do Nouvet, não nossa** — mas agora é uma opção real.

---

## 5. Identidade (import do go-live)

| Tabela | Linhas |
|---|---|
| `glo_pessoa` | 4.581 |
| `glo_contato` | 9.504 |
| `vet_animal` | 5.740 |
| `vet_especie` | 13 |

`glo_contato` tem `tco_var_nome` (tipo do contato), `con_var_contato` (o valor) e **`con_var_preferencial`** — ou seja, dá para saber qual telefone é o preferencial de cada pessoa. São ~2,1 contatos por pessoa: a desambiguação de telefone tem que ser resolvida no import.

`vet_agenda` também carrega `age_var_telefone` direto no compromisso — útil para casar contato do WhatsApp com histórico de agendamento sem passar por `glo_pessoa`.

O `clientes.csv` usado na Story 1/4 do Piloto (5.671 linhas) é compatível em ordem de grandeza com `vet_animal` (5.740) — provavelmente era um export por animal, não por pessoa. **O schema de `identidade_cliente_pet` deve ser redesenhado a partir de `glo_pessoa` + `glo_contato` + `vet_animal`, não do CSV antigo.**

---

## 6. O que isso decide, e o que abre

**Decide:**
1. Outlook usa **resource mailboxes por recurso** (sala/equipamento/consultório), não caixa por profissional.
2. A escala que precisa ir para a nossa interface é **(recurso × dia)** — granularidade dia, com rotação. Não é grade de horas.
3. **Horário de funcionamento por recurso e duração por serviço não existem no SimplesVet** — são dado novo, que nasce na nossa interface. É o primeiro conteúdo que o Nouvet vai ter que preencher.
4. O indicador de sucesso mais forte já tem linha de base: **2,5% de confirmação prévia** e **20,1% de compromissos sem atendimento**.
5. Care Center é o maior volume por larga margem (29,6%) — o foco está certo.

**Abre (perguntas para o Nouvet):**
1. O que é a **Escola Nouvet** (14,2% da agenda)? Entra no escopo do agente?
2. O que é **Transporte - Leva e Traz** (4,3%)? É agendável pelo cliente?
3. **"Retorno pós Internação" (8,4%)** — quem agenda hoje, e deveria ser proativo do agente?
4. Confirmar **duração padrão por tipo de atendimento** — não existe no sistema, alguém precisa ditar.
5. Confirmar **horário de funcionamento por recurso** — hoje é convenção, não dado.
6. **Orçamentos**: com a tabela de preços disponível, o agente pode informar valor de itens simples, ou mantém a regra de nunca informar?
7. Os 2 consultórios de oncologia (`Consult onc-1`, `onc-2`) e a exceção da **"Rose"** — como se relacionam?
