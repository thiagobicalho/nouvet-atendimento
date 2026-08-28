# Estrutura atual do projeto — atendimento

Caminho: `/home/thiago/projetos/nouvet/atendimento`

## Pastas na raiz (confirmadas via listagem de diretório)
- `.agents/skills/` — cópias dos skills BMAD (mesmo conteúdo de `.claude/skills/`), usados por outros harnesses de agente.
- `.claude/` — configuração do Claude Code: `settings.local.json`, `settings.json` (configurado neste projeto com `model`: `claude-sonnet-5[1m]` e `effortLevel`: `high`), marcadores/lock do Headroom (`.headroom_wrap_*`, incluindo `.headroom_wrap_owners.json` — estado local do Headroom, ignorado pelo Git via `.gitignore`), e `skills/` (skills BMAD espelhados).
- `.git/` — repositório git, branch atual `main`.
- `.gitignore` — ignora `.env*`, `node_modules/`, `.venv/`, `__pycache__/`, `.headroom/`, `.claude/.headroom_wrap_marker.json`, `.claude/settings.local.json`, `CLAUDE.local.md`, `.serena/cache/`.
- `.serena/` — configuração do Serena para este projeto (`project.yml`, `project.local.yml`, `cache/`, `memories/`).
- `_bmad/` — instalação e configuração do framework BMAD (ver `mem:bmad_configuration`).
- `_bmad-output/` — pasta de saída configurada para artefatos gerados pelo BMAD; contém apenas `test-artifacts/` (vazio no momento da verificação).

## Ausências confirmadas (não há evidência de código de aplicação)
- Não existe pasta `docs/` (referenciada como `project_knowledge` em `_bmad/bmm/config.yaml`, mas ainda não criada).
- Não há manifestos de dependências de aplicação (`package.json`, `requirements.txt`, `pyproject.toml`, etc.) na raiz.
- Não há pasta `src/`, `app/` ou similar com código-fonte de aplicação.
- Os únicos arquivos `.py` do projeto ficam em `_bmad/scripts/` (`config_utils.py`, `memlog.py`, `render_skill.py`, `resolve_config.py`, `resolve_customization.py`) — são scripts internos da ferramenta BMAD, não código da aplicação. Ver `mem:tech_stack_status` para a implicação disso.

## Rastreamento git
- Branch principal: `main`.
