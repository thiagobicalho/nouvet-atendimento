-- 0003 — Tabela de identidade cliente/pet (AD-6, AD-11): identidade operacional rápida
-- ("quem é esse telefone, qual o pet"), alimentada por import único inicial do
-- SimplesVet + novos cadastros diretos, sempre gravados pelo sub-workflow único de
-- Story 4 (AD-11) — nunca por escrita direta de mais de um fluxo. Complementar ao card
-- do RD CRM (funil de negociação), nunca substituto (AD-6).
--
-- Única tabela com PII permanente do banco da aplicação -- por isso usa papel Postgres
-- à parte (identidade_role, criado na 0001), mais restrito que app_role, e NUNCA
-- concedida a app_role (nem o inverso) -- AD-3.
--
-- Um cliente pode ter mais de um pet: a chave natural é o par (telefone, nome_pet), não
-- o telefone isolado.
CREATE TABLE identidade_cliente_pet (
	id                  BIGSERIAL PRIMARY KEY,
	-- E.164 limpo (+55 + DDD + número, já considerando o 9º dígito móvel) -- mesmo
	-- formato canônico da normalização centralizada de AD-8, nunca reimplementado aqui.
	telefone            VARCHAR(20) NOT NULL,
	nome_cliente        VARCHAR(200) NOT NULL CHECK (btrim(nome_cliente) <> ''),
	nome_pet            VARCHAR(200) NOT NULL CHECK (btrim(nome_pet) <> ''),
	especie_pet         VARCHAR(50),
	raca_pet            VARCHAR(100),
	-- Referência ao contato/card no RD CRM (AD-8) -- permite a porta única (AD-11)
	-- checar existência antes de criar, sem duplicar o funil de negociação aqui.
	rd_crm_contact_id   VARCHAR(100),
	origem              VARCHAR(20) NOT NULL DEFAULT 'cadastro_direto'
	                        CHECK (origem IN ('import_simplesvet', 'cadastro_direto')),
	created_at          TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated_at          TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	UNIQUE (telefone, nome_pet)
);

CREATE INDEX idx_identidade_cliente_pet_telefone ON identidade_cliente_pet (telefone);

-- Privilégio mínimo: só identidade_role acessa esta tabela -- nunca app_role (AD-3).
GRANT USAGE ON SCHEMA public TO identidade_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON identidade_cliente_pet TO identidade_role;

GRANT USAGE, SELECT ON identidade_cliente_pet_id_seq TO identidade_role;
