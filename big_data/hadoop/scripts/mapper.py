import csv
import sys

# Lê os dados de sessões enviados pelo Hadoop
leitor = csv.reader(sys.stdin)

for linha in leitor:
    # Ignora o cabeçalho e linhas vazias
    if not linha or linha[0] == "sessao_id":
        continue

    if len(linha) < 7:
        continue

    # Coluna que identifica o gênero do jogo
    genero = linha[6].strip()

    if genero:
        print(f"{genero}\t1")
