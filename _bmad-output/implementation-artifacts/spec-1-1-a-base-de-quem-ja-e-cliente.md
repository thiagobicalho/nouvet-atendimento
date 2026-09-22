---
title: 'Story 1.1 — A base de quem já é cliente'
type: 'feature'
created: '2026-09-21'
status: done
baseline_revision: 'e2353ff45326d1cb434a420e7f19ae01524dd234'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
operator_actions:
  - Aplicar a migration n8n/migrations/0014_identidade_tutor_pet.sql no Postgres real via `docker compose exec -T postgres psql -v ON_ERROR_STOP=1 --username "$POSTGRES_SUPERUSER" --dbname "$POSTGRES_APP_DB" < n8n/migrations/0014_identidade_tutor_pet.sql` (comando documentado em import/README.md) — docker-entrypoint-initdb.d só roda na primeira inicialização do volume, então o arquivo presente sozinho não basta.
  - Definir SIMPLESVET_EXPORT_HOST_DIR no .env do host com o caminho (fora do repositório) para um diretório contendo o export real do SimplesVet (glo_pessoa.csv, glo_contato.csv, vet_animal.csv).
  - Rodar `docker compose run --rm importer` contra o export real e conferir o relatório de cobertura impresso ao final (contagem absoluta + fração por tutor/pet/telefone/registros descartados).
  - Rodar `docker compose run --rm importer` uma segunda vez sobre o mesmo export (ou um export mais novo) e confirmar em identidade_tutor/identidade_pet/identidade_telefone que nenhum registro duplicou e nenhum campo foi sobrescrito indevidamente — valida a AC de re-execução idempotente que este ambiente de build não tem como testar sem Postgres real.
  - Depois do import rodar contra dado real, consultar identidade_telefone em busca de algum telefone com mais de um tutor_id distinto e confirmar que ambos os vínculos foram gravados, nenhum resolvido a um tutor arbitrário — valida a AC de telefone ambíguo, que depende de dado real para ocorrer.
  - Decidir com o Thiago quando identidade_cliente_pet (tabela antiga do Piloto, ainda referenciada pelos workflows n8n `01 - Agente`/`04 - Registrar Atendimento CRM` marcados active:true em 21/09/2026) pode ser descomissionada — esta story deliberadamente não alterou nem removeu essa tabela.
deferred:
  - summary: >-
      Nenhum lock consultivo impede duas execuções manuais concorrentes do
      importador contra o mesmo Postgres.
    evidence: |-
      O "Never" da story proíbe rotina periódica/agendada, mas nada impede dois
      operadores rodarem `docker compose run --rm importer` ao mesmo tempo — os
      UPSERTs são idempotentes individualmente, mas não há garantia de isolamento
      entre duas execuções completas simultâneas.
    location: import/importador/main.py
    severity: low
  - summary: >-
      O import não deixa rastro persistido além de stdout/log (quando rodou,
      quais contagens).
    evidence: |-
      Útil para auditoria futura, mas não é exigido por nenhuma AC desta story;
      infraestrutura compartilhada torna isso mais relevante a médio prazo.
    location: import/importador/main.py
    severity: low
  - summary: >-
      import/tests/ não roda em nenhuma automação de CI.
    evidence: |-
      Não há CI configurado no repositório hoje — gap pré-existente, só
      incidentalmente exposto por esta story ao adicionar o primeiro pacote de
      testes Python do projeto.
    severity: low
---

<intent-contract>

## Intent

**Problem:** A Nouvi não tem como reconhecer quem já é cliente — tutores, pets, telefones e preferências vivem só no SimplesVet, que não tem API.

**Approach:** Um programa standalone (`import/`, fora do n8n, `AD-15`) lê o export do SimplesVet direto do disco e carrega tutores/pets/telefones no domínio próprio do Postgres (`identidade_role`), normalizando telefone para E.164 e deixando a base pronta para as stories de reconhecimento (1.5) e preferência (1.6).

## Boundaries & Constraints

