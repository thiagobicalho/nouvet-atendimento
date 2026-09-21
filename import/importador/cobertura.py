"""Cálculo do relatório de cobertura do import (NFR-9: "Cobertura é sempre número
absoluto + fração da base, nunca percentual isolado").

Função pura, sem I/O e sem dependência de Postgres -- recebe os dados já lidos pelo
`csv_source` e os contadores calculados durante a carga (`main.py`), devolve linhas de
texto prontas para impressão. Testável em isolamento (`tests/test_cobertura.py`).
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence


@dataclass(frozen=True)
class Cobertura:
    """Um item de cobertura: sempre absoluto + fração, nunca percentual isolado."""

    campo: str
    preenchidos: int
    total: int

    @property
    def fracao(self) -> str:
        return f"{self.preenchidos}/{self.total}"

    def __str__(self) -> str:
        return f"{self.campo}: {self.preenchidos} de {self.total} ({self.fracao})"


def calcular_cobertura(
    *,
    tutores: Sequence,
    pets: Sequence,
    pets_gravados: int,
    telefones_gravados: int,
    telefones_nao_normalizaveis: int,
    contatos_sem_tutor: int = 0,
    pets_sem_tutor: int = 0,
    linhas_descartadas: int = 0,
) -> dict:
    """`tutores`/`pets` são sequências de `csv_source.Tutor`/`csv_source.Pet` (ou
    qualquer objeto com os mesmos atributos, usado pelos testes de unidade) -- só
    usadas aqui para os campos de preenchimento do pet (espécie/raça/nascimento), nunca
    como proxy de "quantos foram de fato gravados" (Review: "pets importados" não pode
    ser sempre 100% quando alguns são descartados por falta de tutor correspondente).

    `pets_gravados` é o número que de fato chegou a `db.upsert_pet` -- pode ser menor
    que `len(pets)` quando `pet.simplesvet_codigo_pessoa` não bate com nenhum tutor
    carregado (`pets_sem_tutor`). `telefones_gravados`/`telefones_nao_normalizaveis`
    vêm de `main.py`, que já sabe quantos contatos Celular resultaram em vínculo
    gravado vs. telefone não normalizável (Edge-Case Matrix); `contatos_sem_tutor`
    soma ao denominador para que a fração não exclua silenciosamente contato órfão
    (mesma classe de problema do `pets_gravados`).
    """
    total_tutores = len(tutores)
    total_pets = len(pets)
    total_contatos_celular = telefones_gravados + telefones_nao_normalizaveis + contatos_sem_tutor

    pets_com_especie = sum(1 for p in pets if p.especie is not None)
    pets_com_raca = sum(1 for p in pets if p.raca is not None)
    pets_com_nascimento = sum(1 for p in pets if p.data_nascimento is not None)

    itens = [
        Cobertura("tutores importados", total_tutores, total_tutores),
        Cobertura("telefones válidos gravados", telefones_gravados, total_contatos_celular),
        # Absoluto contra o total lido do CSV, nunca contra si mesmo -- "pets
        # importados" reflete quantos de fato chegaram ao banco (`pets_gravados`),
        # não quantos foram meramente lidos (`total_pets`); quando `pets_sem_tutor` > 0
        # a fração fica < 1, honesta sobre o que foi descartado (NFR-9).
        Cobertura("pets importados", pets_gravados, total_pets),
        Cobertura("pets com espécie", pets_com_especie, total_pets),
        Cobertura("pets com raça", pets_com_raca, total_pets),
        Cobertura("pets com data de nascimento", pets_com_nascimento, total_pets),
    ]
    # "descartados" soma linhas que nunca viraram Tutor/Pet/Contato (linha corrompida,
    # ErroLinha) com as que foram lidas mas não gravadas por falta de tutor
    # correspondente (pets_sem_tutor/contatos_sem_tutor); estas últimas já estão
    # contadas dentro de total_pets/total_contatos_celular acima, então a base do
    # denominador soma tutores + pets + contatos processados + linhas corrompidas, sem
    # contar nada duas vezes.
    registros_descartados = pets_sem_tutor + contatos_sem_tutor + linhas_descartadas
    if registros_descartados:
        base_processada = total_tutores + total_pets + total_contatos_celular + linhas_descartadas
        itens.append(
            Cobertura(
                "registros descartados (linha corrompida ou sem tutor correspondente)",
                registros_descartados,
                base_processada,
            )
        )
    return {"itens": itens, "linhas": [str(item) for item in itens]}
