-- identidade_bancada.sql — Fixture reservada de identidade para a bancada adversarial
-- (Story 1.5, `AD-32`). Insere tutores/telefones/pets sintéticos direto em
-- `identidade_tutor`/`identidade_telefone`/`identidade_pet` (Story 1.1, migration
-- 0014) -- as mesmas tabelas de produção, não um ambiente de teste isolado (`AD-30` é
-- do Épico 4; mesmo compromisso que a Story 1.4 já aceitou ao rodar a bancada contra a
-- instância real).
--
-- Nunca linha de cliente real: nome sempre prefixado `BANCADA-TESTE` (auditável e
-- removível a qualquer momento por esse prefixo) e telefone sempre DDD `00`
-- (inexistente no Brasil -- mesma convenção sintética de `bancada-teste/rodar.py`,
-- Story 1.4).
--
-- Idempotente via `WHERE NOT EXISTS` -- nunca `ON CONFLICT` cru (Code Map da story):
-- `identidade_tutor.simplesvet_codigo_pessoa`/`identidade_pet.simplesvet_codigo_animal`
-- são `NULL` para estes registros (`origem = 'cadastro_direto'`, sem código de origem
-- do SimplesVet), então não há chave natural para um `ON CONFLICT` -- a checagem de
-- duplicidade aqui é pelo nome reservado, único o bastante dentro do prefixo
-- `BANCADA-TESTE`. Reaplicar este arquivo não duplica nada.
--
-- Aplicação manual via `psql`, nunca automática (mesmo padrão de `n8n/seed`, ver
-- `bancada-teste/README.md` desta pasta para o comando exato).
--
-- Telefones usados abaixo são exatamente os que `bancada-teste/rodar.py`
-- (`gerar_identidade_sintetica`) calcula, de forma determinística, a partir do campo
-- `nome:` de cada `.yaml` em `bancada-teste/casos/` -- por isso aparecem aqui como
-- literais, e não podem mudar sem também mudar o `nome:` do caso correspondente:
--   - "2-cliente-reconhecido-um-pet"        -> 00943675484
--   - "3-cliente-reconhecido-varios-pets"   -> 00981800970
--   - "4-numero-ambiguo"                    -> 00964790533 (ligado a 2 tutores)
-- `telefone_normalizar` (migration 0006) é chamado aqui dentro do próprio INSERT --
-- nunca gravamos o telefone já normalizado à mão -- mesma regra de "nunca reimplementa
-- a normalização" que vale para qualquer outro ponto do sistema (`AD-8`).
--
-- Três tutores sintéticos ao todo:
--   1. "BANCADA-TESTE Tutor Um Pet" -- só o telefone do caso 2, só um pet (cobre
--      reconhecido/1 tutor/1 pet -- nunca pergunta qual pet).
--   2. "BANCADA-TESTE Tutor Vários Pets" -- telefone do caso 3 (só dele, cobre
--      reconhecido/1 tutor/2 pets -- pergunta qual pet) e também o telefone do caso 4
--      (compartilhado com o tutor 3 abaixo -- é a metade "ambígua" deste tutor).
--   3. "BANCADA-TESTE Tutor Ambíguo B" -- só o telefone do caso 4, compartilhado com o
--      tutor 2 acima. Duas linhas com o mesmo telefone e `tutor_id` diferentes em
--      `identidade_telefone` já é o estado ambíguo (Design Notes da migration 0014) --
--      sem isso, o caso 4 não teria como existir sem um quarto tutor.

-- 1. BANCADA-TESTE Tutor Um Pet -- caso 2 (reconhecido, 1 pet).
INSERT INTO identidade_tutor (nome, origem)
SELECT 'BANCADA-TESTE Tutor Um Pet', 'cadastro_direto'
WHERE NOT EXISTS (
	SELECT 1 FROM identidade_tutor WHERE nome = 'BANCADA-TESTE Tutor Um Pet'
);

INSERT INTO identidade_telefone (tutor_id, telefone, origem)
SELECT t.id, telefone_normalizar('00943675484'), 'cadastro_direto'
FROM identidade_tutor t
WHERE t.nome = 'BANCADA-TESTE Tutor Um Pet'
  AND NOT EXISTS (
	SELECT 1 FROM identidade_telefone it
	WHERE it.tutor_id = t.id AND it.telefone = telefone_normalizar('00943675484')
  );

