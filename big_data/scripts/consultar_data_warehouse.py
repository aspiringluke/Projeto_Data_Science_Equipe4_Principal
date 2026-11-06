
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "big_data" / "modelo_dimensional" / "data_warehouse.db"

con = sqlite3.connect(DB)
cur = con.cursor()

print("\n===== CONSULTAS DO DATA WAREHOUSE =====")

cur.execute("SELECT COUNT(*) FROM fato_sessoes")
print(f"\nTotal de sessoes: {cur.fetchone()[0]}")

cur.execute("SELECT COUNT(*) FROM fato_partidas")
print(f"Total de partidas: {cur.fetchone()[0]}")

cur.execute("SELECT AVG(duracao_minutos) FROM fato_sessoes")
duracao_media = cur.fetchone()[0]
print(f"\nDuracao media das sessoes: {duracao_media:.2f} minutos")

cur.execute("""
SELECT resultado, COUNT(*)
FROM fato_partidas
GROUP BY resultado
ORDER BY COUNT(*) DESC
""")
print("\nResultados das partidas:")
for resultado, quantidade in cur.fetchall():
    print(f"{resultado}: {quantidade}")

cur.execute("SELECT SUM(valor_total_item) FROM fato_compras")
receita = cur.fetchone()[0] or 0
print(f"\nReceita total: R$ {receita:.2f}")

cur.execute("""
SELECT d.nome_item, SUM(f.quantidade) AS quantidade_vendida
FROM fato_compras f
JOIN dim_item d ON f.item_key = d.item_key
GROUP BY d.nome_item
ORDER BY quantidade_vendida DESC
LIMIT 10
""")
print("\n10 itens mais vendidos:")
for item, quantidade in cur.fetchall():
    print(f"{item}: {quantidade}")

con.close()
