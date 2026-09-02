# Configuração e memória em Postgres

Fonte: `secretariav3-completo/00 - Configurações.json` (provisionamento) e `secretariav3-completo/01 - Secretária V3.json` (leitura em runtime). O exemplo mais simples (`clinica/`) não usa nada disto — lá a personalização está hardcoded no `systemMessage` do agente, o que não serve de referência para o Nouvet.

## Tabelas operacionais (memória e controle de concorrência)

```sql
CREATE TABLE n8n_historico_mensagens (
  id           BIGSERIAL PRIMARY KEY,
  session_id   VARCHAR(40) NOT NULL,
  message      JSONB NOT NULL,
  created_at   TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE n8n_fila_mensagens (
  id           BIGSERIAL PRIMARY KEY,
  id_mensagem  VARCHAR(40) NOT NULL,
  telefone     VARCHAR(40) NOT NULL,
  mensagem     TEXT NOT NULL,
  "timestamp"  TIMESTAMP WITHOUT TIME ZONE NOT NULL
);

CREATE TABLE n8n_status_atendimento (
  id                   BIGSERIAL PRIMARY KEY,
  session_id           VARCHAR(40) NOT NULL UNIQUE,
  lock_conversa        BOOLEAN NOT NULL DEFAULT FALSE,
  aguardando_followup  BOOLEAN NOT NULL DEFAULT FALSE,
  numero_followup      INTEGER NOT NULL DEFAULT 0,
  updated_at           TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

- `n8n_historico_mensagens` é a memória de conversa do agente (o node `memoryPostgresChat` do LangChain lê/grava aqui por `session_id`).
- `n8n_fila_mensagens` é um buffer de debounce: mensagens que chegam picadas (o cliente manda várias seguidas) são enfileiradas por `telefone` e processadas juntas, em vez de disparar uma resposta da IA por fragmento.
- `n8n_status_atendimento` resolve concorrência: `lock_conversa` trava uma sessão enquanto o agente está processando (evita duas execuções simultâneas na mesma conversa); `aguardando_followup`/`numero_followup` controlam o estado do ciclo de follow-up automático. **Relevante para o risco M5 do PRD do Nouvet** (concorrência em agendamento real) — esse é o mecanismo pronto que resolve isso, não precisa desenhar do zero.

## Tabelas de configuração (o que responde ao FR-34/35 do Nouvet)

```sql
CREATE TABLE secretaria_config (
  id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  nome_secretaria VARCHAR(100) NOT NULL,
  nome_empresa VARCHAR(200) NOT NULL,
  endereco TEXT,
  cidade_estado VARCHAR(100),
  telefone VARCHAR(20),
  whatsapp VARCHAR(20),
  email VARCHAR(200),
  site VARCHAR(200),
  horario_funcionamento TEXT NOT NULL,
  formas_pagamento TEXT[],
  prazo_pagamento VARCHAR(50),
  convenios JSONB DEFAULT '[]'::jsonb,
  chatwoot_account_id INTEGER NOT NULL,
  chatwoot_inbox_id INTEGER NOT NULL,
  id_conversa_alerta INTEGER NOT NULL,
  url_chatwoot VARCHAR(500) NOT NULL,
  url_asaas VARCHAR(500),
  lembretes_horas INTEGER[] DEFAULT '{24, 1}',
  follow_ups_horas INTEGER[] DEFAULT '{6, 24, 48}',
  tipo_follow_ups VARCHAR(50)[] DEFAULT '{mensagem, mensagem, mensagem}',
  max_followups INTEGER DEFAULT 3,
  telefone_twilio VARCHAR(20),
  telefone_twilio_whatsapp VARCHAR(20),
  google_tasks_list_id VARCHAR(200),
  retell_sip_usuario VARCHAR(100),
  retell_sip_password VARCHAR(200),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE secretaria_profissionais (
  id BIGSERIAL PRIMARY KEY,
  nome VARCHAR(200) NOT NULL,
  especialidade VARCHAR(200),
  calendar_id VARCHAR(200) NOT NULL UNIQUE,
  duracao_minutos INTEGER DEFAULT 30,
  valor_consulta DECIMAL(10,2) NOT NULL,
  disponibilidade JSONB NOT NULL,
  ativo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);
```

`secretaria_config` é **singleton** (`id` sempre `1`, garantido por `CHECK (id = 1)`) — este schema assume uma instância de agente por banco, não multi-tenant. Se o Nouvet precisar rodar mais de uma "instância" no mesmo banco algum dia, essa tabela precisa de uma coluna de tenant/cliente, que não existe hoje.

Repare que os campos misturam categorias diferentes de config que o PRD do Nouvet trata como uma coisa só (Configuração de Personalização, FR-34): identidade/tom (`nome_secretaria`), dados institucionais (`endereco`, `horario_funcionamento`), limiares de tempo (`lembretes_horas`, `follow_ups_horas`, `max_followups` — o equivalente aos "5 minutos"/"2 ciclos" do Nouvet), e credenciais de integração (`chatwoot_account_id`, `url_asaas`, `telefone_twilio`). Ao desenhar o schema do Nouvet, vale decidir se credenciais de integração ficam nessa mesma tabela ou saem para o cofre de credenciais do n8n (FR-43 do PRD do Nouvet já exige isso para os segredos — este exemplo não separa os dois).

## Provisionamento (como uma instância nasce)

`00 - Configurações.json` é um workflow próprio, acionado por webhook, que recebe um payload de setup (`business_data`, `system_ids`, `features`, `credentials`) e:
1. Roda o `CREATE TABLE IF NOT EXISTS` de todas as tabelas acima.
2. Insere a linha única de `secretaria_config` a partir do payload.
3. Faz split de uma lista de profissionais recebida no payload e insere uma linha por profissional em `secretaria_profissionais`.
4. Cria, via API do Chatwoot, as etiquetas e atributos customizados que o agente vai usar (ex.: `testando-agente`, `agente-off`).

Não é um processo manual de digitar linha por linha no banco — é um endpoint de setup que materializa tudo de uma vez a partir de um payload estruturado.

## Leitura em runtime (o que faz isso ser config de verdade, não hardcode)

Dentro do workflow principal do agente (`01 - Secretária V3.json`), a cada execução:

1. Um node Postgres chamado `Buscar Config` roda: `SELECT c.*, (SELECT json_agg(p.*) FROM secretaria_profissionais p WHERE p.ativo = true) as profissionais FROM secretaria_config c WHERE c.id = 1`.
2. Um node Set chamado `Info` reatribui cada campo do resultado (ex.: `nome_secretaria`, `horario_funcionamento`, `formas_pagamento`) para uma referência estável.
3. O `systemMessage` do nó de agente LangChain interpola esses campos com expressões n8n do tipo *acessar o node "Info" pelo nome, pegar o item atual, ler o campo `nome_secretaria`* — repetido para cada dado que precisa aparecer no prompt (nome da secretária, nome da empresa, horário de funcionamento, endereço, formas de pagamento, convênios, duração do agendamento, preferência de áudio/texto do contato).

Como a leitura acontece a cada execução (não é lida uma vez e cacheada), **editar uma linha em `secretaria_config` muda o comportamento do agente na próxima mensagem, sem tocar no fluxo n8n** — exatamente o que o FR-34/35 do Nouvet exige. É este o padrão a seguir, não o `systemMessage` hardcoded do exemplo `clinica/`.
