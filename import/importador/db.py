"""Conexão Postgres e UPSERTs do importador -- conecta via `identidade_role` (`AD-15`),
o mesmo papel restrito de PII criado na migration `0001`/concedido nas tabelas da
`0014` -- nunca `app_role`/`n8n_role` (`AD-3`).

Toda normalização de telefone acontece chamando `telefone_normalizar()` (função SQL da
migration `0006`) dentro das queries abaixo -- nunca reimplementada em Python (`AD-8`,
Always: "Telefone é sempre normalizado chamando a função `telefone_normalizar()` já
existente... nunca reimplementar a lógica de normalização").

Todo UPSERT enumera explicitamente só as colunas que a migration `0014` cria -- nunca
um `SET` genérico -- para que colunas futuras (preferência, autorização de mensagem,
estado de migração) fiquem automaticamente protegidas contra sobrescrita quando
existirem (Always, Design Notes: "Upsert por código de origem, allowlist de colunas").
"""
from __future__ import annotations

import os

import psycopg2

from . import csv_source

# Toda linha gravada por este importador tem esta origem -- espelha o domínio aceito
# pelo CHECK (origem IN ('import_simplesvet', 'cadastro_direto')) das 3 tabelas da 0014.
ORIGEM_IMPORT_SIMPLESVET = "import_simplesvet"


def conectar():
    """Conecta no Postgres via `identidade_role` -- host/porta/banco/senha só por
    variável de ambiente, nunca hardcoded (mesmo padrão do `.env.example` do repo)."""
    return psycopg2.connect(
        host=os.environ.get("POSTGRES_HOST", "postgres"),
        port=os.environ.get("POSTGRES_PORT", "5432"),
        dbname=os.environ["POSTGRES_APP_DB"],
        user="identidade_role",
        password=os.environ["POSTGRES_IDENTIDADE_ROLE_PASSWORD"],
    )


def upsert_tutor(cur, tutor: csv_source.Tutor) -> int:
    """UPSERT por `simplesvet_codigo_pessoa` (chave de upsert = código de origem do
    SimplesVet, nunca nome, Always). `SET` só grava `nome` -- a única coluna de
    negócio que esta story cria em `identidade_tutor` -- e `updated_at`; qualquer
    coluna futura (ex.: preferência) nunca é referenciada aqui, logo nunca é
    sobrescrita quando existir."""
    cur.execute(
        """
        INSERT INTO identidade_tutor (simplesvet_codigo_pessoa, nome, origem)
        VALUES (%(codigo)s, %(nome)s, %(origem)s)
        ON CONFLICT (simplesvet_codigo_pessoa) DO UPDATE
            SET nome = EXCLUDED.nome,
                updated_at = now()
        RETURNING id
        """,
        {
            "codigo": tutor.simplesvet_codigo_pessoa,
            "nome": tutor.nome,
            "origem": ORIGEM_IMPORT_SIMPLESVET,
        },
    )
    return cur.fetchone()[0]


def upsert_telefone(cur, tutor_id: int, telefone_bruto: str) -> bool:
    """Insere o vínculo tutor-telefone chamando `telefone_normalizar()` no próprio SQL
    (AD-8) -- nunca normaliza em Python. `WHERE telefone_normalizar(...) IS NOT NULL`
    descarta silenciosamente contato não normalizável (Edge-Case Matrix: "Vínculo de
    telefone não é gravado; tutor/pet seguem gravados"), sem lançar erro.

    `ON CONFLICT (tutor_id, telefone) DO NOTHING` -- idempotente entre execuções, e
    nunca deduplicado entre tutores diferentes: o UNIQUE é composto por
    `(tutor_id, telefone)`, não por `telefone` isolado, então o mesmo telefone em dois
    tutores grava as duas linhas (Always).

    Devolve `True` quando o vínculo foi gravado (linha nova) ou já existia com o mesmo
    par; `False` quando o telefone não era normalizável -- usado só para o relatório de
    cobertura, nunca para decidir se algo foi ou não persistido de fato além disso.
    """
    cur.execute(
        """
        SELECT telefone_normalizar(%(bruto)s) IS NOT NULL
        """,
        {"bruto": telefone_bruto},
    )
    (normalizavel,) = cur.fetchone()
    if not normalizavel:
        return False

    cur.execute(
        """
        INSERT INTO identidade_telefone (tutor_id, telefone, origem)
        VALUES (%(tutor_id)s, telefone_normalizar(%(bruto)s), %(origem)s)
        ON CONFLICT (tutor_id, telefone) DO NOTHING
        """,
        {"tutor_id": tutor_id, "bruto": telefone_bruto, "origem": ORIGEM_IMPORT_SIMPLESVET},
    )
    return True


def upsert_pet(cur, pet: csv_source.Pet, tutor_id: int) -> int:
    """UPSERT por `simplesvet_codigo_animal`. `SET` enumera só `tutor_id`, `nome`,
    `especie`, `raca`, `data_nascimento` -- as colunas de negócio que esta story cria em
    `identidade_pet` (Design Notes) -- e `updated_at`; nunca um `SET` genérico, para que
    colunas futuras (preferência, estado de migração) nunca sejam sobrescritas por esta
    função quando existirem.

    `tutor_id` está no `SET` de propósito: se o SimplesVet corrigir o dono de um animal
    (`vet_animal.pes_int_codigo` mudou desde a última carga), re-rodar o import deve
    refletir essa correção -- é a mesma filosofia de "derivar uma vez, ser dono" (AD-15)
    aplicada a um campo que o próprio SimplesVet continua sendo dono. Nunca confundir
    com as colunas de domínio próprio (preferência etc.), que nunca entram neste `SET`."""
    cur.execute(
        """
        INSERT INTO identidade_pet
            (simplesvet_codigo_animal, tutor_id, nome, especie, raca, data_nascimento, origem)
        VALUES
            (%(codigo)s, %(tutor_id)s, %(nome)s, %(especie)s, %(raca)s, %(nascimento)s, %(origem)s)
        ON CONFLICT (simplesvet_codigo_animal) DO UPDATE
            SET tutor_id = EXCLUDED.tutor_id,
                nome = EXCLUDED.nome,
                especie = EXCLUDED.especie,
                raca = EXCLUDED.raca,
                data_nascimento = EXCLUDED.data_nascimento,
                updated_at = now()
        RETURNING id
        """,
        {
            "codigo": pet.simplesvet_codigo_animal,
            "tutor_id": tutor_id,
            "nome": pet.nome,
            "especie": pet.especie,
            "raca": pet.raca,
            "nascimento": pet.data_nascimento,
            "origem": ORIGEM_IMPORT_SIMPLESVET,
        },
    )
    return cur.fetchone()[0]
