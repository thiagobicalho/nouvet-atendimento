#!/usr/bin/env python3
"""Verifica a correspondência entre os telefones hardcoded em
`identidade_bancada.sql` e os telefones que `bancada-teste/rodar.py` calcula, em
tempo de execução, a partir do campo `nome:` dos casos que dependem deste fixture
(Story 1.5, `AD-32`).

Por quê este script existe: `identidade_bancada.sql` grava telefones literais
(`00943675484`, `00981800970`, `00964790533`) para casar com o telefone sintético que
`rodar.py` (`gerar_identidade_sintetica`) deriva do `nome:` de cada `.yaml` em
`casos/`. Essa correspondência não é verificada por nenhum outro ponto -- se o
algoritmo de hash de `gerar_identidade_sintetica` mudar, ou se o `nome:` de um desses
casos for editado sem atualizar o fixture, os casos 2-4 silenciosamente deixam de
exercitar os caminhos `reconhecido`/`nao_autorizado`: eles caem de volta para
`identidade_status=novo`, que já é um resultado "aceitável" quando o fixture não foi
aplicado (ver comentário em cada `.yaml`) -- então nem a leitura humana do transcrito
pegaria a regressão. Este script é o único lugar que garante isso.

Stdlib puro (mesmo padrão de `rodar.py`) -- nenhuma dependência externa. Roda sob
demanda, nunca automaticamente; falha com saída não-zero e mensagem clara em caso de
divergência.
"""
from __future__ import annotations

import importlib.util
import re
import sys
from pathlib import Path

RAIZ_FIXTURES = Path(__file__).resolve().parent
RAIZ_BANCADA = RAIZ_FIXTURES.parent
CAMINHO_FIXTURE_SQL = RAIZ_FIXTURES / "identidade_bancada.sql"
CAMINHO_RODAR_PY = RAIZ_BANCADA / "rodar.py"
DIR_CASOS = RAIZ_BANCADA / "casos"

# Casos que o fixture precisa cobrir -- os únicos 3 cujo telefone sintético tem
# entrada esperada em `identidade_bancada.sql` (casos 5/6 usam telefone sintético sem
# fixture, de propósito -- ver os próprios `.yaml`).
ARQUIVOS_DE_CASO_ESPERADOS = [
    "2-cliente-reconhecido-um-pet.yaml",
    "3-cliente-reconhecido-varios-pets.yaml",
    "4-numero-ambiguo.yaml",
]


def _carregar_rodar_py():
    """Importa `rodar.py` como módulo, sem depender de `bancada-teste` ser um
    pacote Python instalável -- mesma técnica de carregamento dinâmico usada por
    qualquer outro script standalone deste diretório. Seguro: `rodar.py` só executa
    `main()` sob `if __name__ == "__main__"`, nunca na importação.
    """
    spec = importlib.util.spec_from_file_location("rodar", CAMINHO_RODAR_PY)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"não foi possível carregar {CAMINHO_RODAR_PY}")
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


def _telefones_literais_no_fixture(texto_sql: str) -> set[str]:
    """Todo literal passado para `telefone_normalizar(...)` em `identidade_bancada.sql`
    -- é assim que o fixture referencia telefone, nunca gravando o valor já
    normalizado à mão (ver comentário do próprio `.sql`).
    """
    return set(re.findall(r"telefone_normalizar\('(\d+)'\)", texto_sql))


def main() -> int:
    if not CAMINHO_FIXTURE_SQL.exists():
        print(f"Fixture não encontrado: {CAMINHO_FIXTURE_SQL}", file=sys.stderr)
        return 1
    if not CAMINHO_RODAR_PY.exists():
        print(f"rodar.py não encontrado: {CAMINHO_RODAR_PY}", file=sys.stderr)
        return 1

    rodar = _carregar_rodar_py()
    texto_sql = CAMINHO_FIXTURE_SQL.read_text(encoding="utf-8")
    telefones_no_fixture = _telefones_literais_no_fixture(texto_sql)

    divergencias: list[str] = []
    for nome_arquivo in ARQUIVOS_DE_CASO_ESPERADOS:
        caminho_caso = DIR_CASOS / nome_arquivo
        if not caminho_caso.exists():
            divergencias.append(f"caso esperado não encontrado: {caminho_caso}")
            continue

        caso = rodar.carregar_caso(caminho_caso)
        nome_caso = caso.get("nome") or caminho_caso.stem
        telefone_calculado, _ = rodar.gerar_identidade_sintetica(nome_caso)

        if telefone_calculado not in telefones_no_fixture:
            divergencias.append(
                f"{nome_arquivo}: nome de caso {nome_caso!r} calcula o telefone "
                f"{telefone_calculado!r} (via rodar.gerar_identidade_sintetica), mas "
                f"esse literal não aparece em nenhum telefone_normalizar(...) de "
                f"{CAMINHO_FIXTURE_SQL.name} -- fixture e caso divergiram."
            )

    if divergencias:
        print(
            "Correspondência fixture <-> casos quebrada -- atualize "
            f"{CAMINHO_FIXTURE_SQL.name} ou o `nome:` do(s) caso(s) abaixo antes de "
            "rodar a bancada (os casos 2-4 deixariam de exercitar "
            "reconhecido/nao_autorizado e cairiam silenciosamente em 'novo'):",
            file=sys.stderr,
        )
        for divergencia in divergencias:
            print(f"  - {divergencia}", file=sys.stderr)
        return 1

    print(
        "OK -- todos os telefones calculados por rodar.gerar_identidade_sintetica() "
        f"para {', '.join(ARQUIVOS_DE_CASO_ESPERADOS)} aparecem em "
        f"{CAMINHO_FIXTURE_SQL.name}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
