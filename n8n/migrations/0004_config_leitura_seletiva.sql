-- 0004 — Porta única de leitura seletiva de secretaria_config (AD-1, Config-as-Data).
--
-- secretaria_config (0002) nunca é lida via dump completo (SELECT-asterisco) pelo agente:
-- toda leitura passa por secretaria_config_ler(p_fase, p_setor), que devolve só a
-- fatia da fase da conversa corrente -- nunca a linha inteira. Antes do setor ser
-- classificado, a fase é 'triagem' (tom, dados institucionais mínimos, guardrails de
-- alerta/emergência). Depois do setor classificado, a fase é 'setor' (fatia daquele
-- setor -- catálogo de serviços filtrado, limiares de SLA, mesmos guardrails de
-- alerta/emergência, já que um sinal de alerta ou emergência declarada pode surgir a
-- qualquer momento da conversa, não só na saudação inicial).
--
-- Story 5/6 ("01 - Agente.json") vai chamar esta função via node Postgres a cada
-- turno -- esta story entrega só o contrato de dados, não o node que o consome.
CREATE OR REPLACE FUNCTION secretaria_config_ler(p_fase TEXT, p_setor TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
	SELECT
		CASE p_fase
			WHEN 'triagem' THEN (
				-- jsonb_strip_nulls remove as chaves cujo valor é NULL (ex.: endereco,
				-- telefone -- dado institucional ainda não fornecido, ver seed) do JSON
				-- devolvido, evitando inflar toda leitura de triagem com campos vazios --
				-- não afeta arrays/objetos vazios ('[]'/'{}'), só o literal null.
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
				FROM secretaria_config c
				WHERE c.id = 1
			)
			-- p_setor é obrigatório nesta fase -- sem ele não há fatia de setor para
			-- montar. Tratado como fase inválida (NULL), mesmo padrão do ELSE abaixo,
			-- em vez de devolver uma fatia quase vazia silenciosamente. String vazia
			-- tratada como ausente pelo mesmo motivo (chamador malformado, não um
			-- setor real).
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
					-- Só o setor Exames recebe a lista de exames que exigem anestesia
					-- (FR-16) -- os demais setores recebem '[]'::jsonb, para reduzir a
					-- superfície de um setor vazar informação de outro (AD-1).
					'exames_exigem_anestesia', CASE
						WHEN p_setor = 'Exames' THEN c.exames_exigem_anestesia
						ELSE '[]'::jsonb
					END,
					'mapeamento_stage_crm', c.mapeamento_stage_crm -> p_setor,
					'sinais_alerta_clinico', c.sinais_alerta_clinico,
					'destinatarios_emergencia', c.destinatarios_emergencia,
					'sla_resposta_minutos', c.sla_resposta_minutos
				))
				FROM secretaria_config c
				WHERE c.id = 1
				) END
			)
			ELSE NULL
		END;
$$;

-- Postgres concede EXECUTE em função nova a PUBLIC por padrão -- sem este REVOKE, o
-- papel restrito de identidade (PII) conseguiria chamar a função apesar do GRANT
-- abaixo ser só para o papel padrão (AD-3).
REVOKE EXECUTE ON FUNCTION secretaria_config_ler(TEXT, TEXT) FROM PUBLIC;

-- Concedido só ao papel padrão (AD-3) -- nunca ao papel restrito de identidade (PII),
-- que não tem motivo para ler config de negócio.
GRANT EXECUTE ON FUNCTION secretaria_config_ler(TEXT, TEXT) TO app_role;
