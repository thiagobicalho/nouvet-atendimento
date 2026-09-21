"""Leitura dos CSVs de export do SimplesVet (`glo_pessoa`, `glo_contato`, `vet_animal`).

Parser tolerante a:

- Quebra de linha dentro de campo entre aspas (achado do
  `2026-09-15-analise-base-simplesvet.md:121`) -- resolvido pela própria stdlib: abrir
  o arquivo com ``newline=""`` (recomendação oficial do módulo `csv`) faz o `csv.reader`
  ler a linha lógica completa, mesmo que ela ocupe várias linhas físicas, sem cortar no
  primeiro `\n`.
- Linha corrompida (aspas que não fecham direito) -- vira registro de erro (`ErroLinha`)
  e é pulada, nunca aborta o import inteiro. Detectada quando o número de campos da
  linha não bate com o número de colunas do cabeçalho: uma aspa não fechada faz o
  `csv.reader` engolir a(s) linha(s) física(s) seguinte(s) dentro do mesmo campo,
  deslocando a contagem de colunas daquele registro -- o próximo registro bem formado
  volta a sincronizar normalmente (comportamento verificado empiricamente com a stdlib;
  não corrompe as linhas seguintes).

Nunca chama `telefone_normalizar()` nem reimplementa a lógica de normalização de
telefone (`AD-8`) -- este módulo só repassa o valor bruto do contato; normalização é
responsabilidade exclusiva do SQL em `db.py`.

O export em si (CSV) nunca é lido de dentro do repositório -- o caminho do diretório
vem de variável de ambiente (`SIMPLESVET_EXPORT_DIR`, ver `main.py`), fora do
versionamento (NFR-6).
"""
from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator, Optional


# Contatos "Celular" são os únicos candidatos a telefone/WhatsApp -- Email,
# Residencial, Comercial e Outros ficam fora desta story (Design Notes).
TIPO_CONTATO_CELULAR = "Celular"

# O export do SimplesVet usa a string literal "NULL" (não célula vazia) para
# representar campo ausente -- ver amostra real em
# `_bmad-output/reference/simplesvet/banco/*.csv`.
_MARCADORES_AUSENTE = {"", "NULL"}


@dataclass(frozen=True)
class ErroLinha:
    """Uma linha do CSV que não pôde ser interpretada -- logada, nunca aborta o
    import (Edge-Case Matrix: "Linha que não fecha aspas corretamente vira registro
    de erro logado; import não aborta")."""

    fonte: str
    numero_linha: int
    motivo: str


@dataclass(frozen=True)
class Tutor:
    simplesvet_codigo_pessoa: int
    nome: str


@dataclass(frozen=True)
class Contato:
    """Um contato do tipo Celular -- valor ainda bruto, como veio do CSV (sem
    normalização; ver docstring do módulo)."""

    simplesvet_codigo_pessoa: int
    valor_bruto: str


@dataclass(frozen=True)
class Pet:
    simplesvet_codigo_animal: int
    simplesvet_codigo_pessoa: int
    nome: str
    especie: Optional[str]
    raca: Optional[str]
    # Já em formato ISO (YYYY-MM-DD) no export real -- repassado como string; o cast
    # para DATE acontece no INSERT (Postgres aceita ISO 8601 nativamente).
    data_nascimento: Optional[str]


def _valor_ou_none(valor: Optional[str]) -> Optional[str]:
    """Campo ausente (célula vazia ou literal "NULL") vira `None` -- grava NULL e o
    registro segue utilizável, nunca é descartado por dado faltando (Always)."""
    if valor is None:
        return None
    valor = valor.strip()
    return None if valor in _MARCADORES_AUSENTE else valor


def _linhas(caminho: Path) -> Iterator[tuple[int, Optional[dict], Optional[ErroLinha]]]:
    """Itera as linhas lógicas de um CSV, devolvendo `(numero_linha, linha, erro)` --
    exatamente um dos dois últimos elementos é `None`.

    `numero_linha` conta registros lógicos a partir de 2 (linha 1 = cabeçalho) -- uma
    linha lógica corrompida pode ter consumido mais de uma linha física (ver docstring
    do módulo), então este número é a posição do registro na sequência, não
    necessariamente o número da linha física no arquivo.
    """
    with caminho.open("r", newline="", encoding="utf-8") as arquivo:
        leitor = csv.reader(arquivo)
        cabecalho = next(leitor)
        total_colunas = len(cabecalho)
        for numero_linha, linha in enumerate(leitor, start=2):
            if not linha:
                continue
            if len(linha) != total_colunas:
                yield (
                    numero_linha,
                    None,
                    ErroLinha(
                        fonte=caminho.name,
                        numero_linha=numero_linha,
                        motivo=(
                            f"linha com {len(linha)} colunas, esperado {total_colunas} "
                            "-- provável aspas não fechadas corretamente"
                        ),
                    ),
                )
                continue
            yield numero_linha, dict(zip(cabecalho, linha)), None