INSERT INTO identidade_pet (tutor_id, nome, especie, origem)
SELECT t.id, 'BANCADA-TESTE Pet Rex', 'cachorro', 'cadastro_direto'
FROM identidade_tutor t
WHERE t.nome = 'BANCADA-TESTE Tutor Um Pet'
  AND NOT EXISTS (
	SELECT 1 FROM identidade_pet p WHERE p.tutor_id = t.id AND p.nome = 'BANCADA-TESTE Pet Rex'
  );

-- 2. BANCADA-TESTE Tutor Vários Pets -- caso 3 (reconhecido, 2 pets) e metade do caso
-- 4 (telefone ambíguo, compartilhado com o tutor 3 abaixo).
INSERT INTO identidade_tutor (nome, origem)
SELECT 'BANCADA-TESTE Tutor Vários Pets', 'cadastro_direto'
WHERE NOT EXISTS (
	SELECT 1 FROM identidade_tutor WHERE nome = 'BANCADA-TESTE Tutor Vários Pets'
);

INSERT INTO identidade_telefone (tutor_id, telefone, origem)
SELECT t.id, telefone_normalizar('00981800970'), 'cadastro_direto'
FROM identidade_tutor t
WHERE t.nome = 'BANCADA-TESTE Tutor Vários Pets'
  AND NOT EXISTS (
	SELECT 1 FROM identidade_telefone it
	WHERE it.tutor_id = t.id AND it.telefone = telefone_normalizar('00981800970')
  );

INSERT INTO identidade_telefone (tutor_id, telefone, origem)
SELECT t.id, telefone_normalizar('00964790533'), 'cadastro_direto'
FROM identidade_tutor t
WHERE t.nome = 'BANCADA-TESTE Tutor Vários Pets'
  AND NOT EXISTS (
	SELECT 1 FROM identidade_telefone it
	WHERE it.tutor_id = t.id AND it.telefone = telefone_normalizar('00964790533')
  );

INSERT INTO identidade_pet (tutor_id, nome, especie, origem)
SELECT t.id, 'BANCADA-TESTE Pet Bidu', 'cachorro', 'cadastro_direto'
FROM identidade_tutor t
WHERE t.nome = 'BANCADA-TESTE Tutor Vários Pets'
  AND NOT EXISTS (
	SELECT 1 FROM identidade_pet p WHERE p.tutor_id = t.id AND p.nome = 'BANCADA-TESTE Pet Bidu'
  );

INSERT INTO identidade_pet (tutor_id, nome, especie, origem)
SELECT t.id, 'BANCADA-TESTE Pet Mia', 'gato', 'cadastro_direto'
FROM identidade_tutor t
WHERE t.nome = 'BANCADA-TESTE Tutor Vários Pets'
  AND NOT EXISTS (
	SELECT 1 FROM identidade_pet p WHERE p.tutor_id = t.id AND p.nome = 'BANCADA-TESTE Pet Mia'
  );

-- 3. BANCADA-TESTE Tutor Ambíguo B -- outra metade do caso 4: mesmo telefone do tutor
-- 2 acima, tutor_id diferente. A partir daqui, `00964790533` resolve para 2 tutores
-- distintos -- `identidade_tutor_buscar_por_telefone` (migration 0016) devolve
-- `nao_autorizado`, e nem este pet nem os do tutor 2 são expostos.
INSERT INTO identidade_tutor (nome, origem)
SELECT 'BANCADA-TESTE Tutor Ambíguo B', 'cadastro_direto'
WHERE NOT EXISTS (
	SELECT 1 FROM identidade_tutor WHERE nome = 'BANCADA-TESTE Tutor Ambíguo B'
);

INSERT INTO identidade_telefone (tutor_id, telefone, origem)
SELECT t.id, telefone_normalizar('00964790533'), 'cadastro_direto'
FROM identidade_tutor t
WHERE t.nome = 'BANCADA-TESTE Tutor Ambíguo B'
  AND NOT EXISTS (
	SELECT 1 FROM identidade_telefone it
	WHERE it.tutor_id = t.id AND it.telefone = telefone_normalizar('00964790533')
  );

INSERT INTO identidade_pet (tutor_id, nome, especie, origem)
SELECT t.id, 'BANCADA-TESTE Pet Toby', 'cachorro', 'cadastro_direto'
FROM identidade_tutor t
WHERE t.nome = 'BANCADA-TESTE Tutor Ambíguo B'
  AND NOT EXISTS (
	SELECT 1 FROM identidade_pet p WHERE p.tutor_id = t.id AND p.nome = 'BANCADA-TESTE Pet Toby'
  );
