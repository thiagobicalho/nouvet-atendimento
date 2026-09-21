-- 0014 — Base própria de identidade (Story 1.1, AD-15/AD-3): tutores, telefones e
-- pets carregados pelo importador standalone do export SimplesVet (`import/`, fora do
-- n8n), preparando o terreno para reconhecimento por telefone (Story 1.5) e memória de
-- preferência (Story 1.6).
--
-- Só cria tabelas novas -- nunca `DROP`/`ALTER` em `identidade_cliente_pet` (0003/0009).
-- Aquela tabela alimenta os workflows do Piloto (`01 - Agente`, `04 - Registrar
-- Atendimento CRM` etc.), confirmados `active: true` na instância n8n real
-- (multi-tenant Btech) em 21/09/2026 -- coexistência, nunca substituição, até decisão
-- explícita e futura de descomissionamento (Never desta story).
--
-- `GRANT` só a `identidade_role` (criado na 0001) -- nunca `app_role`/`n8n_role`
-- (AD-3), mesmo papel restrito que já protege `identidade_cliente_pet`.

-- identidade_tutor: um tutor por `pes_int_codigo` do SimplesVet. `simplesvet_codigo_pessoa`
-- é único mas nullable -- nullable porque uma story futura (1.7, "A Nouvi cadastra quem
-- ainda não é cliente") também vai gravar tutores sem origem SimplesVet, sem código de
-- origem algum; Postgres trata múltiplos NULL como não-conflitantes num UNIQUE, então
-- isso nunca colide entre si. Chave de upsert do importador é este código -- nunca
-- casamento por nome (Always).
CREATE TABLE identidade_tutor (
	id                          BIGSERIAL PRIMARY KEY,
	simplesvet_codigo_pessoa    INTEGER UNIQUE,
	nome                        VARCHAR(200) NOT NULL CHECK (btrim(nome) <> ''),
	origem                      VARCHAR(20) NOT NULL
	                                CHECK (origem IN ('import_simplesvet', 'cadastro_direto')),
	created_at                  TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated_at                  TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

GRANT USAGE ON SCHEMA public TO identidade_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON identidade_tutor TO identidade_role;
GRANT USAGE, SELECT ON identidade_tutor_id_seq TO identidade_role;

-- identidade_telefone: tabela filha, não array `TEXT[]` (ver Design Notes da story) --
-- detectar ambiguidade (mesmo telefone em >1 tutor) exige correlação indexada entre
-- linhas, inviável com array. `UNIQUE (tutor_id, telefone)` -- deliberadamente NÃO
-- `UNIQUE (telefone)` sozinho -- é o que permite duas linhas legítimas para o mesmo
-- telefone em tutores diferentes (Always: "telefone ligado a mais de um tutor grava as
-- duas ligações, nunca resolve para um tutor arbitrário"). Duas linhas com o mesmo
-- `telefone` e `tutor_id` diferentes já É o estado ambíguo -- sem flag própria, a
-- Story 1.5 (AD-32) consulta por contagem.
CREATE TABLE identidade_telefone (
	id          BIGSERIAL PRIMARY KEY,
	-- Sem `ON DELETE CASCADE`/`SET NULL` -- default `NO ACTION`, deliberado: apagar um
	-- tutor não é um fluxo que esta story define, e o default impede apagar um tutor
	-- silenciosamente órfão de telefone sem decisão explícita de quem for implementar
	-- exclusão de tutor no futuro.
	tutor_id    BIGINT NOT NULL REFERENCES identidade_tutor (id),
	-- E.164 limpo (+55 + DDD + número) -- sempre gravado via `telefone_normalizar()`
	-- (migration 0006) chamado no SQL do importador, nunca reimplementado (AD-8).
	telefone    VARCHAR(20) NOT NULL,
	origem      VARCHAR(20) NOT NULL
	                CHECK (origem IN ('import_simplesvet', 'cadastro_direto')),
	created_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	UNIQUE (tutor_id, telefone)
);

-- Índice em telefone (não só o composto acima, que tem tutor_id como coluna líder e
-- não serve sozinho pra busca "todos os tutores deste telefone" -- exatamente a
-- consulta que a Story 1.5 precisa para detectar ambiguidade).
CREATE INDEX idx_identidade_telefone_telefone ON identidade_telefone (telefone);

GRANT SELECT, INSERT, UPDATE, DELETE ON identidade_telefone TO identidade_role;
GRANT USAGE, SELECT ON identidade_telefone_id_seq TO identidade_role;

-- identidade_pet: um pet por `ani_int_codigo` do SimplesVet, vinculado direto ao
-- tutor (`vet_animal.pes_int_codigo` no export). `simplesvet_codigo_animal` único
-- nullable pelo mesmo motivo de `identidade_tutor.simplesvet_codigo_pessoa` (Story 1.7
-- futura cadastra pets sem origem SimplesVet). Campo ausente no export (porte, espécie
-- etc.) grava NULL e o registro segue utilizável -- nunca descartado por dado faltando
-- (Always).
CREATE TABLE identidade_pet (
	id                          BIGSERIAL PRIMARY KEY,
	simplesvet_codigo_animal    INTEGER UNIQUE,
	-- Mesmo default `NO ACTION` de `identidade_telefone.tutor_id` acima -- e mesma
	-- justificativa.
	tutor_id                    BIGINT NOT NULL REFERENCES identidade_tutor (id),
	nome                        VARCHAR(200) NOT NULL CHECK (btrim(nome) <> ''),
	especie                     VARCHAR(50),
	raca                        VARCHAR(100),
	data_nascimento             DATE,
	origem                      VARCHAR(20) NOT NULL
	                                CHECK (origem IN ('import_simplesvet', 'cadastro_direto')),
	created_at                  TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated_at                  TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_identidade_pet_tutor_id ON identidade_pet (tutor_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON identidade_pet TO identidade_role;
GRANT USAGE, SELECT ON identidade_pet_id_seq TO identidade_role;
