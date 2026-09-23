-- 0017 — Preferência estável do pet (Story 1.6, FR-5a/FR-40a/UX-DR4): plano, perfume,
-- acessório, produto próprio e observação livre, gravados e mantidos só pela conversa --
-- nunca pelo importador do SimplesVet (`import/importador/db.py:upsert_pet`, Story 1.1,
-- já projetado para nunca tocar esta coluna, ver comentário do próprio `SET`).
--
-- `preferencia JSONB` sobre `identidade_pet` (`0014`) -- nunca colunas fixas por campo:
-- a lista (plano/perfume/acessório/produto próprio/observação livre) é exemplo do PRD,
-- não um enum fechado, e "observação livre" é texto não-estruturado por natureza. Sem
-- `NOT NULL`/`DEFAULT` -- `NULL` é o estado real de "pet sem preferência registrada"
-- (Code Map do `systemMessage`), distinto de `'{}'::jsonb` (preferência vazia
-- explícita, que esta migration nunca produz sozinha).

ALTER TABLE identidade_pet
	ADD COLUMN preferencia JSONB;

-- `identidade_tutor_buscar_por_telefone` (`0016`) é reestendida via `CREATE OR REPLACE
-- FUNCTION` (mesmo padrão da 0010/0011/0012) para expor `preferencia` em cada pet do
-- array -- único ponto de leitura de identidade que `01 - Agente.json` já consome
-- (`Buscar Identidade` → `Info.pets`), então nenhum node muda, só o formato do dado que
-- já atravessa esse caminho.
CREATE OR REPLACE FUNCTION identidade_tutor_buscar_por_telefone(p_telefone TEXT)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
	WITH telefone AS (
		SELECT telefone_normalizar(p_telefone) AS v
	),
	tutores AS (
		SELECT DISTINCT it.tutor_id
		FROM identidade_telefone it
		JOIN telefone ON it.telefone = telefone.v
	),
	contagem AS (
		SELECT count(*) AS n FROM tutores
	),
	tutor_unico AS (
		SELECT t.id, t.nome
		FROM identidade_tutor t
		JOIN tutores ON tutores.tutor_id = t.id
		JOIN contagem ON contagem.n = 1
	),
	pets AS (
		SELECT jsonb_agg(
			jsonb_build_object('nome', p.nome, 'especie', p.especie, 'preferencia', p.preferencia)
			ORDER BY p.id
		) AS v
		FROM identidade_pet p
		JOIN tutor_unico ON tutor_unico.id = p.tutor_id
	)
	SELECT jsonb_build_object(
		'status', CASE
			WHEN contagem.n = 0 THEN 'novo'
			WHEN contagem.n > 1 THEN 'nao_autorizado'
			ELSE 'reconhecido'
		END,
		'tutor', CASE
			WHEN tutor_unico.id IS NOT NULL THEN jsonb_build_object('nome', tutor_unico.nome)
			ELSE NULL
		END,
		'pets', CASE
			WHEN tutor_unico.id IS NOT NULL THEN COALESCE(pets.v, '[]'::jsonb)
			ELSE NULL
		END
	)
	FROM contagem
	LEFT JOIN tutor_unico ON true
	LEFT JOIN pets ON true;
$$;