**Always:**
- Migration nova é só aditiva, numerada `0014+` em `n8n/migrations/`, nunca reescreve `0001`–`0013`.
- Só `identidade_role` recebe GRANT nas tabelas novas (`AD-3`) — nunca `app_role`/`n8n_role`.
- Telefone é sempre normalizado chamando a função `telefone_normalizar()` já existente (migration `0006`) dentro do SQL do próprio importador — nunca reimplementar a lógica de normalização (`AD-8`).
- Import é idempotente: chave de upsert é o código de origem do SimplesVet (`pes_int_codigo`/`ani_int_codigo`), nunca casamento por nome.
- Todo UPSERT enumera explicitamente só as colunas que esta story cria — nunca um `SET` genérico — para que colunas futuras (preferência, autorização de mensagem, estado de migração) fiquem automaticamente protegidas contra sobrescrita quando existirem.
- Cobertura é sempre número absoluto + fração da base (NFR-9), nunca percentual isolado.
- Nenhum CSV do export, nem artefato gerado pelo import, entra no versionamento (NFR-6) — caminho do export vem de variável de ambiente, fora do repo.
- O importador é executável standalone, roda fora do n8n, conecta direto no Postgres (`AD-15`).
- Telefone ligado a mais de um tutor grava as duas ligações (uma linha por par tutor-telefone) — nunca resolve para um tutor arbitrário.
- Registro com campo ausente (porte, espécie etc.) grava com o campo NULL e segue utilizável — nunca é descartado por dado faltando.

**Block If:** Nenhuma decisão bloqueante identificada — as escolhas de implementação (tipo de contato importado como telefone, layout do programa) estão justificadas em Design Notes.

**Never:**
- Nunca `DROP`/`ALTER` `identidade_cliente_pet` (`0003`/`0009`) nesta story — os workflows do Piloto (`01 - Agente`, `04 - Registrar Atendimento CRM` etc.) seguem `active: true` na instância n8n real (confirmado via MCP em 21/09/2026) e podem ainda ler/escrever essa tabela. Coexistência, nunca substituição, até decisão explícita de descomissionamento.
- Nunca virar rotina periódica/agendada (`AD-15`) — só execução sob demanda.
- Nunca rodar como workflow/sub-workflow n8n.
- Nunca aplicar a migration ou rodar o importador contra o Postgres real de produção sem autorização explícita — é infraestrutura compartilhada com outros clientes da Btech e com o Piloto ainda ativo.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Primeira carga | Export completo, tabelas novas vazias | Tutores, pets, vínculo e telefones gravados; telefone em E.164 | Nenhum erro esperado |
| Telefone ambíguo | Mesmo telefone normalizado em >1 `pes_int_codigo` | Duas linhas em `identidade_telefone`, nenhuma resolvida a um tutor só | Nenhum erro esperado |
| Re-execução sem mudança | Importador roda de novo sobre export mais novo | Nenhuma duplicata; nenhum campo de domínio próprio sobrescrito | Nenhum erro esperado |
| Campo ausente | Linha sem `esp_var_nome`/porte | Campo gravado NULL, registro segue utilizável | Nenhum erro esperado |
| Telefone não normalizável | Contato "Celular" vazio/não numérico | `telefone_normalizar()` retorna NULL | Vínculo de telefone não é gravado; tutor/pet seguem gravados; conta na cobertura como não preenchido |
| Quebra de linha dentro de campo | Observação/tag com `\n` entre aspas no CSV | Parser lê a linha lógica completa, sem corromper colunas seguintes | Linha que não fecha aspas corretamente vira registro de erro logado; import não aborta |
| Artefato do import | Qualquer saída gerada pelo programa | Nada de PII no repositório | Nenhum erro esperado |

</intent-contract>

## Code Map

