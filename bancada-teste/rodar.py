#!/usr/bin/env python3
"""Bancada de teste standalone (Story 1.4, AD-20).

Dispara, turno a turno, os casos de `casos/*.yaml` contra a segunda porta do agente
(`n8n/workflows/08 - Entrada de Teste.json`, webhook síncrono `responseMode:
responseNode`) e grava um transcrito por caso em `transcritos/`, para leitura humana.
Nunca decide sozinho se um caso passou ou falhou -- o veredito é sempre humano, lendo
o transcrito (ver README.md desta pasta).

Stdlib puro, sem framework nem dependência externa -- inclusive o parser de
`casos/*.yaml` abaixo é um parser mínimo, específico do formato restrito usado neste
diretório (chave: valor escalar + uma lista `turnos:`), não um parser YAML genérico.

Nunca chama RD Conversas/Tallos/Meta nem qualquer API de mensageria -- a única
chamada de rede que este programa faz é para a URL da entrada de teste (local, dentro
da rede compose).
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
DIR_CASOS = RAIZ / "casos"
DIR_TRANSCRITOS = RAIZ / "transcritos"

# URL padrão dentro da rede compose (docker-compose.yml) -- o workflow `08` precisa
# estar importado e ativo na instância n8n para responder em `/webhook/...`; rodando
# fora do compose (ou testando manualmente antes de ativar), sobrescreva com
# BANCADA_TESTE_URL apontando para `/webhook-test/...`.
URL_PADRAO = "http://n8n:5678/webhook/atendimento-nouvet-teste"


def _valor_escalar(texto: str) -> str:
    """Remove aspas simples/duplas ao redor de um valor escalar `chave: valor`."""
    texto = texto.strip()
    if len(texto) >= 2 and texto[0] == texto[-1] and texto[0] in ('"', "'"):
        return texto[1:-1]
    return texto


def carregar_caso(caminho: Path) -> dict:
    """Parser mínimo e específico do formato de `casos/*.yaml` -- não é um parser YAML
    genérico. Suporta só:

      - linhas `chave: valor escalar` (opcionalmente entre aspas simples/duplas);
      - uma lista de escalares sob a chave de nível raiz `turnos:`, um item por linha
        `  - "valor"`;
      - linhas em branco e comentários de linha inteira (`# ...`) são ignorados.

    Qualquer coisa fora desse subconjunto (mapas aninhados, âncoras, blocos `|`/`>`,
    etc.) não é suportada -- suficiente para o formato usado nesta bancada.
    """
    dados: dict = {"turnos": []}
    em_lista_turnos = False
    for linha_bruta in caminho.read_text(encoding="utf-8").splitlines():
        linha = linha_bruta.strip()
        if not linha or linha.startswith("#"):
            continue
        if linha == "turnos:":
            em_lista_turnos = True
            continue
        if em_lista_turnos and linha.startswith("- "):
            dados["turnos"].append(_valor_escalar(linha[2:]))
            continue
        # Qualquer outra linha de nível raiz encerra a lista de turnos.
        em_lista_turnos = False
        if ":" in linha:
            chave, _, valor = linha.partition(":")
            dados[chave.strip()] = _valor_escalar(valor)
    return dados


def gerar_identidade_sintetica(nome_caso: str) -> tuple[str, str]:
    """Telefone/contact_id sintéticos, isolados por caso, DDD ``00`` (inexistente no
    Brasil -- ver "Design Notes" do spec desta story). ``telefone_normalizar``
    (migration 0006) só valida contagem de dígitos, não faixa de DDD real -- qualquer
    sufixo de 8 dígitos aqui normaliza com sucesso sem jamais colidir com um telefone
    real de cliente. Determinístico por nome de caso (nunca por acaso, nunca
    reaproveitado entre casos diferentes).
    """
    digest = hashlib.sha256(f"bancada-teste::{nome_caso}".encode("utf-8")).hexdigest()
    apenas_digitos = "".join(c for c in digest if c.isdigit())
    sufixo = (apenas_digitos + "00000000")[:8]
    # DDD "00" (2 dígitos) + 9º dígito móvel fixo "9" (1 dígito) + sufixo (8 dígitos)
    # = 11 dígitos locais -- formato que telefone_normalizar aceita sem alteração.
    telefone = f"009{sufixo}"
    contact_id = f"bancada-teste-{sufixo}"
    return telefone, contact_id


def chamar_entrada_de_teste(url: str, contact_id: str, telefone: str, mensagem: str) -> str:
    """Uma chamada HTTP síncrona à segunda porta (`08 - Entrada de Teste.json`). Nunca
    chama RD Conversas/Tallos/Meta -- só esta URL local. Se a chamada falhar (agente
    ou n8n indisponível), devolve uma nota honesta em vez de derrubar o script -- a
    execução do caso não trava, e o runner segue pro próximo turno.
    """
    corpo = json.dumps(
        {"contact_id": contact_id, "telefone": telefone, "mensagem_agregada": mensagem}
    ).encode("utf-8")
    requisicao = urllib.request.Request(
        url,
        data=corpo,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(requisicao, timeout=120) as resposta:
            payload = json.loads(resposta.read().decode("utf-8"))
    except urllib.error.HTTPError as erro:
        return f"[FALHA AO CHAMAR A ENTRADA DE TESTE: HTTP {erro.code} -- {erro.reason}]"
    except (urllib.error.URLError, TimeoutError, OSError) as erro:
        return f"[FALHA AO CHAMAR A ENTRADA DE TESTE: {erro}]"
    except json.JSONDecodeError as erro:
        return f"[RESPOSTA NÃO ERA JSON VÁLIDO: {erro}]"

    if not isinstance(payload, dict) or "output" not in payload:
        return f"[RESPOSTA SEM CAMPO 'output': {payload!r}]"
    if payload["output"] is None:
        return "[RESPOSTA COM CAMPO 'output' VAZIO]"
    return str(payload["output"])


def montar_transcrito(
    nome_caso: str,
    descricao: str,
    telefone: str,
    contact_id: str,
    turnos: list[tuple[str, str]],
) -> str:
    linhas = [
        f"# Caso: {nome_caso}",
        "",
        f"- Descrição: {descricao}",
        f"- Telefone sintético (DDD 00, nunca real): {telefone}",
        f"- contact_id sintético: {contact_id}",
        f"- Executado em (UTC): {datetime.now(timezone.utc).isoformat()}",
        "",
        "Veredito passou/não passou é sempre humano, lendo os turnos abaixo -- este "
        "runner nunca calcula um agregado verde/vermelho.",
        "",
    ]
    for indice, (fala_cliente, resposta_nouvi) in enumerate(turnos, start=1):
        linhas.extend(
            [
                f"## Turno {indice}",
                "",
                f"**Cliente:** {fala_cliente}",
                "",
                f"**Nouvi:** {resposta_nouvi}",
                "",
            ]
        )
    return "\n".join(linhas)


def rodar_caso(caminho_caso: Path, url: str) -> Path:
    caso = carregar_caso(caminho_caso)
    nome_caso = caso.get("nome") or caminho_caso.stem
    descricao = caso.get("descricao", "")
    falas = caso.get("turnos", [])
    telefone, contact_id = gerar_identidade_sintetica(nome_caso)

    turnos_executados: list[tuple[str, str]] = []
    for fala in falas:
        resposta = chamar_entrada_de_teste(url, contact_id, telefone, fala)
        turnos_executados.append((fala, resposta))

    transcrito = montar_transcrito(nome_caso, descricao, telefone, contact_id, turnos_executados)
    DIR_TRANSCRITOS.mkdir(parents=True, exist_ok=True)
    carimbo = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    caminho_saida = DIR_TRANSCRITOS / f"{carimbo}-{caminho_caso.stem}.md"
    caminho_saida.write_text(transcrito, encoding="utf-8")
    return caminho_saida


def _nome_declarado(caminho_caso: Path) -> str | None:
    """Só o nome (ou stem, na ausência de `nome:`) que `caminho_caso` declararia, para
    a checagem de duplicidade abaixo -- roda antes de qualquer caso ser executado, então
    um caso ilegível aqui não é reportado nesta função (isso acontece de novo, e é
    tratado, no loop de execução em `main()`); aqui ele só é ignorado da checagem de
    duplicidade, para não travar a checagem inteira por causa de um arquivo ruim.
    """
    try:
        caso = carregar_caso(caminho_caso)
    except Exception:
        return None
    return caso.get("nome") or caminho_caso.stem


def _checar_nomes_duplicados(casos: list[Path]) -> dict[str, list[Path]]:
    """Mapeia nome de caso -> arquivos que o declaram, só para nomes que aparecem em
    mais de um arquivo. Nunca deixa dois casos compartilharem telefone/contact_id
    sintético (gerado a partir do nome, `gerar_identidade_sintetica`) em silêncio.
    """
    arquivos_por_nome: dict[str, list[Path]] = {}
    for caminho_caso in casos:
        nome_caso = _nome_declarado(caminho_caso)
        if nome_caso is None:
            continue
        arquivos_por_nome.setdefault(nome_caso, []).append(caminho_caso)
    return {nome: arquivos for nome, arquivos in arquivos_por_nome.items() if len(arquivos) > 1}


def main() -> int:
    url = os.environ.get("BANCADA_TESTE_URL", URL_PADRAO)
    partes_url = urllib.parse.urlparse(url)
    if not partes_url.scheme or not partes_url.netloc:
        print(
            f"BANCADA_TESTE_URL inválida: {url!r} -- precisa ter esquema e host "
            "(ex.: http://n8n:5678/webhook/atendimento-nouvet-teste). "
            "Corrija a variável de ambiente antes de rodar a bancada.",
            file=sys.stderr,
        )
        return 1

    casos = sorted(DIR_CASOS.glob("*.yaml"))
    if not casos:
        print(f"Nenhum caso encontrado em {DIR_CASOS}", file=sys.stderr)
        return 1

    # Nunca roda nada se dois arquivos de caso declararem o mesmo nome (ou o mesmo
    # stem, na ausência de `nome:`) -- isso quebraria o isolamento de
    # telefone/contact_id sintético entre casos (Always da story).
    duplicados = _checar_nomes_duplicados(casos)
    if duplicados:
        print(
            "Nomes de caso duplicados -- corrija antes de rodar a bancada (dois casos "
            "nunca podem compartilhar telefone/contact_id sintético):",
            file=sys.stderr,
        )
        for nome_caso, arquivos in duplicados.items():
            lista_arquivos = ", ".join(str(arquivo) for arquivo in arquivos)
            print(f"  - {nome_caso!r} aparece em: {lista_arquivos}", file=sys.stderr)
        return 1

    for caminho_caso in casos:
        try:
            print(f"Rodando caso: {caminho_caso.name}")
            caminho_transcrito = rodar_caso(caminho_caso, url)
            print(f"  -> transcrito gravado em {caminho_transcrito}")
        except Exception as erro:
            # Um caso ruim (arquivo não-UTF-8, resposta HTTP não decodificável, etc.)
            # nunca derruba o restante da bancada -- reporta e segue pro próximo.
            print(f"  -> FALHOU ao rodar {caminho_caso.name}: {erro}", file=sys.stderr)
            continue

    print(
        "\nExecução concluída. Leia os transcritos em "
        f"{DIR_TRANSCRITOS} -- o veredito passou/não passou é sempre humano."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
