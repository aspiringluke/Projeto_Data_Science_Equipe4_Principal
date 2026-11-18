
import subprocess
from pathlib import Path

from transferencia_arquivos import (
    PASTA_ORIGINAIS,
    PASTA_TRATADOS,
    TIPOS_ORIGINAIS,
    TIPOS_TRATADOS,
    copia_valida,
    garantir_copias,
    hashes_remotos,
    listar_lotes,
    lote_estavel,
    remover_verificados
)

BASE_LOCAL = Path.home() / "projeto_big_data"
LOTES_LOCAIS = BASE_LOCAL / "lotes_tratados"
ARQUIVO_LOCAL = BASE_LOCAL / "arquivos_originais"

LIMPEZAS_POR_CICLO = 10
ARQUIVAMENTOS_POR_CICLO = 3


def informar(mensagem):
    print(f"[ARMAZENAMENTO] {mensagem}", flush=True)


def limpar_tratados(lote_id, arquivos):
    if not lote_estavel(arquivos):
        return False

    hashes = hashes_remotos(PASTA_TRATADOS, arquivos)

    if not copia_valida(LOTES_LOCAIS, arquivos, hashes):
        return False

    remover_verificados(PASTA_TRATADOS, arquivos, hashes)
    informar(f"Lote {lote_id}: tratados removidos da VM2")

    return True


def arquivar_originais(lote_id, arquivos):
    if not lote_estavel(arquivos):
        return False

    hashes = hashes_remotos(PASTA_ORIGINAIS, arquivos)
    destino = ARQUIVO_LOCAL / lote_id

    garantir_copias(PASTA_ORIGINAIS, destino, arquivos, hashes)

    if not copia_valida(destino, arquivos, hashes):
        raise RuntimeError("Arquivamento não validado")

    remover_verificados(PASTA_ORIGINAIS, arquivos, hashes)
    informar(f"Lote {lote_id}: originais arquivados no WSL")

    return True


def executar_limpezas(lotes, processados):
    total = 0

    for lote_id in sorted(set(lotes) & processados):
        if total >= LIMPEZAS_POR_CICLO:
            break

        try:
            if limpar_tratados(lote_id, lotes[lote_id]):
                total += 1

        except (OSError, subprocess.SubprocessError, RuntimeError) as erro:
            informar(f"Limpeza adiada para {lote_id}: {erro}")


def executar_arquivamentos(processados):
    lotes = listar_lotes(
        PASTA_ORIGINAIS, TIPOS_ORIGINAIS, ".csv"
    )

    total = 0

    for lote_id in sorted(set(lotes) & processados):
        if total >= ARQUIVAMENTOS_POR_CICLO:
            break

        try:
            if arquivar_originais(lote_id, lotes[lote_id]):
                total += 1

        except (OSError, subprocess.SubprocessError, RuntimeError) as erro:
            informar(f"Arquivamento adiado para {lote_id}: {erro}")
