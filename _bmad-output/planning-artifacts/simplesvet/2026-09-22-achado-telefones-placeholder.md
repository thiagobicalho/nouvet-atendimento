# Achado — telefones placeholder no cadastro do SimplesVet

Levantado ao rodar o importador (Story 1.1) contra o export real, em 22/09/2026. Não é defeito do importador — é dado do próprio SimplesVet, e precisa ir para o Nouvet decidir.

## O que apareceu

10 telefones estão ligados a mais de um tutor distinto na base — o `AD-32` (autorização por tutor, não por telefone) já trata isso corretamente, tratando o telefone como não autorizado até se resolver. Mas dois desses casos não são ambiguidade real:

| Telefone | Tutores distintos ligados | Provável causa |
|---|---|---|
| `+5511999999999` | 6 | Valor "todo 9" — placeholder típico de sistema quando ninguém capturou o telefone real |
| `+5599999999999` | 4 | Mesmo padrão |

Os outros 8 telefones ambíguos (2–3 tutores cada) parecem ser casos reais — famílias com mais de um telefone cadastrado, exatamente o cenário que a `AD-32`/FR-17a foram desenhados para proteger. Esses não entram nesta recomendação.

## Recomendação (Thiago, 22/09)

**Não manter esses dois números.** Foram claramente cadastrados de forma errada no SimplesVet — não representam telefone real de nenhum dos 6 (ou 4) tutores ligados a eles. Levar ao Nouvet como pergunta: confirmar que são erro de cadastro e, se sim, decidir se a Btech filtra esses valores no importador (lista de exclusão) ou se o Nouvet corrige na origem.

## Efeito prático enquanto isso não é decidido

Nenhum. O `AD-32` já impede qualquer ação sobre agendamento quando o telefone resolve para mais de um tutor — então esses dois números placeholder já ficam automaticamente bloqueados para cancelamento/remarcação, mesmo sem limpeza. O risco não é de segurança, é de **um cliente real que por acaso tenha um desses números mal cadastrados esbarrar num "não autorizado" sem entender por quê** — impacto de experiência, não de dado exposto.
