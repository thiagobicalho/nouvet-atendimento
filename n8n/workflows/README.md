# n8n/workflows

Exports de workflow n8n (`.json`), um arquivo por workflow. Convenção de nomenclatura
numérica por papel no fluxo (Design Paradigm, `ARCHITECTURE-SPINE.md`), reaproveitando
o padrão já validado em `_bmad-output/reference/modelo-n8n/secretariav3-completo/`:

- `00 - Configurações.json` — setup/config inicial
- `01 - Agente.json` — raciocínio do agente; sem webhook próprio — é um sub-workflow
  chamado via `executeWorkflowTrigger`
  ("Receber Turno") recebendo só `contact_id`, `telefone` e `mensagem_agregada`
  (`AD-20`); quem o chama hoje é `07 - Ingresso e Fila.json`. Desde a Story 1.3, o
  `Agente Nouvet` não tem nenhuma ferramenta (`ai_tool`) conectada — identidade, tom e
  apresentação única (por telefone/nome, via `Memory`) são a única resposta desta fase;
  triagem por setor, catálogo, emergência e transferência (`02`–`04`, arquivos intactos
  no disco) voltam redesenhados em stories futuras (1.8–1.10). As 3 consultas Postgres
  da fase (`Buscar Config`/`Normalizar telefone`/`Buscar Identidade`), o node `Info`
  (também pode falhar ao dereferenciar o retorno delas) e o próprio node `Agente
  Nouvet` têm `onError: continueErrorOutput`, convergindo para `Registrar Falha`
  (grava em `atendimento_falha_registro`, migration `0015`) e `Montar Mensagem de
  Falha` — leaf que devolve `output` com mensagem honesta, mesmo contrato que `Enviar
  resposta RD Conversas` (`07`) já consome no caminho de sucesso.
- `07 - Ingresso e Fila.json` — camada de ingresso (`AD-20`): recebe o webhook do RD
  Conversas/Tallos, enfileira toda mensagem em `n8n_fila_mensagens` antes de qualquer
  outro processamento, trava a conversa (lock com TTL), agrega mensagens picadas em um
  único lote, chama `01 - Agente.json` com o contrato fixo e envia a resposta —
  reconsulta a fila antes de liberar o lock para nunca deixar uma mensagem chegada
  durante o processamento sem um próximo ciclo agendado. Diferente dos demais
  sub-workflows numerados: `07` **chama** `01`, não é chamado por ele — não é uma
  ferramenta do agente, é quem o aciona.
- `08 - Entrada de Teste.json` — segunda porta, só para teste (Story 1.4, `AD-20`):
  `Webhook` síncrono (`responseMode: responseNode`, path `atendimento-nouvet-teste`)
  que recebe `contact_id`/`telefone`/`mensagem_agregada` no corpo da requisição, chama
  `01 - Agente.json` pelo mesmo contrato e workflowId que `07` usa (`ivPwIf28PgVGX8LW`)
  e devolve a fala da Nouvi (`output`) no próprio corpo da resposta HTTP via
  `Respond to Webhook`. Não enfileira, não trava conversa, não agrega mensagens picadas
  e **nunca** chama RD Conversas/Tallos/Meta — cada chamada é um turno único e síncrono;
  quem orquestra multi-turno é `bancada-teste/rodar.py` (ver `bancada-teste/README.md`),
  chamando esta entrada turno a turno com telefone/`contact_id` sintéticos isolados.
  Igual a `07`: **chama** `01`, nunca é chamado por ele, e nunca modifica `01` nem `07`.
- `02`–`06` — sub-workflows de ferramenta e integração chamados pelo `01` (escalar
  humano, buscar info de setor, registrar atendimento no CRM, etc.), um arquivo por
  ação

Importar via n8n UI ou `n8n import:workflow --input=<arquivo>`.

**Nunca** exportar/versionar um workflow com credencial embutida — credenciais ficam só
no cofre nativo do n8n (AD-2), nunca neste diretório.
