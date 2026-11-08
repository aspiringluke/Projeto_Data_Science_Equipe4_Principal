# Projeto Integrado Data Science
Projeto Integrado do módulo de Data Science na UNIFEOB.

> [!IMPORTANT]
> Este diretório faz parte de um trabalho maior. Acesse o [repositório principal](/) da Equipe 4 para conhecer todas as etapas do projeto.

## 👨‍💻 Equipe

**Grupo 4**
- Gabriel da Silva Freitas — RA: 24001078
- Jose Carlos Pereira Neto — RA: 24000209
- Lucas Paulino Gomes — RA: 24000580
- Luis Miguel Vitor — RA: 24000174
- Maria Luiza Tavares Procopio — RA: 24001256
- Thierry Antonello Pengo — RA: 24000073

## 🗄️ Big Data

Esta etapa do Projeto Integrado desenvolve o armazenamento, a organização e o processamento de dados de telemetria de jogos digitais. O objetivo é transformar dados de jogadores, sessões, partidas, compras e itens em informações que apoiem a análise de engajamento, utilização e comportamento dos jogadores.

Os dados utilizados são sintéticos, produzidos pelo gerador do projeto e preparados pelo processo de ETL.
Tecnologias e conceitos
- Data Lake: organização dos arquivos brutos e tratados.
- Data Warehouse: estrutura analítica baseada em tabelas fato e dimensão, modelada em SQLite.
- Apache Hadoop (HDFS): armazenamento dos arquivos tratados no sistema de arquivos distribuído.
- Hadoop Streaming / MapReduce: contagem de sessões por gênero de jogo.
- YARN: gerenciamento dos recursos durante o processamento MapReduce.
- Python, Pandas, Matplotlib e SQLite: leitura, validação, análise, visualização e demonstrações didáticas.
- Hive, Pig, Sqoop e HBase: conceitos apresentados por meio de exemplos em Python/SQLite; não foram executados como serviços reais nesta etapa.

### 🔄 Fluxo dos dados

Geração de dados sintéticos<br>
          ↓<br>
     Dados brutos<br>
          ↓<br>
      ETL / limpeza<br>
          ↓<br>
Data Lake (arquivos CSV tratados)<br>
          ├──────────────→ Data Warehouse (modelo dimensional em SQLite)<br>
          ↓<br>
       HDFS<br>
          ↓<br>
YARN + Hadoop Streaming MapReduce<br>
          ↓<br>
Resultados por gênero de jogo<br>
          ↓<br>
Análises, tabelas e gráficos no notebook<br>

O processamento com Hadoop foi realizado em um ambiente Ubuntu 24.04 no WSL2, em nó único, com Hadoop 3.4.2 e Java 17. Essa configuração demonstra o funcionamento dos componentes, mas não equivale a um cluster com vários computadores.

### 🗂️ Estrutura dos arquivos
A estrutura abaixo corresponde aos diretórios e arquivos utilizados na etapa de Big Data do projeto local:

<pre>
big_data/
├── data_lake/
│   └── processed/
│       ├── compras_limpo.csv
│       ├── itens_compras_limpo.csv
│       ├── itens_limpo.csv
│       ├── jogadores_limpo.csv
│       ├── partidas_limpo.csv
│       └── sessoes_limpo.csv
├── hadoop/
│   ├── instalar_hadoop.sh
│   ├── configurar_hadoop.sh
│   ├── iniciar_hadoop.sh
│   └── scripts/
│       ├── mapper.py
│       └── reducer.py
└── notebook/
    └── hadoop.ipynb
</pre>

> [!NOTE]
> O conteúdo disponível no GitHub pode diferir até a publicação final da pasta big_data/. **Verifique os arquivos antes de reproduzir o procedimento em outra máquina.**

### 📊 Data Lake e Data Warehouse

O Data Lake preserva os conjuntos de dados utilizados pelo projeto, distinguindo os arquivos originais dos dados tratados após o ETL.

O Data Warehouse utiliza um modelo dimensional em SQLite, com três tabelas fato e cinco dimensões:
Tabelas fato	Tabelas dimensão
fato_sessoes	dim_jogador
fato_partidas	dim_data
fato_compras	dim_plataforma
	dim_genero_jogo
	dim_item

