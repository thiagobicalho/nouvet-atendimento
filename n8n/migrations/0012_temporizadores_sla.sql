-- 0012 — Temporizadores, Continuidade e SLA (CAP-8/Story 12). Fecha o schema base do
-- estado de espera por sessão (`estado_espera`) e do ciclo de escalonamento
-- (`numero_ciclo_escalonamento`) em `n8n_status_atendimento`, do destinatário do
-- escalonamento de SLA (`destinatarios_gestor_sla`, público distinto de
-- `destinatarios_emergencia`) em `atendimento_config`, e do único ponto de escrita
-- desse estado (`atendimento_estado_espera_marcar`), consumido por
-- `04 - Registrar Atendimento CRM.json` ao fechar cada um dos 5 fluxos de setor.
--
-- Remove `aguardando_followup`/`numero_followup` (`n8n_status_atendimento`) e
-- `lembretes_horas`/`follow_ups_horas`/`max_followups` (`atendimento_config`) --
-- schema morto desde a Story 1 (0002): nunca seedado (`n8n/seed/0001_atendimento_config.sql`
-- não referencia nenhum dos 5), nunca exposto por `atendimento_config_ler`, nunca
-- referenciado por nenhum workflow (confirmado por grep antes desta migration) -- e de
-- granularidade incompatível com o SLA fixo de `sla_resposta_minutos` que esta story
-- reaproveita como única fonte do intervalo, em vez de reaproveitados como estão.

ALTER TABLE n8n_status_atendimento
	DROP COLUMN aguardando_followup,
	DROP COLUMN numero_followup;

ALTER TABLE atendimento_config
	DROP COLUMN lembretes_horas,
	DROP COLUMN follow_ups_horas,
	DROP COLUMN max_followups;

-- estado_espera: default 'aguardando_cliente' (comportamento pré-handoff, rastreado só
-- em Postgres -- nenhum card ainda existe nesta fase, ver Design Notes da story) --
-- `Registrar_atendimento_crm` (via `atendimento_estado_espera_marcar`) é o único ponto
-- que grava 'aguardando_atendimento_humano', sempre no fechamento de um dos 5 fluxos de
-- setor -- nunca por `Escalar_humano` (Always da story).
ALTER TABLE n8n_status_atendimento
	ADD COLUMN estado_espera VARCHAR(30) NOT NULL DEFAULT 'aguardando_cliente'
		CHECK (estado_espera IN ('aguardando_cliente', 'aguardando_atendimento_humano'));

-- numero_ciclo_escalonamento: contagem de ciclos de escalonamento ao gestor já
-- disparados para o handoff corrente -- zerado sempre que `atendimento_estado_espera_marcar`
-- (re)marca 'aguardando_atendimento_humano' (novo handoff), incrementado só pelo cron
-- (`06 - Lembretes e Escalonamento SLA.json`) quando uma Task de SLA vencida não teve
-- atividade recente do lead (nunca no caminho "lead ainda ativo, renova sem avisar").
ALTER TABLE n8n_status_atendimento
	ADD COLUMN numero_ciclo_escalonamento INTEGER NOT NULL DEFAULT 0;

-- destinatarios_gestor_sla: mesmo formato/convenção de `destinatarios_emergencia`
-- (array de objetos com `contact_id` do RD Conversas, ver 02 - Escalar Humano.json) --
-- público distinto (gestor de SLA de resposta, não emergência clínica) -- CAP-12 (este
-- mecanismo) nunca reusa `destinatarios_emergencia` e vice-versa.
ALTER TABLE atendimento_config
	ADD COLUMN destinatarios_gestor_sla JSONB NOT NULL DEFAULT '[]'::jsonb;

