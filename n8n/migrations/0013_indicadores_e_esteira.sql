-- 0013 — Indicadores e Visibilidade Gerencial (CAP-11/Story 15). Fecha DW-50 (nenhum
-- registro persistido dos 3 desvios de triagem via `Escalar_humano`) e entrega a fonte
-- de leitura dos 5 indicadores mínimos exigidos pela diretoria do Nouvet (FR-36–39,
-- SM-5), até aqui sem nenhum mecanismo de serving nomeado (Deferred da spine, §4.11).
--
-- Três peças: (1) esteira de lembretes com contador + teto configuráveis, substituindo
-- o Sweep A "reenvia para sempre" da Story 12; (2) `atendimento_registro_setor`, tabela
-- append-only escrita só por `04 - Registrar Atendimento CRM.json`, cobrindo tanto os 5
-- setores reais quanto os 3 desvios de triagem agora delegados a `04` por
-- `02 - Escalar Humano.json`; (3) 5 funções `LANGUAGE sql STABLE` (mesmo padrão de
-- `atendimento_config_ler`) que leem esse estado sob demanda — sem nenhuma automação de
-- envio nova.

-- atendimento_config: intervalos_esteira_horas/max_tentativas_esteira são a única fonte
-- dos intervalos crescentes/teto da esteira (Always desta story) — nunca hardcoded em
-- nenhum workflow. Default '{1,6,24}'/3 é só o valor inicial operacional (calibrável
-- pela Btech via UPDATE direto, mesmo modelo de config já usado por
-- `sla_resposta_minutos`, AD-1) — não uma regra de negócio fixa.
ALTER TABLE atendimento_config
	ADD COLUMN intervalos_esteira_horas INTEGER[] NOT NULL DEFAULT '{1,6,24}',
	ADD COLUMN max_tentativas_esteira INTEGER NOT NULL DEFAULT 3;

-- n8n_status_atendimento: numero_tentativas_esteira conta quantos lembretes já foram
-- enviados para o handoff aguardando_cliente corrente; esteira_esgotada marca que o
-- teto foi atingido sem resposta (FR-37 "não atendido", ver Design Notes da story — não
-- usa stage_id/pipeline do RD CRM). Ambos são zerados só por `lock_conversa_adquirir`
-- (mesmo ponto que já zera nada disso hoje, mas já toca updated_at a cada mensagem) —
-- nunca por um hook novo em `01 - Agente.json` (Never desta story).
ALTER TABLE n8n_status_atendimento
	ADD COLUMN numero_tentativas_esteira INTEGER NOT NULL DEFAULT 0,
	ADD COLUMN esteira_esgotada BOOLEAN NOT NULL DEFAULT FALSE;

