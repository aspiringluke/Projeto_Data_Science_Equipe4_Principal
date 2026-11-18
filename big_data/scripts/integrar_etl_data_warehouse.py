
import csv
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

from gerenciar_armazenamento import (
    LOTES_LOCAIS,
    executar_arquivamentos,
    executar_limpezas,
    limpar_tratados
)

from transferencia_arquivos import (
    PASTA_TRATADOS,
    TIPOS_TRATADOS,
    garantir_copias,
    hashes_remotos,
    listar_lotes,
    lote_estavel
)

DB = Path.home() / "projeto_big_data" / "data_warehouse" / "data_warehouse.db"
SCRIPT_DW = Path(__file__).resolve().parent / "criar_data_warehouse.py"

INTERVALO = 15
INTERVALO_FALHAS = 3600

FALHAS = {}


def informar(mensagem):
    print(f"[INTEGRADOR] {mensagem}", flush=True)


def lotes_processados():
    with sqlite3.connect(DB, timeout=30) as con:
        return {
            str(linha[0])
            for linha in con.execute(
                "SELECT lote_id FROM lotes_processados"
            )
        }


def validar_csvs(arquivos):
    for nome, _, _ in arquivos:
        caminho = LOTES_LOCAIS / nome

        with caminho.open(encoding="utf-8-sig", newline="") as arquivo:
            leitor = csv.reader(arquivo)
            cabecalho = next(leitor, None)

        if not cabecalho or not all(cabecalho):
            raise RuntimeError(f"CSV sem cabeçalho válido: {nome}")


def falha_em_espera(lote_id):
    ultima = FALHAS.get(lote_id)

    return ultima is not None and time.time() - ultima < INTERVALO_FALHAS


def importar_lote(lote_id, arquivos):
    if not lote_estavel(arquivos):
        return

    hashes = hashes_remotos(PASTA_TRATADOS, arquivos)

    garantir_copias(
        PASTA_TRATADOS, LOTES_LOCAIS, arquivos, hashes
    )

    validar_csvs(arquivos)
    informar(f"Importando lote {lote_id}")

    subprocess.run(
        [
            sys.executable, "-u", str(SCRIPT_DW),
            str(LOTES_LOCAIS), lote_id
        ],
        check=True
    )

    if lote_id not in lotes_processados():
        raise RuntimeError(f"Lote {lote_id} não confirmado no DW")

    informar(f"Lote {lote_id}: importação confirmada")
    FALHAS.pop(lote_id, None)

    try:
        limpar_tratados(lote_id, arquivos)
    except (OSError, subprocess.SubprocessError, RuntimeError) as erro:
        informar(f"Limpeza adiada para {lote_id}: {erro}")


def processar_pendentes(lotes, processados):
    pendentes = sorted(set(lotes) - processados)

    for indice, lote_id in enumerate(pendentes, 1):
        if falha_em_espera(lote_id):
            continue

        informar(f"Processando {indice}/{len(pendentes)}: {lote_id}")

        try:
            importar_lote(lote_id, lotes[lote_id])

        except (
            OSError, subprocess.SubprocessError,
            RuntimeError, ValueError, csv.Error
        ) as erro:
            FALHAS[lote_id] = time.time()
            informar(f"Falha no lote {lote_id}: {erro}")
            informar("Lote mantido pendente; continuando os demais")


def executar_ciclo():
    lotes = listar_lotes(
        PASTA_TRATADOS, TIPOS_TRATADOS, "_limpo.csv"
    )

    processados = lotes_processados()
    pendentes = set(lotes) - processados

    informar(
        f"Disponíveis: {len(lotes)} | "
        f"Processados: {len(processados)} | "
        f"Pendentes: {len(pendentes)}"
    )

    executar_limpezas(lotes, processados)
    processar_pendentes(lotes, processados)
    executar_arquivamentos(lotes_processados())


def main():
    if not DB.is_file():
        raise FileNotFoundError(f"Banco não encontrado: {DB}")

    LOTES_LOCAIS.mkdir(parents=True, exist_ok=True)
    informar("Integração e gerenciamento automático iniciados")

    try:
        while True:
            try:
                executar_ciclo()

            except (
                OSError, subprocess.SubprocessError,
                sqlite3.Error, RuntimeError, ValueError
            ) as erro:
                informar(f"Falha: {erro}")

            informar(f"Próxima verificação em {INTERVALO} segundos")
            time.sleep(INTERVALO)

    except KeyboardInterrupt:
        informar("Monitoramento encerrado")


if __name__ == "__main__":
    main()