- `n8n/migrations/0003_identidade_cliente_pet.sql`, `n8n/migrations/0009_identidade_cliente_pet_campos_reais.sql` -- schema antigo do Piloto (tabela única `identidade_cliente_pet`, papel `identidade_role`, AD-3) — nunca tocado por esta story, só referência.
- `n8n/migrations/0006_identidade_porta_unica.sql` -- define `telefone_normalizar(p_telefone TEXT) RETURNS TEXT` (E.164, `IMMUTABLE`, `GRANT` a `app_role` e `identidade_role`) — reusar via chamada SQL, nunca reimplementar.
- `n8n/migrations/0001_bootstrap_bancos_e_papeis.sh` -- cria o papel `identidade_role` e a senha via `IDENTIDADE_ROLE_PASSWORD`/`.env` `POSTGRES_IDENTIDADE_ROLE_PASSWORD` — mesmo papel que a migration nova usa.
- `n8n/migrations/README.md` -- convenção de documentar cada migration numerada; seguir o mesmo padrão para a `0014`.
- `docker-compose.yml` -- serviço `postgres` sem porta publicada ao host; importador precisa entrar na mesma rede compose (serviço novo) para alcançar `postgres:5432`.
- `.env.example` -- `POSTGRES_IDENTIDADE_ROLE_PASSWORD`, `POSTGRES_APP_DB` já existentes, reusar sem criar variável de senha nova.
- `_bmad-output/reference/simplesvet/banco/glo_pessoa.csv` -- schema real do tutor (24 colunas: `pes_int_codigo`, `pes_var_nome`, `pes_var_cpf` etc.) — **sem telefone**, gitignored, só para dev/teste local, nunca commitar.
- `_bmad-output/reference/simplesvet/banco/glo_contato.csv` -- telefones/e-mails por `pes_int_codigo`; `tco_var_nome` distingue `Celular` (5.862 de 9.505 linhas) de `Email`/`Residencial`/`Comercial`/`Outros`; `con_var_contato` é o valor bruto, ex. `"(11) 98268-8240"`.
- `_bmad-output/reference/simplesvet/banco/vet_animal.csv` -- schema real do pet (`ani_int_codigo`, `pes_int_codigo` — vínculo direto ao tutor, `esp_var_nome`, `rac_var_nome`, `ani_dat_nascimento`).
- `_bmad-output/planning-artifacts/simplesvet/2026-09-15-analise-base-simplesvet.md:121` -- aviso: ~7 linhas do export têm quebra de linha dentro de campo entre aspas — parser precisa aguentar.
- `_bmad-output/planning-artifacts/simplesvet/2026-09-15-analise-base-simplesvet.md:192` -- schema novo deve vir de `glo_pessoa` + `glo_contato` + `vet_animal`, não do `clientes.csv` antigo do Piloto.
- `_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-17/ARCHITECTURE-SPINE.md:245-273` -- Structural Seed (`import/` top-level) e tabelas-alvo `identidade_tutor`/`identidade_pet`.
- n8n MCP (`n8n_list_workflows`, confirmado 21/09/2026) -- workflows `01 - Agente`, `02 - Escalar Humano`, `03 - Buscar Info Setor`, `04 - Registrar Atendimento CRM`, `05 - Gerenciar Task SLA`, `06 - Lembretes e Escalonamento SLA` estão **`active: true`** na instância real (`myeditor.uniqueads.com.br`, multi-tenant Btech) — evidência viva de que `identidade_cliente_pet` pode ainda estar em uso.

## Tasks & Acceptance

**Execution:**
- `n8n/migrations/0014_identidade_tutor_pet.sql` -- criar `identidade_tutor` (`id`, `simplesvet_codigo_pessoa` único nullable, `nome`, `origem`, `created_at`, `updated_at`), `identidade_telefone` (`id`, `tutor_id` FK, `telefone`, `origem`, `created_at`, `UNIQUE(tutor_id, telefone)`, índice em `telefone`), `identidade_pet` (`id`, `simplesvet_codigo_animal` único nullable, `tutor_id` FK, `nome`, `especie`, `raca`, `data_nascimento`, `origem`, `created_at`, `updated_at`); `GRANT` só a `identidade_role` -- estabelece a base nova sem tocar `identidade_cliente_pet` (AD-15/AD-3).
- `n8n/migrations/README.md` -- adicionar entrada da `0014` no mesmo padrão das entradas `0001`–`0013`.
- `import/importador/csv_source.py` -- ler `glo_pessoa.csv`/`glo_contato.csv`/`vet_animal.csv` com parser que respeita aspas com quebra de linha embutida; linha corrompida vira registro de erro logado, não aborta o import -- cobre o achado do `2026-09-15-analise-base-simplesvet.md:121`.
- `import/importador/db.py` -- conexão Postgres via `identidade_role` (env), UPSERT de tutor/pet por código SimplesVet com `SET` restrito às colunas desta story, `INSERT` de telefone chamando `telefone_normalizar()` no SQL, sem deduplicar telefone repetido entre tutores.
- `import/importador/main.py` -- orquestra leitura + carga; ao final, calcula e imprime relatório de cobertura (contagem absoluta + fração preenchida por campo relevante, NFR-9).
- `import/README.md` -- como rodar (`docker compose run --rm importer`), variáveis de ambiente esperadas, onde colocar o export real no host (nunca no repo), nota de que só contatos `Celular` viram telefone.
- `import/requirements.txt` -- `psycopg2-binary`, `pytest`.
- `import/Dockerfile` -- imagem mínima do importador (mesma base Python usada nos testes).
- `docker-compose.yml` -- adicionar serviço `importer` sob `profiles: ["tools"]` (nunca inicia com `docker compose up` default), rede compartilhada com `postgres`, credenciais via `POSTGRES_IDENTIDADE_ROLE_PASSWORD` já existente.
- `import/tests/test_csv_source.py` -- teste de unidade: parsing com quebra de linha, telefone não normalizável (mock de `telefone_normalizar` como função pura equivalente), campo ausente — CSVs sintéticos fictícios, nunca dado real.
- `import/tests/test_cobertura.py` -- teste de unidade do cálculo de cobertura (contagem absoluta + fração).

