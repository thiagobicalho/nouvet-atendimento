# Jornadas-Chave do Usuário — Atendimento Nouvet

Referenciadas pelas Capabilities do SPEC.md como "realiza UJ-N". Termos em negrito seguem `glossary.md`.

## UJ-1. Mariana agenda banho para o cachorro pelo Care Center

- **Persona + contexto:** Mariana, cliente recorrente do Nouvet, já tem cadastro e pet associado ao seu telefone.
- **Entry state:** manda mensagem no WhatsApp do Nouvet num sábado à noite, fora do horário comercial.
- **Path:** o sistema identifica Mariana e o cão dela pelo telefone → pergunta diretamente o que ela precisa hoje (sem presumir com base no último atendimento) → ela pede banho → o Agente do Care Center coleta serviço (banho cachorro), data e horário preferidos, e profissional de preferência → registra o pedido completo no **card** e roteia para um humano confirmar o agendamento.
- **Climax:** o humano que assume já vê serviço, data/horário preferidos e profissional desejado prontos no card — não precisa perguntar nada disso de novo a Mariana, só confirmar contra a agenda real.
- **Resolution:** card é atualizado com a preferência de agendamento coletada e o estado **Aguardando Atendimento Humano**; card só recebe cadastro definitivo agora que a intenção de agendar foi confirmada.
- **Edge case:** o Piloto não tenta agendamento automático em nenhum setor — mesmo quando o profissional preferido claramente não teria horário, essa checagem e a sugestão de alternativa ficam a cargo do humano que assume o card, não da IA.

## UJ-2. Carlos, cliente novo, não sabe se quer clínico geral ou especialista

- **Persona + contexto:** Carlos nunca foi cliente do Nouvet; o cão dele está com uma queixa que ele não sabe classificar.
- **Entry state:** primeira mensagem via WhatsApp, telefone não encontrado na base.
- **Path:** sistema não encontra cadastro → pergunta diretamente o que ele precisa → Carlos diz que quer "uma consulta" mas não sabe qual especialidade → o Agente de Consultas pergunta a queixa e se o pet já é acompanhado por algum especialista → não havendo indicação clara, direciona por padrão ao clínico geral.
- **Climax:** Carlos recebe a orientação de que o clínico geral vai avaliar primeiro e encaminhar se necessário — sem parecer que está sendo "empurrado" para uma opção genérica.
- **Resolution:** preferências de data/horário são coletadas; cadastro de Carlos só é criado no CRM neste ponto, porque a intenção de agendar já está confirmada.
- **Edge case:** se durante a conversa Carlos relatar um sintoma classificado como **Sinal de Alerta** (ex.: "ele não para de vomitar há 3 dias"), o fluxo de triagem interrompe a coleta normal e aciona **handoff** humano imediato com prioridade máxima.

## UJ-3. Fernanda pede um exame que depende de orçamento

- **Persona + contexto:** Fernanda recebeu uma carta de encaminhamento do veterinário pedindo uma tomografia para o gato dela.
- **Entry state:** cliente já identificada, envia o documento anexado no WhatsApp.
- **Path:** o Agente de Exames recebe o pedido → verifica que tomografia requer anestesia → pergunta se Fernanda já tem exames pré-anestésicos prontos → ela diz que não → o agente registra que o orçamento precisa incluir os pré-anestésicos → todo o contexto é anexado ao card e roteado para o humano responsável por orçamento.
- **Climax:** quando o humano assume, ele já vê a carta, o tipo de exame, a pendência de pré-anestésicos e não precisa perguntar nada disso de novo a Fernanda.
- **Resolution:** atendimento entra em estado "aguardando atendimento humano"; a IA não tenta calcular valores nem agendar — isso depende de aprovação humana do orçamento.
- **Edge case:** nenhuma segmentação por tipo de exame acontece no Piloto — mesmo um exame simples de laboratório segue o mesmo caminho único até um humano.

## UJ-4. Retorno de cliente recorrente meses depois

- **Persona + contexto:** Mariana (UJ-1) volta a falar com o Nouvet três meses depois, agora para agendar uma consulta.
- **Entry state:** telefone já reconhecido, card existente com o histórico do banho anterior.
- **Path:** sistema identifica Mariana e o pet → pergunta o que ela precisa hoje (não assume que é outro banho) → ela pede consulta → o novo atendimento é adicionado ao card, aparecendo primeiro no histórico, com o registro do banho anterior preservado abaixo.
- **Climax:** um atendente humano que abrir o card mais tarde vê imediatamente a consulta em andamento no topo, e pode consultar o histórico do banho anterior sem precisar perguntar a Mariana.
- **Resolution:** card funciona como memória operacional contínua, nunca substituindo registros anteriores.
- **Edge case (Open Question):** o mecanismo exato de reposicionamento do card no pipeline quando o cliente retorna (nova etapa? mesma etapa com novo item no topo do histórico?) ainda não está fechado — ver SPEC.md, Open Questions.

## UJ-5. Atraso do atendimento humano aciona escalonamento (perspectiva do gestor)

- **Persona + contexto:** Edson Candido, gestor Nouvet, precisa garantir que nenhum atendimento fique esquecido em "aguardando humano".
- **Entry state:** um card está em **Aguardando Atendimento Humano** após handoff da IA.
- **Path:** passam 5 minutos sem que um humano responda → sistema envia atualização automática ao cliente informando que a solicitação segue em andamento **e**, já neste primeiro ciclo, informa Edson de que aquele atendimento está em atraso → a cada novo **Ciclo de Escalonamento**, o sistema informa Edson novamente, com o nível de urgência crescendo a cada ciclo — Edson é avisado desde o início do atraso, não só depois que a situação já se agravou.
- **Climax:** Edson recebe visibilidade do atraso desde o primeiro sinal, a tempo de intervir com a equipe antes que o cliente perceba a demora como abandono.
- **Resolution:** card retorna a "aguardando atendimento humano" normal assim que alguém assume; o aviso progressivo não substitui o atendimento, só mantém Edson informado enquanto ele durar.