Esse modelo permite organizar as informações para consultas sobre sessões, partidas e compras.

### ⚙️ Hadoop: HDFS, MapReduce e YARN

Os seis arquivos CSV tratados foram armazenados no HDFS em: `/telemetria/limpos/`

A análise MapReduce utiliza os scripts mapper.py e reducer.py para contar sessões por gênero de jogo. O YARN gerencia a execução do trabalho. O resultado foi gravado em: `/telemetria/resultados/sessoes_por_genero/part-00000`

#### Resultados da execução

A execução real do Hadoop Streaming, concluída em 05/11/2026, processou 37.366 sessões, agrupadas em 11 gêneros.

|Gênero    |Sessões|
|----------|-------|
|FPS       |  4.516|
|Estratégia|  3.836|
|Esportes  |  3.565|
|Corrida   |  3.409|
|Ação      |  3.397|
|Luta      |  3.225|
|Survival  |  3.202|
|Aventura  |  3.168|
|MOBA      |  3.043|
|Simulação |  3.040|
|RPG       |  2.965|
|Total     | 37.366|

O gênero FPS apresentou a maior quantidade de sessões.

### ▶️ Como executar o notebook

1. **Obtenha o projeto**

Quando a versão final estiver publicada no GitHub, clone o repositório principal com os submódulos:

```bash
git clone https://github.com/aspiringluke/Projeto_Data_Science_Equipe4_Principal.git --recurse-submodules
```

2. **Prepare o Python**

No terminal, na raiz do projeto, crie e ative um ambiente virtual:

```bash
python -m venv .venv
```

No Windows (PowerShell):

```powershell
.venv\Scripts\Activate.ps1
```

No Linux:

```bash
source .venv/bin/activate
```

Instale as bibliotecas utilizadas no notebook:

```bash
python -m pip install pandas matplotlib ipython ipykernel jupyter
```

3. **Abra o notebook**

Abra big_data/notebook/hadoop.ipynb no VS Code ou Jupyter, selecione o ambiente Python preparado e execute as células em sequência.

As análises locais usam caminhos relativos à raiz do repositório. Os arquivos tratados devem estar disponíveis em big_data/data_lake/processed/.

> [!NOTE]
> As consultas ao HDFS e ao YARN exigem uma instalação funcional do Hadoop, com os serviços iniciados e os comandos hdfs e yarn disponíveis no PATH ou em HADOOP_HOME. Em computadores sem Hadoop, o notebook pode executar as análises locais e mostrar o resultado histórico identificado do MapReduce, mas isso não significa que o Hadoop tenha sido executado nessa máquina.

4. **Verifique o Hadoop (opcional para as análises locais)**

No terminal Linux/WSL em que o Hadoop foi configurado, verifique os processos:

```bash
jps
```

Depois, confira os arquivos e o resultado no HDFS:

```bash
hdfs dfs -ls /telemetria/limpos
hdfs dfs -cat /telemetria/resultados/sessoes_por_genero/part-00000
```

O script big_data/hadoop/iniciar_hadoop.sh foi usado no ambiente de desenvolvimento para iniciar os serviços. Sua execução em outra máquina pressupõe que o Hadoop e suas configurações tenham sido preparados previamente. Não formate o NameNode de uma instalação que já contenha dados.

### 🧪 Validação e portabilidade

Para verificar a reprodução do projeto em outro computador:

1. Obtenha a versão completa do repositório e confirme a presença dos seis CSVs tratados.
2. Instale as dependências Python e execute o notebook do início ao fim.
3. Confirme a leitura dos arquivos, a geração das tabelas e do gráfico e a contagem total de 37.366 sessões.
4. Para validar o processamento Hadoop real, prepare um ambiente Hadoop compatível, inicie HDFS/YARN e confira a saída do MapReduce no HDFS.

A portabilidade do notebook Python e a instalação do ambiente Hadoop são etapas diferentes. O teste de execução em outra máquina ainda precisa ser realizado.

### 📚 Documentação

A documentação do Projeto Integrado descreve a caracterização do problema, os 5 Vs do Big Data, a arquitetura, o Data Lake, o Data Warehouse, a modelagem dimensional e a implementação do Hadoop.

O notebook big_data/notebook/hadoop.ipynb apresenta os procedimentos, as demonstrações e as análises dos resultados.