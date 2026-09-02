-- 0005 — Debounce e lock de concorrência com recuperação de TTL (AD-5). Resolve DW-2
-- (n8n_status_atendimento sem timestamp de aquisição do lock) e DW-3 (n8n_fila_mensagens
-- sem coluna de status/processado nem índice único de dedup).
--
-- ALTER TABLE nas duas tabelas criadas na 0002 (nunca recria) + as duas funções
-- atômicas que a Story 5/6 ("01 - Agente.json") vai chamar do fluxo de ingestão
-- (enfileirar -> travar -> esperar -> reconsultar -> agregar -> destravar, ver
-- .claude/skills/n8n-agent-patterns/references/agente-e-subfluxos.md) -- esta story
-- entrega só o contrato Postgres, não os nodes n8n reais.

-- n8n_status_atendimento: timestamp de quando o lock foi adquirido, necessário para
-- calcular expiração por TTL (AD-5 -- "achado CRÍTICO" do review adversarial: sem isso,
-- um crash no meio do processamento trava o telefone para sempre).
ALTER TABLE n8n_status_atendimento
	ADD COLUMN lock_adquirido_em TIMESTAMP WITHOUT TIME ZONE;

-- Backfill obrigatório: sem isto, qualquer linha já com lock_conversa = TRUE no
-- instante em que esta migration roda ficaria com lock_adquirido_em = NULL, e o
-- `OR lock_adquirido_em IS NULL` de lock_conversa_adquirir trataria isso como
-- "recuperável" -- toda conversa legitimamente em andamento no momento do deploy
-- vira instantaneamente roubável pela próxima chamada, quebrando a exclusão mútua
-- exatamente no momento mais sensível (achado do review adversarial, patch [high]).
-- Ancorado em updated_at (já atualizado no momento do lock, AD-5) para dar a um lock
-- já ativo uma janela de TTL completa a partir de quando ele foi de fato adquirido,
-- em vez de uma janela zerada.
UPDATE n8n_status_atendimento
SET lock_adquirido_em = COALESCE(lock_adquirido_em, updated_at, now())
WHERE lock_conversa = TRUE;

-- n8n_fila_mensagens: marca quais mensagens já foram agregadas/processadas por uma
-- execução (para "consumir" só os ids específicos daquele lote, nunca um DELETE cego
-- por telefone -- apagaria mensagem nova chegada durante a espera) + índice único em
-- id_mensagem para dedup de retry de webhook via ON CONFLICT (id_mensagem) DO NOTHING
-- (a inserção em si é feita pelo workflow de ingestão, fora desta story).
ALTER TABLE n8n_fila_mensagens
	ADD COLUMN processada BOOLEAN NOT NULL DEFAULT FALSE;

CREATE UNIQUE INDEX idx_n8n_fila_mensagens_id_mensagem ON n8n_fila_mensagens (id_mensagem);

-- lock_conversa_adquirir: peça crítica de AD-5. Um único INSERT ... ON CONFLICT
-- (session_id) DO UPDATE ... WHERE <lock livre OU TTL expirado>, envolto em COALESCE
-- para nunca devolver NULL (sessão nova sem conflito também cai no INSERT normal e
-- devolve TRUE via RETURNING). O WHERE da cláusula DO UPDATE é o que torna a operação
-- atômica: duas transações concorrentes disputam o lock de linha do UPSERT via a
-- UNIQUE constraint de session_id (0002) e só uma enxerga a condição como verdadeira
-- depois que a outra já commitou -- nunca dois round-trips separados (SELECT depois
-- UPDATE), que abriria a janela de corrida entre leitura e escrita.
-- p_ttl_minutos vem sempre de secretaria_config.lock_ttl_minutos (nunca hardcoded) --
-- quem chama passa o valor lido a cada turno.
-- Guard de p_session_id NULL/vazio: mesmo padrão de secretaria_config_ler (Story 2,
-- 0004), que trata entrada malformada do chamador como caso inválido em vez de agir
-- sobre ela -- INSERT ... SELECT ... WHERE (em vez de INSERT ... VALUES) faz a fonte
-- do INSERT produzir zero linhas para entrada inválida, então nada é inserido/
-- atualizado e a função devolve FALSE via o COALESCE abaixo (achado do review
-- adversarial, patch [low]). btrim() em vez de só `<> ''` -- um p_session_id
-- só-espaço passaria pelo `<> ''` cru e criaria uma linha travada com identificador
-- de lixo (achado do review adversarial, edge-case hunter, patch [low]).
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
			    updated_at = now()
			WHERE n8n_status_atendimento.lock_conversa = FALSE
			   OR n8n_status_atendimento.lock_adquirido_em IS NULL
			   OR n8n_status_atendimento.lock_adquirido_em < now() - make_interval(mins => p_ttl_minutos)
		RETURNING TRUE
	)
	SELECT COALESCE((SELECT * FROM tentativa), FALSE);
$$;

-- lock_conversa_liberar: destrava a sessão. AD-7 implica que quem chama isto deve
-- fazê-lo só depois de toda a sequência de mensagens pausadas ser enviada, nunca logo
-- após computar a resposta -- decisão de quando chamar é de quem constrói o workflow
-- de envio (fora desta story); aqui só a operação de destravar em si.
CREATE OR REPLACE FUNCTION lock_conversa_liberar(p_session_id TEXT)
RETURNS VOID
LANGUAGE sql
AS $$
	UPDATE n8n_status_atendimento
	SET lock_conversa = FALSE,
	    lock_adquirido_em = NULL,
	    updated_at = now()
	WHERE session_id = p_session_id;
$$;

-- Postgres concede EXECUTE em função nova a PUBLIC por padrão -- sem este REVOKE, o
-- papel restrito de identidade (PII, AD-3) conseguiria chamar as funções apesar do
-- GRANT abaixo ser só para o papel padrão. Mesmo padrão da 0004
-- (secretaria_config_ler) -- o papel de identidade nunca recebe este GRANT.
REVOKE EXECUTE ON FUNCTION lock_conversa_adquirir(TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION lock_conversa_adquirir(TEXT, INTEGER) TO app_role;

REVOKE EXECUTE ON FUNCTION lock_conversa_liberar(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION lock_conversa_liberar(TEXT) TO app_role;
