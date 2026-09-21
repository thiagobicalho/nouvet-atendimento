# n8n/workflows

Exports de workflow n8n (`.json`), um arquivo por workflow. Convenção de nomenclatura
numérica por papel no fluxo (Design Paradigm, `ARCHITECTURE-SPINE.md`), reaproveitando
o padrão já validado em `_bmad-output/reference/modelo-n8n/secretariav3-completo/`:

- `00 - Configurações.json` — setup/config inicial
- `01 - Agente.json` — raciocínio do agente (Recepcionista IA / Agente de Setor, mesmo
  nó); sem webhook próprio — é um sub-workflow chamado via `executeWorkflowTrigger`
  ("Receber Turno") recebendo só `contact_id`, `telefone` e `mensagem_agregada`
  (`AD-20`); quem o chama hoje é `07 - Ingresso e Fila.json`
- `07 - Ingresso e Fila.json` — camada de ingresso (`AD-20`): recebe o webhook do RD
  Conversas/Tallos, enfileira toda mensagem em `n8n_fila_mensagens` antes de qualquer
  outro processamento, trava a conversa (lock com TTL), agrega mensagens picadas em um
  único lote, chama `01 - Agente.json` com o contrato fixo e envia a resposta —
  reconsulta a fila antes de liberar o lock para nunca deixar uma mensagem chegada
  durante o processamento sem um próximo ciclo agendado. Diferente dos demais
  sub-workflows numerados: `07` **chama** `01`, não é chamado por ele — não é uma
  ferramenta do agente, é quem o aciona.
- `02`–`06` — sub-workflows de ferramenta e integração chamados pelo `01` (escalar
  humano, buscar info de setor, registrar atendimento no CRM, etc.), um arquivo por
  ação

Importar via n8n UI ou `n8n import:workflow --input=<arquivo>`.

**Nunca** exportar/versionar um workflow com credencial embutida — credenciais ficam só
no cofre nativo do n8n (AD-2), nunca neste diretório.
