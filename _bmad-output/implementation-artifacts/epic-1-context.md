# Epic 1 Context: A Nouvi atende, reconhece e sabe quando parar

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Qualquer pessoa que escrever no WhatsApp do Nouvet recebe resposta imediata, a qualquer hora, de uma atendente virtual (a Nouvi) que já sabe quem ela é e qual o pet — e que reconhece com clareza o que não é dela: emergência vira orientação para vir agora, pedido fora do escopo da onda vira transferência, e pergunta sobre agendamento de outra pessoa não recebe informação nenhuma. É uma recepcionista virtual completa e segura, ainda sem marcar horário, entregável sozinha e sem depender de nenhum épico posterior. Inclui o importador único do cadastro do SimplesVet (é o que dá nome, pet e histórico para a Nouvi reconhecer alguém) e a configuração básica que este épico consome: catálogo de serviços (nome, sinônimos, onda), identidade/tom da Nouvi, e destinatários de emergência com o mapa de setores de transferência.

## Stories

- Story 1.1: A base de quem já é cliente (importador do SimplesVet)
- Story 1.2: A mensagem chega e não se perde (ingresso, fila, agregação)
- Story 1.3: A Nouvi responde (identidade, tom, memória de conversa)
- Story 1.4: Uma segunda porta, para poder testar (entrada de teste + bancada adversarial)
- Story 1.5: A Nouvi sabe quem está falando (reconhecimento por telefone, autorização)
- Story 1.6: Preferências que não se perguntam duas vezes
- Story 1.7: A Nouvi cadastra quem ainda não é cliente
- Story 1.8: A Nouvi entende o que o cliente quer (catálogo, linguagem natural)
- Story 1.9: A Nouvi reconhece emergência
- Story 1.10: A Nouvi transfere e fica quieta
- Story 1.11: A Nouvi não pode ser virada do avesso (guardrails, prompt injection)

## Requirements & Constraints

- Reconhecimento é por telefone do WhatsApp, normalizado, resolvendo para exatamente um tutor. Telefone que não resolve para ninguém é tratado como cliente novo; telefone que resolve para mais de um é não autorizado. Em nenhum dos dois casos a Nouvi pergunta "você já é cliente?" — o tratamento é indistinguível para quem escreve.
- Cliente novo é atendido sem cadastro prévio como barreira: dado cadastral faltante só é pedido quando a tarefa em curso precisa dele, ou oferecido como complemento opcional ao final, nunca como etapa que atrase o atendimento.
- Memória de conversa persiste entre mensagens e entre sessões (retomada dias depois).
- Preferência estável do pet (plano, perfume, acessório, produto próprio, observação livre) é confirmada com uma única pergunta fechada, nunca reperguntada campo a campo; o que muda durante a conversa passa a valer dali em diante.
- Identificação de serviço usa um catálogo curado (nome + sinônimos) com uma "onda" ativa; serviço fora da onda corrente ou não reconhecido nunca é chutado — conduz a transferência.
- Mensagens picadas do mesmo cliente em intervalo curto são agregadas e tratadas como um único pedido, respondido uma única vez.
- Emergência tem precedência sobre qualquer outra coisa em curso, em qualquer ponto da conversa: interrompe o que estava sendo feito, nunca oferece horário, orienta a vir imediatamente e alerta os destinatários configurados; nunca diagnostica nem minimiza sintoma.
- Transferência para humano preserva o histórico da conversa; a Nouvi fica em silêncio enquanto o humano conduz e retoma depois sem anunciar que "voltou".
- Todo texto do cliente é tratado como dado, nunca como instrução; a Nouvi nunca revela configuração interna, contato de plantão ou o próprio prompt; nunca finge ser humana; nunca usa termo interno ("onda", "sistema", "API", "fluxo") com o cliente.
- Autorização é escopada ao tutor, não ao telefone: a Nouvi nunca confirma nem nega agendamento de terceiro, nunca pede dado pessoal para "validar identidade", e nunca vincula telefone novo a cadastro existente — isso é ação humana.
- O importador do SimplesVet cria a base de reconhecimento (tutores, pets, vínculos de telefone) sem nunca sobrescrever campo que a conversa já é dona (preferência, estado de migração) e sem duplicar registro criado pela conversa; telefone ambíguo é gravado como ambíguo, nunca resolvido arbitrariamente; é seguro reexecutar; a cobertura de cada campo é reportada em número absoluto e em fração da base.
- Resposta chega em poucos segundos; quando algo for demorar, a sinalização vai dentro da mesma mensagem — nunca como envio separado (cada mensagem extra é cobrada pela Meta a partir de 01/10/2026, e o agente responde uma única vez por turno).
- Qualquer falha técnica gera mensagem honesta ao cliente, sem detalhe técnico, mais registro para a equipe — nunca silêncio.
- Nenhum dado de cliente entra no repositório; o ambiente de desenvolvimento nunca alcança cliente real nem mensageria real.
- Nome, tom, saudação da Nouvi, catálogo (nome/sinônimo/onda) e destinatários de emergência/mapa de setores são configuráveis como dado, sem alterar fluxo nem publicar versão.

## Technical Decisions