-- atendimento_estado_espera_marcar: porta única de escrita de `estado_espera` (Always
-- da story). Estado fora do domínio aceito pelo CHECK acima produz zero linhas
-- afetadas -- mesma falha silenciosa das demais funções deste diretório
-- (atendimento_config_ler, lock_conversa_adquirir, telefone_normalizar).
--
-- Correlação por `telefone_normalizar(session_id) = telefone_normalizar(p_session_id)`,
-- nunca por igualdade crua de string: `n8n_status_atendimento.session_id` é sempre o
-- telefone bruto recebido do webhook do RD Conversas (mesmo valor usado por
-- `lock_conversa_adquirir`/`sessionKey` da memória, Story 3/5 -- nunca normalizado antes
-- de chegar em `n8n_status_atendimento`), enquanto o `telefone` que
-- `Registrar_atendimento_crm` tem disponível em `04 - Registrar Atendimento CRM.json` é
-- `$('Receber Solicitação').item.json.telefone` (E.164 limpo, já normalizado para as
-- chamadas ao RD CRM, recebido do agente de setor via `toolWorkflow`).
-- Comparar os dois formatos direto (`=`) nunca bateria para o mesmo cliente na prática --
-- reaproveita `telefone_normalizar` (AD-8, "reutilizado por qualquer ponto que precise
-- comparar/casar contato", já concedido a app_role desde a 0006) em vez de reimplementar
-- normalização inline, e evita a única alternativa que resolveria isso de outra forma
-- (passar o `session_id` bruto por `01 - Agente.json`), vedada pelo `Never` desta story
-- ("Não modifica 01 - Agente.json").
CREATE OR REPLACE FUNCTION atendimento_estado_espera_marcar(p_session_id TEXT, p_estado TEXT)
RETURNS VOID
LANGUAGE sql
AS $$
	UPDATE n8n_status_atendimento
	SET estado_espera = p_estado,
	    numero_ciclo_escalonamento = 0,
	    updated_at = now()
	WHERE telefone_normalizar(session_id) IS NOT NULL
	  AND telefone_normalizar(session_id) = telefone_normalizar(p_session_id)
	  AND p_estado IN ('aguardando_cliente', 'aguardando_atendimento_humano');
$$;

REVOKE EXECUTE ON FUNCTION atendimento_estado_espera_marcar(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION atendimento_estado_espera_marcar(TEXT, TEXT) TO app_role;

-- atendimento_config_ler: estende a fatia 'triagem' com `destinatarios_gestor_sla`
-- (mesma classe de campo operacional que `destinatarios_emergencia`/`sla_resposta_minutos`,
-- já presentes ali) -- só a fatia 'triagem' (não 'setor'), mesmo padrão de
-- `destinatarios_emergencia` hoje: o cron (`06`) lê a config via este mesmo ponto único
-- de leitura (AD-1), nunca por SELECT direto na tabela. Corpo completo repetido (CREATE
-- OR REPLACE exige a função inteira) -- único campo novo é `destinatarios_gestor_sla` no
-- `jsonb_build_object` da fatia 'triagem'; resto idêntico à 0010.
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
					'destinatarios_gestor_sla', c.destinatarios_gestor_sla,
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

REVOKE EXECUTE ON FUNCTION atendimento_config_ler(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION atendimento_config_ler(TEXT, TEXT) TO app_role;

-- n8n_task_sla_lock / task_sla_lock_adquirir / task_sla_lock_liberar: fecha achado
-- [high] de review -- `05 - Gerenciar Task SLA.json` faz um check-then-act (busca a
-- Task "Acompanhamento SLA" aberta do deal, depois decide POST/PUT) sem nenhuma
-- exclusão mútua entre invocações concorrentes para o MESMO `deal_id` (`04` no
-- fechamento de um handoff correndo ao mesmo tempo que um ciclo do cron `06`, ou dois
-- ciclos do cron sobrepostos) -- sem lock, isso pode criar 2 Tasks "Acompanhamento
-- SLA" no mesmo deal, violando o próprio Acceptance Criterion desta story ("existe
-- exatamente uma Task de SLA aberta no deal, nunca duplicada entre execuções").
--
-- Mesmo espírito de `lock_conversa_adquirir` (0005/AD-5) -- não `pg_advisory_lock`
-- nativo (que exige manter a MESMA conexão física do início ao fim da sequência,
-- garantia que o node Postgres do n8n não dá entre chamadas separadas dentro do mesmo
-- workflow) -- e sim uma linha de lock com TTL de recuperação, reivindicada por um
-- único `INSERT ... ON CONFLICT ... DO UPDATE ... WHERE <livre ou TTL expirado>`
-- atômico (mesmo padrão de `n8n_status_atendimento`/`lock_conversa_adquirir`), que
-- funciona através de chamadas/conexões separadas porque o estado vive na tabela, não
-- na sessão do banco. TTL reaproveita `atendimento_config.lock_ttl_minutos` (já
-- existente, mesmo campo usado por `lock_conversa_adquirir`) -- nenhum campo de config
-- novo. Quem não consegue o lock (`task_sla_lock_adquirir` devolve FALSE) simplesmente
-- desiste desta invocação sem criar/renovar nada -- a invocação concorrente que já
-- detém o lock cobre o mesmo objetivo, então desistir não perde nenhuma garantia.
CREATE TABLE n8n_task_sla_lock (
	id                 BIGSERIAL PRIMARY KEY,
	deal_id            VARCHAR(40) NOT NULL UNIQUE,
	lock_adquirido_em  TIMESTAMP WITHOUT TIME ZONE,
	updated_at         TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

GRANT SELECT, INSERT, UPDATE, DELETE ON n8n_task_sla_lock TO app_role;
GRANT USAGE, SELECT ON n8n_task_sla_lock_id_seq TO app_role;

CREATE OR REPLACE FUNCTION task_sla_lock_adquirir(p_deal_id TEXT, p_ttl_minutos INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
AS $$
	WITH tentativa AS (
		INSERT INTO n8n_task_sla_lock (deal_id, lock_adquirido_em, updated_at)
		SELECT p_deal_id, now(), now()
		WHERE p_deal_id IS NOT NULL AND btrim(p_deal_id) <> ''
		ON CONFLICT (deal_id) DO UPDATE
			SET lock_adquirido_em = now(),
			    updated_at = now()
			WHERE n8n_task_sla_lock.lock_adquirido_em IS NULL
			   OR n8n_task_sla_lock.lock_adquirido_em < now() - make_interval(mins => p_ttl_minutos)
		RETURNING TRUE
	)
	SELECT COALESCE((SELECT * FROM tentativa), FALSE);
$$;

-- task_sla_lock_liberar: `lock_adquirido_em = NULL` (nunca DELETE da linha) -- mesmo
-- padrão de `lock_conversa_liberar`, faz a linha voltar a contar como "livre" para a
-- condição do `DO UPDATE` acima sem precisar recriar a linha/UNIQUE a cada ciclo.
CREATE OR REPLACE FUNCTION task_sla_lock_liberar(p_deal_id TEXT)
RETURNS VOID
LANGUAGE sql
AS $$
	UPDATE n8n_task_sla_lock
	SET lock_adquirido_em = NULL,
	    updated_at = now()
	WHERE deal_id = p_deal_id;
$$;

REVOKE EXECUTE ON FUNCTION task_sla_lock_adquirir(TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION task_sla_lock_adquirir(TEXT, INTEGER) TO app_role;

REVOKE EXECUTE ON FUNCTION task_sla_lock_liberar(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION task_sla_lock_liberar(TEXT) TO app_role;
