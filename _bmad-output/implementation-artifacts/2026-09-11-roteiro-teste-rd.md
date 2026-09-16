# Roteiro do teste noturno — comportamento real do RD Conversas (11/09/2026)

Executam: Thiago (WhatsApp de teste 5511989892343 + painel do RD) e Amelia (execuções do n8n, workflow `01 - Agente`). Janela: à noite, fora do pico de clientes reais.

## Pré-condições
- [ ] Setor **`Atendimento IA`** criado no painel do RD (Configurações da empresa → setores), **sem nenhum atendente humano** (se o RD exigir alguém, só o usuário "Gestão TI"). Não há endpoint nem tool de MCP para criar setor — é manual.
- [ ] Automação `TESTE IA` (Começo → Salvar opt-in → Encaminhar para fila) apontando para o setor `Atendimento IA`, opção "Aguarda na fila até ser escolhido".
- [ ] **Número usado no teste: o do Care Center** (menor volume de clientes reais). Entrada atual desse número = automação `Care Center` (`69c694c5d1e8213e7f40c902`). Na hora do teste: **remover o canal WhatsApp da `Care Center`** (T0 = sem automação), depois **atribuir à `TESTE IA`** (T1+); ao final, devolver o canal à `Care Center`. Não tocar no "Fluxo Simples 31.08.26" nem no número principal.
- [ ] O `contact.id` do Thiago **pode ser outro** nesse canal — ler do payload do T0 e usar esse valor como `customer` no T3 (o `99` aceita `body.customer`).
- [ ] Setor **`Recepção Teste`** criado, com "exibição do menu: Ativado" e o usuário **thiagobicalho** como único funcionário (o Thiago faz o papel do atendente humano em T4/T5, sem depender da recepção real).
- [ ] Fluxo `→ Recepção (teste)`: Começo → Encaminhar para fila → setor `Recepção Teste` → "Aguarda na fila até ser escolhido". **ID obtido via API em 11/09 19:32**: `6aa47e8c0779a0112ce0a862` (`TESTE IA` = `6aa46e57dc96595e4ab5a6cb`; `Fluxo Simples 31.08.26` = `6a95ed686455e7a055b5fb84`; `Care Center` = `69c694c5d1e8213e7f40c902`).
- [ ] Thiago logado no painel do RD como thiagobicalho num navegador, e com o WhatsApp de teste no celular.
- [ ] Webhook com os 4 eventos marcados (queremos **ver** todos os `action` esta noite).
- [ ] Conversa de teste **finalizada** no painel antes de começar (para o "oi" abrir conversa nova).

## O que registrar em cada passo
`action` recebido no webhook · quantas vezes o webhook disparou · se o `POST /messages/{id}/send` do bot voltou 200 · se chegou mensagem dobrada no WhatsApp.

## Passos

| # | Ação do Thiago | Pergunta que responde | Registrar |
|---|---|---|---|
| T0 | Com a automação **desligada**: mandar `oi` | Em que estado chega a 1ª mensagem sem automação? | `action` |
| T0b | Mandar `quero marcar um banho pro Bidu` | O bot responde normalmente nesse estado? | `action`, status do send |
| — | Finalizar conversa no painel; **ligar** a automação de teste (OPT-IN + fila) | | |
| T1 | Mandar `oi quero marcar um banho pro Bidu` (uma mensagem só, com conteúdo) | Chega em `automation`? O RD dispara de novo quando vira fila (sem nova mensagem)? O bot consegue enviar durante `automation`? | `action`(s), nº de disparos, status do send, dobrou? |
| T2 | Mandar `Meu nome é Thiago, preciso agendar um banho` | Vírgula ainda derruba o fluxo atual (esperado: sim, só confirmar) | erro em `Enfileirar mensagem` |
| T3 | Amelia chama o `99 - Teste RD` (webhook `teste-rd-99`, header `x-teste-token`) com `{ "flow": "6aa47e8c0779a0112ce0a862" }` → `POST /v2/forward-to-customer` | O que chega quando o contato é encaminhado? | `action`, disparou sem mensagem? |
| T3b | Mandar `alô?` enquanto ninguém pegou | Mensagem na fila humana chega como `queue_wait`? (bot responderia — esperado: sim, é o bug que vamos prevenir) | `action` |
| T4 | Thiago (como thiagobicalho, no painel) **pega** a conversa; do celular manda `oi atendente` | Chega como `on_attendance`? | `action` |
| T5 | Thiago **finaliza** a conversa no painel; do celular manda `oi de novo` | Como sabemos que voltou pro bot? Reabre em `automation`? | `action`, disparou algo no encerramento? |

