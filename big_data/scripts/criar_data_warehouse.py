
import csv
import sqlite3
from datetime import date
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
PROCESSED = BASE / "data_lake" / "processed"
DB = BASE / "modelo_dimensional" / "data_warehouse.db"

ARQUIVOS = {
    "jogadores": "jogadores_limpo.csv",
    "sessoes": "sessoes_limpo.csv",
    "partidas": "partidas_limpo.csv",
    "compras": "compras_limpo.csv",
    "itens": "itens_limpo.csv",
    "itens_compras": "itens_compras_limpo.csv"
}

def ler(nome):
    with (PROCESSED / ARQUIVOS[nome]).open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def numero(valor, tipo=float):
    return tipo(str(valor).replace(",", ".")) if valor not in (None, "", "NA") else None

def data_key(valor):
    return int(valor[:10].replace("-", "")) if valor and valor != "NA" else 0


def inserir(cur, tabela, colunas, linhas):
    campos = colunas.split()
    marcadores = ", ".join("?" for _ in campos)
    sql = f"INSERT INTO {tabela} ({', '.join(campos)}) VALUES ({marcadores})"
    cur.executemany(sql, linhas)

def criar_tabelas(cur):
    cur.executescript("""
        CREATE TABLE dim_jogador (
            jogador_key INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id INTEGER UNIQUE NOT NULL,
            nome TEXT, username TEXT, idade INTEGER, genero TEXT,
            cidade TEXT, estado TEXT, pais TEXT, nivel_jogador INTEGER,
            data_criacao_conta TEXT
        );

        CREATE TABLE dim_data (
            data_key INTEGER PRIMARY KEY,
            data_completa TEXT UNIQUE NOT NULL,
            ano INTEGER, mes INTEGER, dia INTEGER, trimestre INTEGER
        );

        CREATE TABLE dim_plataforma (
            plataforma_key INTEGER PRIMARY KEY AUTOINCREMENT,
            plataforma TEXT UNIQUE NOT NULL
        );

        CREATE TABLE dim_genero_jogo (
            genero_jogo_key INTEGER PRIMARY KEY AUTOINCREMENT,
            genero_jogo TEXT UNIQUE NOT NULL
        );

        CREATE TABLE dim_item (
            item_key INTEGER PRIMARY KEY AUTOINCREMENT,
            item_id INTEGER UNIQUE NOT NULL,
            nome_item TEXT, categoria_item TEXT, raridade TEXT,
            preco_base REAL
        );

        CREATE TABLE fato_sessoes (
            sessao_id INTEGER PRIMARY KEY,
            jogador_key INTEGER NOT NULL REFERENCES dim_jogador(jogador_key),
            data_key INTEGER NOT NULL REFERENCES dim_data(data_key),
            plataforma_key INTEGER NOT NULL REFERENCES dim_plataforma(plataforma_key),
            genero_jogo_key INTEGER NOT NULL REFERENCES dim_genero_jogo(genero_jogo_key),
            data_inicio TEXT, data_fim TEXT, duracao_minutos REAL,
            nivel_inicio INTEGER, nivel_fim INTEGER
        );

        CREATE TABLE fato_partidas (
            partida_id INTEGER PRIMARY KEY,
            sessao_id INTEGER NOT NULL REFERENCES fato_sessoes(sessao_id),
            jogador_key INTEGER NOT NULL REFERENCES dim_jogador(jogador_key),
            data_key INTEGER NOT NULL REFERENCES dim_data(data_key),
            data_inicio TEXT, data_fim TEXT, duracao_minutos REAL,
            resultado TEXT, pontuacao REAL, experiencia_ganha REAL
        );

        CREATE TABLE fato_compras (
            item_compra_id INTEGER PRIMARY KEY,
            compra_id INTEGER NOT NULL,
            sessao_id INTEGER NOT NULL REFERENCES fato_sessoes(sessao_id),
            jogador_key INTEGER NOT NULL REFERENCES dim_jogador(jogador_key),
            data_key INTEGER NOT NULL REFERENCES dim_data(data_key),
            item_key INTEGER NOT NULL REFERENCES dim_item(item_key),
            quantidade INTEGER, valor_unitario REAL,
            desconto REAL, valor_total_item REAL
        );
    """)

