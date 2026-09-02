-- 0006 — Porta única idempotente de identidade cliente/pet (AD-6/AD-11). Resolve o
-- achado HIGH do review adversarial (duas mensagens quase simultâneas de telefones
-- diferentes do mesmo núcleo familiar podendo criar dois cards duplicados no RD CRM),
-- DW-4 (sem índice em rd_crm_contact_id) e a metade case-insensitive de DW-10 (UNIQUE
-- (telefone, nome_pet) case-sensitive).
--
-- ALTER TABLE/DROP CONSTRAINT sobre a tabela criada na 0003 (nunca recria) + três
-- funções novas -- esta story entrega só o contrato Postgres (função-única-statement,
-- LANGUAGE sql com CTEs, mesmo estilo de lock_conversa_adquirir na 0005), não o
-- sub-workflow n8n real que chama a API do RD CRM (CAP-1/CAP-7, story futura).

-- telefone_normalizar: normalização centralizada de telefone (AD-8) -- formato
-- canônico E.164 limpo (+55 + DDD + número, já considerando o 9º dígito móvel).
-- Utilitário genérico sem acesso a PII (não toca a tabela de identidade), por isso
-- concedido tanto a app_role quanto a identidade_role (ver GRANT abaixo) -- qualquer
-- ponto do sistema que precise comparar/casar telefone usa esta função, nunca
-- reimplementa a lógica inline (AD-8).
--
-- Aceita qualquer um dos formatos já vistos no cadastro: com/sem DDI 55, com/sem o 9º
-- dígito móvel, com/sem pontuação. Entrada não reconhecível como celular BR (não numérica,
-- vazia, NULL, ou que não resulta em exatamente 11 dígitos locais após as normalizações
-- acima) devolve NULL -- falha silenciosa, mesmo padrão de outras funções deste
-- diretório (secretaria_config_ler, lock_conversa_adquirir).
CREATE OR REPLACE FUNCTION telefone_normalizar(p_telefone TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
	WITH digitos AS (
		-- Remove tudo que não é dígito (espaços, parênteses, hífen, "+"). COALESCE com
		-- '' trata NULL de entrada sem precisar de guard separado -- o pipeline abaixo
		-- naturalmente devolve NULL no final para string vazia (nunca chega a 11 dígitos).
		SELECT regexp_replace(COALESCE(p_telefone, ''), '\D', '', 'g') AS v
	),
	sem_ddi AS (
		-- DDI 55 só é removido quando o total já sugere DDI presente (>= 12 dígitos) --
		-- evita truncar por engano um número de 11 dígitos que por coincidência começa
		-- com "55" (DDD 55 = Santa Catarina/RS).
		SELECT CASE
			WHEN length(v) >= 12 AND left(v, 2) = '55' THEN substring(v FROM 3)
			ELSE v
		END AS v
		FROM digitos
	),
	com_nono_digito AS (
		-- Número local de 10 dígitos (DDD + 8 dígitos, formato antigo/sem o 9º dígito
		-- móvel) ganha o "9" logo após o DDD.
		SELECT CASE
			WHEN length(v) = 10 THEN left(v, 2) || '9' || substring(v FROM 3)
			ELSE v
		END AS v
		FROM sem_ddi
	)
	SELECT CASE WHEN length(v) = 11 THEN '+55' || v ELSE NULL END
	FROM com_nono_digito;
$$;

-- Postgres concede EXECUTE em função nova a PUBLIC por padrão -- REVOKE sempre precede
-- o GRANT correspondente (mesmo padrão das 0004/0005).
REVOKE EXECUTE ON FUNCTION telefone_normalizar(TEXT) FROM PUBLIC;

-- Utilitário genérico, sem PII -- único caso deste diretório concedido a app_role E
-- identidade_role ao mesmo tempo (AD-3 continua valendo para leitura/escrita da
-- própria tabela de identidade, só não para este utilitário).
GRANT EXECUTE ON FUNCTION telefone_normalizar(TEXT) TO app_role, identidade_role;

-- Chave natural de dedup vira (telefone, lower(btrim(nome_pet))) -- decisão desta
-- story para DW-10: variação de caixa ("Rex"/"rex") nunca cria linha nova; dois pets
-- reais com nome idêntico no mesmo telefone são tratados como a mesma identidade
-- (última chamada atualiza espécie/raça), limitação aceita e documentada, não um bug.
-- DROP CONSTRAINT em vez de recriar a tabela (Code Map) -- nome da constraint
-- auto-gerado pelo Postgres na 0003 a partir de UNIQUE (telefone, nome_pet).
ALTER TABLE identidade_cliente_pet
	DROP CONSTRAINT identidade_cliente_pet_telefone_nome_pet_key;

CREATE UNIQUE INDEX idx_identidade_cliente_pet_telefone_nome_pet
	ON identidade_cliente_pet (telefone, (lower(btrim(nome_pet))));

-- idx_identidade_cliente_pet_telefone (0003) fica redundante a partir daqui: telefone
-- é a coluna líder do novo índice único acima, que já cobre sozinho qualquer busca por
-- telefone (regra de prefixo de índice composto do Postgres) -- mantê-lo só duplicaria
-- overhead de escrita sem ganho de leitura.
DROP INDEX idx_identidade_cliente_pet_telefone;

-- DW-4: índice de apoio ao caminho de lookup conversa -> contato do RD CRM que a
-- porta única (e a Story 11 de registro no CRM) precisa. Parcial (WHERE ... IS NOT
-- NULL) porque a maioria das linhas ainda não tem card vinculado no momento do
-- cadastro Postgres (o card é criado depois, pelo sub-workflow futuro de AD-11).
CREATE INDEX idx_identidade_cliente_pet_rd_crm_contact_id
	ON identidade_cliente_pet (rd_crm_contact_id)
	WHERE rd_crm_contact_id IS NOT NULL;

-- identidade_cliente_pet_buscar: porta única de LEITURA (CAP-1) -- devolve todos os
-- registros já vinculados ao telefone informado (um cliente pode ter mais de um pet),
-- em qualquer formato aceito por telefone_normalizar, sempre resolvendo pro mesmo
-- cliente independente de como o telefone chegou (com/sem DDI, com/sem 9º dígito).
-- jsonb_agg sobre zero linhas devolve NULL -- "nenhum cliente encontrado" propaga como
-- NULL, mesmo padrão de falha silenciosa das demais funções.
CREATE OR REPLACE FUNCTION identidade_cliente_pet_buscar(p_telefone TEXT)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
	SELECT jsonb_agg(
		jsonb_build_object(
			'id', id,
			'telefone', telefone,
			'nome_cliente', nome_cliente,
			'nome_pet', nome_pet,
			'especie_pet', especie_pet,
			'raca_pet', raca_pet,
			'rd_crm_contact_id', rd_crm_contact_id,
			'origem', origem,
			'created_at', created_at,
			'updated_at', updated_at
		) ORDER BY id
	)
	FROM identidade_cliente_pet
	WHERE telefone = telefone_normalizar(p_telefone);
$$;

REVOKE EXECUTE ON FUNCTION identidade_cliente_pet_buscar(TEXT) FROM PUBLIC;

-- Só identidade_role -- nunca app_role (AD-3, PII permanente). Qualquer Agente de
-- Setor/sub-workflow que precise consultar identidade passa pela porta única, nunca
-- por SELECT direto na tabela.
GRANT EXECUTE ON FUNCTION identidade_cliente_pet_buscar(TEXT) TO identidade_role;

-- identidade_cliente_pet_resolver: porta única de ESCRITA idempotente (AD-11) -- a
-- ÚNICA forma permitida de gravar em identidade_cliente_pet (nunca INSERT/UPDATE
-- direto de outro ponto, incluindo o import inicial do SimplesVet, que também chama
-- esta função com origem='import_simplesvet'; ver n8n/seed/README.md).
--
-- LANGUAGE sql com CTEs (não plpgsql) -- mesmo padrão de função-única-statement já
-- estabelecido no diretório (lock_conversa_adquirir, 0005).
--
-- Ordem das CTEs importa e reflete a garantia de atomicidade exigida por AD-11:
--   1. entrada/valida: normaliza e valida os parâmetros -- telefone
--      não-normalizável ou nome_cliente/nome_pet vazio/NULL produz zero linhas em
--      "valida", e todo o resto do pipeline (lock, upsert, sinal) também produz zero
--      linhas -- a função devolve NULL sem gravar nada (mesmo padrão de falha
--      silenciosa de secretaria_config_ler/lock_conversa_adquirir).
--   2. travado: adquire pg_advisory_xact_lock(hashtext(telefone_normalizado)) --
--      o "lock consultivo por telefone normalizado" citado literalmente em AD-11.
--      pg_advisory_xact_lock é volatile, então esta CTE nunca é inlinada pelo
--      planner à frente do upsert que depende dela -- o lock é adquirido antes de
--      checar/gravar, serializando tanto o caso de retry (429/500 do RD CRM) quanto
--      o de duas chamadas concorrentes para o mesmo telefone+pet. Liberado
--      automaticamente no fim da transação implícita da chamada (xact).
--   3. upsert: INSERT ... ON CONFLICT (telefone, (lower(btrim(nome_pet)))) DO UPDATE
--      -- o conflict target mira a EXPRESSÃO do índice único case-insensitive criado
--      acima (não uma constraint nomeada), por isso os parênteses extras em volta da
--      expressão. UPDATE grava nome_cliente/nome_pet sempre com o valor mais recente
--      (implementa FR-4 "de graça" via UPSERT: variação de caixa do nome do pet ou
--      correção de dono/cônjuge no mesmo telefone+pet nunca cria segunda linha).
--      especie_pet/raca_pet/rd_crm_contact_id só são sobrescritos quando o chamador
--      manda um valor novo (COALESCE com o valor já gravado) -- uma chamada posterior
--      que corrige só nome_cliente/nome_pet e omite os demais campos nunca "esquece"
--      espécie/raça/card já conhecidos de uma chamada anterior mais completa (achado
--      do review, patch [medium]). `(xmax = 0)` é o truque padrão de Postgres para
--      diferenciar INSERT
--      (xmax = 0) de UPDATE via ON CONFLICT (xmax do transaction atual, != 0) sem
--      round-trip extra -- vira o `'criado'` do retorno.
--   4. duplicidade: sinal de possível duplicidade familiar (AD-11) -- outro telefone
--      (necessariamente diferente, senão seria a mesma linha) já tem pet com o mesmo
--      nome (case-insensitive). Não elimina o caso (são números realmente diferentes,
--      cônjuges do mesmo núcleo familiar) -- só avisa o caller (o sub-workflow n8n
--      futuro que constrói a Task de revisão humana no card do RD CRM).
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
			NULLIF(btrim(p_rd_crm_contact_id), '') AS rd_crm_contact_id
	),
	valida AS (
		-- Entrada inválida (telefone não-normalizável, nome_cliente/nome_pet vazio ou
		-- NULL, ou origem fora do domínio aceito pelo CHECK da tabela) produz zero
		-- linhas aqui -- propaga zero linhas por todo o resto do pipeline (nunca
		-- adquire lock, nunca grava) e a função devolve NULL no final. O filtro de
		-- origem espelha o CHECK (origem IN ('import_simplesvet', 'cadastro_direto'))
		-- da 0003 -- sem ele, um origem inválido chegaria ao INSERT e estouraria uma
		-- violação de CHECK não tratada, quebrando o contrato de falha silenciosa que
		-- o resto desta função segue (achado do review, patch [medium]).
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
			(telefone, nome_cliente, nome_pet, especie_pet, raca_pet, rd_crm_contact_id, origem)
		SELECT telefone, nome_cliente, nome_pet, especie_pet, raca_pet, rd_crm_contact_id, origem
		FROM travado
		ON CONFLICT (telefone, (lower(btrim(nome_pet)))) DO UPDATE
			SET nome_cliente = EXCLUDED.nome_cliente,
			    nome_pet = EXCLUDED.nome_pet,
			    -- especie_pet/raca_pet/rd_crm_contact_id só são sobrescritos quando a
			    -- chamada mais recente traz um valor novo (COALESCE com o já gravado) --
			    -- uma correção que só manda nome_cliente/nome_pet (ex.: cônjuge
			    -- corrigindo o dono) nunca apaga espécie/raça já conhecidas de uma
			    -- chamada anterior mais completa (achado do review, patch [medium]).
			    especie_pet = COALESCE(EXCLUDED.especie_pet, identidade_cliente_pet.especie_pet),
			    raca_pet = COALESCE(EXCLUDED.raca_pet, identidade_cliente_pet.raca_pet),
			    rd_crm_contact_id = COALESCE(EXCLUDED.rd_crm_contact_id, identidade_cliente_pet.rd_crm_contact_id),
			    updated_at = now()
		RETURNING
			id, telefone, nome_cliente, nome_pet, especie_pet, raca_pet,
			rd_crm_contact_id, origem, created_at, updated_at,
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
		'criado', upsert.criado,
		'possivel_duplicidade_familiar', duplicidade.possivel_duplicidade_familiar
	)
	FROM upsert, duplicidade;
$$;

REVOKE EXECUTE ON FUNCTION identidade_cliente_pet_resolver(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;

-- Só identidade_role -- nunca app_role (AD-3). Todo Agente de Setor que precisar
-- criar/atualizar identidade chama esta função via o sub-workflow único de AD-11
-- (story futura), nunca grava direto na tabela.
GRANT EXECUTE ON FUNCTION identidade_cliente_pet_resolver(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO identidade_role;
