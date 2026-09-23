-- 0016 — Porta única de LEITURA sobre a base própria de identidade (Story 1.5,
-- AD-32/AD-3/AD-8): resolve reconhecimento por telefone contra `identidade_tutor` /
-- `identidade_telefone` / `identidade_pet` (Story 1.1, migration 0014) -- nunca contra
-- `identidade_cliente_pet` (tabela do Piloto, mantida por coexistência, fora de
-- escopo desta story).
--
-- O achado que motiva esta migration: `01 - Agente.json` já chama
-- `identidade_cliente_pet_buscar($1)` (migration 0006) usando a credencial "Nouvet"
-- (`app_role`) -- mas aquela função só tem `GRANT EXECUTE` para `identidade_role`
-- (comentário explícito na 0006: "nunca app_role"). Contra um Postgres real, esse
-- `SELECT` sempre falhou por permissão; o `onError: continueErrorOutput` da 0015 fez a
-- conversa cair no caminho de falha honesta em vez de travar, o que escondeu o
-- problema até agora. Esta migration não conserta a função antiga (que segue órfã, por
-- coexistência com o Piloto) -- entrega uma função nova, com o `GRANT` correto, e o
-- node passa a chamar essa.
--
-- `identidade_tutor`/`identidade_telefone`/`identidade_pet` são a exceção deliberada
-- da Story 1.1: `GRANT` só a `identidade_role`, nunca `app_role` (AD-3), porque tocam
-- PII permanente. A única forma de `01 - Agente.json` (credencial `app_role`) ler esse
-- dado sem violar AD-3 é uma função que roda com o privilégio de quem a criou, não de
-- quem a chama -- primeira `SECURITY DEFINER` deste diretório. `SET search_path` fixo
-- evita o vetor clássico de sequestro de função/tipo via schema malicioso em
-- `SECURITY DEFINER` sem isso: o `search_path` do chamador nunca influencia a
-- resolução de `identidade_telefone`/`identidade_tutor`/`identidade_pet`/
-- `telefone_normalizar` dentro desta função.
--
-- `LANGUAGE sql` com CTEs -- mesmo padrão de função-única-statement já estabelecido no
-- diretório (`lock_conversa_adquirir` na 0005, `identidade_cliente_pet_buscar`/
-- `identidade_cliente_pet_resolver` na 0006).
--
-- Contrato de retorno: `{"status": "novo"|"reconhecido"|"nao_autorizado", "tutor":
-- {...}|null, "pets": [...]|null}` -- `tutor`/`pets` são sempre `null` fora de
-- "reconhecido" (Always da story: telefone `nao_autorizado` nunca expõe dado de
-- nenhum dos tutores encontrados).
--
--   - `telefone` CTE: normaliza a entrada via `telefone_normalizar` (migration 0006,
--     AD-8) -- mesmo já recebendo o valor normalizado do node "Normalizar telefone"
--     (Always da story: a função normaliza internamente, nunca confia no chamador).
--     Telefone não-normalizável produz `v IS NULL`; o `JOIN` seguinte contra
--     `identidade_telefone.telefone = NULL` nunca casa nenhuma linha (semântica de
--     NULL em SQL), então esse caso cai naturalmente em "0 tutores" -- mesmo caminho
--     de "novo" de um telefone válido não cadastrado, sem `CASE` extra.
--   - `tutores` CTE: todo `tutor_id` distinto ligado a esse telefone em
--     `identidade_telefone` -- é a consulta "todos os tutores deste telefone" que o
--     índice `idx_identidade_telefone_telefone` (0014) existe para servir.
--   - `contagem` CTE: `count(*)` sobre `tutores` -- sempre devolve exatamente 1 linha
--     (mesmo com 0 tutores), então os `LEFT JOIN ON true` finais nunca perdem a linha
--     base por causa dela.
--   - `tutor_unico` CTE: só produz linha quando `contagem.n = 1` -- 0 ou >1 tutores
--     nunca resolvem para um tutor específico (AD-32: "só exatamente um é
--     autorizado", mesma regra usada por reconhecimento/preferências/cadastro).
--   - `pets` CTE: pets do tutor único, só nome/espécie (contrato do Code Map) --
--     `jsonb_agg` ordenado por `id` para saída estável entre chamadas.
--   - `SELECT` final: monta o JSON de status conforme a contagem, e só popula
--     `tutor`/`pets` quando `tutor_unico` resolveu (0 ou >1 tutores devolvem ambos
--     `null`, nunca um objeto parcial).
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
			jsonb_build_object('nome', p.nome, 'especie', p.especie)
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

-- Dono passa a ser `identidade_role` -- é o privilégio com que a função roda para
-- qualquer chamador (`SECURITY DEFINER`), nunca o privilégio de quem a chama
-- (`app_role`, via credencial "Nouvet" em `01 - Agente.json`).
ALTER FUNCTION identidade_tutor_buscar_por_telefone(TEXT) OWNER TO identidade_role;

-- Postgres concede EXECUTE em função nova a PUBLIC por padrão -- REVOKE sempre
-- precede o GRANT correspondente (mesmo padrão das 0004/0005/0006).
REVOKE EXECUTE ON FUNCTION identidade_tutor_buscar_por_telefone(TEXT) FROM PUBLIC;

-- Só `app_role` -- nunca `GRANT` direto de `app_role` nas tabelas `identidade_*`
-- (AD-3). `identidade_role` não precisa de GRANT explícito aqui: já é dona da função
-- (ALTER OWNER acima) e das tabelas que ela lê.
GRANT EXECUTE ON FUNCTION identidade_tutor_buscar_por_telefone(TEXT) TO app_role;