**Acceptance Criteria:**
- Given o export do SimplesVet disponível no caminho configurado, when o importador roda, then tutores, pets, vínculo tutor↔pet e telefones ficam gravados em `identidade_tutor`/`identidade_pet`/`identidade_telefone`, com telefone em E.164.
- Given um telefone que aparece em mais de um `pes_int_codigo` do export, when o importador roda, then ambos os vínculos tutor-telefone são gravados, nenhum resolvido a um tutor único.
- Given que o importador já rodou antes, when ele roda de novo sobre um export mais recente, then nenhum campo de domínio próprio é sobrescrito e nenhum registro criado pela conversa é duplicado.
- Given um registro sem porte ou sem espécie, when o importador roda, then o campo fica NULL e o registro segue utilizável.
- Given o import concluído, when se consulta a cobertura, then o número absoluto de tutores/pets/telefones carregados aparece, cada um com a fração da base preenchida.
- Given qualquer artefato gerado pelo import, when o repositório é inspecionado, then nenhum dado de cliente está versionado.

## Spec Change Log

_Nenhuma entrada — sem loopback `bad_spec` nesta execução._

## Review Triage Log

### 2026-09-21 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 10 (high 1, medium 6, low 3)
- defer: 3 (low 3)
- reject: 6
- addressed_findings:
  - `[high]` `[patch]` "pets importados" na cobertura sempre reportava 100% (numerador = denominador = `len(pets)`), nunca refletindo pets descartados por falta de tutor correspondente (`pets_sem_tutor`) — corrigido: `main.py` agora passa `pets_gravados` para `calcular_cobertura`, que reporta o valor realmente persistido.
  - `[medium]` `[patch]` Contatos `Celular` sem tutor correspondente desapareciam tanto do numerador quanto do denominador de "telefones válidos gravados", inflando a fração aparente — corrigido: `contatos_sem_tutor` agora soma ao denominador.
  - `[medium]` `[patch]` Linhas descartadas por corrupção de parsing (`ErroLinha`) só apareciam em `logger.warning` espalhados, nunca no relatório final de cobertura — corrigido: nova linha "registros descartados" agregando `linhas_descartadas` + `pets_sem_tutor` + `contatos_sem_tutor`.
  - `[medium]` `[patch]` `pes_int_codigo`/`ani_int_codigo` não numérico faria `int()` lançar `ValueError` não capturado, abortando o import inteiro — viola o Always "linha corrompida... nunca aborta o import inteiro" (não observado no export real, mas o parser não podia depender disso) — corrigido: `_int_ou_erro` em `csv_source.py`, com teste de regressão.
  - `[medium]` `[patch]` `db.py` (upsert_tutor/upsert_telefone/upsert_pet — a lógica real de allowlist de colunas e de "telefone ambíguo grava as duas linhas") tinha zero cobertura de teste — corrigido: `import/tests/test_db.py` com cursor falso, verificando a allowlist do `SET` e que `upsert_telefone` só insere quando `telefone_normalizar()` (simulado) diz que é normalizável. Não substitui verificação contra Postgres real (ver Design Notes/Verification).
  - `[medium]` `[patch]` Nenhum dos dois documentos (`import/README.md`, spec) descrevia o comando real para aplicar a migration `0014` a um volume Postgres já inicializado (`docker-entrypoint-initdb.d` só roda na primeira inicialização) — corrigido: comando `docker compose exec ... psql ...` adicionado a `import/README.md`.
  - `[low]` `[patch]` `_caminho_export()` só checava se o diretório existia, não os 3 CSVs esperados dentro dele — um `glo_pessoa.csv` ausente virava `FileNotFoundError` cru — corrigido: checagem explícita com mensagem clara.
  - `[low]` `[patch]` `main()`/`importar()` não tinham `rollback()` explícito nem mensagem amigável em falha de conexão/transação — traceback cru subia sem contexto — corrigido: `try/except` com `rollback()`, log claro, e `psycopg2.OperationalError` tratado em `main()`.
  - `[low]` `[patch]` `identidade_telefone.tutor_id`/`identidade_pet.tutor_id` (migration `0014`) não documentavam por que não há `ON DELETE CASCADE` — corrigido com comentário explicando que é o default deliberado.
  - `[low]` `[patch]` `upsert_pet`'s `SET tutor_id = EXCLUDED.tutor_id` (reatribuição de pet a outro tutor num re-import) não estava documentado como decisão deliberada — corrigido com comentário.
  - `[low]` `defer`: ausência de lock consultivo contra duas execuções manuais concorrentes do importador.
  - `[low]` `defer`: nenhum rastro persistido do import além de stdout/log (contagens, quando rodou).
  - `[low]` `defer`: nenhuma automação de CI roda `import/tests/` — não há CI no repositório hoje, pré-existente.
  - `reject` (investigado e descartado com evidência): risco de encoding não-UTF-8 no export real (`chardet` confirmou UTF-8, 99% de confiança, nos 3 CSVs); drift entre cabeçalho dos fixtures de teste e o CSV real (comparação direta confirmou match exato); sensibilidade a maiúsculas/minúsculas em `"NULL"`/`"Celular"` (amostra real confirma valores consistentes, sem variantes); `StopIteration` em CSV vazio (sem ocorrência real); `KeyError` por coluna ausente no cabeçalho (schema real estável, confirmado); transação abortar inteira ao encontrar uma data inválida (comportamento é o desenhado deliberadamente pela própria docstring de `importar()` — tudo ou nada — não é defeito).

