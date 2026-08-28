# Configuração do BMAD — atendimento

Fonte: `_bmad/_config/manifest.yaml`, `_bmad/core/config.yaml`, `_bmad/bmm/config.yaml`.

## Instalação (manifest.yaml)
- Versão da instalação: `6.11.0` (instalada e atualizada em 2026-08-27T15:34:16Z).
- Módulos instalados:
  - `core` v6.11.0 — built-in
  - `bmm` v6.11.0 — built-in
  - `bmb` v2.2.1 — externo, pacote npm `bmad-builder`, repo `bmad-code-org/bmad-builder`, canal `stable`
  - `cis` v0.3.1 — externo, pacote npm `bmad-creative-intelligence-suite`, repo `bmad-code-org/bmad-module-creative-intelligence-suite`, canal `stable`
  - `tea` v1.23.3 — externo, pacote npm `bmad-method-test-architecture-enterprise`, repo `bmad-code-org/bmad-method-test-architecture-enterprise`, canal `stable`
  - `bmad-loop` v0.11.1 — externo, sem pacote npm, repo `bmad-code-org/bmad-loop`, canal `stable`
- IDEs integrados: `claude-code`, `codex`, `cursor`.

## Configuração do módulo core (`_bmad/core/config.yaml`)
- `user_name`: Thiago
- `project_name`: atendimento
- `communication_language`: Portuguese BR
- `document_output_language`: Portuguese BR
- `output_folder`: `{project-root}/_bmad-output`

## Configuração do módulo bmm (`_bmad/bmm/config.yaml`)
- `user_skill_level`: intermediate
- `planning_artifacts`: `{project-root}/_bmad-output/planning-artifacts`
- `implementation_artifacts`: `{project-root}/_bmad-output/implementation-artifacts`
- `project_knowledge`: `{project-root}/docs` (pasta ainda não existe — ver `mem:project_structure`)
- Repete `user_name`, `project_name`, `communication_language`, `document_output_language`, `output_folder` com os mesmos valores do core.

## Outros módulos configurados (existem `config.yaml` próprios, não lidos em detalhe nesta verificação)
- `_bmad/bmb/config.yaml`
- `_bmad/cis/config.yaml`
- `_bmad/tea/config.yaml`
- `_bmad/bmad-loop/config.yaml`
- `_bmad/config.toml` e `_bmad/config.user.toml` — resolvidos por `_bmad/scripts/config_utils.py:load_central_config`, que lê `{project_root}/_bmad/config.toml` (obrigatório) e `{project_root}/_bmad/config.user.toml` (opcional) relativos ao `--project-root` passado ao script; escopo é este projeto, não uma instalação global (não alterados)
- `_bmad/custom/config.toml` e `_bmad/custom/config.user.toml`

Ver `mem:idioma_e_convencoes` para como esses idiomas se aplicam ao trabalho no projeto.
