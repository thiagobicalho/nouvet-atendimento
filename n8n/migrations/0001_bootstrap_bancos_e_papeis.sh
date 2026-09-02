#!/bin/bash
# 0001 — Bootstrap: cria o segundo banco (interno do n8n) e os 3 papéis de privilégio
# mínimo (AD-3). O banco da aplicação (nouvet_app, POSTGRES_APP_DB) já existe neste
# ponto — é o banco default do container, criado pelo entrypoint oficial do Postgres
# antes de rodar qualquer script deste diretório.
#
# É .sh (não .sql puro) porque precisa passar senha vinda de variável de ambiente para
# o psql — nunca senha fixa versionada no repo, e nunca interpolada direto no texto SQL
# (senha vira variável do psql, `-v`, referenciada como `:'nome'`/`:"nome"` no heredoc,
# que faz o quoting seguro de literal — ver comentário abaixo do bloco psql). Segue o
# padrão oficial da imagem `postgres` para provisionar múltiplos bancos/usuários via
# docker-entrypoint-initdb.d.
#
# Variáveis de ambiente esperadas (definidas em docker-compose.yml a partir do .env):
#   POSTGRES_USER, POSTGRES_DB   -- injetadas pela própria imagem postgres
#   N8N_ROLE_PASSWORD, APP_ROLE_PASSWORD, IDENTIDADE_ROLE_PASSWORD
#
# Nomes de banco/papel são fixos aqui (não configuráveis por env var) — só a senha de
# cada papel é secreta:
#   banco interno do n8n: nouvet_n8n       | papel dono: n8n_role
#   banco da aplicação:   $POSTGRES_DB      | papel padrão: app_role
#                                            | papel de identidade (PII): identidade_role

set -euo pipefail

# Senhas passadas como variáveis do psql (-v), nunca interpoladas direto no texto SQL:
# `:'nome'` é a sintaxe de variável quoted do psql, que faz o quoting seguro de literal
# SQL (escapa aspas simples internas) -- ao contrário de interpolação bash direta em
# `PASSWORD '${VAR}'`, que permite uma senha contendo `'; DROP TABLE ...; --` escapar do
# literal e executar como statement SQL independente.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
	-v pg_db="$POSTGRES_DB" \
	-v n8n_pw="$N8N_ROLE_PASSWORD" \
	-v app_pw="$APP_ROLE_PASSWORD" \
	-v identidade_pw="$IDENTIDADE_ROLE_PASSWORD" <<-'EOSQL'
	-- Banco interno do n8n (DB_TYPE=postgresdb) -- nunca compartilhado com o banco da
	-- aplicação, nunca SQLite (AD-3).
	CREATE DATABASE nouvet_n8n;

	-- Postgres concede CONNECT a PUBLIC por padrão em todo banco novo -- revoga aqui para
	-- que só os papéis explicitamente autorizados abaixo consigam conectar, reforçando o
	-- privilégio mínimo de AD-3 (superusuário continua conectando sempre, independente
	-- de GRANT/REVOKE).
	REVOKE CONNECT ON DATABASE nouvet_n8n FROM PUBLIC;
	REVOKE CONNECT ON DATABASE :"pg_db" FROM PUBLIC;

	-- Papel dono do banco interno do n8n: precisa poder criar/alterar seu próprio
	-- schema (workflows/execuções/credenciais) a cada versão nova do n8n. Sem nenhum
	-- acesso ao banco da aplicação.
	CREATE ROLE n8n_role LOGIN PASSWORD :'n8n_pw';
	ALTER DATABASE nouvet_n8n OWNER TO n8n_role;

	-- Papel padrão do banco da aplicação: fila/lock/config/profissionais/histórico
	-- (privilégios específicos concedidos na migration 0002, depois que as tabelas
	-- existem). Nunca recebe privilégio sobre a tabela de identidade (0003).
	CREATE ROLE app_role LOGIN PASSWORD :'app_pw';
	GRANT CONNECT ON DATABASE :"pg_db" TO app_role;

	-- Papel restrito só para a tabela de identidade cliente/pet (PII permanente) --
	-- mais restrito que app_role; privilégio concedido na migration 0003, nunca
	-- reaproveitado para outra tabela.
	CREATE ROLE identidade_role LOGIN PASSWORD :'identidade_pw';
	GRANT CONNECT ON DATABASE :"pg_db" TO identidade_role;
EOSQL
