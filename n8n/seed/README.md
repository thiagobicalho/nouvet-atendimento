# n8n/seed

Dados iniciais de `secretaria_config` — tom, dados institucionais, catálogo de serviços,
lista interina de sinais de alerta clínico, limiares de SLA/follow-up, contatos de
plantonista/emergência (AD-1, Config-as-Data).

Este seed é o **ponto de partida** para popular a tabela na primeira subida do banco de
cada ambiente (dev, depois produção) — não é a fonte viva depois disso. Durante o Piloto,
edição de conteúdo em produção é feita só pela equipe Btech via acesso direto ao banco
(Consistency Conventions da spine), não reaplicando este seed.

## Aplicação (manual, não automática)

Diferente de `n8n/migrations` (montado em `docker-entrypoint-initdb.d`, roda sozinho na
primeira subida do volume — ver `docker-compose.yml`), `n8n/seed` **não** é montado no
container nem roda automaticamente. Depois de subir a stack e aplicar as migrations
0001-0004, aplicar o seed manualmente, conectado ao banco da aplicação
(`$POSTGRES_APP_DB`, default `nouvet_app`):

```sh
psql -h <host> -U <superusuário ou app_role> -d "${POSTGRES_APP_DB:-nouvet_app}" -f n8n/seed/0001_secretaria_config.sql
```

Idempotente (`ON CONFLICT (id) DO NOTHING`) — reaplicar não duplica nem sobrescreve a
linha singleton (`id=1`).
