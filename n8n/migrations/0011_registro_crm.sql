-- 0011 — Registro e Memória no CRM (CAP-7/Story 11). Fecha o pré-requisito de schema
-- do fluxo de Task de cadastro pendente já antecipado textualmente pela Story 4
-- (AD-11): `identidade_cliente_pet` ganha `simplesvet_status`, derivado de `origem`
-- só no momento do `INSERT` (nunca alterado por uma chamada seguinte do resolver,
-- mesmo padrão já usado para a própria coluna `origem` desde a 0006) -- o sinal que o
-- sub-workflow `04 - Registrar Atendimento CRM.json` usa para decidir se cria a Task
-- de cadastro pendente no SimplesVet.
--
-- ALTER TABLE sobre a tabela criada na 0003 (nunca recria) + `CREATE OR REPLACE
-- FUNCTION identidade_cliente_pet_resolver` preservando o `REVOKE`/`GRANT` já
-- existente desde a 0006 (mesmo padrão da 0010, que reafirma `REVOKE`/`GRANT` por
-- clareza mesmo sem reconceder nada de fato novo).

ALTER TABLE identidade_cliente_pet
	ADD COLUMN simplesvet_status VARCHAR(20) NOT NULL DEFAULT 'pendente'
		CHECK (simplesvet_status IN ('pendente', 'cadastrado'));

-- Backfill de dado pré-existente (se a 0011 rodar contra um cluster que já tem linhas
-- de `origem = 'import_simplesvet'`): o `DEFAULT 'pendente'` do `ADD COLUMN` acima
-- vale pra toda linha já existente, inclusive as de import -- corrige aqui, uma única
-- vez, pra essas linhas nascerem com o status correto sem depender de uma nova
-- chamada do resolver (que nunca mais escreve nesta coluna depois do INSERT original).
UPDATE identidade_cliente_pet
	SET simplesvet_status = 'cadastrado'
	WHERE origem = 'import_simplesvet';

