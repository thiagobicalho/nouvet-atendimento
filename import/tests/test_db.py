"""Testes de unidade do módulo `db` -- sem Postgres real (ambiente sem Docker/psql,
ver spec Design Notes "Verificação limitada ao alcance deste ambiente"). Usa um cursor
falso (`FakeCursor`) que só grava o SQL/params executados, sem conexão nenhuma --
verifica a *construção* das queries (a garantia real de "nunca sobrescrever coluna
futura" é a allowlist explícita no `SET`, não algo que dependa de Postgres estar de
pé), não a semântica de Postgres em si (`ON CONFLICT`, `UNIQUE`, `telefone_normalizar`
de verdade) -- essa parte segue pendente de verificação do operador contra Postgres
real (Review: "db.py tem zero cobertura de teste")."""
from __future__ import annotations

import re

from importador import csv_source, db


class FakeCursor:
    """Cursor falso -- grava cada `execute()` e devolve os `fetchone()` na ordem
    fornecida. Não conecta em nada; existe só para os testes deste arquivo."""

    def __init__(self, respostas_fetchone):
        self.execucoes: list[tuple[str, dict]] = []
        self._respostas = iter(respostas_fetchone)

    def execute(self, sql, params=None):
        self.execucoes.append((sql, params))

    def fetchone(self):
        return next(self._respostas)


def _colunas_do_set(sql: str) -> set[str]:
    """Extrai os nomes de coluna do trecho `SET ... RETURNING`/fim de um UPSERT --
    usado para confirmar que só as colunas que esta story cria aparecem ali (Design
    Notes: "Upsert por código de origem, allowlist de colunas")."""
    trecho_set = re.search(r"DO UPDATE\s+SET(.*?)(RETURNING|$)", sql, re.DOTALL)
    assert trecho_set is not None, "UPSERT sem cláusula SET -- SQL mudou de forma inesperada"
    return {
        atribuicao.split("=", 1)[0].strip()
        for atribuicao in trecho_set.group(1).split(",")
        if atribuicao.strip()
    }


def test_upsert_tutor_set_so_referencia_colunas_desta_story():
    """`SET` de `upsert_tutor` nunca referencia coluna futura (preferência, autorização
    de mensagem, estado de migração) -- é o mecanismo real que protege re-execução do
    import contra sobrescrever campo de domínio próprio (Always)."""
    cur = FakeCursor(respostas_fetchone=[(42,)])
    tutor = csv_source.Tutor(simplesvet_codigo_pessoa=1, nome="Ana Fictícia")

    tutor_id = db.upsert_tutor(cur, tutor)

    assert tutor_id == 42
    assert len(cur.execucoes) == 1
    sql, params = cur.execucoes[0]
    assert _colunas_do_set(sql) == {"nome", "updated_at"}
    assert params["origem"] == db.ORIGEM_IMPORT_SIMPLESVET


def test_upsert_pet_set_so_referencia_colunas_desta_story():
    cur = FakeCursor(respostas_fetchone=[(7,)])
    pet = csv_source.Pet(
        simplesvet_codigo_animal=100,
        simplesvet_codigo_pessoa=1,
        nome="Rex",
        especie="Canina",
        raca="SRD",
        data_nascimento="2020-01-01",
    )

    pet_id = db.upsert_pet(cur, pet, tutor_id=42)

    assert pet_id == 7
    sql, params = cur.execucoes[0]
    assert _colunas_do_set(sql) == {
        "tutor_id",
        "nome",
        "especie",
        "raca",
        "data_nascimento",
        "updated_at",
    }
    assert params["tutor_id"] == 42


def test_upsert_telefone_nao_normalizavel_nao_insere():
    """Quando `telefone_normalizar()` (simulado via `fetchone` -> `(False,)`) diz que o
    valor não é normalizável, nenhum INSERT é emitido -- só a checagem (Edge-Case
    Matrix: "Vínculo de telefone não é gravado; tutor/pet seguem gravados")."""
    cur = FakeCursor(respostas_fetchone=[(False,)])

    gravado = db.upsert_telefone(cur, tutor_id=42, telefone_bruto="abc-nao-e-telefone")

    assert gravado is False
    assert len(cur.execucoes) == 1
    sql, _params = cur.execucoes[0]
    assert "telefone_normalizar" in sql
    assert "INSERT" not in sql


def test_upsert_telefone_normalizavel_insere_via_telefone_normalizar_no_sql():
    """Telefone normalizável grava via `telefone_normalizar()` chamado dentro do SQL --
    nunca normalizado em Python (AD-8) -- com `ON CONFLICT (tutor_id, telefone) DO
    NOTHING`, nunca deduplicado por telefone isolado entre tutores diferentes (Always)."""
    cur = FakeCursor(respostas_fetchone=[(True,)])

    gravado = db.upsert_telefone(cur, tutor_id=42, telefone_bruto="(11) 98268-8240")

    assert gravado is True
    assert len(cur.execucoes) == 2
    sql_insert, params_insert = cur.execucoes[1]
    assert "telefone_normalizar(%(bruto)s)" in sql_insert
    assert "ON CONFLICT (tutor_id, telefone) DO NOTHING" in sql_insert
    assert params_insert["tutor_id"] == 42
    assert params_insert["origem"] == db.ORIGEM_IMPORT_SIMPLESVET
