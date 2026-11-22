# Projeto Integrado Data Science
Projeto Integrado do módulo de **Data Science** na UNFEOB

## 👨‍💻 Equipe

**Grupo 4**
- Gabriel da Silva Freitas — RA: 24001078
- Jose Carlos Pereira Neto — RA: 24000209
- Lucas Paulino Gomes — RA: 24000580
- Luis Miguel Vitor — RA: 24000174
- Maria Luiza Tavares Procopio — RA: 24001256
- Thierry Antonello Pengo — RA: 24000073

## 🧭 Clonando o repositório

```bash
git clone https://github.com/aspiringluke/Projeto_Data_Science_Equipe4_Principal.git --recurse-submodules
```

> [!NOTE]
> Note que nosso repositório utiliza submódulos git para melhor gerenciar todas as partes do projeto. Certifique-se de executar o `git clone` com a opção `--recurse-submodules` para garantir que eles sejam baixados corretamente

## 🚩 Visão do Projeto
O projeto está sendo desenvolvido em parceria com a empresa **MIMA Games & Design LTDA.**, inscrita no CNPJ **34.362.072/0001-09**.
A empresa participa do projeto fornecendo contexto e informações relacionadas ao setor de desenvolvimento de jogos digitais para utilização acadêmica durante a elaborção da solução.

### Problema
Jogos digitais podem gerar grandes quantidades de dados relacionados à sua utilização, incluindo ações dos jogadores, operações financeiras e informações técnicas do software. A análise desses dados permite compreender o comportamento dos jogadores, identificar padrões de utilização, acompanhar o desempenho comercial do produto e encontrar situações que necessitem de investigações aprofundadas. Como a quantidade de dados é massiva, este enquadra-se como um problema de Big Data.

### Objetivo
Construir uma **pipeline de Big Data** que colete dados de jogos digitais, como dados de uso, jogadores, informações técnicas e receita gerada, a fim de identificar padrões que permitam aos desenvolvedores e gestores:
- ajustar o design do jogo para corrigir problemas;
- monitorar e prever o engajamento de determinado conteúdo;
- identificar jogadores com risco de abandonar o jogo;
- avaliar a rentabilidade do jogo ou de partes dele;
- encontrar padrões e pontos de atenção nos dados coletados;
- utilizar os dados como apoio para futuras tomadas de decisão.

### 🎮 Telemetria em Jogos Digitais
A telemetria em jogos digitais consiste na coleta remota de dados gerados durante a utilização de um jogo. É uma abordagem que utiliza ferramentas de software dentro do próprio jogo ou em parelelo a ele que envia informações através da rede, permitindo aos desenvolvedores analisar uma quantidade muito maior de dados do que seria possível num ambiente de desenvolvimento, com a vantagem dos dados refletirem o real funcionamento do jogo e as ações dos jogadores.

## 🐍 Gerador de Dados

Como o projeto não utiliza diretamente dados provenientes de um jogo real, foi desenvolvido um **gerador de dados sintéticos em Python**.

