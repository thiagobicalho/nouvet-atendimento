-- 0015 — Registro de falha técnica na fase de resposta base (Story 1.3, NFR-4/AD-31):
-- tabela append-only que garante rastro para a equipe sempre que uma das 3 consultas
-- Postgres desta fase (`Buscar Config`, `Normalizar telefone`, `Buscar Identidade`) ou
-- o próprio node do agente (`Agente Nouvet`) falha em `n8n/workflows/01 - Agente.json`
-- -- nunca deixa a execução parar sem resposta ao cliente. O contrato de saída
-- (`$json.output`) é o mesmo do caminho de sucesso, consumido sem alteração por
-- `n8n/workflows/07 - Ingresso e Fila.json` (`Enviar resposta RD Conversas`).
--
-- Append-only: sem `UPDATE`/`DELETE` concedido -- cada falha é um evento imutável,
-- nunca editado depois de gravado. `GRANT` só a `app_role` (criado na 0001) -- é o
-- papel da credencial Postgres ("Nouvet") usada por `01 - Agente.json`, nunca
-- `identidade_role` (papel restrito de PII, sem motivo pra gravar aqui).
CREATE TABLE atendimento_falha_registro (
	id                  BIGSERIAL PRIMARY KEY,
	-- Sem FK para identidade_tutor/identidade_cliente_pet -- a falha pode acontecer
	-- antes da identidade ser resolvida (ou por causa dela própria falhar), então
	-- contact_id/telefone são só o dado bruto do turno (`Receber Turno`), nunca uma
	-- referência validada contra outra tabela.
	contact_id          TEXT,
	telefone            TEXT,
	mensagem_agregada   TEXT,
	-- Texto livre do erro, só para investigação da equipe -- nunca é o texto que o
	-- cliente recebe (`Montar Mensagem de Falha` usa uma mensagem honesta e genérica à
	-- parte, sem detalhe técnico, ver `01 - Agente.json`).
	erro                TEXT,
	created_at          TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Mesma convenção de `atendimento_registro_setor` (0013): índice em created_at para
-- consulta por intervalo de tempo (ex.: falhas das últimas 24h para investigação).
CREATE INDEX idx_atendimento_falha_registro_created_at ON atendimento_falha_registro (created_at);

-- `app_role` já recebeu `GRANT USAGE ON SCHEMA public` na 0002 -- nenhuma migration
-- posterior repete esse grant (0004/0005/0007/0013/0014 conferidas), então esta
-- também não repete.
GRANT SELECT, INSERT ON atendimento_falha_registro TO app_role;
GRANT USAGE, SELECT ON atendimento_falha_registro_id_seq TO app_role;