def carregar(cur, d):
    jogadores = d["jogadores"]
    sessoes = d["sessoes"]
    partidas = d["partidas"]
    compras = d["compras"]
    itens = d["itens"]
    itens_compras = d["itens_compras"]

    inserir(cur, "dim_jogador", "player_id nome username idade genero cidade estado pais nivel_jogador data_criacao_conta", [
        (int(j["player_id"]), j["nome"], j["username"], numero(j["idade"], int),
         j["genero"], j["cidade"], j["estado"], j["pais"],
         numero(j["nivel_jogador"], int), j["data_criacao_conta"])
        for j in jogadores
    ])

    inserir(cur, "dim_item", "item_id nome_item categoria_item raridade preco_base", [
        (int(i["item_id"]), i["nome_item"], i["categoria_item"], i["raridade"], numero(i["preco_base"]))
        for i in itens
    ])

    plataformas = sorted({s["plataforma"] or "Não informado" for s in sessoes})
    generos = sorted({s["genero_jogo"] or "Não informado" for s in sessoes})

    inserir(cur, "dim_plataforma", "plataforma", [(p,) for p in plataformas])
    inserir(cur, "dim_genero_jogo", "genero_jogo", [(g,) for g in generos])

    datas = {s["data_inicio_sessao"][:10] for s in sessoes}
    datas |= {p["data_inicio_partida"][:10] for p in partidas}
    datas |= {c["data_compra"][:10] for c in compras}
    datas.discard("")
    datas.discard("NA")

    linhas_data = [(0, "Não informado", None, None, None, None)]

    for valor in sorted(datas):
        d = date.fromisoformat(valor)
        linhas_data.append((
            data_key(valor), valor, d.year, d.month,
            d.day, (d.month - 1) // 3 + 1
        ))

    inserir(cur, "dim_data", "data_key data_completa ano mes dia trimestre", linhas_data)

    jogador_keys = dict(cur.execute("SELECT player_id, jogador_key FROM dim_jogador"))
    item_keys = dict(cur.execute("SELECT item_id, item_key FROM dim_item"))
    plataforma_keys = dict(cur.execute("SELECT plataforma, plataforma_key FROM dim_plataforma"))
    genero_keys = dict(cur.execute("SELECT genero_jogo, genero_jogo_key FROM dim_genero_jogo"))

    sessoes_info = {}
    linhas = []

    for s in sessoes:
        sid = int(s["sessao_id"])
        jogador = jogador_keys[int(s["player_id"])]
        sessoes_info[sid] = jogador

        linhas.append((
            sid, jogador, data_key(s["data_inicio_sessao"]),
            plataforma_keys[s["plataforma"] or "Não informado"],
            genero_keys[s["genero_jogo"] or "Não informado"],
            s["data_inicio_sessao"], s["data_fim_sessao"],
            numero(s["duracao_minutos"]),
            numero(s["nivel_inicio"], int),
            numero(s["nivel_fim"], int)
        ))

    inserir(cur, "fato_sessoes", "sessao_id jogador_key data_key plataforma_key genero_jogo_key data_inicio data_fim duracao_minutos nivel_inicio nivel_fim", linhas)

    inserir(cur, "fato_partidas", "partida_id sessao_id jogador_key data_key data_inicio data_fim duracao_minutos resultado pontuacao experiencia_ganha", [
        (int(p["partida_id"]), int(p["sessao_id"]), sessoes_info[int(p["sessao_id"])],
         data_key(p["data_inicio_partida"]), p["data_inicio_partida"], p["data_fim_partida"],
         numero(p["duracao_minutos"]), p["resultado"], numero(p["pontuacao"]),
         numero(p["experiencia_ganha"]))
        for p in partidas
    ])

    compras_info = {int(c["compra_id"]): c for c in compras}
    linhas = []

    for ic in itens_compras:
        compra_id = int(ic["compra_id"])
        compra = compras_info[compra_id]
        sid = int(compra["sessao_id"])

        linhas.append((
            int(ic["item_compra_id"]), compra_id, sid, sessoes_info[sid],
            data_key(compra["data_compra"]),
            item_keys[int(ic["item_id"])],
            numero(ic["quantidade"], int),
            numero(ic["valor_unitario"]),
            numero(ic["desconto"]),
            numero(ic["valor_total_item"])
        ))

    inserir(cur, "fato_compras", "item_compra_id compra_id sessao_id jogador_key data_key item_key quantidade valor_unitario desconto valor_total_item", linhas)

def main():
    dados = {nome: ler(nome) for nome in ARQUIVOS}
    DB.parent.mkdir(parents=True, exist_ok=True)

    temp = DB.with_name("data_warehouse_temp.db")
    temp.unlink(missing_ok=True)
    con = sqlite3.connect(temp)

    try:
        con.execute("PRAGMA foreign_keys = ON")
        cur = con.cursor()
        criar_tabelas(cur)
        carregar(cur, dados)

        if cur.execute("PRAGMA foreign_key_check").fetchall():
            raise ValueError("Foram encontradas relações inválidas")

        con.commit()

    except Exception:
        con.rollback()
        con.close()
        temp.unlink(missing_ok=True)
        raise

    else:
        con.close()

    temp.replace(DB)
    print("Data Warehouse atualizado:", DB)

if __name__ == "__main__":
    main()
