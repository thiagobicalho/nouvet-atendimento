# Modelo de cadastro de serviço — o que precisa ser mapeado

Levantado por Thiago em 16/09: *"durante o mapeamento dos serviços da clínica temos que pensar em tudo o que temos que mapear"*. Este documento define **o conjunto completo de atributos** que cada serviço precisa ter para o agente conseguir agendá-lo — e, por consequência, o esquema da tabela de configuração e o que a interface da Btech precisa permitir editar.

---

## 1. Por que não dá para usar o catálogo do SimplesVet direto

O `eco_produto` tem **2.185 itens ativos**, mas é um **catálogo de faturamento**, não de serviços. Três problemas o tornam inutilizável como está:

**Mistura serviço com insumo.** A categoria "Banho" tem 75 itens ativos: dois são serviços (`Banho Nouvet | Cães` R$ 120,00 e `Banho Nouvet | Gatos` R$ 240,00); o resto são colônias, condicionadores e shampoos consumidos durante o banho.

**O preço é uma função, não um valor.** Exemplos reais do catálogo:

| Serviço | Varia por |
|---|---|
| Banho | **espécie** — Cães R$ 120,00 · Gatos R$ 240,00 |
| Carding (tosa) | **porte × pelagem** — P-Curto R$ 46,00 · P-Longo R$ 60,00 · M-Curto R$ 52,00 · M-Longo R$ 65,00 · G-Curto R$ 60,00 · G-Longo R$ 72,00 · GG-Curto R$ 65,00 · GG-Longo R$ 85,00 |
| Desembolo | **grau de dificuldade** — Nível I R$ 40,00 · II R$ 60,00 · III R$ 80,00 · Avançado R$ 180,00 |
| Consulta Geral | **horário** — comercial vs **Plantão** R$ 440,00 vs após as 20h |
| Consulta Especializada | **profissional** — de R$ 515,00 a R$ 960,00 conforme o especialista |
| Qualquer um acima | **plano** — variantes `|Black Pet` custam R$ 1,00 |

**Desembolo é julgamento humano.** O nível só é conhecido quando alguém vê o animal. O agente **não pode** cotar isso.

> **Conclusão:** o agente precisa de um **catálogo próprio, curado e pequeno** — só o que ele sabe agendar — com ligação para os itens de faturamento correspondentes. Esse catálogo é o que a interface de configuração da Btech mantém.

---

## 2. Atributos de um serviço

### 2.1 Identidade

| Atributo | O que é | Quem preenche |
|---|---|---|
| `nome_interno` | Como aparece na agenda (bate com `vet_tipoatendimento`) | Btech |
| `nome_cliente` | Como o agente chama o serviço na conversa | Btech |
| `sinonimos` | Como o cliente pede ("banho", "banhinho", "dar um banho") — alimenta o reconhecimento | Btech |
| `setor` | Care Center, Consultas, Imagem, Vacinas, Orçamentos | Btech |
| `onda` | 1, 2, 3 ou 4 — controla o que o agente já sabe fazer | Btech |
| `ativo` | Liga/desliga sem mexer no fluxo | Btech |

### 2.2 Agendamento

| Atributo | O que é | Quem preenche |
|---|---|---|
| `agendavel_pelo_agente` | **agenda** · **só registra pedido** (ex.: transporte) · **não agenda, transfere** | Nouvet |
| `duracao_minutos` | Tempo que ocupa o recurso | Nouvet (tabela medida) |
| `recursos_habilitados` | Quais recursos podem executar (1:N) | Nouvet |
| `grade_permitida` | Múltiplos de 30 min, ou também :15/:45 | Nouvet |
| `antecedencia_minima` | Não marcar para daqui a 10 minutos | Nouvet |
| `antecedencia_maxima` | Limite de quão longe pode marcar | Nouvet |
| `janela_permitida` | Faixa dentro do horário do recurso (ex.: banho só até 15h, para dar tempo de secar) | Nouvet |
| `dias_permitidos` | Dias da semana em que o serviço acontece | Nouvet |
| `permite_encaixe` | Se pode passar do limite do recurso | Nouvet |