Acesse-o no submódulo [gerador](https://github.com/luisvitor-unifeob/Gerador_de_Dados_Equipe4.git). Lá encontrará instruções de execução. Note que se trata de um repositório separado


## ⚙️ DevOps

Explicações técnicas da infraestrutura encontram-se em [infraestrutura/README_infra.md](infraestrutura/README_infra.md)

## 📈 Análise Exploratória de Dados

O relatório de análise exploratória de dados (AED) documenta, em R Markdown, o caminho percorrido para ler, inspecionar e preparar os dados de telemetria de jogos digitais gerados pelo simulador do projeto, desenvolvido em parceria com a MIMA Games & Design LTDA. Ele importa os seis conjuntos de dados (compras, itens, itens de compra, jogadores, partidas e sessões) e realiza uma análise inicial da estrutura de cada um, utilizando `head()`, `names()`, `str()` e `summary()`. Em seguida, investiga a "sujeira" presente nos dados, como valores ausentes e descontos fora do intervalo válido, que são sinalizados em vez de corrigidos, a fim de preservar a rastreabilidade.

Na etapa de transformação, o relatório padroniza os valores ausentes, remove registros duplicados, uniformiza textos e categorias com base em listas de valores válidos, converte números armazenados como texto e corrige datas registradas em formatos distintos (ISO, dd/mm/aaaa e mm/dd/aaaa), utilizando referências internas dos próprios dados para resolver ambiguidades. Também mapeia os estados dos jogadores para suas respectivas siglas ISO 3166-2.

Na etapa de validação, são utilizadas diversas funções para verificar se ainda existem sujeiras ou inconsistências nos dados transformados. Inicialmente, são realizadas validações gerais, comuns a todos os conjuntos de dados, como a verificação da ausência de IDs ou linhas duplicadas, de valores ausentes em colunas que o gerador nunca deixa em branco e de textos vazios remanescentes. Também são realizadas validações específicas para cada conjunto de dados, como a identificação de tempos de sessão inconsistentes no dataset de sessões e de idades fora do intervalo permitido no dataset de jogadores.

Por fim, na etapa de construção de gráficos, é utilizada a biblioteca `ggplot2` para desenvolver gráficos de análise que permitem identificar padrões e tendências presentes nos dados produzidos pelo simulador.

Entretanto, antes da construção dos gráficos, foi realizada uma subetapa de pré-análise, utilizando métricas de estatística descritiva e funções da biblioteca `dplyr` para gerar novas variáveis com os valores necessários à análise das métricas por meio dos gráficos. As explicações técnicas podem ser encontradas no tópico [Probabilidade e Estatística](#-probabilidade-e-estatística)

O relatório pode ser encontrado em: [Análise Exploratória de Dados (AED)](AED/aed-PIGrupo4.Rmd)

## 🗄️ Big Data
A etapa de **Big Data** é responsável pelo armazenamento, processamento e análise dos dados sintéticos de telemetria de jogos digitais. Para isso, utilizamos um **Data Lake** para organizar os dados brutos e tratados, um **Data Warehouse** com modelagem dimensional para facilitar consultas analíticas, **Apache Hadoop** para demonstrar armazenamento e processamento com HDFS e MapReduce, e **Apache Spark** para análises e simulação de processamento em lotes. Também aplicamos técnicas de **Machine Learning** para previsão e identificação de perfis de jogadores, além de análises **OLAP** para explorar os dados por diferentes perspectivas.

O objetivo é transformar os registros de jogadores, sessões, partidas e compras em indicadores úteis para compreender o comportamento dos usuários e apoiar a tomada de decisões. A integração completa com a pipeline automatizada ainda está em desenvolvimento.

 **Documentação completa, notebooks e resultados:** [Big Data](https://github.com/aspiringluke/Projeto_Data_Science_Equipe4_Principal/blob/big-data/big_data/README.md)


## 📊 Probabilidade e Estatística

A etapa de Probabilidade e Estatística tem como objetivo utilizar medidas de estatística descritiva para resumir, organizar e interpretar os dados, facilitando a identificação de padrões, tendências e possíveis comportamentos presentes nos conjuntos analisados. Medidas como média, mediana, moda, frequência, soma, variância, desvio padrão e quartis permitem compreender a distribuição dos dados, comparar diferentes grupos, identificar valores discrepantes (outliers) e observar a dispersão das informações. Dessa forma, essas métricas servem como base para a construção de gráficos e para a interpretação dos resultados da análise exploratória de dados (AED).

Neste relatório, foram utilizadas funções das bibliotecas `dplyr` e `ggplot2` para agrupar informações e calcular medidas estatísticas que posteriormente foram representadas nos gráficos. Foram utilizadas, principalmente, médias para comparar a duração das sessões entre plataformas e a experiência adquirida em diferentes intervalos de tempo; frequências para identificar os horários e dias da semana com maior atividade; somatórios para identificar as categorias de itens mais comprados e calcular o faturamento mensal; além de boxplots, que permitem visualizar a mediana, os quartis, a dispersão e os valores discrepantes da experiência adquirida por gênero de jogo. Também foram utilizados gráficos de dispersão para observar possíveis relações entre a duração das sessões e a evolução dos jogadores.

A partir dessas representações, foi possível levantar diferentes pontos de análise, como a existência de diferenças na duração média das sessões entre plataformas, possíveis padrões de atividade conforme os horários e dias da semana, a relação entre o tempo de sessão e a experiência adquirida, as diferenças de distribuição da experiência entre os gêneros de jogos, a popularidade das categorias de itens e a variação do faturamento ao longo dos meses. Também foi possível comparar o faturamento médio entre compras com desconto e com preço normal, identificando possíveis diferenças de comportamento entre as categorias de itens.

Por fim, as informações obtidas por meio das medidas estatísticas e dos gráficos servem como referência para análises posteriores no Google Colab, utilizando o Apache Hadoop e/ou o Apache Spark. A intenção é aprofundar os padrões identificados, explorar possíveis relações entre diferentes variáveis e aplicar técnicas de processamento e análise sobre volumes maiores de dados. Assim, os resultados da estatística descritiva funcionam como um ponto de partida para investigações mais aprofundadas, permitindo validar hipóteses e identificar comportamentos que não seriam tão evidentes em uma análise isolada dos gráficos.