-- `identidade_pet_atualizar_preferencia`: porta única de ESCRITA de preferência,
-- chamada pelo `Agente Nouvet` como ferramenta (`01 - Agente.json`) quando o cliente
-- informa ou confirma uma mudança. Mesma regra de autorização de
-- `identidade_tutor_buscar_por_telefone` (`AD-32`, "mesma regra usada por
-- reconhecimento/preferências/cadastro", Épico 1 Context) -- só grava quando o telefone
-- resolve para exatamente um tutor. Paridade explícita com o contrato de status da
-- função de leitura (`0016`): 0 tutores devolve `novo`, mais de 1 devolve
-- `nao_autorizado` -- nunca colapsados no mesmo status aqui, mesma distinção que a
-- leitura já faz.
--
-- `p_preferencia` é sempre um PATCH, nunca um replace: `COALESCE(preferencia,
-- '{}'::jsonb) || COALESCE(p_preferencia, '{}'::jsonb)` funde só as chaves informadas
-- agora sobre a preferência existente -- é o que permite o cliente mudar "sem perfume"
-- sem apagar "com corte de unha" já registrado, e é a mesma razão pela qual o
-- `systemMessage` nunca precisa perguntar de novo o que já sabe (Design Notes do
-- spec). O lado direito também é blindado com `COALESCE(..., '{}'::jsonb)`: sem isso,
-- um `p_preferencia` `NULL` (ex.: `$fromAI` falhando em extrair valor) faria
-- `qualquer_coisa || NULL::jsonb` avaliar para `NULL` -- apagando silenciosamente toda
-- a preferência já gravada do pet. `p_preferencia` que não seja um objeto JSON
-- (array/string/number) nunca é mesclado -- o `WHERE jsonb_typeof(p_preferencia) =
-- 'object'` da CTE de escrita abaixo garante isso -- porque `||` entre um objeto jsonb
-- e um valor não-objeto produz um ARRAY, quebrando o contrato de "`preferencia` é
-- sempre objeto" que o `systemMessage`/`identidade_tutor_buscar_por_telefone`
-- assumem. Esse caso devolve `preferencia_invalida`, sem gravar nada.
--
-- Pet resolvido por nome, case-insensitive/trim (`lower(btrim(...))`, mesmo padrão de
-- case-insensitivity já usado para `nome_pet` na `0006`) dentro do tutor único --
-- nunca por id, porque a ferramenta só recebe o nome que o próprio `systemMessage` já
-- devolveu ao modelo via `Info.pets`. Nome que não bate com nenhum pet do tutor
-- (alucinação do modelo, nunca esperado no fluxo normal) devolve `pet_nao_encontrado`
-- sem gravar nada -- mesma postura defensiva de nunca um `UPDATE` parcial silencioso.
--
-- Os três modos de falha (`nao_autorizado`/`novo`, `pet_nao_encontrado`,
-- `preferencia_invalida`) ficam sempre distinguíveis no `CASE` final -- nunca
-- colapsados na mesma condição do `pet_alvo`, que resolveria "pet não encontrado" e
-- "preferência mal formada" para o mesmo status.
CREATE FUNCTION identidade_pet_atualizar_preferencia(
	p_telefone TEXT,
	p_pet_nome TEXT,
	p_preferencia JSONB
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
	WITH telefone AS (
		SELECT telefone_normalizar(p_telefone) AS v
	),
	tutores AS (
		SELECT DISTINCT it.tutor_id
		FROM identidade_telefone it
		JOIN telefone ON it.telefone = telefone.v
	),
	contagem AS (
		SELECT count(*) AS n FROM tutores
	),
	tutor_unico AS (
		SELECT t.id
		FROM identidade_tutor t
		JOIN tutores ON tutores.tutor_id = t.id
		JOIN contagem ON contagem.n = 1
	),
	pet_alvo AS (
		SELECT p.id
		FROM identidade_pet p
		JOIN tutor_unico ON tutor_unico.id = p.tutor_id
		WHERE lower(btrim(p.nome)) = lower(btrim(p_pet_nome))
	),
	-- CTE de escrita: `WHERE id IN (SELECT id FROM pet_alvo) AND jsonb_typeof(p_preferencia)
	-- = 'object'` casa zero linhas em qualquer um dos três casos de falha (telefone
	-- não-autorizado/novo, pet não encontrado, ou `p_preferencia` que não é um objeto
	-- JSON, incluindo `NULL` -- `jsonb_typeof(NULL::jsonb)` é `NULL`, nunca `'object'`)
	-- -- `UPDATE` roda sem efeito, nunca lança erro, nunca precisa de `IF` em PL/pgSQL.
	-- O `COALESCE(p_preferencia, '{}'::jsonb)` no `SET` é defesa em profundidade: com o
	-- guard do `WHERE` acima essa linha nunca roda para `p_preferencia NULL`, mas o
	-- `COALESCE` garante que, mesmo assim, `preferencia || NULL::jsonb` (que avalia
	-- para `NULL` e apagaria toda a preferência já gravada) nunca é o que é escrito.
	atualizado AS (
		UPDATE identidade_pet
		SET preferencia = COALESCE(preferencia, '{}'::jsonb) || COALESCE(p_preferencia, '{}'::jsonb),
		    updated_at = now()
		WHERE id IN (SELECT id FROM pet_alvo)
		  AND jsonb_typeof(p_preferencia) = 'object'
		RETURNING nome, preferencia
	)
	SELECT jsonb_build_object(
		'status', CASE
			WHEN contagem.n = 0 THEN 'novo'
			WHEN contagem.n > 1 THEN 'nao_autorizado'
			WHEN pet_alvo.id IS NULL THEN 'pet_nao_encontrado'
			WHEN p_preferencia IS NULL OR jsonb_typeof(p_preferencia) <> 'object' THEN 'preferencia_invalida'
			ELSE 'atualizado'
		END,
		'pet', CASE
			WHEN atualizado.nome IS NOT NULL
			THEN jsonb_build_object('nome', atualizado.nome, 'preferencia', atualizado.preferencia)
			ELSE NULL
		END
	)
	FROM contagem
	LEFT JOIN pet_alvo ON true
	LEFT JOIN atualizado ON true;
$$;

-- Mesmo hardening das duas funções `SECURITY DEFINER` desta migration: dona
-- `identidade_role` (privilégio de quem lê/escreve `identidade_pet`, nunca de quem
-- chama), `search_path` fixo (evita sequestro de função/tipo via schema malicioso),
-- `REVOKE` de `PUBLIC` sempre antes do `GRANT` correspondente, `EXECUTE` só para
-- `app_role` (nunca `GRANT` direto de `app_role` nas tabelas `identidade_*`, `AD-3`).
ALTER FUNCTION identidade_pet_atualizar_preferencia(TEXT, TEXT, JSONB) OWNER TO identidade_role;
REVOKE EXECUTE ON FUNCTION identidade_pet_atualizar_preferencia(TEXT, TEXT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION identidade_pet_atualizar_preferencia(TEXT, TEXT, JSONB) TO app_role;
