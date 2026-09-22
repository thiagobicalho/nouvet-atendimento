# bancada-teste/

Bancada de teste adversarial standalone (Story 1.4, `AD-20`). Dispara casos de teste
turno a turno contra a segunda porta do agente (`n8n/workflows/08 - Entrada de
Teste.json`) e grava um transcrito por caso, para leitura humana -- sem gastar
mensagem real nem tocar cliente real (`NFR-10`).

Programa executável fora do n8n, sob demanda -- nunca uma rotina periódica/agendada,
mesmo padrão do `import/` (Story 1.1). `rodar.py` é stdlib puro (sem framework, sem
dependência externa): lê `casos/*.yaml`, dispara cada turno via HTTP contra a entrada
de teste e grava o resultado em `transcritos/`.

## O que esta bancada NUNCA faz

- Nunca chama RD Conversas, Tallos, Meta ou qualquer API de mensageria -- a única
  chamada de rede que `rodar.py` faz é para a URL da entrada de teste (`08`), dentro
  da rede compose.
- Nunca decide sozinha se um caso passou ou falhou. A execução é automática; o
  julgamento é sempre humano, lendo o transcrito. Não existe agregado verde/vermelho
  em nenhum lugar deste diretório.
- Nunca reaproveita um telefone/`contact_id` entre casos, nem usa telefone de cliente
  real -- todo telefone sintético usa o DDD `00` (inexistente no Brasil; ver "Por que
  DDD `00`" abaixo).

## Limitação conhecida: não exercita o envio pelo RD Station

A entrada de teste (`08 - Entrada de Teste.json`) devolve a fala da Nouvi direto no
corpo da resposta HTTP -- ela nunca passa pelo node que envia a resposta ao RD
Conversas/Tallos (`Enviar resposta RD Conversas`, presente só em
`07 - Ingresso e Fila.json`). Rodar um caso aqui confirma o que o agente **decide
responder**, nunca confirma que a integração de envio real (autenticação, formatação,
limites da API do RD) funciona. Essa parte só é validada rodando o fluxo de produção
(`07`) de ponta a ponta contra o RD Station de verdade.

## Como rodar

Com a stack de pé e `08 - Entrada de Teste.json` já importado e **ativo** na instância
n8n (importe via UI ou `n8n import:workflow --input="n8n/workflows/08 - Entrada de
Teste.json"`):

```bash
docker compose run --rm bancada-teste
```

`docker compose run` ignora `profiles` e ataca o serviço diretamente, então não é
preciso `--profile tools` -- mas o serviço nunca sobe sozinho com `docker compose up`
default (`profiles: ["tools"]` em `docker-compose.yml`).

O runner lê todo arquivo em `casos/*.yaml`, roda cada um (turno a turno, na mesma
sessão isolada) e grava um transcrito por caso em `transcritos/<carimbo>-<caso>.md`.
Ao final, imprime onde os transcritos foram gravados -- nunca um resumo passou/falhou.

### Rodando fora do compose (URL de teste do n8n)

Antes de ativar `08` na instância (ou para testar manualmente sem ativá-lo), o n8n
expõe o webhook em modo de teste (`/webhook-test/...`, só responde uma vez, com o
editor do workflow aberto e "Listen for test event" ativo). Aponte o runner para essa
URL via variável de ambiente:

```bash
BANCADA_TESTE_URL="http://n8n:5678/webhook-test/atendimento-nouvet-teste" \
  docker compose run --rm -e BANCADA_TESTE_URL bancada-teste
```

## Como ler um transcrito

Cada arquivo em `transcritos/` traz, nesta ordem: nome do caso, descrição, telefone e
`contact_id` sintéticos usados (para conferir isolamento entre casos), horário de
execução e, para cada turno, a fala do cliente e a resposta da Nouvi lado a lado.

Ler é comparar o que a Nouvi respondeu com o que o design de conversa
(`_bmad-output/planning-artifacts/design-conversa/2026-09-18-design-de-conversa-onda1.md`)
descreve para aquele caso, e decidir -- humanamente -- se aquilo é aceitável para o
estágio atual do produto. Um transcrito que diverge do texto canônico não é
necessariamente um defeito: várias capacidades (reconhecimento por telefone, catálogo,
agendamento) chegam em stories futuras, e o caso `1-banho-conhecido` documenta
explicitamente por que ele ainda não "passa" (ver comentário no próprio `.yaml`).

## Como um caso novo é acrescentado (stories futuras)

Cada caso é um arquivo `casos/<nome>.yaml` com três chaves:

```yaml
nome: <identificador do caso, usado para gerar o telefone sintético>
descricao: "<uma frase sobre o que o caso cobre>"
turnos:
  - "<primeira fala do cliente>"
  - "<segunda fala do cliente>"
```

`rodar.py` gera telefone/`contact_id` sintéticos a partir do campo `nome` -- casos
diferentes nunca colidem, e o mesmo caso sempre reproduz o mesmo telefone entre
execuções (determinístico, não aleatório), o que ajuda a comparar transcritos ao longo
do tempo. Não é necessário registrar o caso em nenhum outro lugar: `rodar.py` lê todo
arquivo `casos/*.yaml` automaticamente.

O parser de `.yaml` deste diretório é intencionalmente mínimo (chave: valor escalar +
uma lista `turnos:`, sem mapas aninhados, âncoras ou blocos `|`/`>`) -- suficiente para
o formato usado aqui, para manter `rodar.py` sem dependência de uma biblioteca YAML de
terceiros (`stdlib`, `Code Map`). Um caso adversarial futuro (bypass de autorização,
improviso de catálogo, emergência mascarada, injeção de prompt, extração de
configuração -- ver Epic 1 Context) usa exatamente o mesmo formato.

## Variáveis de ambiente

- `BANCADA_TESTE_URL` -- URL da entrada de teste. Default (dentro da rede compose):
  `http://n8n:5678/webhook/atendimento-nouvet-teste` (fixado em `docker-compose.yml`).
