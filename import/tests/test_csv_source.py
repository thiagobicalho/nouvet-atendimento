"""Testes de unidade do parser de CSV do importador. CSVs sintéticos fictícios
escritos direto nos testes -- nunca dado real (Task: "CSVs sintéticos fictícios,
nunca dado real")."""
from __future__ import annotations

import re

from importador import csv_source

CABECALHO_PESSOA = (
    '"pes_int_codigo","pes_var_nome","pes_var_chave","pes_var_sexo","pes_var_rg",'
    '"pes_var_cpf","pes_var_aniversario","pes_txt_observacao","pes_txt_tag",'
    '"end_var_cep","end_var_endereco","end_var_numero","end_var_complemento",'
    '"end_var_bairro","end_var_uf","end_var_municipio","end_var_referencia",'
    '"pes_dec_totalcompra","pes_dec_maiorcompra","pes_dat_primeiracompra",'
    '"pes_dat_ultimacompra","pes_dec_saldoaberto","pes_dec_ticketmedio",'
    '"pes_dti_atualizacao","pes_dti_inclusao"\n'
)

CABECALHO_CONTATO = (
    '"con_int_codigo","pes_int_codigo","pes_var_chave","pes_var_nome","tco_var_nome",'
    '"con_var_contato","con_var_complemento","con_var_observacao","con_var_preferencial",'
    '"con_dti_inclusao"\n'
)

CABECALHO_ANIMAL = (
    '"ani_int_codigo","ani_var_chave","pes_int_codigo","pes_var_nome","ani_var_nome",'
    '"ani_var_sexo","ani_var_esterilizacao","ani_var_morto","esp_var_nome",'
    '"esp_int_codigo","rac_int_codigo","rac_var_nome","pel_int_codigo","pel_var_nome",'
    '"ani_dat_nascimento","ani_var_pedigree","ani_var_numeropedigree","ani_var_chip",'
    '"ani_txt_tag","ani_dec_peso","ani_dat_peso","ani_var_foto","ani_dti_atualizacao",'
    '"ani_dti_inclusao"\n'
)


def _linha_pessoa(codigo="1", nome="Tutor Fictício", observacao="NULL"):
    return (
        f'"{codigo}","{nome}","999","NULL","NULL","NULL","NULL","{observacao}","NULL",'
        '"NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL",'
        '"NULL","0.00","0.00","2026-01-01 00:00:00","2026-01-01 00:00:00"\n'
    )


def _linha_contato(codigo_contato, codigo_pessoa, tipo, valor):
    return (
        f'"{codigo_contato}","{codigo_pessoa}","999","Tutor Fictício","{tipo}","{valor}",'
        '"NULL","NULL","NULL","2026-01-01 00:00:00"\n'
    )


def _linha_animal(codigo_animal, codigo_pessoa, nome, especie="NULL", raca="NULL", nascimento="NULL"):
    return (
        f'"{codigo_animal}","888","{codigo_pessoa}","Tutor Fictício","{nome}","NULL","NULL",'
        f'"Não","{especie}","NULL","NULL","{raca}","NULL","NULL","{nascimento}","NULL",'
        '"NULL","NULL","NULL","NULL","NULL","NULL","NULL","NULL"\n'
    )


# --- glo_pessoa.csv --------------------------------------------------------------


def test_ler_tutores_le_registros_bem_formados(tmp_path):
    caminho = tmp_path / "glo_pessoa.csv"
    caminho.write_text(
        CABECALHO_PESSOA + _linha_pessoa("1", "Ana Fictícia") + _linha_pessoa("2", "Bruno Fictício"),
        encoding="utf-8",
    )

    tutores, erros = csv_source.ler_tutores(caminho)

    assert erros == []
    assert [t.simplesvet_codigo_pessoa for t in tutores] == [1, 2]
    assert [t.nome for t in tutores] == ["Ana Fictícia", "Bruno Fictício"]


def test_ler_tutores_quebra_de_linha_dentro_de_campo_nao_corrompe_colunas_seguintes(tmp_path):
    """Campo entre aspas com \\n interno, mas aspas fechando corretamente -- linha
    lógica única, colunas seguintes intactas (Edge-Case Matrix: "Parser lê a linha
    lógica completa, sem corromper colunas seguintes")."""
    observacao_com_quebra = "Observação\ncom quebra de linha interna"
    conteudo = (
        CABECALHO_PESSOA
        + _linha_pessoa("1", "Ana Fictícia")
        + _linha_pessoa("2", "Bruno Fictício", observacao=observacao_com_quebra)
        + _linha_pessoa("3", "Carla Fictícia")
    )
    caminho = tmp_path / "glo_pessoa.csv"
    caminho.write_text(conteudo, encoding="utf-8")

    tutores, erros = csv_source.ler_tutores(caminho)

    assert erros == []
    assert [t.simplesvet_codigo_pessoa for t in tutores] == [1, 2, 3]
    assert [t.nome for t in tutores] == ["Ana Fictícia", "Bruno Fictício", "Carla Fictícia"]