## Design Notes

**Coexistência, não substituição.** A investigação encontrou os workflows do Piloto (`01 - Agente`, `04 - Registrar Atendimento CRM` etc.) com `active: true` na instância n8n real (multi-tenant, compartilhada com outros clientes Btech) em 21/09/2026 — evidência de que `identidade_cliente_pet` pode ainda estar em uso produtivo, apesar do pivô de produto. Por isso a migration `0014` só cria tabelas novas (`identidade_tutor`/`identidade_telefone`/`identidade_pet`); `DROP`/`ALTER` de `identidade_cliente_pet` fica para uma decisão futura e explícita de descomissionamento, fora desta story.

**Telefone normalizado por tabela filha, não array.** A espinha descreve `identidade_tutor` com "telefones (lista)". Optei por uma tabela filha (`identidade_telefone`, `UNIQUE(tutor_id, telefone)`, índice em `telefone`) em vez de coluna `TEXT[]` porque detectar ambiguidade (mesmo telefone em >1 tutor) exige correlação indexada entre linhas — inviável de forma eficiente com array. Ambiguidade não precisa de flag própria: duas linhas com o mesmo `telefone` e `tutor_id` diferentes já É o estado ambíguo, que a Story 1.5 (`AD-32`) consulta por contagem.

**Só `Celular` vira telefone.** `glo_contato.tco_var_nome` traz `Celular` (5.862/9.505), `Email`, `Residencial`, `Comercial`, `Outros`. Só `Celular` é candidato a WhatsApp/E.164; os demais não fazem sentido para reconhecimento por telefone e ficam fora desta story.

**Upsert por código de origem, allowlist de colunas.** Chave de upsert é `simplesvet_codigo_pessoa`/`simplesvet_codigo_animal` (não nome, que tem duplicidade/grafia inconsistente na base). O `SET` do `UPSERT` enumera só as colunas que esta story cria (`nome`, `especie`, `raca`, `data_nascimento`) — nunca um `SET` genérico. Isso é o mecanismo real que garante a AC de não-sobrescrita: quando stories futuras (1.6 preferência, 3.1 autorização, épico 4 estado de migração) adicionarem colunas, o `UPSERT` desta story nunca as referencia, logo nunca as sobrescreve — sem precisar de `origem` por campo agora, que só passa a ser necessário quando a primeira coluna de preferência existir.

