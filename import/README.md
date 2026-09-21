# import/

Importador standalone do export do SimplesVet (Story 1.1, `AD-15`). Carrega
`identidade_tutor`, `identidade_telefone` e `identidade_pet` (migration
`n8n/migrations/0014_identidade_tutor_pet.sql`) a partir de três CSVs do export
(`glo_pessoa.csv`, `glo_contato.csv`, `vet_animal.csv`), lidos direto do disco.

Programa executável fora do n8n, sob demanda -- nunca um workflow/sub-workflow n8n,
nunca uma rotina periódica/agendada. O n8n não tem volume para os arquivos do export
nem privilégio de `identidade_role`; este programa conecta direto no Postgres com o
papel restrito de PII (`identidade_role`, `AD-3`).

## Onde colocar o export

O export do SimplesVet (CSV, dado real de cliente) **nunca entra no repositório**
(NFR-6) -- fica num caminho qualquer no host, fora deste diretório. `docker-compose.yml`
monta esse caminho só-leitura dentro do container via a variável de ambiente
`SIMPLESVET_EXPORT_HOST_DIR` (definida no `.env`, nunca versionada).

O diretório apontado precisa conter, no mínimo:

- `glo_pessoa.csv` -- tutores
- `glo_contato.csv` -- telefones/e-mails (só contatos `tco_var_nome == "Celular"`
  viram telefone -- os demais tipos, ex. `Email`/`Residencial`/`Comercial`/`Outros`,
  não fazem sentido para reconhecimento por telefone e ficam fora desta story)
- `vet_animal.csv` -- pets

## Como rodar

Com a stack já de pé (`docker compose up -d postgres`), aplique a migration `0014`
antes da primeira execução. `docker-entrypoint-initdb.d` (mecanismo que aplica
`n8n/migrations/*` automaticamente) só roda na **primeira** inicialização do volume do
Postgres -- num volume já existente (caso real de produção, que já rodou `0001`-`0013`),
`0014` precisa ser aplicada manualmente:

```bash
docker compose exec -T postgres psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_SUPERUSER" --dbname "$POSTGRES_APP_DB" \
  < n8n/migrations/0014_identidade_tutor_pet.sql
```

Só então:

```bash
docker compose run --rm importer
```

`docker compose run` ignora `profiles` e ataca o serviço `importer` diretamente, então
não é preciso `--profile tools` -- mas o serviço nunca sobe sozinho com
`docker compose up` default (`profiles: ["tools"]`).

O importador é idempotente: rodar de novo sobre um export mais recente nunca duplica
registro nem sobrescreve campo de domínio próprio (preferência, autorização de
mensagem, estado de migração) que a conversa já tenha gravado -- só atualiza as
colunas que esta story cria (nome/espécie/raça/data de nascimento do pet, nome do
tutor) via UPSERT por código de origem do SimplesVet.

Ao final, imprime um relatório de cobertura -- sempre número absoluto + fração da base
por campo (nunca percentual isolado).

## Variáveis de ambiente

Lidas do `.env` da raiz do repo (mesmo arquivo da stack n8n/Postgres):

- `SIMPLESVET_EXPORT_HOST_DIR` -- caminho no host com os 3 CSVs do export (fora do
  repo).
- `POSTGRES_APP_DB`, `POSTGRES_IDENTIDADE_ROLE_PASSWORD` -- já existentes, reusados
  sem criar credencial nova.

Dentro do container (fixas em `docker-compose.yml`, não precisam ser definidas à
mão): `POSTGRES_HOST=postgres`, `POSTGRES_PORT=5432`, `SIMPLESVET_EXPORT_DIR=/export`.

## Testes

Testes de unidade rodam sem Postgres/Docker -- CSVs sintéticos fictícios, nunca dado
real:

```bash
cd import
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/pytest -q
```
