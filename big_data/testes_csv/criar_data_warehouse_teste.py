
import csv
csv.field_size_limit(10 * 1024 * 1024)
import sqlite3
import sys
import time
from datetime import date
from pathlib import Path

DB = Path(__file__).resolve().parent / "data_warehouse_teste.db"

ARQUIVOS = {
    "jogadores": "jogadores",
    "sessoes": "sessoes",
    "partidas": "partidas",
    "compras": "compras",
    "itens": "itens",
    "itens_compras": "itens_compra"
}


def progresso(mensagem):
    print(f"[DW] {mensagem}", flush=True)


def encontrar_arquivo(pasta, lote_id, nome):
    arquivos = [
        arquivo for arquivo in pasta.glob(f"{lote_id}-{ARQUIVOS[nome]}_*_limpo.csv")
        if arquivo.name.split("-", 1)[1].split("_202", 1)[0] == ARQUIVOS[nome]
    ]

    if len(arquivos) != 1:
        raise FileNotFoundError(f"Esperado exatamente um arquivo de {nome} para o lote {lote_id}; encontrados: {len(arquivos)}")

    return arquivos[0]


def ler(pasta, lote_id, nome):
    inicio = time.perf_counter()

    with encontrar_arquivo(pasta, lote_id, nome).open(encoding="utf-8-sig", newline="") as arquivo:
        dados = list(csv.DictReader(arquivo))

    progresso(f"{nome}: {len(dados)} registros lidos em {time.perf_counter() - inicio:.1f}s")
    return dados


def numero(valor, tipo=float):
    return tipo(str(valor).replace(",", ".")) if valor not in (None, "", "NA") else None


def data_key(valor):
    return int(valor[:10].replace("-", "")) if valor and valor != "NA" else 0


def inserir(cur, tabela, colunas, linhas, tamanho_bloco=10000):
    campos = colunas.split()
    marcadores = ", ".join("?" for _ in campos)
    sql = f"INSERT INTO {tabela} ({', '.join(campos)}) VALUES ({marcadores})"
    total = len(linhas)
    inicio = time.perf_counter()

    progresso(f"{tabela}: iniciando inserção de {total} registros")

    for posicao in range(0, total, tamanho_bloco):
        bloco = linhas[posicao:posicao + tamanho_bloco]
        cur.executemany(sql, bloco)
        concluido = posicao + len(bloco)
        progresso(f"{tabela}: {concluido}/{total} registros ({time.perf_counter() - inicio:.1f}s)")

    progresso(f"{tabela}: concluída em {time.perf_counter() - inicio:.1f}s")


def criar_tabelas(cur):
    cur.executescript("""
        CREATE TABLE IF NOT EXISTS lotes_processados (
            lote_id TEXT PRIMARY KEY,
            data_processamento TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS dim_jogador (
            jogador_key INTEGER PRIMARY KEY AUTOINCREMENT,
            lote_id TEXT NOT NULL,
            player_id INTEGER NOT NULL,
            nome TEXT, username TEXT, idade INTEGER, genero TEXT,
            cidade TEXT, estado TEXT, pais TEXT, nivel_jogador INTEGER,
            data_criacao_conta TEXT,
            UNIQUE (lote_id, player_id)
        );

        CREATE TABLE IF NOT EXISTS dim_data (
            data_key INTEGER PRIMARY KEY,
            data_completa TEXT UNIQUE NOT NULL,
            ano INTEGER, mes INTEGER, dia INTEGER, trimestre INTEGER
        );

        CREATE TABLE IF NOT EXISTS dim_plataforma (
            plataforma_key INTEGER PRIMARY KEY AUTOINCREMENT,
            plataforma TEXT UNIQUE NOT NULL
        );

        CREATE TABLE IF NOT EXISTS dim_genero_jogo (
            genero_jogo_key INTEGER PRIMARY KEY AUTOINCREMENT,
            genero_jogo TEXT UNIQUE NOT NULL
        );

        CREATE TABLE IF NOT EXISTS dim_item (
            item_key INTEGER PRIMARY KEY AUTOINCREMENT,
            lote_id TEXT NOT NULL,
            item_id INTEGER NOT NULL,
            nome_item TEXT, categoria_item TEXT, raridade TEXT,
            preco_base REAL,
            UNIQUE (lote_id, item_id)
        );

        CREATE TABLE IF NOT EXISTS fato_sessoes (
            sessao_key INTEGER PRIMARY KEY AUTOINCREMENT,
            lote_id TEXT NOT NULL,
            sessao_id INTEGER NOT NULL,
            jogador_key INTEGER NOT NULL REFERENCES dim_jogador(jogador_key),
            data_key INTEGER NOT NULL REFERENCES dim_data(data_key),
            plataforma_key INTEGER NOT NULL REFERENCES dim_plataforma(plataforma_key),
            genero_jogo_key INTEGER NOT NULL REFERENCES dim_genero_jogo(genero_jogo_key),
            data_inicio TEXT, data_fim TEXT, duracao_minutos REAL,
            nivel_inicio INTEGER, nivel_fim INTEGER,
            UNIQUE (lote_id, sessao_id)
        );

        CREATE TABLE IF NOT EXISTS fato_partidas (
            partida_key INTEGER PRIMARY KEY AUTOINCREMENT,
            lote_id TEXT NOT NULL,
            partida_id INTEGER NOT NULL,
            sessao_key INTEGER NOT NULL REFERENCES fato_sessoes(sessao_key),
            jogador_key INTEGER NOT NULL REFERENCES dim_jogador(jogador_key),
            data_key INTEGER NOT NULL REFERENCES dim_data(data_key),
            data_inicio TEXT, data_fim TEXT, duracao_minutos REAL,
            resultado TEXT, pontuacao REAL, experiencia_ganha REAL,
            UNIQUE (lote_id, partida_id)
        );

        CREATE TABLE IF NOT EXISTS fato_compras (
            item_compra_key INTEGER PRIMARY KEY AUTOINCREMENT,
            lote_id TEXT NOT NULL,
            item_compra_id INTEGER NOT NULL,
            compra_id INTEGER NOT NULL,
            sessao_key INTEGER NOT NULL REFERENCES fato_sessoes(sessao_key),
            jogador_key INTEGER NOT NULL REFERENCES dim_jogador(jogador_key),
            data_key INTEGER NOT NULL REFERENCES dim_data(data_key),
            item_key INTEGER NOT NULL REFERENCES dim_item(item_key),
            quantidade INTEGER, valor_unitario REAL,
            desconto REAL, valor_total_item REAL,
            UNIQUE (lote_id, item_compra_id)
        );
    """)