**Verificação limitada ao alcance deste ambiente.** Este ambiente de desenvolvimento não tem Docker nem `psql`/Postgres local instalado, e o único Postgres alcançável é o de produção compartilhada (ver Coexistência acima) — aplicar a migration e rodar o importador contra dado real exige o operador. A Verificação abaixo cobre o que dá para confirmar sem tocar infraestrutura viva.

## Verification

**Commands:**
- `cd import && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt && .venv/bin/pytest -q` -- expected: todos os testes de unidade passam (parsing, ambiguidade, campo ausente, telefone não normalizável, cálculo de cobertura) sem precisar de Postgres real.
- `docker compose config` -- expected: `docker-compose.yml` continua válido com o serviço `importer` novo sob `profiles: ["tools"]`, sem alterar o comportamento de `docker compose up` default.

**Manual checks (sem CLI para a parte que depende de Postgres real):**
- Revisar `n8n/migrations/0014_identidade_tutor_pet.sql` por inspeção contra o padrão das migrations `0001`–`0013` (comentários, `GRANT` só a `identidade_role`, nenhum `DROP`/`ALTER` de `identidade_cliente_pet`).
- Aplicar a migration `0014` e rodar `docker compose run --rm importer` contra o export real fica pendente de execução do operador (ver Auto Run Result) — este ambiente não alcança Postgres real sem risco à infraestrutura compartilhada/Piloto ainda ativo.

## Auto Run Result

**Status:** `awaiting-operator` — todo o código desta story está implementado, testado (no que este ambiente permite) e commitado; falta só execução contra infraestrutura real, que exige o operador (ver `operator_actions` no frontmatter).

**Resumo do que foi implementado:** migration aditiva `0014` (tabelas `identidade_tutor`/`identidade_telefone`/`identidade_pet`, `GRANT` só a `identidade_role`, sem tocar `identidade_cliente_pet`) e um importador Python standalone (`import/`) que lê os 3 CSVs do export SimplesVet, normaliza telefone via `telefone_normalizar()` (SQL, nunca reimplementado), faz UPSERT idempotente por código de origem com allowlist explícita de colunas, e imprime um relatório de cobertura honesto (absoluto + fração, incluindo registros descartados).

**Arquivos alterados:**
- `n8n/migrations/0014_identidade_tutor_pet.sql` -- nova migration aditiva (tutor/telefone/pet).
- `n8n/migrations/README.md` -- entrada da `0014` no padrão das anteriores.
- `docker-compose.yml` -- serviço `importer` sob `profiles: ["tools"]`.
- `.env.example` -- variável `SIMPLESVET_EXPORT_HOST_DIR` documentada.
- `import/importador/csv_source.py` -- parser tolerante a quebra de linha/aspas não fechadas/código não numérico, nunca aborta o import inteiro.
- `import/importador/db.py` -- UPSERTs com allowlist de colunas e normalização de telefone via SQL.
- `import/importador/cobertura.py` -- cálculo de cobertura honesto (absoluto + fração, inclui descartes).
- `import/importador/main.py` -- orquestração, checagem de arquivos esperados, transação única com rollback explícito em falha.
- `import/README.md`, `import/Dockerfile`, `import/requirements.txt`, `import/pytest.ini` -- empacotamento e documentação.
- `import/tests/test_csv_source.py`, `import/tests/test_cobertura.py`, `import/tests/test_db.py` -- 20 testes de unidade, CSVs sintéticos fictícios, cursor Postgres falso.

**Findings da revisão:** ver `## Review Triage Log` acima — 10 `patch` aplicados (1 alto, 6 médio, 3 baixo; o de severidade alta era um bug real de cobertura: "pets importados" sempre reportava 100%), 3 `defer` (registrados em `deferred:` no frontmatter), 6 `reject` (investigados e descartados com evidência direta contra o export real: encoding UTF-8 confirmado, cabeçalho dos fixtures de teste confirmado idêntico ao CSV real, valores de `tco_var_nome`/marcador `NULL` confirmados consistentes na amostra real).

