-- 0001 — Seed inicial de secretaria_config (AD-1, Config-as-Data). Popula a linha
-- singleton (id=1) com o conteúdo de negócio já confirmado disponível hoje. Aplicação
-- manual (README.md deste diretório) -- não roda em docker-entrypoint-initdb.d, só
-- n8n/migrations roda automaticamente (docker-compose.yml).
--
-- ON CONFLICT (id) DO NOTHING: reaplicar este arquivo depois da primeira vez não
-- duplica nem sobrescreve a linha -- edição de conteúdo em produção passa a ser feita
-- direto no banco (Consistency Conventions da spine), não reaplicando este seed.
INSERT INTO secretaria_config (
	id,
	nome_secretaria,
	nome_empresa,
	tom_voz,
	sla_resposta_minutos,
	lock_ttl_minutos,
	catalogo_servicos,
	sinais_alerta_clinico,
	exames_exigem_anestesia,
	destinatarios_emergencia,
	mapeamento_stage_crm
) VALUES (
	1,
	'Assistente Nouvet',
	'Nouvet',
	-- Grounded em NFR-5 (conversa natural/fluida, nunca estrutura de menu rígido tipo
	-- URA) + FR-32 (sempre se identifica explicitamente como atendente virtual, nunca
	-- passa por humano) + CAP-1 (Recepção e Identificação: personaliza com o que já
	-- sabe do cliente/pet, sem soar robotizado).
	'Acolhedor, caloroso e natural, como uma recepcionista humana experiente -- nunca ' ||
	'estruturado como menu de URA ("digite 1 para X"). Sempre se identifica ' ||
	'explicitamente como atendente virtual do Nouvet logo no início da conversa (ex.: ' ||
	'"Eu sou o atendente virtual do Nouvet, estou aqui para te ajudar"), sem por isso ' ||
	'soar robotizado. Nunca diagnostica, nunca minimiza a gravidade de um sintoma ' ||
	'relatado pelo cliente.',
	5,
	5,
	-- Catálogo de serviços do Care Center (3 itens confirmados hoje: banho cachorro,
	-- banho gato, tosa). Sem preço/duração -- dado ainda não fornecido por Thiago;
	-- adicionar quando o Nouvet passar a lista de preços real.
	'[
		{"setor": "Care Center", "servico": "Banho - Cachorro"},
		{"setor": "Care Center", "servico": "Banho - Gato"},
		{"setor": "Care Center", "servico": "Tosa"}
	]'::jsonb,
	-- Lista interina de sinais de alerta clínico (FR-8): único exemplo já confirmado
	-- no material comercial/entrevistas do Nouvet até hoje (PRD, Questão em Aberto
	-- #15 -- lista definitiva ainda pendente de validação da equipe clínica).
	'[
		"Vômito por 3 dias seguidos ou mais"
	]'::jsonb,
	-- Exames que exigem anestesia (FR-16): único exemplo já confirmado no PRD hoje.
	'[
		"Tomografia"
	]'::jsonb,
	-- PENDENTE: contatos reais de plantonista/profissionais envolvidos por setor
	-- (FR-41) ainda não fornecidos por Thiago -- fica vazio até o Nouvet passar a
	-- lista real. Não bloqueia build, bloqueia só o go-live.
	'[]'::jsonb,
	-- PENDENTE: mapeamento de stage_id do funil RD Station CRM por setor (FR-23)
	-- ainda não fornecido por Thiago -- fica vazio até o funil real ser mapeado. Não
	-- bloqueia build, bloqueia só o go-live.
	'{}'::jsonb
)
ON CONFLICT (id) DO NOTHING;
