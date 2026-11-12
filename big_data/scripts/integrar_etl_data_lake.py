
import shutil
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
RAIZ = BASE.parent
DESTINO = BASE / "data_lake" / "processed"

ARQUIVOS = [
    "jogadores_limpo.csv", "sessoes_limpo.csv", "partidas_limpo.csv",
    "compras_limpo.csv", "itens_limpo.csv", "itens_compras_limpo.csv"
]

def encontrar_origem():
    if len(sys.argv) > 1:
        pastas = [Path(sys.argv[1])]
    else:
        pastas = [
            RAIZ / "csvs_tratados",
            RAIZ / "etl" / "csvs_tratados",
            RAIZ / "etl" / "limpos",
            RAIZ / "gerador" / "gerador" / "limpos",
            RAIZ / "gerador" / "limpos"
        ]
        pastas += [p.parent for p in RAIZ.rglob("jogadores_limpo.csv")]

    for pasta in dict.fromkeys(pastas):
        if pasta != DESTINO and all((pasta / arq).is_file() for arq in ARQUIVOS):
            return pasta

    raise FileNotFoundError(
        "Não encontrei os seis CSVs tratados. Confirme se o ETL foi executado "
        "e se a pasta de saída está no seu computador."
    )

def main():
    origem = encontrar_origem()
    DESTINO.mkdir(parents=True, exist_ok=True)

    for arquivo in ARQUIVOS:
        shutil.copy2(origem / arquivo, DESTINO / arquivo)
        print("Copiado:", arquivo)

    print("Arquivos integrados em:", DESTINO)

if __name__ == "__main__":
    main()
