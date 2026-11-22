from pathlib import Path
from datetime import datetime
import subprocess
import sys

hdfs = str(Path.home() / "hadoop/bin/hdfs")

origem = (
    "/telemetria/data_warehouse/resultados/"
    "sessoes_por_genero_yarn_nova_execucao"
)

def executar(*args):
    return subprocess.run(
        [hdfs, "dfs", *args],
        capture_output=True,
        text=True,
        timeout=60
    )

teste = executar("-test", "-e", origem)

if teste.returncode == 1:
    print("Pasta de saída livre. Hadoop pronto.")
    sys.exit(0)

if teste.returncode != 0:
    sys.exit("Erro ao consultar o HDFS: " + teste.stderr)

destino = (
    origem + "_arquivado_" +
    datetime.now().strftime("%Y%m%d_%H%M%S_%f")
)

if executar("-test", "-e", destino).returncode != 1:
    sys.exit("Destino não está disponível. Nada foi alterado.")

resultado = executar("-mv", origem, destino)

if resultado.returncode != 0:
    sys.exit("Falha ao arquivar: " + resultado.stderr)

print("Resultado anterior preservado em:", destino)
print("Pasta de saída livre. Hadoop pronto.")
