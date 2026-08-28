# Idioma e convenções existentes — atendimento

## Idioma (confirmado em `_bmad/core/config.yaml` e `_bmad/bmm/config.yaml`)
- Idioma de comunicação com o usuário: **Portuguese BR**.
- Idioma dos documentos de saída gerados pelo BMAD: **Portuguese BR**.

## Convenções observadas na estrutura de arquivos
- Nomes de pastas e arquivos de configuração em inglês (`_bmad`, `_bmad-output`, `config.yaml`), mesmo com o idioma de comunicação/documentação em português — convenção da própria ferramenta BMAD, não específica deste projeto.
- Saídas geradas pelo BMAD são segregadas em `_bmad-output/` (raiz), com subpastas por tipo: `planning-artifacts/`, `implementation-artifacts/`, `test-artifacts/` (única existente até agora, vazia).
- `.gitignore` já prevê convenções de segredo/local state: arquivos `.env*` (exceto `*.example`), estado local dos assistentes (`.headroom/`, `.claude/settings.local.json`, `CLAUDE.local.md`) e caches (`.venv/`, `node_modules/`, `__pycache__/`, `.serena/cache/`) são todos ignorados.

## Não observado / não confirmado
- Nenhuma convenção de código (lint, formatação, estilo) pôde ser confirmada — não há código de aplicação no repositório ainda.
- Nenhum README ou documento de arquitetura foi encontrado na raiz do projeto.
