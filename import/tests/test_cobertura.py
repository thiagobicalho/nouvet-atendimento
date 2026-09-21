"""Testes de unidade do cálculo de cobertura -- contagem absoluta + fração da base
(NFR-9), nunca percentual isolado. Dados sintéticos, sem Postgres."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from importador.cobertura import Cobertura, calcular_cobertura


@dataclass(frozen=True)
class _TutorFake:
    simplesvet_codigo_pessoa: int
    nome: str


@dataclass(frozen=True)
class _PetFake:
    especie: Optional[str]
    raca: Optional[str]
    data_nascimento: Optional[str]


def test_cobertura_formata_absoluto_e_fracao_nunca_percentual_isolado():
    item = Cobertura("campo de teste", 3, 10)

    assert item.fracao == "3/10"
    texto = str(item)
    assert "3" in texto and "10" in texto
    assert "%" not in texto


def test_calcular_cobertura_conta_tutores_e_telefones():
    tutores = [_TutorFake(1, "Ana"), _TutorFake(2, "Bruno"), _TutorFake(3, "Carla")]

    relatorio = calcular_cobertura(
        tutores=tutores,
        pets=[],
        pets_gravados=0,
        telefones_gravados=4,
        telefones_nao_normalizaveis=1,
    )

    linhas = "\n".join(relatorio["linhas"])
    assert "tutores importados: 3 de 3 (3/3)" in linhas
    # 4 telefones válidos gravados de 5 contatos Celular no total (4 válidos + 1 não
    # normalizável) -- absoluto + fração, nunca percentual isolado.
    assert "telefones válidos gravados: 4 de 5 (4/5)" in linhas


def test_calcular_cobertura_conta_pets_por_campo_preenchido():
    pets = [
        _PetFake(especie="Canina", raca="SRD", data_nascimento="2020-01-01"),
        _PetFake(especie=None, raca="Vira-lata", data_nascimento=None),
        _PetFake(especie="Felina", raca=None, data_nascimento=None),
    ]

    relatorio = calcular_cobertura(
        tutores=[],
        pets=pets,
        pets_gravados=3,
        telefones_gravados=0,
        telefones_nao_normalizaveis=0,
    )

    linhas = "\n".join(relatorio["linhas"])
    assert "pets importados: 3 de 3 (3/3)" in linhas
    assert "pets com espécie: 2 de 3 (2/3)" in linhas
    assert "pets com raça: 2 de 3 (2/3)" in linhas
    assert "pets com data de nascimento: 1 de 3 (1/3)" in linhas


def test_calcular_cobertura_pets_gravados_menor_que_lidos_reflete_descarte():
    """Regression: `pets_gravados` (o que de fato chegou ao banco) pode ser menor que
    `len(pets)` (o que foi lido do CSV) quando algum pet não tem tutor correspondente --
    a linha "pets importados" tem que refletir isso, nunca ficar 100% por construção
    (Review: "pets importados... always 100%, regardless of how many were actually
    skipped")."""
    pets = [
        _PetFake(especie="Canina", raca=None, data_nascimento=None),
        _PetFake(especie=None, raca=None, data_nascimento=None),
        _PetFake(especie=None, raca=None, data_nascimento=None),
    ]

    relatorio = calcular_cobertura(
        tutores=[],
        pets=pets,
        pets_gravados=1,
        telefones_gravados=0,
        telefones_nao_normalizaveis=0,
        pets_sem_tutor=2,
    )

    linhas = "\n".join(relatorio["linhas"])
    assert "pets importados: 1 de 3 (1/3)" in linhas
    assert "registros descartados (linha corrompida ou sem tutor correspondente): 2 de" in linhas


def test_calcular_cobertura_contato_sem_tutor_entra_no_denominador():
    """Regression: contato Celular sem tutor correspondente não pode desaparecer do
    denominador -- senão a fração de "telefones válidos gravados" fica artificialmente
    maior do que realmente é (Review: "silently understates/inflates apparent
    coverage")."""
    relatorio = calcular_cobertura(
        tutores=[],
        pets=[],
        pets_gravados=0,
        telefones_gravados=2,
        telefones_nao_normalizaveis=1,
        contatos_sem_tutor=1,
    )

    linhas = "\n".join(relatorio["linhas"])
    # 2 válidos de 4 no total (2 válidos + 1 não normalizável + 1 sem tutor) -- nunca
    # "2 de 3", que esconderia o contato órfão.
    assert "telefones válidos gravados: 2 de 4 (2/4)" in linhas


def test_calcular_cobertura_sem_contatos_nao_divide_por_zero():
    relatorio = calcular_cobertura(
        tutores=[],
        pets=[],
        pets_gravados=0,
        telefones_gravados=0,
        telefones_nao_normalizaveis=0,
    )

    linhas = "\n".join(relatorio["linhas"])
    assert "telefones válidos gravados: 0 de 0 (0/0)" in linhas


def test_calcular_cobertura_linhas_descartadas_aparecem_no_relatorio():
    """Linha corrompida (`ErroLinha`, contada em `linhas_descartadas`) precisa aparecer
    no relatório final, não só em logs espalhados (Review: "only surfaces as scattered
    logger.warning lines... never rolled into the final Cobertura do import
    printout")."""
    relatorio = calcular_cobertura(
        tutores=[],
        pets=[],
        pets_gravados=0,
        telefones_gravados=0,
        telefones_nao_normalizaveis=0,
        linhas_descartadas=3,
    )

    linhas = "\n".join(relatorio["linhas"])
    assert "registros descartados (linha corrompida ou sem tutor correspondente): 3 de" in linhas
