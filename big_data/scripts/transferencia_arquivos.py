
import hashlib
import os
import re
import shlex
import subprocess
import time
from pathlib import Path

HOST = "aluno@192.168.122.11"
CHAVE_SSH = Path.home() / ".ssh" / "devops_lab"

PASTA_TRATADOS = "/opt/projeto/csvs_tratados"
PASTA_ORIGINAIS = "/opt/projeto/processados"

TIPOS_TRATADOS = (
    "jogadores", "sessoes", "partidas",
    "compras", "itens", "itens_compras"
)

TIPOS_ORIGINAIS = (
    "jogadores", "sessoes", "partidas",
    "compras", "itens", "itens_compra"
)

IDADE_MINIMA = 600


def executar_ssh(comando, timeout=120):
    resultado = subprocess.run(
        [
            "ssh", "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=10",
            "-i", str(CHAVE_SSH), HOST, comando
        ],
        capture_output=True,
        text=True,
        check=True,
        timeout=timeout
    )
    return resultado.stdout


def calcular_hash(arquivo):
    sha256 = hashlib.sha256()

    with arquivo.open("rb") as dados:
        for bloco in iter(lambda: dados.read(1024 * 1024), b""):
            sha256.update(bloco)

    return sha256.hexdigest()


def identificar_tipo(nome, lote_id, tipos, sufixo):
    for tipo in sorted(tipos, key=len, reverse=True):
        if nome.startswith(f"{lote_id}-{tipo}_") and nome.endswith(sufixo):
            return tipo

    return None


def listar_lotes(pasta, tipos, sufixo):
    comando = (
        f"find {shlex.quote(pasta)} -maxdepth 1 -type f "
        f"-name '*{sufixo}' -printf '%f\\t%s\\t%T@\\n'"
    )

    lotes = {}

    for linha in executar_ssh(comando).splitlines():
        nome, tamanho, alteracao = linha.split("\t")
        lote_id = nome.split("-", 1)[0]

        if not re.fullmatch(r"\d+", lote_id):
            continue

        tipo = identificar_tipo(nome, lote_id, tipos, sufixo)

        if tipo:
            arquivo = (nome, int(tamanho), float(alteracao))
            lotes.setdefault(lote_id, {}).setdefault(tipo, []).append(arquivo)

    return {
        lote_id: [arquivos[tipo][0] for tipo in tipos]
        for lote_id, arquivos in lotes.items()
        if set(arquivos) == set(tipos)
        and all(len(lista) == 1 for lista in arquivos.values())
    }


def lote_estavel(arquivos):
    agora = time.time()

    return all(
        tamanho > 0 and agora - alteracao >= IDADE_MINIMA
        for _, tamanho, alteracao in arquivos
    )


def hashes_remotos(pasta, arquivos):
    caminhos = [f"{pasta}/{nome}" for nome, _, _ in arquivos]

    comando = "sha256sum -- " + " ".join(
        shlex.quote(caminho) for caminho in caminhos
    )

    hashes = {}

    for linha in executar_ssh(comando, timeout=300).splitlines():
        hash_sha256, caminho = linha.split(maxsplit=1)
        hashes[Path(caminho.lstrip("*")).name] = hash_sha256

    if set(hashes) != {nome for nome, _, _ in arquivos}:
        raise RuntimeError("Lista de hashes incompleta")

    return hashes


def copia_valida(pasta, arquivos, hashes):
    for nome, tamanho, _ in arquivos:
        destino = pasta / nome

        if not destino.is_file():
            return False

        if destino.stat().st_size != tamanho:
            return False

        if calcular_hash(destino) != hashes[nome]:
            return False

    return True


def copiar_arquivo(pasta_remota, pasta_local, arquivo, hash_esperado):
    nome, tamanho, _ = arquivo
    destino = pasta_local / nome
    temporario = pasta_local / f"{nome}.baixando"

    try:
        subprocess.run(
            [
                "scp", "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=10",
                "-i", str(CHAVE_SSH),
                f"{HOST}:{pasta_remota}/{nome}",
                str(temporario)
            ],
            check=True,
            timeout=300
        )

        if temporario.stat().st_size != tamanho:
            raise RuntimeError(f"Tamanho divergente: {nome}")

        if calcular_hash(temporario) != hash_esperado:
            raise RuntimeError(f"SHA-256 divergente: {nome}")

        os.replace(temporario, destino)

    finally:
        temporario.unlink(missing_ok=True)


def garantir_copias(pasta_remota, pasta_local, arquivos, hashes):
    pasta_local.mkdir(parents=True, exist_ok=True)

    for arquivo in arquivos:
        nome, tamanho, _ = arquivo
        destino = pasta_local / nome

        if destino.is_file() and destino.stat().st_size == tamanho:
            if calcular_hash(destino) == hashes[nome]:
                continue

        copiar_arquivo(pasta_remota, pasta_local, arquivo, hashes[nome])

    if not copia_valida(pasta_local, arquivos, hashes):
        raise RuntimeError("Cópias locais não foram validadas")


def remover_verificados(pasta, arquivos, hashes):
    for nome, _, _ in arquivos:
        caminho = shlex.quote(f"{pasta}/{nome}")
        esperado = shlex.quote(hashes[nome])

        comando = (
            f"atual=$(sha256sum -- {caminho} | cut -d ' ' -f 1) "
            f"&& test \"$atual\" = {esperado} "
            f"&& rm -- {caminho}"
        )

        executar_ssh(comando, timeout=300)