-- identidade_cliente_pet_resolver: mesmo corpo da 0006, com `simplesvet_status`
-- calculado a partir de `origem` só na CTE `entrada` (nunca recalculado depois) e
-- incluído na lista de colunas do `INSERT` -- deliberadamente ausente da cláusula de
-- atualização do UPSERT (mesmo padrão já usado para `origem`, que também nunca é
-- sobrescrita numa 2ª chamada), e presente no `RETURNING`/JSON de saída.
CREATE OR REPLACE FUNCTION identidade_cliente_pet_resolver(
	p_telefone TEXT,
	p_nome_cliente TEXT,
	p_nome_pet TEXT,
	p_especie_pet TEXT DEFAULT NULL,
	p_raca_pet TEXT DEFAULT NULL,
	p_origem TEXT DEFAULT 'cadastro_direto',
	p_rd_crm_contact_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE sql
AS $$
	WITH entrada AS (
		SELECT
			telefone_normalizar(p_telefone) AS telefone,
			NULLIF(btrim(p_nome_cliente), '') AS nome_cliente,
			NULLIF(btrim(p_nome_pet), '') AS nome_pet,
			NULLIF(btrim(p_especie_pet), '') AS especie_pet,
			NULLIF(btrim(p_raca_pet), '') AS raca_pet,
			COALESCE(NULLIF(btrim(p_origem), ''), 'cadastro_direto') AS origem,
			NULLIF(btrim(p_rd_crm_contact_id), '') AS rd_crm_contact_id,
			-- simplesvet_status nasce 'pendente' para cadastro_direto (a Task de
			-- cadastro pendente no SimplesVet, story 11, é quem consome este sinal) e
			-- 'cadastrado' para import_simplesvet (o cadastro no SimplesVet já existe
			-- desde antes do import) -- só calculado aqui, no momento do INSERT.
			CASE
				WHEN COALESCE(NULLIF(btrim(p_origem), ''), 'cadastro_direto') = 'import_simplesvet'
					THEN 'cadastrado'
				ELSE 'pendente'
			END AS simplesvet_status
	),
	valida AS (
		-- Entrada inválida (telefone não-normalizável, nome_cliente/nome_pet vazio ou
		-- NULL, ou origem fora do domínio aceito pelo CHECK da tabela) produz zero
		-- linhas aqui -- propaga zero linhas por todo o resto do pipeline (nunca
		-- adquire lock, nunca grava) e a função devolve NULL no final.
		SELECT * FROM entrada
		WHERE telefone IS NOT NULL
		  AND nome_cliente IS NOT NULL
		  AND nome_pet IS NOT NULL
		  AND origem IN ('import_simplesvet', 'cadastro_direto')
	),
	travado AS (
		SELECT valida.*, pg_advisory_xact_lock(hashtext(telefone)) AS _lock
		FROM valida
	),
	upsert AS (
		INSERT INTO identidade_cliente_pet
			(telefone, nome_cliente, nome_pet, especie_pet, raca_pet, rd_crm_contact_id, origem, simplesvet_status)
		SELECT telefone, nome_cliente, nome_pet, especie_pet, raca_pet, rd_crm_contact_id, origem, simplesvet_status
		FROM travado
		ON CONFLICT (telefone, (lower(btrim(nome_pet)))) DO UPDATE
			SET nome_cliente = EXCLUDED.nome_cliente,
			    nome_pet = EXCLUDED.nome_pet,
			    -- especie_pet/raca_pet/rd_crm_contact_id só são sobrescritos quando a
			    -- chamada mais recente traz um valor novo (COALESCE com o já gravado).
			    -- Coluna nova desta story NUNCA aparece aqui (assim como origem) --
			    -- gravada só no INSERT original, nunca alterada por uma chamada
			    -- seguinte do resolver (Always desta story).
			    especie_pet = COALESCE(EXCLUDED.especie_pet, identidade_cliente_pet.especie_pet),
			    raca_pet = COALESCE(EXCLUDED.raca_pet, identidade_cliente_pet.raca_pet),
			    rd_crm_contact_id = COALESCE(EXCLUDED.rd_crm_contact_id, identidade_cliente_pet.rd_crm_contact_id),
			    updated_at = now()
		RETURNING
			id, telefone, nome_cliente, nome_pet, especie_pet, raca_pet,
			rd_crm_contact_id, origem, simplesvet_status, created_at, updated_at,
			(xmax = 0) AS criado
	),
	duplicidade AS (
		SELECT EXISTS (
			SELECT 1
			FROM identidade_cliente_pet i, upsert u
			WHERE i.id <> u.id
			  AND i.telefone <> u.telefone
			  AND lower(btrim(i.nome_pet)) = lower(btrim(u.nome_pet))
		) AS possivel_duplicidade_familiar
	)
	SELECT jsonb_build_object(
		'id', upsert.id,
		'telefone', upsert.telefone,
		'nome_cliente', upsert.nome_cliente,
		'nome_pet', upsert.nome_pet,
		'especie_pet', upsert.especie_pet,
		'raca_pet', upsert.raca_pet,
		'rd_crm_contact_id', upsert.rd_crm_contact_id,
		'origem', upsert.origem,
		'simplesvet_status', upsert.simplesvet_status,
		'criado', upsert.criado,
		'possivel_duplicidade_familiar', duplicidade.possivel_duplicidade_familiar
	)
	FROM upsert, duplicidade;
$$;

-- REVOKE sempre precede o GRANT correspondente -- CREATE OR REPLACE não reconcede
-- PUBLIC por si só (a função já existia desde a 0006), reafirmado aqui só por clareza/
-- idempotência do arquivo isolado (mesmo padrão da 0010).
REVOKE EXECUTE ON FUNCTION identidade_cliente_pet_resolver(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;

-- Só identidade_role -- nunca app_role (AD-3).
GRANT EXECUTE ON FUNCTION identidade_cliente_pet_resolver(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO identidade_role;
