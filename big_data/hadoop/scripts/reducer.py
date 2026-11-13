import sys

genero_atual = None
total = 0

for linha in sys.stdin:
    linha = linha.strip()

    if not linha:
        continue

    genero, quantidade = linha.split("\t", 1)
    quantidade = int(quantidade)

    if genero_atual == genero:
        total += quantidade
    else:
        if genero_atual is not None:
            print(f"{genero_atual}\t{total}")

        genero_atual = genero
        total = quantidade

if genero_atual is not None:
    print(f"{genero_atual}\t{total}")
