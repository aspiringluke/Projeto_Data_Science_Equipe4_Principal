from pathlib import Path
import importlib.util
import re
import sys
import csv

RAIZ = Path(__file__).resolve().parents[2]
PASTA = RAIZ / "big_data" / "testes_csv"
ENTRADA = PASTA / ".tmp"
BANCO = PASTA / "data_warehouse_teste.db"
ORIGINAL = RAIZ / "big_data" / "scripts" / "criar_data_warehouse.py"

TIPOS = {
    "jogadores": "jogadores",
    "sessoes": "sessoes",
    "partidas": "partidas",
    "compras": "compras",
    "itens": "itens",
    "itens_compras": "itens_compra",
}


def localizar(lote, tipo):
    prefixo = TIPOS[tipo]
    encontrados = sorted(
        p for p in ENTRADA.rglob("*.csv")
        if p.name.startswith(f"{lote}-{prefixo}_") and " - Copia" not in p.stem
    )
    if not encontrados:
        raise ValueError(f"CSV ausente: {lote} / {prefixo}")
    return encontrados

def encontrar_arquivo(pasta, lote_id, nome):
    raise RuntimeError("Use a leitura combinada dos CSVs")


def ler_combinado(pasta, lote_id, nome):
    dados = []
    for arquivo in localizar(lote_id, nome):
        with arquivo.open(encoding="utf-8-sig", newline="") as f:
            dados.extend(csv.DictReader(f))

    chaves = {
        "jogadores": "player_id",
        "sessoes": "sessao_id",
        "partidas": "partida_id",
        "compras": "compra_id",
        "itens": "item_id",
        "itens_compras": "item_compra_id",
    }

    chave = chaves[nome]
    unicos = {}
    for linha in dados:
        identificador = linha[chave]
        if identificador not in unicos:
            unicos[identificador] = linha

    print(
        f"[DW] {nome}: {len(unicos)} registros únicos "
        f"({len(dados) - len(unicos)} duplicados ignorados)"
    )
    return list(unicos.values())


if not ENTRADA.is_dir():
    raise SystemExit(f"Pasta não encontrada: {ENTRADA}")

arquivos = list(ENTRADA.rglob("*.csv"))
lotes = sorted({
    p.name.split("-", 1)[0]
    for p in arquivos
    if "-jogadores_" in p.name
})

print(f"CSVs encontrados: {len(arquivos)}")
print(f"Lotes encontrados: {len(lotes)}")

if len(arquivos) != 120 or len(lotes) != 10:
    raise SystemExit("Quantidade inesperada. Importação cancelada.")

# Conferir os 6 arquivos de cada lote antes de gravar.
for lote in lotes:
    for tipo in TIPOS:
        for arquivo in localizar(lote, tipo):
            with arquivo.open(encoding="utf-8-sig", newline="") as f:
                cabecalho = next(csv.reader(f), None)
                if not cabecalho:
                    raise SystemExit(f"CSV vazio: {arquivo}")

# Carregar a lógica dimensional já existente.
spec = importlib.util.spec_from_file_location(
    "warehouse_teste", ORIGINAL
)
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)

# Redirecionar exclusivamente para o banco de testes.
modulo.DB = BANCO

modulo.ler = ler_combinado

# Aceitar datas ISO e datas americanas MM/DD/YYYY.
from datetime import date as Date, datetime as DateTime

date_original = modulo.date


def converter_data(valor):
    valor = str(valor).strip()
    formatos = (
        "%Y-%m-%d",
        "%m/%d/%Y",
        "%d-%m-%Y",
        "%d/%m/%Y",
    )
    for formato in formatos:
        try:
            return DateTime.strptime(valor[:10], formato).date()
        except ValueError:
            continue
    raise ValueError(f"Formato de data desconhecido: {valor}")

class DataCompativel:
    @staticmethod
    def fromisoformat(valor):
        return converter_data(valor)

modulo.date = DataCompativel

def data_key_compativel(valor):
    if not valor or valor == "NA":
        return 0
    return int(converter_data(valor).strftime("%Y%m%d"))

modulo.data_key = data_key_compativel



if BANCO.resolve() == (
    Path.home() / "projeto_big_data" /
    "data_warehouse" / "data_warehouse.db"
).resolve():
    raise SystemExit("ERRO: destino igual ao original.")

print(f"\nBanco de TESTES: {BANCO}")
print("O banco original não será utilizado.\n")

for indice, lote in enumerate(lotes, 1):
    print(f"\n========== LOTE {indice}/{len(lotes)}: {lote} ==========")
    sys.argv = [
        str(ORIGINAL),
        str(ENTRADA),
        lote
    ]
    modulo.main()

print("\nIMPORTAÇÃO CONCLUÍDA!")
print(f"Banco criado: {BANCO}")