### 2.3 Pré-requisitos ← *a dimensão levantada em 16/09*

| Atributo | O que é | Quem preenche |
|---|---|---|
| `exige_pedido_medico` | Serviço só acontece com pedido/encaminhamento (típico de exames) | Nouvet |
| `validacao_do_pedido` | **O que precisa ser conferido** no pedido — ver §3 | Nouvet |
| `exige_exame_previo` | Ex.: pré-anestésico antes de exame com sedação | Nouvet |
| `validade_exame_previo` | Por quantos dias o exame prévio vale | Nouvet |
| `exige_avaliacao_previa` | Precisa de consulta antes (cirurgia, anestesia) | Nouvet |
| `exige_vacinacao_em_dia` | Comum em banho/creche — e **o agente tem como saber**, via `vet_animal_vacina` | Nouvet |
| `exige_jejum` | Vira instrução ao cliente, não bloqueio | Nouvet |
| `restricao_especie` | Só cães, só gatos, ambos | Nouvet |
| `restricao_porte` | Portes atendidos | Nouvet |
| `restricao_idade` | Idade mínima/máxima (filhote, idoso) | Nouvet |

### 2.4 Preço

| Atributo | O que é | Quem preenche |
|---|---|---|
| `modo_preco` | **valor fechado** · **tabela por variação** · **depende de orçamento** | Nouvet |
| `dimensoes_preco` | Quais variáveis mudam o valor: espécie, porte, pelagem, plantão, profissional, plano | Nouvet |
| `tabela_preco` | A matriz de valores, quando `modo_preco = tabela` | Nouvet |
| `itens_faturamento` | Ligação com os códigos do `eco_produto` | Btech |
| `ressalva_preco` | Texto que acompanha o valor ("não inclui medicação") | Nouvet |
| `preco_varia_por_plano` | Se cliente Black Pet tem valor diferente — e se o agente informa | Nouvet |

### 2.5 Preparo e instruções ao cliente

| Atributo | O que é | Quem preenche |
|---|---|---|
| `instrucoes_pre` | Jejum, chegar 15 min antes, trazer carteira de vacinação | Nouvet |
| `o_que_trazer` | Documentos, exames anteriores, pedido médico | Nouvet |
| `duracao_percebida` | O que dizer ao cliente sobre quanto tempo leva (pode diferir do slot) | Nouvet |

### 2.6 Depois de agendado

| Atributo | O que é | Quem preenche |
|---|---|---|
| `lembrete_horas_antes` | Quando lembrar (pode ser mais de um) | Nouvet |
| `pede_confirmacao` | Se o lembrete pede resposta | Nouvet |
| `permite_remarcar_pelo_agente` | E até quantas horas antes | Nouvet |
| `permite_cancelar_pelo_agente` | E até quantas horas antes | Nouvet |
| `politica_no_show` | O que acontece quando o cliente não aparece | Nouvet |

### 2.7 Combinações

| Atributo | O que é | Quem preenche |
|---|---|---|
| `aceita_transporte` | Se o Leva e Traz pode ser pedido junto | Nouvet |
| `servicos_combinaveis` | O que pode ser marcado no mesmo dia/visita (banho + tosa, banho + vacina) | Nouvet |
| `ordem_na_combinacao` | Se há sequência obrigatória | Nouvet |

### 2.8 Exceções

| Atributo | O que é | Quem preenche |
|---|---|---|
| `quando_transferir` | Situações em que o agente para e passa para humano | Nouvet |
| `setor_destino` | Para qual setor do RD | Nouvet |

---

## 3. "Exige pedido médico" — o que precisa ser validado

Foi a pergunta que abriu este documento, e ela se desdobra em quatro decisões por serviço:

