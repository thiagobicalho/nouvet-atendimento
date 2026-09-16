# Levantamento RD Conversas — achados de 11/09/2026 (para levar ao Nouvet)

Fonte: API v2 do Conversas (`employees_list`, `wallets_list`), doc oficial (`developers.rdstation.com`) e painel (prints do Thiago). Contexto: o produto novo transfere para humano **sempre por dentro do RD**, via `POST /v2/forward-to-customer {customer, flow}` → fluxo do RD → "encaminhar para fila de espera sequencialmente" → departamento. O RD faz o rodízio; nós escolhemos o departamento, nunca a pessoa.

## 1. Cadastro de funcionários — inconsistências a resolver com o Nouvet

| Achado | Contas encontradas | Pergunta para o Nouvet |
|---|---|---|
| Zeila da recepção: duas contas com grafias diferentes | `Zêila Moreira` (zeila.moreira@) e `Zélia Moreira` (zelia.moreira@) | Qual é a conta ativa? A outra deve ser desativada? |
| Larissa da recepção: duas pessoas | `Larissa Costa` (larissa.costa@) e `Larissa Araújo` (larissa.araujo@) | Qual Larissa responde o RD na recepção? |
| Débora Oliveira: cinco contas | debora.oliveira@, debora.silva@nouvet.com.**bt** (typo), debora.silva@, recepcao_1andar@, debora.olveira@ (typo) | Qual é a real? As demais são lixo de cadastro? |
| Contas genéricas/compartilhadas | Marketing Nouvet, Internação Nouvet, Internação 2 (2 contas: internacao2@ e internacao1@), Financeiro, Veterinários Nouvet, Gestão TI | Alguma delas deve receber transferência do bot? (padrão: não) |
| Externo | jonathan@tidos.com.br | Ainda deve ter acesso? |

Confirmados existentes (grafia do RD):
- **Orçamentos**: Leticia Mota, Simone Lopes Costa, Danielle Alcântara Alves, Edson Candido.
- **Recepção**: Kátia Valéria da Silva Souza, Gabriela Calixto Souza, Airton Junior, Marcela Santos, Giovanna Silva, Suzany David, Gislaine Oliveira (+ Zeila e Larissa a confirmar acima).

## 2. Estrutura que precisa existir no RD antes do go-live

- **Departamentos**: `Atendimento IA` (setor exclusivo do bot, **sem nenhum atendente humano** — a conversa fica em `queue_wait` neste setor enquanto o bot atende via API; nenhum humano vê essa fila), `Orçamentos` e `Recepção`, com as pessoas acima. Nos fluxos de transferência usar a opção **"Vai direto para o próximo atendente"** (é o rodízio); no fluxo de entrada do bot usar **"Aguarda na fila até ser escolhido"**. Excluir o setor `Atendimento IA` dos relatórios de tempo de espera do próprio RD (senão a métrica vira lixo).
  - **Criado em 11/09** pelo Thiago: `Atendimento IA`, id `atendimento_ia_c7c76`, expediente 24h, sem funcionários. **Regra descoberta na prática**: um setor só aparece no dropdown "Encaminhar para fila" das automações se **"Configuração de exibição do menu" = Ativado** — não depende de ter funcionário. Manter ativado. Hoje existem "Recepção Clínica" e "Recepção Care Center" (vistos na automação antiga) — decidir se viram um só `Recepção` ou se o bot escolhe entre os dois.
- **Fluxos de transferência** (um passo cada, só "encaminhar para fila de espera sequencialmente"): `→ Orçamentos`, `→ Recepção`. O bot chama `forward-to-customer` com o ID do fluxo (`conversas-v2-list-flows`).
- **Como uma automação "liga"**: no RD, a automação de entrada é a que tem o **canal** atribuído (lista "Fluxos de Automação" mostra os badges WhatsApp/Telegram/Facebook). Ativar a nova = mover o canal WhatsApp do "Fluxo Simples 31.08.26" para ela. Fluxos que só servem de alvo de `forward-to-customer` (transferências) **não recebem canal**.
- **Automação de entrada**: substituir o fluxo atual (boas-vindas + OPT-IN + menu Clínica/Care Center + fila) por **OPT-IN + encaminhar para fila** — sem mensagem, sem passo que espere resposta. Decisão de 11/09 (Thiago confirmou).
- **Webhook** (`Integrações > Webhooks`): manter `Automação` + `Fila de espera` marcados (o bot precisa dos dois); `Em atendimento` só se o teste noturno mostrar que precisamos dele para detectar encerramento.
- **Carteiras** existentes: "Veterinários Encaminhantes", "Marketing", "Em andamento" — não são mecanismo de roteamento; ignorar.

