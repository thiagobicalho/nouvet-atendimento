"""Importador standalone do export SimplesVet (`AD-15`) -- lê o export direto do
disco (`glo_pessoa.csv`, `glo_contato.csv`, `vet_animal.csv`) e carrega
`identidade_tutor`/`identidade_telefone`/`identidade_pet` no Postgres via
`identidade_role`. Ao final, imprime o relatório de cobertura (`NFR-9`).

Executável fora do n8n, sob demanda -- nunca como workflow/sub-workflow n8n, nunca
rotina periódica/agendada (Never). Rodar: `docker compose run --rm importer`
(ver `import/README.md`).
"""
from __future__ import annotations

import logging
import os
from pathlib import Path

import psycopg2

from . import csv_source, db
from .cobertura import calcular_cobertura

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("importador")


_ARQUIVOS_ESPERADOS = ("glo_pessoa.csv", "glo_contato.csv", "vet_animal.csv")


def _caminho_export() -> Path:
    """Caminho do export vem de variável de ambiente, nunca hardcoded nem dentro do
    repo (NFR-6: "Nenhum CSV do export... entra no versionamento"). Falha cedo e com
    mensagem clara (nunca traceback cru) se o diretório ou algum dos 3 CSVs esperados
    não existir -- honesto sobre o que falta, nunca silencioso (Review: "FileNotFoundError
    crashes with raw traceback")."""
    valor = os.environ.get("SIMPLESVET_EXPORT_DIR")
    if not valor:
        raise SystemExit(
            "SIMPLESVET_EXPORT_DIR não definida -- aponte para o diretório local (fora "
            "do repo) com glo_pessoa.csv, glo_contato.csv e vet_animal.csv."
        )
    caminho = Path(valor)
    if not caminho.is_dir():
        raise SystemExit(f"SIMPLESVET_EXPORT_DIR={caminho} não é um diretório existente.")
    faltando = [nome for nome in _ARQUIVOS_ESPERADOS if not (caminho / nome).is_file()]
    if faltando:
        raise SystemExit(
            f"SIMPLESVET_EXPORT_DIR={caminho} não contém: {', '.join(faltando)}."
        )
    return caminho


def _logar_erros(erros: list[csv_source.ErroLinha]) -> None:
    for erro in erros:
        logger.warning("linha ignorada -- %s:%s -- %s", erro.fonte, erro.numero_linha, erro.motivo)


def importar(export_dir: Path, conexao) -> dict:
    """Orquestra leitura + carga; devolve o relatório de cobertura (`calcular_cobertura`).
    Uma única transação -- se algo falhar no meio, nada fica gravado pela metade."""
    tutores, erros_tutor = csv_source.ler_tutores(export_dir / "glo_pessoa.csv")
    contatos, erros_contato = csv_source.ler_contatos_celular(export_dir / "glo_contato.csv")
    pets, erros_pet = csv_source.ler_pets(export_dir / "vet_animal.csv")
    erros = [*erros_tutor, *erros_contato, *erros_pet]
    _logar_erros(erros)

    logger.info(
        "lidos do export: %d tutores, %d contatos Celular, %d pets",
        len(tutores),
        len(contatos),
        len(pets),
    )

    tutor_id_por_codigo: dict[int, int] = {}
    telefones_gravados = 0
    telefones_nao_normalizaveis = 0
    contatos_sem_tutor = 0
    pets_gravados = 0
    pets_sem_tutor = 0

    try:
        with conexao.cursor() as cur:
            for tutor in tutores:
                tutor_id_por_codigo[tutor.simplesvet_codigo_pessoa] = db.upsert_tutor(cur, tutor)

            for contato in contatos:
                tutor_id = tutor_id_por_codigo.get(contato.simplesvet_codigo_pessoa)
                if tutor_id is None:
                    contatos_sem_tutor += 1
                    logger.warning(
                        "contato sem tutor correspondente -- pes_int_codigo=%s",
                        contato.simplesvet_codigo_pessoa,
                    )
                    continue
                if db.upsert_telefone(cur, tutor_id, contato.valor_bruto):
                    telefones_gravados += 1
                else:
                    telefones_nao_normalizaveis += 1

            for pet in pets:
                tutor_id = tutor_id_por_codigo.get(pet.simplesvet_codigo_pessoa)
                if tutor_id is None:
                    pets_sem_tutor += 1
                    logger.warning(
                        "pet sem tutor correspondente -- pes_int_codigo=%s (ani_int_codigo=%s)",
                        pet.simplesvet_codigo_pessoa,
                        pet.simplesvet_codigo_animal,
                    )
                    continue
                db.upsert_pet(cur, pet, tutor_id)
                pets_gravados += 1
    except Exception:
        # Uma única transação: se algo falhar no meio, desfaz tudo -- nunca deixa
        # gravado pela metade (docstring desta função). `rollback()` explícito (em vez
        # de confiar só no fechamento da conexão) mais uma mensagem clara em vez de
        # deixar só o traceback cru subir (Review: "never fail silently" também vale
        # para uma ferramenta de operador, não só para o agente).
        conexao.rollback()
        logger.error("import abortado, nada foi gravado -- ver traceback acima")
        raise

    conexao.commit()

    if pets_sem_tutor:
        logger.warning("%d pet(s) não gravados por falta de tutor correspondente", pets_sem_tutor)

    return calcular_cobertura(
        tutores=tutores,
        pets=pets,
        pets_gravados=pets_gravados,
        telefones_gravados=telefones_gravados,
        telefones_nao_normalizaveis=telefones_nao_normalizaveis,
        contatos_sem_tutor=contatos_sem_tutor,
        pets_sem_tutor=pets_sem_tutor,
        linhas_descartadas=len(erros),
    )


def main() -> None:
    export_dir = _caminho_export()
    try:
        conexao = db.conectar()
    except psycopg2.OperationalError as erro:
        raise SystemExit(f"não foi possível conectar no Postgres (identidade_role): {erro}")

    try:
        relatorio = importar(export_dir, conexao)
    finally:
        conexao.close()

    print("\n=== Cobertura do import ===")
    for linha in relatorio["linhas"]:
        print(linha)


if __name__ == "__main__":
    main()