1. **O pedido é obrigatório para agendar, ou pode ser levado no dia?** Muda se o agente bloqueia ou apenas avisa.
2. **O agente precisa receber o arquivo, ou basta o cliente dizer que tem?** Receber significa anexo no WhatsApp — que o agente hoje sabe reconhecer, mas não interpretar.
3. **O que precisa ser conferido?** Aqui existe uma escala, e a escolha muda radicalmente o esforço:
   - **(a) Só receber** — o agente anexa à solicitação e a clínica confere no dia. *Trivial.*
   - **(b) Conferir se existe** — houve anexo, sim ou não. *Trivial.*
   - **(c) Ler o pedido** — extrair qual exame, quem pediu, data. *Exige leitura de documento/OCR; erro tem custo clínico.*
   - **(d) Validar clinicamente** — se o pedido é adequado, se está no prazo, se o profissional é habilitado. *Fora de escopo de um agente.*
4. **Pedido externo vale?** Ou só de veterinário do Nouvet?

> **Nossa recomendação para as ondas 1 a 3: nível (a) ou (b).** O agente recebe o anexo, registra que existe, e a conferência continua humana. Subir para (c) é projeto próprio, com risco clínico, e não cabe no prazo.

---

## 4. Exemplo preenchido — Banho (onda 1)

Serve como modelo do que precisa ser respondido para cada serviço. Os campos com **?** são o que falta.

| Atributo | Valor |
|---|---|
| `nome_interno` | Avaliação Check in Pet - Banho e tosa |
| `nome_cliente` | Banho |
| `sinonimos` | banho, banhinho, dar banho, banho e tosa |
| `setor` | Care Center |
| `agendavel_pelo_agente` | agenda |
| `duracao_minutos` | **?** — medido: mediana 75', moda 60' |
| `recursos_habilitados` | Marcele Carvalho, Patrícia Colfera, Kaio Silva da Costa |
| `janela_permitida` | **?** — recursos operam 10h–17h; há limite para dar tempo de secar? |
| `antecedencia_minima` | **?** |
| `exige_vacinacao_em_dia` | **?** — comum no mercado; temos o dado em `vet_animal_vacina` |
| `restricao_porte` | **?** — há porte que não atendem? |
| `modo_preco` | tabela por variação |
| `dimensoes_preco` | espécie (Cães R$ 120,00 / Gatos R$ 240,00); tosa acrescenta porte × pelagem; plano Black Pet |
| `instrucoes_pre` | **?** |
| `lembrete_horas_antes` | **?** |
| `permite_remarcar_pelo_agente` | **?** |
| `aceita_transporte` | sim — como pedido a confirmar |
| `servicos_combinaveis` | tosa, hidratação?, vacina? **?** |
| `quando_transferir` | desembolo (nível é julgamento humano), pedido fora do catálogo, animal agressivo? **?** |

---

## 5. Consequências

**Para a interface de configuração (Btech).** Não é um formulário de dez campos. É um **CRUD de serviço** com abas — identidade, agendamento, pré-requisitos, preço (com matriz de variação), instruções, lembretes, combinações, exceções. E a matriz de preço por porte × pelagem exige uma tela própria. Isso é maior do que estava dimensionado.

**Para o questionário do Nouvet.** A maior parte destes campos é resposta deles. O Bloco B hoje pergunta só duração e horário — **está incompleto**. Sugestão: em vez de perguntar campo a campo no documento, levar **uma planilha por serviço**, começando pelos da onda 1 (banho e tosa), onde eles preenchem o que só eles sabem.

**Para as ondas.** O esforço de mapeamento por serviço é alto. Isso reforça a entrega modular: mapear **dois serviços** direito (banho, tosa) é viável para 01/10; mapear quarenta não é.

**Para o modelo de dados.** A tabela de configuração de serviço tem ~35 campos, sendo vários multivalorados (recursos, sinônimos, combinações) e um matricial (preço). Não cabe em `secretaria_config` como JSON solto — precisa de tabelas próprias.