## 2b. Fluxos de automação existentes (via `GET /v2/flows`, 11/09)

| ID | Título | Observação |
|---|---|---|
| 68934f1ad2af75001358c128 | Principal | antigo? (não aparece com canal) |
| 697cb58d697ab302c6117bec | Principal v2 | antigo? |
| 6a95ed686455e7a055b5fb84 | Fluxo Simples 31.08.26 | **entrada atual** do WhatsApp principal + Telegram + Facebook |
| 69c694c5d1e8213e7f40c902 | Care Center | entrada do 2º número WhatsApp |
| 68d141b5767c80e99a38494d | Ação de Marketing - sem fila | marketing |
| 68e43f04b5c1740fec7d6a61 | NPS | **candidato a reaproveitar** para avaliação pós-atendimento/pós-consulta |
| 6a6a496992be8f956849cf7e | Site – Atendimento | entrada de outro canal (site?) |
| 69c19eaffdce246fa3e2ef05 | Ordem Númerica_principal | ? |
| 69ef9f21e56a0105a08fa4b3 | Internação Encerramento_ | internação |
| 6aa46e57dc96595e4ab5a6cb | TESTE IA | criado 11/09 (Thiago) — futura entrada do bot |
| 6aa47e8c0779a0112ce0a862 | Recepção Teste IA | criado 11/09 (Thiago) — alvo de transferência de teste |

Gotcha de API: o campo do nome vem como **`titulo`**, não `title` como diz a doc. Perguntar ao Nouvet o que fazem "Principal", "Principal v2", "Ordem Númerica_principal" e "Site – Atendimento" antes de desligar qualquer um.

## 3. Perguntas abertas para o Nouvet

1. O que é **"Oncologia"** no atendimento? Departamento, especialidade de consulta, ou fila própria? Como o bot deve tratar?
2. Quem é o responsável por manter o cadastro de funcionários no RD daqui em diante (desativar duplicatas, incluir novos)?
3. Um atendente que **finaliza** a conversa no painel: isso existe como ação? (Define como o bot volta a assumir a conversa.)
4. **Oncologia**: segue Consultas (consulta com especialidade oncologia), mas em alguns casos pós-consulta o atendimento é encaminhado para a **"Rose"**. Quem é a Rose e qual é a conta dela no RD? (Não há ninguém com esse nome na lista de funcionários — Romilda? Raysa? outra?) Qual é o critério que define "esse caso vai pra Rose"?
5. Há **duas automações de entrada com canal WhatsApp**: "Fluxo Simples 31.08.26" (WhatsApp + Telegram + Facebook — o número principal "Nouvet") e "Care Center" (WhatsApp — presumivelmente o segundo número). O agente vai atender **os dois números** ou só o principal? Se os dois, o webhook precisa distinguir o canal (`contact.channel_label`) e o Care Center vira entrada direta no fluxo de banho/tosa. E Telegram/Facebook: o bot também atende, ou só WhatsApp?
6. Consultas tem **mais de 20 especialidades**. Precisamos da lista completa com: profissional(is) que atendem, duração padrão da consulta, e se há pré-requisito (ex.: encaminhamento). Isso alimenta a tabela de config e a escala.

## 4. Limites da API que afetam o desenho (confirmados na doc oficial)

- Não há endpoint de **opt-in/consentimento** — o opt-in fica no nó OPT-IN da automação do RD.
- Não há **transferência para operador/departamento** — só `forward-to-customer` para um fluxo.
- O payload do webhook **não traz departamento** — o estado "aguardando humano" precisa viver no nosso Postgres.
- Templates: `send-message-template` (v3) por HTTP; as variantes `filled` estão depreciadas; o node de comunidade `n8n-nodes-rdsc` não expõe templates nem transferência.
