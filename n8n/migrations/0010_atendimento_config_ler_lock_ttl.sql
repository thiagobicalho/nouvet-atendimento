-- 0010 — Fecha DW-26: `atendimento_config_ler` (0008) ainda não expõe `lock_ttl_minutos`
-- em nenhuma das fases ('triagem'/'setor'), então não existe porta única (AD-1) pela
-- qual a Story 5 ("01 - Agente.json") obtenha o TTL a passar para
-- `lock_conversa_adquirir` (0005) sem reimplementar leitura direta da tabela. Mesma
-- classe de campo operacional que `sla_resposta_minutos`, já presente nas duas fatias
-- -- nenhuma coluna nova em `atendimento_config` (o dado já existe desde a 0002).
--
-- Corpo completo repetido (CREATE OR REPLACE exige a função inteira) -- único campo
-- novo é `lock_ttl_minutos` em cada `jsonb_build_object`; resto idêntico à 0008.
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
					'sla_resposta_minutos', c.sla_resposta_minutos,
					'lock_ttl_minutos', c.lock_ttl_minutos
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
					'lock_ttl_minutos', c.lock_ttl_minutos,
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

-- REVOKE sempre precede o GRANT correspondente (mesmo padrão das 0004/0005/0008) --
-- CREATE OR REPLACE não reconcede PUBLIC por si só (a função já existia), mas mantido
-- por clareza/idempotência do arquivo isolado.
REVOKE EXECUTE ON FUNCTION atendimento_config_ler(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION atendimento_config_ler(TEXT, TEXT) TO app_role;
