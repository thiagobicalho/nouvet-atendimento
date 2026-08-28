# Stack tecnológica da aplicação — PENDENTE

Status: **não definida**. Nenhuma evidência confirmada de linguagem/framework para a aplicação "atendimento" em si.

## Importante — não confundir com scripts do BMAD
- Os únicos arquivos `.py` do repositório estão em `_bmad/scripts/` e são utilitários internos da ferramenta BMAD (`config_utils.py`, `memlog.py`, `render_skill.py`, `resolve_config.py`, `resolve_customization.py`).
- O `.serena/project.yml` lista `language_servers: [python]` porque o Serena detectou esses scripts — **isso não deve ser interpretado como decisão de que a aplicação será em Python**. É apenas o language server ativo para os arquivos `.py` existentes no momento (ferramentas BMAD), não uma escolha de stack do produto.
- Não há `package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, nem qualquer outro manifesto de dependências de aplicação na raiz do projeto.
- Não há pasta `src/`, `app/` ou equivalente com código de aplicação.

## Ação recomendada
- Tratar a stack como decisão em aberto até que haja definição explícita do usuário ou documento de arquitetura (`mem:bmad_configuration` mostra que `_bmad/bmm/config.yaml` aponta `project_knowledge` para `{project-root}/docs`, pasta que ainda não existe).