def test_ler_tutores_linha_com_aspas_nao_fechadas_vira_erro_e_nao_aborta(tmp_path):
    """Aspas que não fecham direito fazem a linha física seguinte ser engolida dentro
    do mesmo campo, deslocando a contagem de colunas daquele registro -- vira
    ErroLinha (nunca lança exceção), e o próximo registro bem formado volta a
    sincronizar normalmente (import não aborta, achado real verificado
    empiricamente com a stdlib `csv`)."""
    linha_corrompida = (
        '"2","Tutor Corrompido","999","NULL","NULL","NULL","NULL","obs sem fechar aspas\n'
        + _linha_pessoa("3", "Carla Fictícia")
    )
    conteudo = CABECALHO_PESSOA + _linha_pessoa("1", "Ana Fictícia") + linha_corrompida + _linha_pessoa("4", "Dora Fictícia")
    caminho = tmp_path / "glo_pessoa.csv"
    caminho.write_text(conteudo, encoding="utf-8")

    tutores, erros = csv_source.ler_tutores(caminho)

    assert [t.simplesvet_codigo_pessoa for t in tutores] == [1, 4]
    assert len(erros) == 1
    assert erros[0].fonte == "glo_pessoa.csv"
    assert "colunas" in erros[0].motivo


def test_ler_tutores_campo_ausente_com_marcador_literal_null(tmp_path):
    """O export usa a string literal "NULL" (não célula vazia) para campo ausente."""
    caminho = tmp_path / "glo_pessoa.csv"
    caminho.write_text(CABECALHO_PESSOA + _linha_pessoa("1", "Ana Fictícia", observacao="NULL"), encoding="utf-8")

    tutores, erros = csv_source.ler_tutores(caminho)

    assert erros == []
    assert len(tutores) == 1


def test_ler_tutores_codigo_nao_numerico_vira_erro_e_nao_aborta(tmp_path):
    """`pes_int_codigo` não numérico não pode deixar `ValueError` subir e abortar o
    import inteiro -- vira `ErroLinha`, mesma garantia de "linha corrompida... nunca
    aborta" (não observado no export real, mas o parser não pode depender disso)."""
    conteudo = (
        CABECALHO_PESSOA
        + _linha_pessoa("1", "Ana Fictícia")
        + _linha_pessoa("12A", "Código Corrompido")
        + _linha_pessoa("3", "Carla Fictícia")
    )
    caminho = tmp_path / "glo_pessoa.csv"
    caminho.write_text(conteudo, encoding="utf-8")

    tutores, erros = csv_source.ler_tutores(caminho)

    assert [t.simplesvet_codigo_pessoa for t in tutores] == [1, 3]
    assert len(erros) == 1
    assert "não é um código numérico" in erros[0].motivo


# --- glo_contato.csv --------------------------------------------------------------


def test_ler_contatos_celular_filtra_so_tipo_celular(tmp_path):
    conteudo = (
        CABECALHO_CONTATO
        + _linha_contato("10", "1", "Celular", "(11) 98268-8240")
        + _linha_contato("11", "1", "Email", "ana@fake.example")
        + _linha_contato("12", "2", "Residencial", "(11) 3333-4444")
    )
    caminho = tmp_path / "glo_contato.csv"
    caminho.write_text(conteudo, encoding="utf-8")

    contatos, erros = csv_source.ler_contatos_celular(caminho)

    assert erros == []
    assert len(contatos) == 1
    assert contatos[0].simplesvet_codigo_pessoa == 1
    assert contatos[0].valor_bruto == "(11) 98268-8240"


def test_ler_contatos_celular_repassa_valor_bruto_sem_normalizar(tmp_path):
    """csv_source nunca chama/reimplementa telefone_normalizar (AD-8) -- só repassa o
    valor bruto do contato, mesmo quando ele não é normalizável."""
    conteudo = CABECALHO_CONTATO + _linha_contato("10", "1", "Celular", "abc-nao-e-telefone")
    caminho = tmp_path / "glo_contato.csv"
    caminho.write_text(conteudo, encoding="utf-8")

    contatos, erros = csv_source.ler_contatos_celular(caminho)

    assert erros == []
    assert contatos[0].valor_bruto == "abc-nao-e-telefone"

    # Mock local de telefone_normalizar (AD-8) -- réplica pura em Python só para este
    # teste confirmar que o valor bruto extraído seria descartado pela normalização
    # real (SQL, migration 0006); nunca usado em código de produção.
    def telefone_normalizar_mock(valor: str) -> str | None:
        digitos = re.sub(r"\D", "", valor or "")
        return digitos if len(digitos) == 11 else None

    assert telefone_normalizar_mock(contatos[0].valor_bruto) is None
    assert telefone_normalizar_mock("(11) 98268-8240") == "11982688240"


# --- vet_animal.csv --------------------------------------------------------------


def test_ler_pets_campo_ausente_grava_none_e_registro_segue_utilizavel(tmp_path):
    conteudo = (
        CABECALHO_ANIMAL
        + _linha_animal("100", "1", "Rex", especie="Canina", raca="SRD", nascimento="2020-01-01")
        + _linha_animal("101", "2", "Fantasma", especie="NULL", raca="NULL", nascimento="NULL")
    )
    caminho = tmp_path / "vet_animal.csv"
    caminho.write_text(conteudo, encoding="utf-8")

    pets, erros = csv_source.ler_pets(caminho)

    assert erros == []
    assert len(pets) == 2

    rex, fantasma = pets
    assert rex.especie == "Canina"
    assert rex.raca == "SRD"
    assert rex.data_nascimento == "2020-01-01"

    assert fantasma.nome == "Fantasma"
    assert fantasma.especie is None
    assert fantasma.raca is None
    assert fantasma.data_nascimento is None


def test_ler_pets_vincula_ao_tutor_pelo_pes_int_codigo(tmp_path):
    caminho = tmp_path / "vet_animal.csv"
    caminho.write_text(CABECALHO_ANIMAL + _linha_animal("100", "42", "Rex"), encoding="utf-8")

    pets, _erros = csv_source.ler_pets(caminho)

    assert pets[0].simplesvet_codigo_animal == 100
    assert pets[0].simplesvet_codigo_pessoa == 42