## Depois do teste
- **Desativar/apagar o `99 - Teste RD`** (webhook público que encaminha contatos — não pode ficar ativo).
- Amelia consolida os `action` por passo neste arquivo (seção "Resultados").
- Winston fecha a máquina de estados `bot | aguardando_humano | humano` a partir dos resultados.
- Murat transforma T1, T3b e T5 em cenários do harness.

## Resultados (11/09, 21h — número do Care Center)

| # | Exec. n8n | `action` recebido | Disparos | Bot enviou? | Observações |
|---|---|---|---|---|---|
| T0 | 466866 | **`all`** | 1 | sim (200) | Sem automação de entrada, a mensagem chega com `action: "all"` — é um 4º estado, corresponde ao checkbox "Todos" do webhook. `contact.id` é o **mesmo** do número principal (`6aa2aeecc80841b7d425d7aa`); `channel_label: "Care Center"`. Bot respondeu com a abertura normal. **Efeito colateral**: sem automação no canal, o RD dispara o **menu numérico de setores** da conta (Configurações da conta → "Setores de atendimento: Ativar" + "Usar números") — 8 setores (Financeiro, Recepção Clínica, Recepção Care Center, Veterinários, Gestão, **Oncologia**, Comercial, Internação); `Atendimento IA` e `Recepção Teste IA` **não** aparecem nele. Conclusão: canal nunca pode ficar sem automação de entrada em produção. A mensagem "Olá! Ainda estamos por aqui…" (21:13) **é nossa**: workflow `06 - Lembretes e Escalonamento SLA`, exec 466883, node `Enviar Lembrete ao Cliente`, disparado 5 min após a resposta do bot (`sla_resposta_minutos=5`). Efeitos colaterais do 06 durante o teste: pode cutucar de novo nos intervalos da esteira (1h/6h/24h). Achados laterais do 06: roda a cada 1 min e `Buscar Tasks de SLA Vencidas` **falha toda vez** (erro RD CRM, caminho "Falhou"); `updated_at` da sessão gravado como `03:08:44Z` para um evento de `00:08:44Z` — bug de fuso (timestamp sem time zone). Nenhum dos dois precisa de correção (fluxo será descartado), mas ambos entram na lista de lições para o novo: **`timestamptz` sempre**, e job de 1 min com erro silencioso não pode existir. |
| T0' (2ª rodada) | 466932 (`/reset`), 466939 (`Oi`) | `/reset` → **`all`**; `Oi` → **`queue_wait`** | 1 cada | sim (200, ambos entregues) | Contato excluído e recriado (`contact.id` novo: `6aa49ce978be943645951228`). Com "Setores de atendimento" da conta **desativado** e canal sem automação, o `/reset` ainda chegou como `all` (menu recém-desligado?) e o `Oi` seguinte já chegou como **`queue_wait`** — sem menu, o RD joga a conversa na fila geral por padrão. Nenhum bot do RD apareceu. Leitura: `all` = "conversa sob o menu/bot da conta"; `queue_wait` = "em alguma fila" (o payload não diz qual). |
| T1 | 466967 | **`all`** | 1 | sim (200) | Canal atribuído à `TESTE IA` (opt-in + fila `Atendimento IA`, sem mensagem). Mensagem única com conteúdo ("Oi quero agendar um banho p o Bidu") chegou **inteira** ao n8n, em `all`, um disparo só; bot respondeu já tratando o pedido (Care Center → pergunta dia/horário). **`contact.id` mudou de novo** (`6aa49f5beae94d4eb7686459`) — **correção (14/09, Thiago)**: mudou porque o contato foi **excluído** entre as rodadas, não por conversa nova (na T1b, 2ª mensagem da mesma conversa, o id foi o mesmo). Regra mantida por segurança: `customer` do `forward-to-customer` **sempre** vem do payload da conversa corrente, nunca de cache. Hipótese em teste: `all` = 1ª mensagem de conversa nova (estado ainda não atribuído); a partir da 2ª, o estado real. |
| T1b | 466990 | **`queue_wait`** | 1 | sim (200) | 2ª mensagem da mesma conversa ("Pode ser amanhã de manhã"), mesmo `contact.id`. **Hipótese confirmada**: `all` = 1ª mensagem de conversa nova; depois vem o estado real. **Porém**: no painel a conversa está em "Fila de espera" **sem setor** (não em `Atendimento IA`) e sem rastro de opt-in → indício forte de que a `TESTE IA` **não rodou** (atribuição do canal não pegou?) — comportamento idêntico ao T0' sem automação. A verificar: badge WhatsApp na lista de automações. Consulta ao contato via API (`GET /contacts/{phone}/exists`) após o T1b: `tags: []`, `employee: null`, `current_wallet: null`, `customizable_field: []`, `channel_metadata.integration: "integration-2"` (= canal Care Center) — **nenhum rastro de opt-in nem de setor**. |
| — | — | — | — | — | Causa provável do T1 sem automação: a publicação da `TESTE IA` no canal foi salva às **21:39** e a mensagem do T1 entrou às **21:39:56** — conversa criada antes/no instante da atribuição; a automação só dispara em conversa nova. Canais WhatsApp da conta: **551131954993** = principal (Fluxo Simples 31.08.26, `integration-1`), **551131951859** = Care Center (`integration-2`, agora na `TESTE IA`). **Repetir T1 com conversa nova (T1'').** |
| T1'' | 467023 | **`all`** | 1 | sim (200) | Conversa nova com a `TESTE IA` já publicada há >10 min. Mensagem inteira chegou ao n8n, um disparo, bot respondeu e entregou. `contact.id` novo de novo (`6aa4a2ec5e6499f31fd89a23`). Contato via API: ainda sem tag/campo de opt-in visível (o endpoint pode simplesmente não expor isso). **Setor da conversa no painel: a confirmar** — é o que prova se a automação rodou. **Bug de prompt**: o agente chamou o Thiago de "Mariana" — o Exemplo 1 do system prompt usa "Mariana" + "Bidu"; o nome do pet do teste bateu com o exemplo e o modelo assumiu o nome da cliente do exemplo. Lição pro prompt novo: exemplos com nomes realistas vazam; usar placeholders ou nomes claramente fictícios. |
| T1''' (traçador) | — | `all` | 1 | sim | `TESTE IA` com passo "Olá" temporário antes do opt-in, conversa nova (`contact.id` `6aa4a525136954dfac2af44c`): **o "Olá" não chegou** → a automação publicada no canal **não dispara** para este telefone, mesmo em conversa nova. Conversa cai na fila geral sem setor e recebe a frase padrão do RD "Por favor, aguarde. Em breve iremos continuar…" (mesma que clientes reais recebem). Hipóteses: (a) o RD guarda "processo de fluxo" por telefone e não reinicia a automação para quem já passou por um fluxo — existe `POST /v2/reset-customers-flow-processes` (sem parâmetros documentados → provavelmente **reseta a conta inteira**); (b) publicação no canal precisa de algo mais que o toggle. Diagnóstico em curso: `forward-to-customer` do contato atual para a `TESTE IA` — se o "Olá" aparecer e o setor mudar, o fluxo funciona e o problema é só o gatilho automático. |

| C1 | — | — | — | — | "Gestão TI" adicionado como funcionário do `Atendimento IA`, contato excluído, `oi` enviado: **"Olá" não veio**. Setor vazio não era a causa (ou não a única). |
| D | — | — | — | — | Hipótese: desligar "Setores de atendimento" (conta) desligou o motor de fluxos de entrada — todas as falhas da `TESTE IA` ocorreram **depois** desse toggle. Não foi possível testar: o toggle não foi reencontrado (não está em "Configurações da empresa", que mostra `Setores: Inativo`; estava numa tela de Chatbot/Mensagens automáticas). |

## Encerramento (11/09, ~22:30)

- Canal WhatsApp do Care Center **devolvido à automação `Care Center`** (Thiago). `TESTE IA` continua existindo, sem canal.
- `99 - Teste RD` **desativado** (Amelia). Manter até o próximo teste; apagar quando não for mais necessário.
- **Estado da conta que ficou alterado e precisa de decisão**: "Setores de atendimento" = **Inativo** (menu numérico desligado). Para o número principal nada muda (tem automação); qualquer canal sem automação agora cai em silêncio na fila geral.
- T3/T3b/T4/T5 **não executados** — dependem de a `TESTE IA` rodar.

## Perguntas para a reunião com o RD (suporte: (85) 3030-0410)

1. Por que a automação `TESTE IA` (Começo → mensagem → Salvar opt-in → Encaminhar para fila `Atendimento IA`), publicada no canal 551131951859, **não executa** nem para conversa nova nem via `POST /v2/forward-to-customer` (200)? Há pré-requisito (setor com funcionário online, "Setores de atendimento" ativo, expediente, outro)?
2. Onde fica o toggle "Setores de atendimento" / "Comandos" / "Configurações do menu de setores" que foi desligado hoje, e ele afeta a execução dos fluxos de automação?
3. O que exatamente o toggle "Configuração de exibição do menu" do setor controla?
4. Semântica oficial do campo `content.action` do webhook: `all`, `automation`, `queue_wait`, `on_attendance` — e existe evento de **encerramento** de atendimento / transferência?
5. O payload do webhook pode incluir o **setor/departamento** da conversa?
6. `forward-to-customer` dispara algum webhook? Como saber que o encaminhamento foi processado?
7. Existe API para **transferir atendimento para setor** (o que o botão "Transferir" do painel faz) e para **finalizar** atendimento?
8. Existe API/registro de **opt-in** por contato? O "Salvar opt-in" do fluxo grava onde?
9. Um contato que já passou por um fluxo re-entra nele em conversa nova? Para que serve `reset-customers-flow-processes` e qual é o escopo (conta inteira?)?
10. Como ligar **dois números** WhatsApp na mesma automação de entrada?
11. Filtro de `queue_wait_count` por departamento: qual identificador usar (slug `atendimento_ia_c7c76` devolveu 0)?
12. **Arquitetura de integração — qual é a forma recomendada pela RD?** Para um agente de IA externo conduzir a conversa, o recomendado é (a) **webhook** de mensagem recebida + envio por `POST /v2/messages/{id}/send`, ou (b) **fluxo de automação com "Mensagem de Requisição Externa"** chamando nossa API e exibindo o retorno via `@VALOR`? Se (b): qual o **timeout** da requisição externa? O fluxo permite **loop** (voltar ao nó de requisição para conversa multi-turno)? O que acontece com mensagens que o cliente envia **enquanto** a requisição externa está em execução? (Ver `_bmad-output/planning-artifacts/rd-conversas/2026-09-15-fork-webhook-vs-requisicao-externa.md`.)
13. **Sandbox / conta de testes**: a doc pública não menciona sandbox do Conversas. A RD fornece conta de testes (como faz para tech partners no Marketing) ou uma segunda "empresa" para homologação, com um número de teste, sem custo? Se não, qual é o procedimento recomendado para testar fluxos sem afetar clientes reais?

## Respostas encontradas na documentação (14/09, Mary)

A central de ajuda (`ajuda.rdstation.com`) renderiza por JavaScript/CAPTCHA — não dá para ler por ferramenta; o que segue veio de trechos indexados por buscador e da doc de developers. Artigos a abrir **no navegador** e colar aqui: "Ativar fluxo em canais de atendimento", "Configurar chatbot", "Configurar atendimento por setores", "Minha automação não está funcionando", "Como configurar a ação Encaminhar para carteira no Editor".

| Pergunta | Resposta da doc | Fonte |
|---|---|---|
| 1 (fluxo não roda) | **RESPONDIDO — causa raiz provável**: a ativação de um fluxo num canal tem um passo que não usamos. Doc *"Ativar fluxo em canais de atendimento"*: *"1. Acesse sua conta no RD Station Conversas; 2. Clique no menu **Automação**; 3. Clique no submenu **Fluxos**; 4. Localize o fluxo desejado; 5. Clique no botão de **Ativar**, na respectiva linha; 6. Na janela que será exibida, **marque a checkbox Aplicar no início**; 7. Selecione um ou mais canais em que o fluxo será aplicado; (…) 9. Clique no botão **Atualizar**."* Nós usamos **"Publicar no canal"** (só liga o canal) — nunca marcamos **"Aplicar no início"**, que é o que faz o fluxo rodar no começo da conversa. Candidato secundário: *"Se a configuração geral da sua conta 'Encaminhar o contato para a fila de espera ao iniciar um atendimento' estiver desativada, o fluxo do chatbot é completamente ignorado. O cliente é encaminhado diretamente para a carteira sem passar pelo fluxo."* Esse toggle está em Configurações da empresa (Thiago colou a página; estado a confirmar). Também: bloco com setor/carteira inválido bloqueia o salvamento e mostra erro visual; **"ao transferir o contato para um humano ou fila, o fluxo automatizado do robô se encerra ali"**. | ajuda.rdstation.com — "Encaminhar para carteira no Editor" |
| 2 (onde está "Setores de atendimento") | Está na própria página **Configurações da empresa**, perto do fim: "Comandos — Ativar/Desativar" e logo abaixo "Setores de atendimento — Ativar/Desativar" (aparece na cópia da página que o Thiago colou). Doc: *"Para ativar o uso de setores basta ativar a opção"*; "Frase Padrão" = texto para o contato escolher o setor; "Ocultar setores fora do período durante o pré-atendimento". | help.rdstation.com.br — Configurações da Empresa |
| 3 ("exibição do menu" do setor) | Não encontrado na doc. Permanece para o RD. | — |
| 4 (semântica de `action`) | Não documentado publicamente. Só o nosso teste: `all` (1ª msg), `automation`, `queue_wait`, `on_attendance`. Sem evento de encerramento documentado. | — |
| 5 (setor no payload) | Não documentado. | — |
| 6 (forward dispara webhook?) | Não documentado; teste diz que **não**. | developers — forward-to-customer |
| 7 (API transferir/finalizar) | Não existe na API v2 (índice completo). | developers — llms.txt |
| 8 (opt-in por API) | Não existe. | developers — llms.txt |
| 9 (re-entrada em fluxo / reset) | Obs.: o artigo "Minha automação não está funcionando" é do RD Station **Marketing**, não do Conversas — não se aplica. | `reset-customers-flow-processes` sem parâmetros documentados. Novidade mar/2025: *"o lead escolhe entre continuar numa negociação anterior, iniciada dentro de 90 dias, ou iniciar uma nova conversa"* — pode influenciar como conversa nova é tratada. | developers; blog RD mar/2025 |
| 10 (dois números numa automação) | A tela "Publicar no canal" lista os dois números com toggle independente → aparentemente **sim**, basta ligar os dois. Confirmar. | print do Thiago |
| 11 (id do departamento no filtro) | Não documentado. | — |
| 12 (sandbox) | Não existe sandbox documentado; conta de testes é prática da RD para parceiros (Marketing). | developers; Medium RD |

Permissão relevante achada de passagem: **"Exibir fila de Chatbot"** — *"os usuários de perfil operador poderão visualizar os contatos que estiverem interagindo com o chatbot"* — é como a recepção enxerga (ou não) a fila do `Atendimento IA`.

**Próxima ação antes de qualquer reunião** (em ordem):
1. **Automação → Fluxos → linha da `TESTE IA` → botão `Ativar` → marcar `Aplicar no início` + canal Care Center → `Atualizar`.** Este é o passo que faltou; "Publicar no canal" sozinho não faz o fluxo rodar no início da conversa.
2. Configurações da empresa → aba Configurações: "Encaminhar o contato para a fila de espera ao iniciar um atendimento" precisa estar **Ativar** (se desativada, *"o fluxo do chatbot é completamente ignorado"*).
3. Mesma aba: religar **Setores de atendimento** (ficou Inativo desde 11/09).
4. Permissões de operador: conferir **"Exibir fila de Chatbot"** — decide se a recepção enxerga a fila do `Atendimento IA`.
5. Repetir T1 numa janela curta; se rodar, seguir T3 → T5.

Ações disponíveis num fluxo (doc "Criar fluxo de atendimento"), úteis para o desenho de produção: mensagem simples, mensagem de requisição (com tipos de resposta validados: texto, CPF, CNPJ, RG, CEP, data, e-mail, telefone, documento/imagem/áudio), condicional, switch, caixa de botões, lista suspensa, tag de identificação, requisição externa (HTTP), e-mail, integração com apps, **Realizar opt-in**, **Interceptação** (= "Encaminhar para carteira" no editor novo).
