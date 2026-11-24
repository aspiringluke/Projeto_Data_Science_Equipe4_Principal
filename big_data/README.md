
# 🎮 Projeto Integrado — Data Science

**Grupo 4 · UNIFEOB · Big Data · 2º semestre de 2026**

> [!IMPORTANT]
> Este diretório faz parte do **Projeto Integrado — Telemetria de Jogos Digitais**, desenvolvido em parceria acadêmica com a **MIMA Games & Design LTDA**. Consulte o [repositório principal](https://github.com/aspiringluke/Projeto_Data_Science_Equipe4_Principal) para conhecer as demais áreas do projeto.

## 👨‍💻 Equipe

| Integrante | RA |
|---|---|
| Gabriel da Silva Freitas | 24001078 |
| José Carlos Pereira Neto | 24000209 |
| Lucas Paulino Gomes | 24000580 |
| Luís Miguel Vitor | 24000174 |
| Maria Luiza Tavares Procópio | 24001256 |
| Thierry Antonello Pengo | 24000073 |

## 🗄️ Big Data

Esta parte do projeto organiza e analisa **dados sintéticos de telemetria de jogos digitais** — jogadores, sessões, partidas, compras e itens — para investigar engajamento, atividade por plataforma e gênero e padrões de consumo.

O trabalho integra geração em lotes, limpeza e transformação, **Data Warehouse dimensional em SQLite**, análises OLAP, experimentos com **Hadoop (HDFS, MapReduce e YARN)**, **Apache Spark** e técnicas complementares de **Machine Learning**.

### 📌 Resultados principais

| Indicador | Resultado |
|---|---:|
| Volume aproximado do Data Warehouse | 14 GB |
| Registros nas nove tabelas (incluindo dimensões e controle) | 111.762.765 |
| Sessões (`fato_sessoes`) | 42.111.433 |
| Partidas (`fato_partidas`) | 66.246.653 |
| Compras (`fato_compras`) | 2.280.065 |
| Jogadores (`dim_jogador`) | 1.110.000 |
| Lotes registrados (`lotes_processados`) | 224 |
| Gêneros de jogo | 11 |
| Sessões na execução validada do MapReduce | 42.111.433 |
| Sessões no experimento de Structured Streaming | 400.000 (16 lotes de 25.000) |

> [!NOTE]
> **Os experimentos não usam todos o mesmo recorte.** A execução validada de Hadoop corresponde à contagem de 42.111.433 sessões do DW, enquanto o experimento de streaming do Spark utiliza 400.000 sessões. Esses valores não devem ser somados. O total de 111.762.765 inclui fatos, dimensões e registros de controle; não representa apenas eventos.

## 🧰 Tecnologias e conceitos

- **Python e R:** geração de dados, preparação, limpeza, transformação e ETL.
- **SQLite:** armazenamento do Data Warehouse analítico.
- **SQL, Pandas, Matplotlib, Seaborn e Plotly:** consultas, indicadores e visualizações OLAP, incluindo cubo 3D.
- **Apache Hadoop 3.4.2:** HDFS, Hadoop Streaming/MapReduce e YARN em ambiente Linux/WSL de nó único.
- **Apache Spark / PySpark:** DataFrames, Spark SQL e simulação de chegada de lotes com Structured Streaming, em ambiente de notebook.
- **Scikit-learn:** classificação, regressão e clusterização (KMeans).
- **Hive, Pig, Sqoop e HBase:** conceitos demonstrados no notebook de Hadoop; os exemplos em Python/SQLite **não equivalem à execução desses serviços**.

### 🔄 Fluxo dos dados

```text
VM1 — Gerador Python
       |
       v
Arquivos CSV sintéticos em lotes
       |
       v
VM2 — Pipeline Python + ETL em R
       |  limpeza, padronização e validação
       v
Data Warehouse SQLite (fatos e dimensões)
       |
       +----> Consultas SQL e análises OLAP / cubo 3D
       |
       +----> Preparação de entrada agregada -> HDFS -> YARN / MapReduce
       |
       +----> Análises com Apache Spark e visualizações
       |
       +----> Experimentos de Machine Learning
```

**Decisão arquitetural:** foi adotado um **Data Warehouse**, e não um Data Lake, porque os dados do projeto são predominantemente estruturados e as análises dependem de relacionamentos consistentes entre sessões, partidas, compras, jogadores, plataformas e períodos. O SQLite facilita a reprodução acadêmica e as consultas locais; **não é, por si só, um banco distribuído**.

## 🗃️ Data Warehouse e modelagem dimensional

O banco possui **três tabelas fato, cinco dimensões e uma tabela de controle**:

| Tipo | Tabelas |
|---|---|
| Fatos | `fato_sessoes`, `fato_partidas`, `fato_compras` |
| Dimensões | `dim_jogador`, `dim_data`, `dim_plataforma`, `dim_genero_jogo`, `dim_item` |
| Controle | `lotes_processados` |

As tabelas fato registram eventos de sessões, partidas e compras. As dimensões permitem agrupar e filtrar esses eventos por jogador, período, plataforma, gênero e item, conforme os relacionamentos de cada fato. Entre as métricas estão **contagem de sessões, duração média, horas jogadas, quantidade de partidas e valores de compras**.

### 📊 OLAP

As análises OLAP combinam consultas SQL e visualizações para comparar o comportamento dos jogadores. O cubo tridimensional utiliza **plataforma, gênero de jogo e ano/trimestre** como dimensões; o tamanho dos pontos representa a quantidade de sessões e a cor representa a duração média. Também foi elaborado um gráfico de horas jogadas por plataforma.

## ⚙️ Hadoop — HDFS, MapReduce e YARN

O ambiente de desenvolvimento utilizou **Ubuntu no WSL2**, **Hadoop 3.4.2** e **Java 17**, com serviços Hadoop em **nó único**. O HDFS armazena entradas e resultados, o YARN gerencia a execução e o Hadoop Streaming executa o processamento com mapper e reducer.

A execução validada agrupou as sessões por **11 gêneros de jogo** e totalizou **42.111.433 sessões**, em concordância com a contagem do Data Warehouse.

**Caminho HDFS registrado na execução validada:**

```text
/telemetria/data_warehouse/resultados/sessoes_por_genero_yarn_20261120_194016_998402
```

> [!IMPORTANT]
> A entrada dessa execução foi **preparada a partir de contagens agregadas previamente no SQLite**. Assim, o experimento comprova o uso de HDFS, Hadoop Streaming e YARN para processar essas agregações, **não** que 42 milhões de linhas individuais tenham sido distribuídas ao MapReduce. A execução em nó único também não representa um cluster físico com várias máquinas.

Para conferir os serviços e consultar o resultado em um ambiente Hadoop já configurado:

```bash
jps
hdfs dfs -ls /telemetria/data_warehouse/resultados/
hdfs dfs -cat /telemetria/data_warehouse/resultados/sessoes_por_genero_yarn_20261120_194016_998402/part-00000
```

O último comando pressupõe que o diretório da execução validada ainda exista no HDFS da máquina. **Não formate o NameNode** para repetir as verificações: isso pode comprometer os dados armazenados.

## ⚡ Apache Spark

O notebook do Spark aplica **DataFrames e Spark SQL** para seleção, filtros, junções, agrupamentos, ordenação e cálculo de indicadores. As visualizações incluem distribuição e duração das sessões, comparação entre gêneros e plataformas, evolução temporal, valores atípicos, correlações e receita por categoria de item.

### Structured Streaming

Foi registrado um experimento com **400.000 sessões processadas em 16 lotes de 25.000**. A progressão dos lotes permite verificar o crescimento acumulado do conjunto processado. Trata-se de uma **simulação de chegada de dados**, e não de uma captura contínua de eventos reais de um jogo.

O Spark foi utilizado em ambiente de notebook, **sem afirmar que sua execução ocorreu sobre o cluster Hadoop**. O código e as saídas do notebook constituem as evidências das consultas e visualizações realizadas.

## 🤖 Machine Learning

Os experimentos complementares exploram três abordagens:

| Abordagem | Finalidade | Observação |
|---|---|---|
| Classificação | Investigar a previsão do resultado de partidas | É necessário avaliar vazamento de dados e desempenho em relação ao modelo de referência. |
| Regressão | Estimar uma variável numérica de desempenho | Foram comparados um modelo de referência e Random Forest, com métricas e valores reais versus previstos. |
| Clusterização (KMeans) | Explorar perfis de comportamento | Foram avaliados agrupamentos, projeção PCA e mapa de calor; os perfis são exploratórios. |

Os resultados são **experimentos com dados sintéticos**, não modelos validados para uso em produção.

## 🗂️ Organização dos notebooks

O README anterior registra a pasta **`big_data/notebooks/`** (plural) na branch `big-data`. Antes do envio final, confirme se os arquivos estão com os nomes e maiúsculas abaixo:

```text
big_data/
├── notebooks/
│   ├── hadoop.ipynb
│   ├── Spark.ipynb
│   ├── ML.ipynb
│   └── OLAP.ipynb
└── README.md
```

A árvore acima apresenta **os notebooks indicados no README anterior**, não um inventário verificado de todos os arquivos do GitHub. Scripts auxiliares do Hadoop, geradores, ETL, banco de dados e dados de entrada devem ser consultados nos respectivos diretórios do projeto, conforme a organização efetivamente publicada.

### ▶️ Como abrir e reproduzir as análises

**1. Obtenha o projeto:**

```bash
git clone https://github.com/aspiringluke/Projeto_Data_Science_Equipe4_Principal.git --recurse-submodules
```

**2. Prepare um ambiente Python, se executar os notebooks localmente:**

```bash
python -m venv .venv
```

No **Windows (PowerShell)**:

```powershell
.venv\Scripts\Activate.ps1
```

No **Linux/WSL**:

```bash
source .venv/bin/activate
```

Instale as dependências de acordo com o notebook e o ambiente utilizado. Para as análises em Python, as bibliotecas podem incluir:

```bash
python -m pip install jupyter ipykernel pandas matplotlib seaborn plotly pyspark scikit-learn
```

**3. Abra o notebook correspondente** no Jupyter, VS Code ou Google Colab. Ajuste os caminhos de leitura dos dados para o local onde os CSVs tratados ou o banco SQLite estiverem disponíveis. Os notebooks podem exigir ambientes diferentes: **Hadoop/HDFS/YARN no WSL** para a execução distribuída e **Spark no ambiente de notebook** para as análises em PySpark.

**4. Valide as saídas:** confira as contagens do Data Warehouse, as consultas e os gráficos. Para o Hadoop, compare a soma por gênero com **42.111.433 sessões** na execução validada; para o experimento de streaming, confira **400.000 sessões em 16 lotes**.

> [!NOTE]
> O Data Warehouse de aproximadamente 14 GB e os arquivos de entrada podem não estar versionados no GitHub devido ao tamanho. **Não se deve presumir que clonar o repositório fornece automaticamente todos os dados necessários**. As saídas salvas dos notebooks são evidências de execuções anteriores, não substituem uma nova execução em outro computador.

## 🧪 Validação e limitações

- **Data Warehouse:** contagens de fatos, dimensões e lotes registradas e verificadas no ambiente do projeto.
- **Hadoop:** execução validada de MapReduce/YARN com total de 42.111.433 sessões em 11 gêneros, usando entrada agregada.
- **Spark:** consultas, indicadores e visualizações, além do experimento de 400.000 sessões em lotes.
- **Machine Learning:** análises de classificação, regressão e clusterização com avaliação de resultados e limitações.
- **Portabilidade:** a reprodução em outra máquina depende dos arquivos de entrada, caminhos, versões e serviços instalados. Não há alegação de que o projeto foi testado integralmente em ambiente limpo.

## 📚 Documentação

O **relatório técnico de Big Data** foi desenvolvido no Overleaf e apresenta:

1. Introdução e os 5 Vs do Big Data.
2. Arquitetura e organização dos dados.
3. ETL e justificativa do Data Warehouse.
4. Modelagem dimensional.
5. Análises OLAP e cubo tridimensional.
6. Hadoop, HDFS, MapReduce e YARN.
7. Spark, DataFrames, Spark SQL e visualizações.
8. Machine Learning e considerações finais.

Os notebooks complementam o relatório com **código-fonte, consultas, resultados e gráficos**. O README resume a arquitetura e orienta a execução, sem substituir o relatório técnico.

---