def _int_ou_erro(
    valor: Optional[str], *, fonte: str, numero_linha: int, campo: str
) -> "tuple[Optional[int], Optional[ErroLinha]]":
    """Converte código do SimplesVet para `int`; um valor não numérico vira `ErroLinha`
    em vez de deixar `ValueError` subir e abortar o import inteiro -- mesma garantia da
    linha com aspas não fechadas (Always: "linha corrompida... nunca aborta o import
    inteiro"). Não observado no export real (todo `pes_int_codigo`/`ani_int_codigo`
    verificado é numérico), mas o parser não pode depender dessa premissa silenciosamente."""
    try:
        return int(valor), None  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None, ErroLinha(
            fonte=fonte,
            numero_linha=numero_linha,
            motivo=f"{campo}={valor!r} não é um código numérico -- registro descartado",
        )


def ler_tutores(caminho: Path) -> tuple[list[Tutor], list[ErroLinha]]:
    """Lê `glo_pessoa.csv` -- um tutor por `pes_int_codigo`."""
    tutores: list[Tutor] = []
    erros: list[ErroLinha] = []
    for numero_linha, linha, erro in _linhas(caminho):
        if erro is not None:
            erros.append(erro)
            continue
        codigo_bruto = _valor_ou_none(linha["pes_int_codigo"])
        nome = _valor_ou_none(linha["pes_var_nome"])
        if codigo_bruto is None or nome is None:
            erros.append(
                ErroLinha(
                    fonte=caminho.name,
                    numero_linha=numero_linha,
                    motivo="pes_int_codigo ou pes_var_nome ausente -- registro descartado",
                )
            )
            continue
        codigo, erro_codigo = _int_ou_erro(
            codigo_bruto, fonte=caminho.name, numero_linha=numero_linha, campo="pes_int_codigo"
        )
        if erro_codigo is not None:
            erros.append(erro_codigo)
            continue
        tutores.append(Tutor(simplesvet_codigo_pessoa=codigo, nome=nome))
    return tutores, erros


def ler_contatos_celular(caminho: Path) -> tuple[list[Contato], list[ErroLinha]]:
    """Lê `glo_contato.csv` -- só contatos `tco_var_nome == "Celular"` (Design Notes:
    "Só Celular vira telefone"); Email/Residencial/Comercial/Outros são ignorados sem
    virar erro (não é dado corrompido, é fora de escopo)."""
    contatos: list[Contato] = []
    erros: list[ErroLinha] = []
    for numero_linha, linha, erro in _linhas(caminho):
        if erro is not None:
            erros.append(erro)
            continue
        if _valor_ou_none(linha["tco_var_nome"]) != TIPO_CONTATO_CELULAR:
            continue
        codigo_bruto = _valor_ou_none(linha["pes_int_codigo"])
        valor_bruto = _valor_ou_none(linha["con_var_contato"])
        if codigo_bruto is None or valor_bruto is None:
            erros.append(
                ErroLinha(
                    fonte=caminho.name,
                    numero_linha=numero_linha,
                    motivo="pes_int_codigo ou con_var_contato ausente -- registro descartado",
                )
            )
            continue
        codigo, erro_codigo = _int_ou_erro(
            codigo_bruto, fonte=caminho.name, numero_linha=numero_linha, campo="pes_int_codigo"
        )
        if erro_codigo is not None:
            erros.append(erro_codigo)
            continue
        contatos.append(Contato(simplesvet_codigo_pessoa=codigo, valor_bruto=valor_bruto))
    return contatos, erros


def ler_pets(caminho: Path) -> tuple[list[Pet], list[ErroLinha]]:
    """Lê `vet_animal.csv` -- um pet por `ani_int_codigo`, vinculado ao tutor via
    `pes_int_codigo`. Campo ausente (`esp_var_nome`/`rac_var_nome`/`ani_dat_nascimento`)
    grava `None` (NULL utilizável), nunca descarta o registro (Always)."""
    pets: list[Pet] = []
    erros: list[ErroLinha] = []
    for numero_linha, linha, erro in _linhas(caminho):
        if erro is not None:
            erros.append(erro)
            continue
        codigo_animal_bruto = _valor_ou_none(linha["ani_int_codigo"])
        codigo_pessoa_bruto = _valor_ou_none(linha["pes_int_codigo"])
        nome = _valor_ou_none(linha["ani_var_nome"])
        if codigo_animal_bruto is None or codigo_pessoa_bruto is None or nome is None:
            erros.append(
                ErroLinha(
                    fonte=caminho.name,
                    numero_linha=numero_linha,
                    motivo=(
                        "ani_int_codigo, pes_int_codigo ou ani_var_nome ausente -- "
                        "registro descartado"
                    ),
                )
            )
            continue
        codigo_animal, erro_animal = _int_ou_erro(
            codigo_animal_bruto, fonte=caminho.name, numero_linha=numero_linha, campo="ani_int_codigo"
        )
        codigo_pessoa, erro_pessoa = _int_ou_erro(
            codigo_pessoa_bruto, fonte=caminho.name, numero_linha=numero_linha, campo="pes_int_codigo"
        )
        if erro_animal is not None or erro_pessoa is not None:
            erros.append(erro_animal or erro_pessoa)
            continue
        pets.append(
            Pet(
                simplesvet_codigo_animal=codigo_animal,
                simplesvet_codigo_pessoa=codigo_pessoa,
                nome=nome,
                especie=_valor_ou_none(linha["esp_var_nome"]),
                raca=_valor_ou_none(linha["rac_var_nome"]),
                data_nascimento=_valor_ou_none(linha["ani_dat_nascimento"]),
            )
        )
    return pets, erros
