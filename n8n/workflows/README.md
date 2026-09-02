# n8n/workflows

Exports de workflow n8n (`.json`), um arquivo por workflow. Convenção de nomenclatura
numérica por papel no fluxo (Design Paradigm, `ARCHITECTURE-SPINE.md`), reaproveitando
o padrão já validado em `_bmad-output/reference/modelo-n8n/secretariav3-completo/`:

- `00 - Configurações.json` — setup/config inicial
- `01 - Agente.json` — orquestração única (Recepcionista IA / Agente de Setor, mesmo nó)
- `02+` — sub-workflows de ferramenta e integração (escalar humano, criar contato/card,
  enviar arquivo, etc.), um arquivo por ação

Importar via n8n UI ou `n8n import:workflow --input=<arquivo>`.

**Nunca** exportar/versionar um workflow com credencial embutida — credenciais ficam só
no cofre nativo do n8n (AD-2), nunca neste diretório.