**Verificação realizada:**
- `cd import && .venv/bin/pytest -q` -- 20/20 testes passam, sem precisar de Postgres (comando do venv adaptado com `uv` porque este ambiente não tem `python3-venv`; mesmo efeito do comando prescrito na spec).
- `docker-compose.yml` validado via `yaml.safe_load` (sem binário `docker` disponível neste ambiente) -- serviço `importer` presente, `profiles: ["tools"]` confirmado.
- `n8n/migrations/0014_identidade_tutor_pet.sql` revisada por inspeção contra o padrão `0001`–`0013` -- `GRANT` só a `identidade_role`, nenhum `DROP`/`ALTER` de `identidade_cliente_pet`.
- Export real (`_bmad-output/reference/simplesvet/banco/`, gitignored, nunca commitado) inspecionado diretamente para embasar/descartar findings da revisão: encoding UTF-8 confirmado (`chardet`, 99% de confiança nos 3 CSVs), cabeçalho de `glo_pessoa.csv`/`glo_contato.csv`/`vet_animal.csv` idêntico byte a byte aos fixtures de teste, `tco_var_nome` confirmado com valores exatos (`Celular`/`Comercial`/`Email`/`Outros`/`Residencial`, sem variação de caixa), datas de nascimento confirmadas em formato ISO.
- **Não verificado neste ambiente** (sem Docker/psql/Postgres alcançável sem risco a infraestrutura compartilhada): aplicar a migration `0014` de fato, rodar o importador contra dado real, confirmar re-execução idempotente e persistência de telefone ambíguo em Postgres de verdade -- itens de `operator_actions`.

**Riscos residuais:**
- O mecanismo real de idempotência/ambiguidade (`ON CONFLICT`, `UNIQUE (tutor_id, telefone)`, `telefone_normalizar()`) está coberto por raciocínio de design + revisão de SQL + testes de construção de query com cursor falso, nunca por uma execução real contra Postgres -- risco residual até o operador rodar `operator_actions`.
- `identidade_cliente_pet` segue viva e potencialmente em uso pelos workflows do Piloto ainda `active: true` -- decisão de descomissionamento explicitamente fora do escopo desta story (ver `Never`).
- 3 itens de baixa severidade ficaram registrados como `deferred` (lock concorrente, rastro de auditoria persistido, CI ausente) -- nenhum bloqueia esta story, mas valem atenção futura.

## Operator Confirmation

Confirmed 2026-09-22: the external actions this story owed were carried out.

- Aplicar a migration n8n/migrations/0014_identidade_tutor_pet.sql no Postgres real via `docker compose exec -T postgres psql -v ON_ERROR_STOP=1 --username "$POSTGRES_SUPERUSER" --dbname "$POSTGRES_APP_DB" < n8n/migrations/0014_identidade_tutor_pet.sql` (comando documentado em import/README.md) — docker-entrypoint-initdb.d só roda na primeira inicialização do volume, então o arquivo presente sozinho não basta.
- Definir SIMPLESVET_EXPORT_HOST_DIR no .env do host com o caminho (fora do repositório) para um diretório contendo o export real do SimplesVet (glo_pessoa.csv, glo_contato.csv, vet_animal.csv).
- Rodar `docker compose run --rm importer` contra o export real e conferir o relatório de cobertura impresso ao final (contagem absoluta + fração por tutor/pet/telefone/registros descartados).
- Rodar `docker compose run --rm importer` uma segunda vez sobre o mesmo export (ou um export mais novo) e confirmar em identidade_tutor/identidade_pet/identidade_telefone que nenhum registro duplicou e nenhum campo foi sobrescrito indevidamente — valida a AC de re-execução idempotente que este ambiente de build não tem como testar sem Postgres real.
- Depois do import rodar contra dado real, consultar identidade_telefone em busca de algum telefone com mais de um tutor_id distinto e confirmar que ambos os vínculos foram gravados, nenhum resolvido a um tutor arbitrário — valida a AC de telefone ambíguo, que depende de dado real para ocorrer.
- Decidir com o Thiago quando identidade_cliente_pet (tabela antiga do Piloto, ainda referenciada pelos workflows n8n `01 - Agente`/`04 - Registrar Atendimento CRM` marcados active:true em 21/09/2026) pode ser descomissionada — esta story deliberadamente não alterou nem removeu essa tabela.

_Appended by the bmad-loop orchestrator (`bmad-loop confirm`, #335): a human confirmed these external actions out of band, and the story was advanced from `awaiting-operator` to `done`._
