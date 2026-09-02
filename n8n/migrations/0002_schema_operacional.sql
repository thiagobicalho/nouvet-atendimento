-- 0002 — Schema operacional do banco da aplicação (Structural Seed da spine): config de
-- personalização, profissionais, memória de conversa, fila de debounce e lock de
-- concorrência. Concedido só ao papel padrão (app_role, criado na 0001) — NUNCA à tabela
-- de identidade cliente/pet, que é a 0003, com papel próprio (AD-3).
--
-- Roda no banco default do container (nouvet_app / $POSTGRES_DB), conectado
-- automaticamente pelo entrypoint do Postgres. Sem seed de conteúdo aqui — a linha
-- singleton de secretaria_config é populada pela Story 2 (Config-as-Data).

-- Config de personalização (AD-1): singleton, id sempre 1. Tom, dados institucionais,
-- limiares de SLA/follow-up, sinais de alerta clínico (FR-8), destinatários de
-- emergência (FR-41), catálogo de serviços/Fontes Confiáveis (FR-30/31), exames que
-- exigem anestesia (FR-16) e mapeamento de stage_id do funil RD CRM por setor (FR-23).
-- Nunca guarda segredo de integração — isso vive só no cofre do n8n (AD-2).
CREATE TABLE secretaria_config (
	id                        INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
	nome_secretaria           VARCHAR(100) NOT NULL DEFAULT 'Assistente Nouvet',
	nome_empresa              VARCHAR(200) NOT NULL DEFAULT 'Nouvet',
	endereco                  TEXT,
	cidade_estado             VARCHAR(100),
	telefone                  VARCHAR(20),
	whatsapp                  VARCHAR(20),
	email                     VARCHAR(200),
	site                      VARCHAR(200),
	horario_funcionamento     TEXT,
	tom_voz                   TEXT,
	formas_pagamento          TEXT[] NOT NULL DEFAULT '{}',
	convenios                 JSONB NOT NULL DEFAULT '[]'::jsonb,
	catalogo_servicos         JSONB NOT NULL DEFAULT '[]'::jsonb,
	exames_exigem_anestesia   JSONB NOT NULL DEFAULT '[]'::jsonb,
	sinais_alerta_clinico     JSONB NOT NULL DEFAULT '[]'::jsonb,
	destinatarios_emergencia  JSONB NOT NULL DEFAULT '[]'::jsonb,
	mapeamento_stage_crm      JSONB NOT NULL DEFAULT '{}'::jsonb,
	sla_resposta_minutos      INTEGER NOT NULL DEFAULT 5,
	lock_ttl_minutos          INTEGER NOT NULL DEFAULT 5,
	lembretes_horas           INTEGER[] NOT NULL DEFAULT '{24,1}',
	follow_ups_horas          INTEGER[] NOT NULL DEFAULT '{6,24,48}',
	max_followups             INTEGER NOT NULL DEFAULT 3,
	created_at                TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated_at                TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Profissionais e especialidade/setor, usados na triagem/roteamento do agente (AD-4:
-- nenhuma checagem de agenda real aqui, só o dado descritivo de quem atende o quê).
CREATE TABLE secretaria_profissionais (
	id             BIGSERIAL PRIMARY KEY,
	nome           VARCHAR(200) NOT NULL,
	especialidade  VARCHAR(200),
	setor          VARCHAR(100),
	ativo          BOOLEAN NOT NULL DEFAULT TRUE,
	created_at     TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated_at     TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Memória de conversa do agente (node memoryPostgresChat do LangChain, por session_id).
CREATE TABLE n8n_historico_mensagens (
	id           BIGSERIAL PRIMARY KEY,
	session_id   VARCHAR(40) NOT NULL,
	message      JSONB NOT NULL,
	created_at   TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Buffer de debounce por telefone (AD-5) -- mensagens picadas chegam aqui antes de
-- serem agregadas e processadas juntas pelo agente.
CREATE TABLE n8n_fila_mensagens (
	id           BIGSERIAL PRIMARY KEY,
	id_mensagem  VARCHAR(40) NOT NULL,
	telefone     VARCHAR(40) NOT NULL,
	mensagem     TEXT NOT NULL,
	"timestamp"  TIMESTAMP WITHOUT TIME ZONE NOT NULL
);

-- Lock de concorrência por sessão com TTL de recuperação (AD-5) + estado do ciclo de
-- follow-up automático (FR-25-29).
CREATE TABLE n8n_status_atendimento (
	id                   BIGSERIAL PRIMARY KEY,
	session_id           VARCHAR(40) NOT NULL UNIQUE,
	lock_conversa        BOOLEAN NOT NULL DEFAULT FALSE,
	aguardando_followup  BOOLEAN NOT NULL DEFAULT FALSE,
	numero_followup      INTEGER NOT NULL DEFAULT 0,
	updated_at           TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_n8n_historico_mensagens_session_id ON n8n_historico_mensagens (session_id);
CREATE INDEX idx_n8n_fila_mensagens_telefone ON n8n_fila_mensagens (telefone);

-- Privilégio mínimo: app_role só faz DML nestas 5 tabelas, nunca DDL, nunca a tabela
-- de identidade (0003).
GRANT USAGE ON SCHEMA public TO app_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON
	secretaria_config,
	secretaria_profissionais,
	n8n_historico_mensagens,
	n8n_fila_mensagens,
	n8n_status_atendimento
TO app_role;

GRANT USAGE, SELECT ON
	secretaria_profissionais_id_seq,
	n8n_historico_mensagens_id_seq,
	n8n_fila_mensagens_id_seq,
	n8n_status_atendimento_id_seq
TO app_role;
