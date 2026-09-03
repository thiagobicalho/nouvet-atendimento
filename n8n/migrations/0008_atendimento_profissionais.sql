-- 0008 — Redesenha atendimento_profissionais (achado de correct-course: tabela criada
-- na 0002 nunca foi conectada a nenhuma leitura -- nenhuma das stories planejadas a
-- consumia). Motivo real de existir: o agente precisa responder "quais profissionais
-- vocês têm?" quando perguntado, sem inventar nome (Fontes Confiáveis, FR-30/31).
--
-- Schema: uma linha por profissional (não por setor) -- um profissional que atende
-- mais de um setor (ex.: clínico geral que também aplica vacina em Vacinas) ganha
-- `setores` com mais de um valor, nunca uma segunda linha duplicando o nome. Desenhado
-- assim pensando na futura UI de autoatendimento (checkbox multi-select de setor por
-- profissional).

ALTER TABLE atendimento_profissionais
	DROP COLUMN setor,
	ADD COLUMN setores TEXT[] NOT NULL DEFAULT '{}',
	ADD CONSTRAINT atendimento_profissionais_nome_key UNIQUE (nome);

-- Conecta a tabela na porta única de leitura seletiva (AD-1): profissionais só
-- aparecem na fatia 'setor' -- nunca em 'triagem' (a fase de triagem não precisa de
-- nome de profissional, só classifica o setor; mesmo princípio já usado por
-- catalogo_servicos/exames_exigem_anestesia de nunca vazar dado fora do contexto
-- corrente) -- e filtrados só pelo setor já classificado (`p_setor = ANY(setores)`),
-- nunca a lista completa de todos os setores.
--
-- Corpo completo repetido (CREATE OR REPLACE exige a função inteira) -- único campo
-- novo é 'profissionais' dentro do CASE 'setor'; resto idêntico à 0004/0007.
CREATE OR REPLACE FUNCTION atendimento_config_ler(p_fase TEXT, p_setor TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
	SELECT
		CASE p_fase
			WHEN 'triagem' THEN (
				SELECT jsonb_strip_nulls(jsonb_build_object(
					'nome_secretaria', c.nome_secretaria,
					'nome_empresa', c.nome_empresa,
					'endereco', c.endereco,
					'cidade_estado', c.cidade_estado,
					'telefone', c.telefone,
					'whatsapp', c.whatsapp,
					'email', c.email,
					'site', c.site,
					'horario_funcionamento', c.horario_funcionamento,
					'tom_voz', c.tom_voz,
					'formas_pagamento', c.formas_pagamento,
					'convenios', c.convenios,
					'sinais_alerta_clinico', c.sinais_alerta_clinico,
					'destinatarios_emergencia', c.destinatarios_emergencia,
					'sla_resposta_minutos', c.sla_resposta_minutos
				))
				FROM atendimento_config c
				WHERE c.id = 1
			)
			WHEN 'setor' THEN (
				CASE WHEN p_setor IS NULL OR p_setor = '' THEN NULL ELSE (
				SELECT jsonb_strip_nulls(jsonb_build_object(
					'nome_secretaria', c.nome_secretaria,
					'nome_empresa', c.nome_empresa,
					'tom_voz', c.tom_voz,
					'setor', p_setor,
					'catalogo_servicos', COALESCE(
						(
							SELECT jsonb_agg(item)
							FROM jsonb_array_elements(c.catalogo_servicos) AS item
							WHERE item ->> 'setor' = p_setor
						),
						'[]'::jsonb
					),
					'exames_exigem_anestesia', CASE
						WHEN p_setor = 'Exames' THEN c.exames_exigem_anestesia
						ELSE '[]'::jsonb
					END,
					'mapeamento_stage_crm', c.mapeamento_stage_crm -> p_setor,
					'sinais_alerta_clinico', c.sinais_alerta_clinico,
					'destinatarios_emergencia', c.destinatarios_emergencia,
					'sla_resposta_minutos', c.sla_resposta_minutos,
					-- Novo nesta migration: só profissionais ativos do setor corrente,
					-- nunca de outro setor.
					'profissionais', COALESCE(
						(
							SELECT jsonb_agg(jsonb_build_object(
								'nome', p.nome,
								'especialidade', p.especialidade
							))
							FROM atendimento_profissionais p
							WHERE p_setor = ANY(p.setores) AND p.ativo = TRUE
						),
						'[]'::jsonb
					)
				))
				FROM atendimento_config c
				WHERE c.id = 1
				) END
			)
			ELSE NULL
		END;
$$;

REVOKE EXECUTE ON FUNCTION atendimento_config_ler(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION atendimento_config_ler(TEXT, TEXT) TO app_role;