def carregar(cur, lote_id, dados):
    jogadores = dados["jogadores"]
    sessoes = dados["sessoes"]
    partidas = dados["partidas"]
    compras = dados["compras"]
    itens = dados["itens"]
    itens_compras = dados["itens_compras"]

    inserir(cur, "dim_jogador", "lote_id player_id nome username idade genero cidade estado pais nivel_jogador data_criacao_conta", [
        (lote_id, int(j["player_id"]), j["nome"], j["username"], numero(j["idade"], int),
         j["genero"], j["cidade"], j["estado"], j["pais"],
         numero(j["nivel_jogador"], int), j["data_criacao_conta"])
        for j in jogadores
    ])

    inserir(cur, "dim_item", "lote_id item_id nome_item categoria_item raridade preco_base", [
        (lote_id, int(i["item_id"]), i["nome_item"], i["categoria_item"], i["raridade"], numero(i["preco_base"]))
        for i in itens
    ])

    progresso("Preparando dimensões auxiliares")

    plataformas = sorted({s["plataforma"] or "Não informado" for s in sessoes})
    generos = sorted({s["genero_jogo"] or "Não informado" for s in sessoes})

    cur.executemany("INSERT OR IGNORE INTO dim_plataforma (plataforma) VALUES (?)", [(p,) for p in plataformas])
    cur.executemany("INSERT OR IGNORE INTO dim_genero_jogo (genero_jogo) VALUES (?)", [(g,) for g in generos])

    datas = {s["data_inicio_sessao"][:10] for s in sessoes}
    datas |= {p["data_inicio_partida"][:10] for p in partidas}
    datas |= {c["data_compra"][:10] for c in compras}
    datas.discard("")
    datas.discard("NA")

    cur.execute(
        "INSERT OR IGNORE INTO dim_data (data_key, data_completa, ano, mes, dia, trimestre) VALUES (?, ?, ?, ?, ?, ?)",
        (0, "Não informado", None, None, None, None)
    )

    linhas_data = []
    for valor in sorted(datas):
        d = date.fromisoformat(valor)
        linhas_data.append((data_key(valor), valor, d.year, d.month, d.day, (d.month - 1) // 3 + 1))

    cur.executemany(
        "INSERT OR IGNORE INTO dim_data (data_key, data_completa, ano, mes, dia, trimestre) VALUES (?, ?, ?, ?, ?, ?)",
        linhas_data
    )

    jogador_keys = dict(cur.execute(
        "SELECT player_id, jogador_key FROM dim_jogador WHERE lote_id = ?", (lote_id,)
    ))
    item_keys = dict(cur.execute(
        "SELECT item_id, item_key FROM dim_item WHERE lote_id = ?", (lote_id,)
    ))
    plataforma_keys = dict(cur.execute("SELECT plataforma, plataforma_key FROM dim_plataforma"))
    genero_keys = dict(cur.execute("SELECT genero_jogo, genero_jogo_key FROM dim_genero_jogo"))

    progresso("Preparando sessões")

    sessoes_info = {}
    linhas_sessoes = []

    for s in sessoes:
        sid = int(s["sessao_id"])
        jogador = jogador_keys[int(s["player_id"])]
        sessoes_info[sid] = jogador

        linhas_sessoes.append((
            lote_id, sid, jogador, data_key(s["data_inicio_sessao"]),
            plataforma_keys[s["plataforma"] or "Não informado"],
            genero_keys[s["genero_jogo"] or "Não informado"],
            s["data_inicio_sessao"], s["data_fim_sessao"],
            numero(s["duracao_minutos"]), numero(s["nivel_inicio"], int),
            numero(s["nivel_fim"], int)
        ))

    inserir(cur, "fato_sessoes", "lote_id sessao_id jogador_key data_key plataforma_key genero_jogo_key data_inicio data_fim duracao_minutos nivel_inicio nivel_fim", linhas_sessoes)

    progresso("Mapeando sessões inseridas")

    sessao_keys = dict(cur.execute(
        "SELECT sessao_id, sessao_key FROM fato_sessoes WHERE lote_id = ?", (lote_id,)
    ))

    progresso("Preparando partidas")

    linhas_partidas = [
        (lote_id, int(p["partida_id"]), sessao_keys[int(p["sessao_id"])],
         sessoes_info[int(p["sessao_id"])], data_key(p["data_inicio_partida"]),
         p["data_inicio_partida"], p["data_fim_partida"],
         numero(p["duracao_minutos"]), p["resultado"],
         numero(p["pontuacao"]), numero(p["experiencia_ganha"]))
        for p in partidas
    ]

    inserir(cur, "fato_partidas", "lote_id partida_id sessao_key jogador_key data_key data_inicio data_fim duracao_minutos resultado pontuacao experiencia_ganha", linhas_partidas)

    progresso("Preparando compras")

    compras_info = {int(c["compra_id"]): c for c in compras}
    linhas_compras = []

    for ic in itens_compras:
        compra_id = int(ic["compra_id"])
        compra = compras_info[compra_id]
        sid = int(compra["sessao_id"])

        linhas_compras.append((
            lote_id, int(ic["item_compra_id"]), compra_id,
            sessao_keys[sid], sessoes_info[sid],
            data_key(compra["data_compra"]),
            item_keys[int(ic["item_id"])],
            numero(ic["quantidade"], int),
            numero(ic["valor_unitario"]),
            numero(ic["desconto"]),
            numero(ic["valor_total_item"])
        ))

    inserir(cur, "fato_compras", "lote_id item_compra_id compra_id sessao_key jogador_key data_key item_key quantidade valor_unitario desconto valor_total_item", linhas_compras)


def main():
    if len(sys.argv) != 3:
        raise ValueError("Uso: python criar_data_warehouse.py <pasta_csvs_tratados> <lote_id>")

    inicio = time.perf_counter()
    pasta = Path(sys.argv[1]).expanduser()
    lote_id = sys.argv[2]

    if not pasta.is_dir():
        raise FileNotFoundError(f"Pasta não encontrada: {pasta}")

    DB.parent.mkdir(parents=True, exist_ok=True)
    progresso(f"Iniciando lote {lote_id}")
    progresso(f"Banco utilizado: {DB}")

    con = sqlite3.connect(DB, timeout=30)

    try:
        con.execute("PRAGMA foreign_keys = ON")
        con.execute("PRAGMA synchronous = NORMAL")
        con.execute("PRAGMA temp_store = MEMORY")
        con.execute("PRAGMA cache_size = -200000")

        cur = con.cursor()
        criar_tabelas(cur)

        if cur.execute("SELECT 1 FROM lotes_processados WHERE lote_id = ?", (lote_id,)).fetchone():
            progresso(f"Lote {lote_id} já processado")
            return

        progresso("Lendo os seis arquivos tratados")
        dados = {nome: ler(pasta, lote_id, nome) for nome in ARQUIVOS}

        progresso("Iniciando carga incremental")
        carregar(cur, lote_id, dados)

        progresso("Registrando lote e confirmando transação")
        cur.execute("INSERT INTO lotes_processados (lote_id) VALUES (?)", (lote_id,))
        con.commit()

    except BaseException:
        progresso("Carga interrompida ou com erro. Desfazendo transação")
        con.rollback()
        raise

    finally:
        con.close()

    progresso(f"Lote {lote_id} processado com sucesso")
    progresso(f"Tempo total: {time.perf_counter() - inicio:.1f}s")


if __name__ == "__main__":
    main()
