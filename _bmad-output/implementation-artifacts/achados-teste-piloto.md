# Achados do teste do Piloto (uso real, pós-construção)

Achados de comportamento observados testando o fluxo em produção (WhatsApp real, número de teste de Thiago), distintos dos achados de review de código de `deferred-work.md` (esses são de dado real / integração real, não de revisão de implementação). Workflow n8n de referência: `01 - Agente` (`ivPwIf28PgVGX8LW`), instância `myeditor.uniqueads.com.br`.

---

### Achado 1 — Fluxo antigo do Tallos/RD Conversas (com menu fixo + opt-in) ainda ativo, rodando em paralelo com o agente de IA

- **Cenário testado**: mensagem "Bom dia" enviada pelo WhatsApp de teste, duas vezes seguidas (10:21 e 10:24).
- **Esperado vs. observado**: esperado que o agente de IA respondesse desde a primeira mensagem. Observado: o cliente recebeu primeiro o menu fixo antigo do Tallos ("Para consultas... selecione CLÍNICA MÉDICA / CARE CENTER") e depois "Resposta inválida! Selecione um item da lista" — só ~14 min depois (10:38) o agente de IA respondeu normalmente. Dois automatismos independentes rodando na mesma caixa de entrada: o fluxo antigo do Tallos (termina em "Encaminhar para fila de espera sequencialmente", sem nenhuma chamada ao webhook n8n) e o novo webhook do agente de IA.
- **Severidade**: importante — não bloqueia o fluxo novo, mas gera experiência confusa/duplicada pro cliente.
- **Evidência**: prints da conversa (menu antigo + "Resposta inválida") e do builder do fluxo Tallos (node de OPT-IN + itens "CLÍNICA MÉDICA"/"CARE CENTER" → fila de espera por setor).
- **Status**: **registrado, sem correção ainda** — não é possível desativar esse fluxo (é o número de produção). Investigar se dá pra excluir o número de teste desse fluxo direto no Tallos (aguardando confirmação de acesso/permissão lá).
- **Opt-in**: verificado que não é bloqueante pra resposta do agente (opt-in da API oficial do WhatsApp só é exigido pra mensagem iniciada pela empresa; resposta a mensagem do cliente cai na janela de 24h, sem exigência). Pode voltar a importar mais pra frente, na Story 12/CAP-8 (lembretes de SLA), que são mensagens proativas — não é um bloqueio agora.

---

### Achado 2 — Campo `mensagem` capturava o objeto inteiro do payload, não só o texto — **CORRIGIDO**

- **Cenário testado**: node "Extrair dados da mensagem" com payload real (`body.content = {id, message, type, action}`).
- **Esperado vs. observado**: esperado `mensagem = "Bom dia"`. Observado: `mensagem = "{\"id\":...,\"message\":\"Bom dia\",\"type\":\"text\",\"action\":\"automation\"}"` (string JSON inteira), porque a expressão `b.message || b.content || b.text` caía no `b.content` (objeto), que o n8n serializa quando o campo é do tipo string.
- **Severidade**: alta — o agente de IA recebia ruído (id/type/action) misturado ao texto real do cliente.
- **Evidência**: execução manual do node no editor (teste de Thiago), + inspeção do payload real via MCP do n8n.
- **Correção aplicada**: expressão trocada para `b.content?.message || b.message || b.content?.text || b.text || '<mensagem sem texto reconhecido>'` (e o mesmo ajuste no cálculo de `tipo`, que também precisa olhar `b.content?.type`). Aplicada direto na versão publicada via MCP do n8n em 10/09.
- **Destino**: resolvido — Build/ajuste direto, sem necessidade de Correct Course.

---

### Achado 3/4 — "Marcar mensagens processadas" falha ao formatar array de IDs pro Postgres (`ANY($1::bigint[])`) — **CORRIGIDO**

- **Cenário testado**: fechamento normal do turno (após o agente responder), node "Marcar mensagens processadas" atualiza `n8n_fila_mensagens` pelos IDs do lote.
- **Esperado vs. observado**:
  - **1ª tentativa** (execução 459494, 10/09): erro `malformed array literal: "1"` — array JS `[1]` estava sendo passado cru pro parâmetro, sem o formato de array do Postgres (`{1}`).
  - **Correção 1 aplicada**: mudamos a expressão pra montar o literal manualmente: `'{' + ids_lote.join(',') + '}'`.
  - **2ª tentativa** (execução 459685, hoje): erro persiste, agora `malformed array literal: "{1"` / "Unexpected end of input" — o preview do node mostra o valor final resolvido corretamente (`{1,2}`), mas o parâmetro que chega no Postgres vem truncado (`{1`). Ou seja, a correção 1 não resolveu — piorou de forma sutil (funciona só quando o lote tem 1 único ID).
- **Causa raiz revisada**: o campo "Query Parameters" (`queryReplacement`) do node Postgres do n8n trata **vírgula como separador entre parâmetros diferentes** ($1, $2, ...), mesmo quando a vírgula está dentro de uma única expressão `{{ }}`. Como `ids_lote.join(',')` produz uma vírgula literal no meio do valor, o n8n corta o parâmetro ali — `$1` vira só o pedaço antes da vírgula.
- **Severidade**: alta — quebra sempre que o lote de mensagens agregadas tiver mais de 1 mensagem (cenário comum: cliente manda várias mensagens picadas antes do agente processar).
- **Correção aplicada**: opção 1 do doc — separador trocado de `,` pra `;` no `.join()`, e a query passou a usar `string_to_array($1, ';')::bigint[]` em vez de `ANY($1::bigint[])` direto sobre o parâmetro cru. Query: `UPDATE n8n_fila_mensagens SET processada = TRUE WHERE id = ANY(string_to_array($1, ';')::bigint[])`. Query Parameters: `={{ ($('Agregar mensagens').item.json.ids_lote || []).join(';') }}`. Aplicada direto na versão publicada via MCP do n8n em 10/09, e sincronizada em `n8n/workflows/01 - Agente.json`. Validação via `n8n_validate_workflow`: 0 erros/warnings.
- **Evidência**: execuções 459494 e 459685 (myeditor.uniqueads.com.br), print do node com erro e do preview do parâmetro resolvido.
- **Destino**: resolvido — Build/ajuste direto, sem necessidade de Correct Course.