- O agente é um único nó LangChain no n8n, com `systemMessage` montado seletivamente a partir de config em Postgres a cada turno — nunca hardcoded, nunca cacheado. Prompt pequeno é também controle de custo por turno.
- A camada de ingresso (fila, lock por sessão, agregação de mensagens picadas) é um sub-workflow próprio, separado da lógica do agente — para que a forma de entrada pelo RD Conversas (ainda em aberto entre webhook assíncrono ou requisição síncrona) possa mudar sem tocar agente, ferramentas ou registro.
- As stories 1.2 e 1.3 partem de `n8n/workflows/01 - Agente.json` do Piloto, não de folha em branco: removem o que não é usado, endurecem o que fica, e não reintroduzem o bug já corrigido de vírgula em parâmetro Postgres.
- A story 1.4 cria uma segunda entrada (Webhook com `responseMode: responseNode` + `respondToWebhook`) apontando para o mesmo sub-workflow do agente, para testes sem tocar WhatsApp/RD/Meta; cada caso de teste tem sessão isolada; execução é automática, julgamento de passou/não passou é humano, lendo transcritos. Essa bancada é reaproveitada por todas as stories seguintes que introduzem um "nunca" (1.5, 1.8, 1.9, 1.11) e, depois, pelo spike de escolha de modelo de linguagem.
- O importador do SimplesVet é um programa executável sob demanda (`import/`), não um fluxo n8n: conecta direto no Postgres com um papel de banco próprio e mais restrito (`identidade_role`), separado do papel do n8n, porque toca dado pessoal permanente.
- Identidade passa a viver em duas tabelas — `identidade_tutor` e `identidade_pet` — substituindo a tabela única do Piloto (`identidade_cliente_pet`); cada campo do pet carrega `origem` (`faturamento` | `cliente` | `importado`). A migração dessa mudança de esquema é decidida pela story 1.1 e registrada como migration numerada nova, sem reescrever as anteriores.
- Telefone é sempre normalizado para E.164, para casar com o identificador que o RD Station entrega.
- Autorização: telefone resolve para zero, um ou mais de um tutor; só "exatamente um" é autorizado. É a mesma regra usada por reconhecimento (1.5), preferências, cadastro novo e qualquer menção a agendamento.
- Achado conhecido: dois números de telefone do export do SimplesVet são placeholders de sistema (não ambiguidade real) e já ficam neutralizados pela regra acima — não exigem tratamento especial nas stories, mas explicam por que alguns "não autorizado" aparecem em números que não deveriam ser ambíguos de verdade.
- O catálogo de serviços, neste épico, cobre apenas nome, sinônimos, onda e estado ativo — duração, preço e vínculo com recursos são extensão do mesmo catálogo, feita no Épico 2.

## UX & Interaction Patterns

- A agente se chama Nouvi (feminino) e se apresenta como atendente virtual do Nouvet uma única vez, no primeiro turno — nunca se repete, nunca admite ser humana mesmo se perguntada diretamente.
- Uma mensagem por turno, sempre; sinalização de demora entra na mesma mensagem, nunca em envio separado.
- Nunca perguntar "você já é cliente?"; cliente novo é perguntado nome e pet de uma vez só, espécie apenas se não vier espontânea, e nunca raça/porte/pelagem no cadastro inicial.
- Preferência estável do pet é confirmada em uma pergunta fechada única ("do mesmo jeito da última vez — com corte de unhas, sem perfume e sem enfeite?").
- Complemento de cadastro só é oferecido depois do agendamento confirmado, de forma opcional e recusável.
- Sem horário disponível (quando aplicável a partir do Épico 2, mas o padrão de tom já vale aqui): nunca nega, nunca promete — oferece alternativa e, na insistência, transfere.
- Em emergência: nunca oferece horário, orienta a vir imediatamente, informa endereço e funcionamento 24h; nunca usa o emoji 🐾 nessa mensagem.
- Emoji 🐾 usado com parcimônia — só em fechamento de agendamento e lembrete do dia; nunca em emergência, falha ou transferência.
- Diante de pedido sobre agendamento de terceiro: nunca confirma nem nega que o agendamento existe, nunca pede dado pessoal para "validar identidade"; oferece os dois caminhos legítimos — quem marcou resolve pelo número dela, ou a Recepção assume a verificação.
- Falha técnica vira mensagem honesta e sem jargão técnico, com aviso à equipe — nunca silêncio.
- Nunca menciona termo interno ("onda", "sistema", "API", "fluxo", "registro") na conversa com o cliente.

## Cross-Story Dependencies

- As stories 1.2 e 1.3 partem do mesmo fluxo herdado do Piloto (`01 - Agente.json`) e dividem a responsabilidade: 1.2 cobre ingresso/fila/agregação, 1.3 cobre identidade/tom/resposta.
- A story 1.4 (sub-workflow isolado + entrada de teste) é pré-requisito de infraestrutura para a bancada adversarial que as stories 1.5, 1.8, 1.9 e 1.11 alimentam com seus próprios casos de "nunca"; a bancada completa também é o critério do spike de escolha de modelo de linguagem.
- A story 1.1 (importador do SimplesVet) precisa rodar antes de a story 1.5 conseguir reconhecer qualquer cliente real, e é reaproveitada sem alteração pelo Épico 2 (recursos do Care Center) e pelo Épico 4 (demais recursos).
- O Épico 1 é entregável e independente do Épico 2 — entrega uma recepcionista completa e segura, ainda sem agendar; o Épico 2 depende do Épico 1, nunca o contrário.