-- atendimento_registro_setor: evento append-only, nunca atualizado/apagado depois de
-- gravado — histórico bruto de onde cada atendimento aterrissou. `categoria` distingue
-- os 5 setores reais ('setor') dos 3 desvios de triagem nomeados por DW-50 ('desvio');
-- `valor` guarda o nome literal (setor real OU o motivo de `Escalar_humano`) — nunca os
-- dois domínios misturados na mesma linha sem essa distinção (Always desta story).
-- `rd_crm_deal_id` é opcional (nem toda gravação tem deal certo no momento da escrita,
-- mas `04` sempre tem `deal_id_final` disponível na prática — ver Code Map).
CREATE TABLE atendimento_registro_setor (
	id                BIGSERIAL PRIMARY KEY,
	telefone          VARCHAR(20) NOT NULL,
	categoria         VARCHAR(10) NOT NULL CHECK (categoria IN ('setor', 'desvio')),
	valor             VARCHAR(100) NOT NULL,
	rd_crm_deal_id    VARCHAR(40),
	created_at        TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_atendimento_registro_setor_created_at ON atendimento_registro_setor (created_at);

GRANT SELECT, INSERT, UPDATE, DELETE ON atendimento_registro_setor TO app_role;
GRANT USAGE, SELECT ON atendimento_registro_setor_id_seq TO app_role;

-- lock_conversa_adquirir: corpo idêntico à 0005, com `numero_tentativas_esteira = 0` e
-- `esteira_esgotada = FALSE` acrescentados ao SET do DO UPDATE (Always desta story) —
-- toda aquisição de lock bem-sucedida (sessão nova OU sessão existente destravada/
-- roubada por TTL) zera a esteira, cobrindo tanto quem some no meio de um fluxo de
-- setor quanto quem nunca foi classificado. O INSERT da via "sessão nova" já nasce com
-- os defaults corretos (0 / FALSE) das colunas acima -- só o UPSERT precisa do reset
-- explícito.
CREATE OR REPLACE FUNCTION lock_conversa_adquirir(p_session_id TEXT, p_ttl_minutos INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
AS $$
	WITH tentativa AS (
		INSERT INTO n8n_status_atendimento (session_id, lock_conversa, lock_adquirido_em, updated_at)
		SELECT p_session_id, TRUE, now(), now()
		WHERE p_session_id IS NOT NULL AND btrim(p_session_id) <> ''
		ON CONFLICT (session_id) DO UPDATE
			SET lock_conversa = TRUE,
			    lock_adquirido_em = now(),
			    updated_at = now(),
			    numero_tentativas_esteira = 0,
			    esteira_esgotada = FALSE
			WHERE n8n_status_atendimento.lock_conversa = FALSE
			   OR n8n_status_atendimento.lock_adquirido_em IS NULL
			   OR n8n_status_atendimento.lock_adquirido_em < now() - make_interval(mins => p_ttl_minutos)
		RETURNING TRUE
	)
	SELECT COALESCE((SELECT * FROM tentativa), FALSE);
$$;

REVOKE EXECUTE ON FUNCTION lock_conversa_adquirir(TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION lock_conversa_adquirir(TEXT, INTEGER) TO app_role;

-- atendimento_config_ler: corpo completo repetido (CREATE OR REPLACE exige a função
-- inteira) -- únicos campos novos são `intervalos_esteira_horas`/`max_tentativas_esteira`
-- na fatia 'triagem' (mesmo público que já lê `sla_resposta_minutos`/`lock_ttl_minutos`
-- ali -- é o Sweep A, `06`, quem consome); fatia 'setor' idêntica à 0012.
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
					'lock_ttl_minutos', c.lock_ttl_minutos,
					'intervalos_esteira_horas', c.intervalos_esteira_horas,
					'max_tentativas_esteira', c.max_tentativas_esteira
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

-- atendimento_indicador_leads_recebidos: FR-36. `n8n_fila_mensagens` nunca é apagada,
-- só marcada `processada` (0005) -- serve como log histórico de toda mensagem recebida,
-- mesmo antes de qualquer sessão/identidade existir. Um lead = um telefone distinto
-- (após normalização -- o mesmo cliente mandando várias mensagens no período conta uma
-- vez), contado pela data bruta do timestamp de recebimento (sem timezone dedicado
-- nesta janela do Piloto).
CREATE OR REPLACE FUNCTION atendimento_indicador_leads_recebidos(
	p_data_inicio DATE DEFAULT CURRENT_DATE,
	p_data_fim DATE DEFAULT CURRENT_DATE
)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
	SELECT COUNT(DISTINCT telefone_normalizar(telefone))::INTEGER
	FROM n8n_fila_mensagens
	WHERE "timestamp"::date BETWEEN p_data_inicio AND p_data_fim;
$$;

REVOKE EXECUTE ON FUNCTION atendimento_indicador_leads_recebidos(DATE, DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION atendimento_indicador_leads_recebidos(DATE, DATE) TO app_role;

-- atendimento_indicador_atendidos_nao_atendidos: FR-37, empacotando os 2 valores do
-- PRD num único indicador (ver Design Notes da story -- "5 indicadores mínimos" mapeia
-- para 4 FRs). Nunca usa stage_id/pipeline do RD CRM (Always desta story):
--   atendido = a sessão alcançou estado_espera = 'aguardando_atendimento_humano'
--     (handoff bem-sucedido -- por fechamento de setor via `04`, ou pelos 3 desvios de
--     triagem agora também registrados via `04`, ver DW-50);
--   não atendido = esteira_esgotada = TRUE sem nunca ter alcançado handoff;
--   qualquer outra combinação (ainda aguardando_cliente, dentro do teto) = pendente,
--     fora dos 2 valores deste indicador -- nem contado como atendido nem como não
--     atendido, mesma leitura do PRD (§4.11) para o período corrente.
-- `n8n_status_atendimento` não tem coluna de criação (só `updated_at`, tocada a cada
-- renovação/lock) -- o filtro de período usa `updated_at`, única referência temporal
-- disponível nesta tabela (limitação de schema documentada, não um desvio da regra).
CREATE OR REPLACE FUNCTION atendimento_indicador_atendidos_nao_atendidos(
	p_data_inicio DATE DEFAULT CURRENT_DATE,
	p_data_fim DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
	SELECT jsonb_build_object(
		'atendidos', COUNT(*) FILTER (
			WHERE estado_espera = 'aguardando_atendimento_humano'
		),
		'nao_atendidos', COUNT(*) FILTER (
			WHERE esteira_esgotada = TRUE
			  AND estado_espera <> 'aguardando_atendimento_humano'
		)
	)
	FROM n8n_status_atendimento
	WHERE updated_at::date BETWEEN p_data_inicio AND p_data_fim;
$$;

REVOKE EXECUTE ON FUNCTION atendimento_indicador_atendidos_nao_atendidos(DATE, DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION atendimento_indicador_atendidos_nao_atendidos(DATE, DATE) TO app_role;

-- atendimento_indicador_distribuicao_setor: FR-38. Só linhas `categoria = 'setor'`
-- (nunca os 3 desvios de triagem, que são um contador à parte -- Always desta story);
-- objeto JSONB por setor real, contagem de linhas gravadas por `04` no período. Setor
-- sem nenhum evento no período simplesmente não aparece como chave (equivalente a 0,
-- mesmo padrão de omissão de `jsonb_strip_nulls` já usado em `atendimento_config_ler`).
CREATE OR REPLACE FUNCTION atendimento_indicador_distribuicao_setor(
	p_data_inicio DATE DEFAULT CURRENT_DATE,
	p_data_fim DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
	SELECT COALESCE(jsonb_object_agg(agrupado.valor, agrupado.total), '{}'::jsonb)
	FROM (
		SELECT valor, COUNT(*) AS total
		FROM atendimento_registro_setor
		WHERE categoria = 'setor'
		  AND created_at::date BETWEEN p_data_inicio AND p_data_fim
		GROUP BY valor
	) agrupado;
$$;

REVOKE EXECUTE ON FUNCTION atendimento_indicador_distribuicao_setor(DATE, DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION atendimento_indicador_distribuicao_setor(DATE, DATE) TO app_role;

-- atendimento_indicador_tempo_resposta: FR-39, tempo de 1ª resposta. Assume
-- `n8n_historico_mensagens.message` no formato padrão do node `memoryPostgresChat`
-- (`{"type": "human"|"ai", ...}`, ver Design Notes da story -- não verificável neste
-- ambiente sem n8n/Postgres real, validar contra dado real na VPS de dev antes do
-- go-live). Para cada sessão, cada par consecutivo humano->IA (via LAG por
-- session_id/created_at) é uma resposta; média em segundos sobre todos os pares do
-- período. Sem par no período: `media_segundos` NULL e `amostras` 0 (nenhuma resposta
-- para medir, não um erro).
CREATE OR REPLACE FUNCTION atendimento_indicador_tempo_resposta(
	p_data_inicio DATE DEFAULT CURRENT_DATE,
	p_data_fim DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
	WITH mensagens AS (
		SELECT
			session_id,
			created_at,
			message ->> 'type' AS tipo,
			LAG(created_at) OVER (PARTITION BY session_id ORDER BY created_at) AS created_at_anterior,
			LAG(message ->> 'type') OVER (PARTITION BY session_id ORDER BY created_at) AS tipo_anterior
		FROM n8n_historico_mensagens
		WHERE created_at::date BETWEEN p_data_inicio AND p_data_fim
	),
	respostas AS (
		SELECT EXTRACT(EPOCH FROM (created_at - created_at_anterior)) AS segundos
		FROM mensagens
		WHERE tipo = 'ai' AND tipo_anterior = 'human'
	)
	SELECT jsonb_build_object(
		'media_segundos', ROUND(AVG(segundos)),
		'amostras', COUNT(*)
	)
	FROM respostas;
$$;

REVOKE EXECUTE ON FUNCTION atendimento_indicador_tempo_resposta(DATE, DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION atendimento_indicador_tempo_resposta(DATE, DATE) TO app_role;

-- atendimento_indicadores_ler: ponto único de leitura (Always desta story) -- a Btech
-- consulta só esta função, nunca as 4 individuais direto. Mesmo padrão de
-- `atendimento_config_ler`: `LANGUAGE sql STABLE`, sem nenhuma automação de envio
-- associada -- só consulta sob demanda.
CREATE OR REPLACE FUNCTION atendimento_indicadores_ler(
	p_data_inicio DATE DEFAULT CURRENT_DATE,
	p_data_fim DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
	SELECT jsonb_build_object(
		'leads_recebidos', atendimento_indicador_leads_recebidos(p_data_inicio, p_data_fim),
		'atendidos_nao_atendidos', atendimento_indicador_atendidos_nao_atendidos(p_data_inicio, p_data_fim),
		'distribuicao_setor', atendimento_indicador_distribuicao_setor(p_data_inicio, p_data_fim),
		'tempo_resposta', atendimento_indicador_tempo_resposta(p_data_inicio, p_data_fim)
	);
$$;

REVOKE EXECUTE ON FUNCTION atendimento_indicadores_ler(DATE, DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION atendimento_indicadores_ler(DATE, DATE) TO app_role;
