# ==============================================================================
# ETL - Telemetria de Jogos Digitais
# Projeto Integrado - Equipe 4 | Parceria: MIMA Games & Design LTDA
#
# Extract  : importa os CSVs "sujos" gerados pelo simulador
# Transform: padroniza nulos, remove duplicatas, normaliza textos/numeros,
#            corrige datas e estados
# Load     : exporta os datasets limpos em CSV
# ==============================================================================


# ------------------------------------------------------------------------------
# 0. CONFIGURAÇÃO E PACOTES
# ------------------------------------------------------------------------------

# TRUE  = imprime a análise exploratória (head, names, str, summary, ausentes, NA)
# FALSE = executa apenas o ETL
EXPLORAR = TRUE

pacotes = c("dplyr", "lubridate", "stringr", "stringi", "ggplot2", "here", "ISOcodes")
# Biblioteca pessoal (evita erro de permissão em /usr/local/lib/R/site-library)
lib_pessoal = Sys.getenv("R_LIBS_USER")
if (lib_pessoal == "") lib_pessoal = file.path(Sys.getenv("HOME"), "R", "library")
dir.create(lib_pessoal, showWarnings = FALSE, recursive = TRUE)
.libPaths(c(lib_pessoal, .libPaths()))
 
faltantes = setdiff(pacotes, rownames(installed.packages()))
if (length(faltantes) > 0) {
  # repos explícito: no Rscript (não interativo) o R não pergunta o espelho do CRAN
  install.packages(faltantes, lib = lib_pessoal, repos = "https://cloud.r-project.org")
}
invisible(lapply(pacotes, library, character.only = TRUE))
 


# ------------------------------------------------------------------------------
# 1. EXTRACT - IMPORTAÇÃO DO DATASET
# ------------------------------------------------------------------------------

# 1.1 Definir base
base_repo = here()

# 1.2 Verificar pasta
pasta_dados = file.path(base_repo, "gerador", "gerador", "output", "sujos")

if (!dir.exists(pasta_dados)){
  stop("A pasta não existe: ", pasta_dados)
}

# 1.3 Função para achar o CSV mais recente
encontrar_csv = function(pasta, padrao){
  arquivos = list.files(pasta, pattern = padrao, full.names = TRUE)

  if (length(arquivos) == 0){
    stop("Nenhum arquivo encontrado com o padrão '", padrao, "' em: ", pasta)
  }

  # Ordena pelo nome (o timestamp está no nome, então ordem alfabética = cronológica)
  sort(arquivos, decreasing = TRUE)[1]
}

# 1.4 Padrões e importação
padroes = c(
  compras       = "^compras_[0-9]{8}_.*\\.csv$",
  itens         = "^itens_[0-9]{8}_.*\\.csv$",
  itens_compras = "^itens_compra_[0-9]{8}_.*\\.csv$",
  jogadores     = "^jogadores_[0-9]+_[0-9]{8}_.*\\.csv$",
  partidas      = "^partidas_[0-9]{8}_.*\\.csv$",
  sessoes       = "^sessoes_[0-9]{8}_.*\\.csv$"
)

for (nome in names(padroes)){
  caminho = encontrar_csv(pasta_dados, padroes[[nome]])

  if (!file.exists(caminho)){
    stop("Arquivo não encontrado: ", caminho)
  }

  assign(nome, read.csv(caminho))
  message("Importado: ", basename(caminho), " -> ", nome)
}


# ------------------------------------------------------------------------------
# 2. ANÁLISE INICIAL E INVESTIGAÇÃO DE DADOS SUJOS (opcional: EXPLORAR = TRUE)
# ------------------------------------------------------------------------------

if (EXPLORAR) {

  datasets = list(Compras = compras, Itens = itens, Itens_Compras = itens_compras,
                  Jogadores = jogadores, Partidas = partidas, Sessões = sessoes)

  # head
  for (n in names(datasets)) { cat(n, ":\n"); print(head(datasets[[n]])); cat("\n") }

  # names
  for (n in names(datasets)) { cat(n, ":\n"); print(names(datasets[[n]])); cat("\n") }

  # str
  for (n in names(datasets)) { cat(n, ":\n"); str(datasets[[n]]); cat("\n") }

  # summary
  for (n in names(datasets)) { cat(n, ":\n"); print(summary(datasets[[n]])); cat("\n") }

  # Valores ausentes (strings vazias)
  for (n in names(datasets)) {
    cat("Valores ausentes -", n, ":\n")
    print(sum(datasets[[n]] == "", na.rm = TRUE))
    cat("\n")
  }

  cat("Média geral de Valores ausentes:\n")
  soma_vazios = c(
    sum(compras == "", na.rm = TRUE),
    sum(itens == "", na.rm = TRUE),
    sum(itens_compras == "", na.rm = TRUE),
    sum(jogadores == "", na.rm = TRUE),
    sum(partidas == "", na.rm = TRUE),
    sum(sessoes == "", na.rm = TRUE)
  )
  media_vazios = mean(soma_vazios)
  print(media_vazios)

  # Valores NA
  for (n in names(datasets)) {
    cat("Valores NA -", n, ":\n")
    print(sum(is.na(datasets[[n]])))
    cat("\n")
  }

  # Descontos inválidos (apenas visualização das linhas problemáticas)
  print(itens_compras |> filter(desconto < 0 | desconto > 1))
}

# Auditoria de descontos: sinaliza (não corrige) valores fora do intervalo [0, 1]
itens_compras = itens_compras |> mutate(
  desconto_invalido = desconto < 0 | desconto > 1
)

cat("Quantidade de descontos inválidos (bruto):\n")
print(sum(itens_compras$desconto_invalido, na.rm = TRUE))


# ------------------------------------------------------------------------------
# 3. TRANSFORM
# ------------------------------------------------------------------------------

# 3.1 Padronização de valores ausentes -----------------------------------------
limpa_nulos = function(df) {
  df[] = lapply(df, function(x) {
    x[x == "" | x == "NA" | x == "NULL"] = NA
    return(x)
  })
  return(df)
}

compras_nulos       = limpa_nulos(compras)
itens_nulos         = limpa_nulos(itens)
itens_compras_nulos = limpa_nulos(itens_compras)
jogadores_nulos     = limpa_nulos(jogadores)
partidas_nulos      = limpa_nulos(partidas)
sessoes_nulos       = limpa_nulos(sessoes)


# 3.2 Remoção de registros duplicados ------------------------------------------
compras_limpas       = compras_nulos       %>% distinct()
itens_limpos         = itens_nulos         %>% distinct()
itens_compras_limpos = itens_compras_nulos %>% distinct()
jogadores_limpos     = jogadores_nulos     %>% distinct()
partidas_limpas      = partidas_nulos      %>% distinct()
sessoes_limpas       = sessoes_nulos       %>% distinct()

cat("Quantidade de duplicadas removidas:\n")
print(c(compras       = nrow(compras)       - nrow(compras_limpas),
        itens         = nrow(itens)         - nrow(itens_limpos),
        itens_compras = nrow(itens_compras) - nrow(itens_compras_limpos),
        jogadores     = nrow(jogadores)     - nrow(jogadores_limpos),
        partidas      = nrow(partidas)      - nrow(partidas_limpas),
        sessoes       = nrow(sessoes)       - nrow(sessoes_limpas)))


# 3.3 Funções de padronização de textos e números ------------------------------
chave_texto = function(x) {
  x %>% as.character() %>% str_squish() %>% stri_trans_general("Latin-ASCII") %>% str_to_lower()
}

padronizar_categoria = function(x, validos, nome = "coluna") {
  idx = match(chave_texto(x), chave_texto(validos))
  out = ifelse(is.na(idx), str_squish(as.character(x)), validos[idx])
  fora_da_lista = unique(out[is.na(idx) & !is.na(x)])
  if (length(fora_da_lista) > 0) {
    cat("Atenção -", nome, "- valores fora da lista:", paste(fora_da_lista, collapse = ", "), "\n")
  }
  out
}

converter_numero = function(x) {
  as.numeric(str_replace(str_squish(as.character(x)), ",", "."))
}


# 3.4 Aplicação da padronização de textos e categorias -------------------------

# --- Sessões: plataforma e gênero ---
generos_jogo_validos = c("FPS", "RPG", "Ação", "Aventura", "Estratégia", "Corrida",
                         "Esportes", "MOBA", "Simulação", "Luta", "Survival")
plataformas_validas  = c("PC", "PlayStation", "Xbox", "Mobile")

sessoes_limpas = sessoes_limpas %>%
  mutate(
    plataforma  = padronizar_categoria(plataforma, plataformas_validas, "sessoes$plataforma"),
    genero_jogo = padronizar_categoria(genero_jogo, generos_jogo_validos, "sessoes$genero_jogo")
  )

# --- Partidas: resultado ---
resultados_validos = c("Vitória", "Derrota", "Empate")

partidas_limpas = partidas_limpas %>%
  mutate(resultado = padronizar_categoria(resultado, resultados_validos, "partidas$resultado"))

# --- Itens: nome, categoria, raridade e preço ---
categorias_validas = c("Skin", "Passe de batalha", "Moeda virtual", "Personagem", "Cosmético",
                       "DLC", "Boost", "Pacote", "Emote", "Acessório")
raridades_validas  = c("Comum", "Incomum", "Rara", "Épica", "Lendária")

nomes_validos = c(
  "Skin Dragão", "Skin Tempestade", "Skin Neon", "Skin Sombria", "Skin Vulcânica", "Skin Glacial",
  "Passe de Batalha Bronze", "Passe de Batalha Prata", "Passe de Batalha Ouro",
  "100 Moedas", "500 Moedas", "1000 Moedas", "2500 Moedas",
  "Personagem Guerreiro", "Personagem Mago", "Personagem Caçador", "Personagem Assassino",
  "Roupa Especial", "Capacete Especial", "Efeito Visual", "Pintura Especial",
  "Expansão Norte", "Expansão Sombria", "Expansão Final",
  "Boost de XP", "Boost de Moedas", "Boost de Progressão",
  "Pacote Inicial", "Pacote Premium", "Pacote Lendário",
  "Emote Dança", "Emote Vitória", "Emote Provocação",
  "Mochila Especial", "Pingente", "Bandeira", "Insígnia"
)

itens_limpos = itens_limpos %>%
  mutate(
    nome_item      = padronizar_categoria(nome_item, nomes_validos, "itens$nome_item"),
    categoria_item = padronizar_categoria(categoria_item, categorias_validas, "itens$categoria_item"),
    raridade       = padronizar_categoria(raridade, raridades_validas, "itens$raridade"),
    preco_base     = converter_numero(preco_base),

    # Preenche raridade ausente apenas quando o preço é inequívoco
    raridade = coalesce(raridade, case_when(
      near(preco_base, 4.90)  ~ "Comum",
      near(preco_base, 14.90) ~ "Incomum",
      near(preco_base, 24.90) ~ "Rara",
      near(preco_base, 39.90) ~ "Épica",
      near(preco_base, 59.90) ~ "Lendária",
      near(preco_base, 79.90) ~ "Lendária",
      TRUE ~ NA_character_
    ))
  )

# --- Itens de compra: conversão numérica ---
# A flag de desconto inválido é recalculada após a conversão, pois os valores
# podem ter chegado como texto (ex.: vírgula decimal).
itens_compras_limpos = itens_compras_limpos %>%
  mutate(across(c(valor_unitario, desconto, valor_total_item), converter_numero)) %>%
  mutate(desconto_invalido = desconto < 0 | desconto > 1)

# --- Jogadores: gênero, país e cidade ---
# Lista de países permitidos
paises_validos = c("Brasil", "Estados Unidos", "Portugal", "Espanha", "França", "Alemanha",
                   "Itália", "Reino Unido", "Canadá", "Austrália", "México", "Argentina")

# Lista de gêneros aceitos
generos_validos = c("Masculino", "Feminino")

# Partículas que devem permanecer em minúsculo nos nomes de cidades
particulas_cidade = c("de", "da", "do", "das", "dos", "del", "della", "di", "du", "la", "le",
                      "les", "los", "las", "of", "the", "von", "van", "der", "den")

# Formata o nome das cidades no estilo "Título" (ex.: "rio de janeiro" -> "Rio de Janeiro")
titulo_cidade = function(x) {
  # Expressão regular para encontrar as partículas isoladas por espaços ou hifens
  padrao = paste0("(?<=[ -])(", paste(particulas_cidade, collapse = "|"), ")(?=[ -])")

  x %>%
    str_to_lower() %>%                                               # tudo minúsculo
    str_to_title() %>%                                               # inicial maiúscula em cada palavra
    str_replace_all(regex(padrao, ignore_case = TRUE), str_to_lower) # devolve as partículas para minúsculo
}

# Dicionário de referência: cidades que já possuem grafia mista (nem tudo maiúsculo, nem tudo minúsculo)
ref_cidades = jogadores_limpos %>%
  filter(!is.na(cidade)) %>%
  mutate(cidade = str_squish(cidade)) %>%
  filter(cidade != str_to_upper(cidade),
         cidade != str_to_lower(cidade)) %>%
  mutate(chave = str_to_lower(cidade)) %>%
  count(chave, cidade) %>%
  arrange(chave, desc(n)) %>%
  distinct(chave, .keep_all = TRUE)                                  # mantém a grafia mais frequente

jogadores_limpos = jogadores_limpos %>%
  mutate(
    cidade = str_squish(cidade),
    chave_cidade = str_to_lower(cidade),

    # Usa a grafia de referência; se não houver, aplica titulo_cidade()
    cidade = coalesce(ref_cidades$cidade[match(chave_cidade, ref_cidades$chave)], titulo_cidade(cidade)),

    genero = padronizar_categoria(genero, generos_validos, "jogadores$genero"),
    pais   = padronizar_categoria(pais, paises_validos, "jogadores$pais")
  ) %>%
  select(-chave_cidade)


# 3.5 Correção de datas --------------------------------------------------------
# Observação: a versão anterior (candidatas/resolve_data/dif_min) foi substituída
# por estas funções. Elas exigem que as colunas de data ainda sejam texto.

# Interpreta cada data em três formatos: ISO (aaaa-mm-dd), DMY e MDY.
# Não escolhe a correta; apenas gera as candidatas.
datas_corrigidas = function(x, hora = FALSE, tz = "UTC") {

  x = str_squish(x)
  n = length(x)
  sufixo = if (hora) " %H:%M:%S" else ""

  ler = function(padrao, formato, trocar_hifen = FALSE) {

    idx = which(grepl(padrao, x))
    segundos = rep(NA_real_, n)

    if (length(idx) > 0) {
      txt = x[idx]

      # 03-05-2024 passa a ser 03/05/2024
      if (trocar_hifen) txt = chartr("-", "/", txt)

      segundos[idx] = as.numeric(
        fast_strptime(txt, paste0(formato, sufixo), tz = tz, lt = FALSE)
      )
    }

    out = as.POSIXct(segundos, origin = "1970-01-01", tz = tz)
    if (hora) out else as.Date(out)
  }

  list(
    iso = ler("^[0-9]{4}-[0-9]{2}-[0-9]{2}", "%Y-%m-%d"),
    dmy = ler("^[0-9]{2}[/-][0-9]{2}[/-][0-9]{4}", "%d/%m/%Y", trocar_hifen = TRUE),
    mdy = ler("^[0-9]{2}/[0-9]{2}/[0-9]{4}", "%m/%d/%Y")
  )
}

# Garante que as colunas ainda são texto (evita reconverter colunas já tratadas)
exigir_texto = function(df, colunas) {
  for (col in colunas) {
    if (!is.character(df[[col]])) {
      stop(
        "A coluna '", col,
        "' já foi convertida. Rode esta etapa a partir do objeto com as datas em texto.",
        call. = FALSE
      )
    }
  }
}

# Segundos desde 01/01/1970 -> data e hora
segundos_para_posix = function(s, tz = "UTC") {
  as.POSIXct(s, origin = "1970-01-01", tz = tz)
}

# Uma data é ambígua quando DMY e MDY são válidas e diferentes (e não há ISO)
eh_ambigua = function(cand) {
  is.na(cand$iso) &
    !is.na(cand$dmy) &
    !is.na(cand$mdy) &
    cand$dmy != cand$mdy
}


# --- Sessões e Partidas: referência = duracao_minutos ---
# Testa as 9 combinações de leitura (ISO, dd/mm, mm/dd do início x as três do fim)
# e escolhe a que bate com duracao_minutos.
resolve_por_duracao = function(ini_txt, fim_txt, duracao, tz = "UTC") {

  ci = datas_corrigidas(ini_txt, hora = TRUE, tz = tz)
  cf = datas_corrigidas(fim_txt, hora = TRUE, tz = tz)

  # Coluna 1: ISO; coluna 2: DMY; coluna 3: MDY
  ini_num = cbind(as.numeric(ci$iso), as.numeric(ci$dmy), as.numeric(ci$mdy))
  fim_num = cbind(as.numeric(cf$iso), as.numeric(cf$dmy), as.numeric(cf$mdy))

  # 3 formatos para o início x 3 para o fim
  combos = expand.grid(i = 1:3, f = 1:3)

  # Erro de cada combinação em relação à duração informada
  erros = matrix(
    vapply(seq_len(nrow(combos)), function(k) {
      abs((fim_num[, combos$f[k]] - ini_num[, combos$i[k]]) / 60 - duracao)
    }, numeric(length(duracao))),
    nrow = length(duracao)
  )

  # Combinações com valores ausentes não podem ser escolhidas
  erros[is.na(erros)] = Inf

  # Combinação de menor erro em cada linha
  melhor = max.col(-erros, ties.method = "first")
  pos = seq_along(melhor)
  erro = erros[cbind(pos, melhor)]

  ini = ini_num[cbind(pos, combos$i[melhor])]
  fim = fim_num[cbind(pos, combos$f[melhor])]

  # Sem combinação validável: prioriza ISO, depois DMY e por último MDY
  sem_ref = is.infinite(erro)
  ini[sem_ref] = dplyr::coalesce(ini_num[, 1], ini_num[, 2], ini_num[, 3])[sem_ref]
  fim[sem_ref] = dplyr::coalesce(fim_num[, 1], fim_num[, 2], fim_num[, 3])[sem_ref]

  list(
    ini = segundos_para_posix(ini, tz),
    fim = segundos_para_posix(fim, tz),
    erro = erro,
    ambigua = eh_ambigua(ci) | eh_ambigua(cf)
  )
}

corrigir_datas_sessoes = function(sessoes) {

  exigir_texto(sessoes, c("data_inicio_sessao", "data_fim_sessao"))

  r = resolve_por_duracao(
    sessoes$data_inicio_sessao,
    sessoes$data_fim_sessao,
    sessoes$duracao_minutos
  )

  cat(
    "Sessões - linhas com data ambígua:", sum(r$ambigua),
    "| resolvidas pela duração:", sum(r$ambigua & r$erro <= 0.5),
    "| sem combinação compatível:", sum(r$erro > 0.5), "\n"
  )

  sessoes %>%
    mutate(
      data_inicio_sessao = r$ini,
      data_fim_sessao = r$fim
    )
}

corrigir_datas_partidas = function(partidas) {

  exigir_texto(partidas, c("data_inicio_partida", "data_fim_partida"))

  r = resolve_por_duracao(
    partidas$data_inicio_partida,
    partidas$data_fim_partida,
    partidas$duracao_minutos
  )

  cat(
    "Partidas - linhas com data ambígua:", sum(r$ambigua),
    "| resolvidas pela duração:", sum(r$ambigua & r$erro <= 0.5),
    "| sem combinação compatível:", sum(r$erro > 0.5), "\n"
  )

  partidas %>%
    mutate(
      data_inicio_partida = r$ini,
      data_fim_partida = r$fim
    )
}


# --- Compras: referência = intervalo da sessão ---
# A compra sempre acontece dentro do intervalo da sua sessão. Para datas ambíguas,
# vale a leitura que cabe nesse intervalo. Se nenhuma ou as duas couberem, assume dd/mm.
# Requer que `sessoes` já tenha as datas corrigidas.
corrigir_datas_compras = function(compras, sessoes) {

  exigir_texto(compras, "data_compra")

  cand = datas_corrigidas(compras$data_compra, hora = TRUE)

  n_iso = as.numeric(cand$iso)
  n_dmy = as.numeric(cand$dmy)
  n_mdy = as.numeric(cand$mdy)

  # Sessão correspondente a cada compra
  pos_sessao = match(compras$sessao_id, sessoes$sessao_id)

  ini_n = as.numeric(sessoes$data_inicio_sessao[pos_sessao])
  fim_n = as.numeric(sessoes$data_fim_sessao[pos_sessao])

  dentro = function(x) {
    !is.na(x) &
      !is.na(ini_n) &
      x >= ini_n &
      x <= fim_n
  }

  # Prioridade: ISO > DMY dentro da sessão > MDY dentro da sessão > DMY > MDY
  nova = ifelse(
    !is.na(n_iso), n_iso,
    ifelse(
      dentro(n_dmy), n_dmy,
      ifelse(
        dentro(n_mdy), n_mdy,
        ifelse(!is.na(n_dmy), n_dmy, n_mdy)
      )
    )
  )

  amb = eh_ambigua(cand)

  cat(
    "Compras - datas ambíguas:", sum(amb),
    "| resolvidas pela sessão:",
    sum(amb & (dentro(n_dmy) != dentro(n_mdy))),
    "| ainda ambíguas (assumido dd/mm):",
    sum(amb & (dentro(n_dmy) == dentro(n_mdy))), "\n"
  )

  compras %>%
    mutate(data_compra = segundos_para_posix(nova))
}


# --- Jogadores ---
# data_nascimento : a idade calculada na data de referência deve ser igual a `idade`.
# data_criacao_conta: a conta é criada depois dos 13 anos do jogador, depois de
#                     2010-01-01 e antes da primeira sessão.
# data_ref é a data em que o gerador rodou (pelo nome dos arquivos, 2026-10-19).

# Idade completa em uma data de referência
idade_em = function(nasc, ref) {
  anos = as.numeric(format(ref, "%Y")) - as.numeric(format(nasc, "%Y"))
  anos - (format(nasc, "%m%d") > format(ref, "%m%d"))
}

# Requer que `sessoes` já tenha as datas corrigidas.
corrigir_datas_jogadores = function(
  jogadores,
  sessoes,
  data_ref = as.Date("2026-10-19")
) {

  exigir_texto(jogadores, c("data_nascimento", "data_criacao_conta"))

  n = nrow(jogadores)
  pos = seq_len(n)

  # ---- PARTE 1: data de nascimento ----
  cn = datas_corrigidas(jogadores$data_nascimento, hora = FALSE)

  num_n = cbind(as.numeric(cn$iso), as.numeric(cn$dmy), as.numeric(cn$mdy))

  # Diferença entre a idade de cada interpretação e a idade informada
  erros_n = matrix(
    unlist(
      lapply(cn, function(d) {
        abs(idade_em(d, data_ref) - jogadores$idade)
      })
    ),
    nrow = n
  )

  erros_n[is.na(erros_n)] = Inf

  melhor_n = max.col(-erros_n, ties.method = "first")
  nasc_num = num_n[cbind(pos, melhor_n)]

  # Sem referência válida: prioriza ISO, DMY e MDY
  sem_ref = is.infinite(erros_n[cbind(pos, melhor_n)])
  nasc_num[sem_ref] = dplyr::coalesce(num_n[, 1], num_n[, 2], num_n[, 3])[sem_ref]

  nasc = as.Date(nasc_num, origin = "1970-01-01")

  # Conferência: % das datas ISO cuja idade bate com `idade`
  iso_ok = !is.na(cn$iso)
  pct_ok = mean(
    idade_em(cn$iso[iso_ok], data_ref) == jogadores$idade[iso_ok],
    na.rm = TRUE
  )

  amb_n = eh_ambigua(cn)

  cat(
    "Nascimento - conferência (datas ISO que batem com idade):",
    round(100 * pct_ok, 1), "%\n"
  )

  cat(
    "Nascimento - datas ambíguas:", sum(amb_n),
    "| resolvidas pela idade:",
    sum(amb_n & (erros_n[, 2] != erros_n[, 3])),
    "| ainda ambíguas (assumido dd/mm):",
    sum(amb_n & (erros_n[, 2] == erros_n[, 3])), "\n"
  )

  # ---- PARTE 2: data de criação da conta ----
  cc = datas_corrigidas(jogadores$data_criacao_conta, hora = FALSE)

  c_iso = as.numeric(cc$iso)
  c_dmy = as.numeric(cc$dmy)
  c_mdy = as.numeric(cc$mdy)

  # Limite inferior: 13 anos de idade e 2010-01-01
  lim_inf = pmax(
    as.numeric(nasc %m+% years(13)),
    as.numeric(as.Date("2010-01-01")),
    na.rm = TRUE
  )

  # Limite superior: primeira sessão do jogador, e nunca depois de data_ref
  prim = tapply(
    as.numeric(as.Date(sessoes$data_inicio_sessao)),
    sessoes$player_id,
    min,
    na.rm = TRUE
  )

  lim_sup = as.numeric(prim[as.character(jogadores$player_id)])
  lim_sup = pmin(lim_sup, as.numeric(data_ref), na.rm = TRUE)

  dentro = function(x) {
    !is.na(x) &
      x >= lim_inf &
      x <= lim_sup
  }

  # Prioridade: ISO > DMY dentro dos limites > MDY dentro dos limites > DMY > MDY
  cria = ifelse(
    !is.na(c_iso), c_iso,
    ifelse(
      dentro(c_dmy), c_dmy,
      ifelse(
        dentro(c_mdy), c_mdy,
        ifelse(!is.na(c_dmy), c_dmy, c_mdy)
      )
    )
  )

  amb_c = eh_ambigua(cc)

  cat(
    "Criação da conta - datas ambíguas:", sum(amb_c),
    "| resolvidas pelos limites:",
    sum(amb_c & (dentro(c_dmy) != dentro(c_mdy))),
    "| ainda ambíguas (assumido dd/mm):",
    sum(amb_c & (dentro(c_dmy) == dentro(c_mdy))), "\n"
  )

  jogadores %>%
    mutate(
      data_nascimento = nasc,
      data_criacao_conta = as.Date(cria, origin = "1970-01-01")
    )
}


# 3.6 Aplicação da correção de datas -------------------------------------------
# Ordem importa: sessões primeiro, pois compras e jogadores dependem delas.
sessoes_limpas   = corrigir_datas_sessoes(sessoes_limpas)
partidas_limpas  = corrigir_datas_partidas(partidas_limpas)
compras_limpas   = corrigir_datas_compras(compras_limpas, sessoes_limpas)
jogadores_limpos = corrigir_datas_jogadores(jogadores_limpos, sessoes_limpas)


# 3.7 Correção de estados (siglas ISO 3166-2) ----------------------------------
# Para cada linha, usando o `pais` como chave:
# 1. Se o `estado` já é uma sigla válida daquele país (pacote ISOcodes), só
#    padroniza para maiúsculo e sem espaços.
# 2. Se é um nome por extenso, procura no dicionário `dic_estados`.
# 3. Se não achar, mantém o texto e lista no console para completar o dicionário.

# Nome do país -> código ISO de 2 letras
pais_para_iso = c(
  "Brasil" = "BR", "Estados Unidos" = "US", "Portugal" = "PT", "Espanha" = "ES",
  "França" = "FR", "Alemanha" = "DE", "Itália" = "IT", "Reino Unido" = "GB",
  "Canadá" = "CA", "Austrália" = "AU", "México" = "MX", "Argentina" = "AR"
)

# Busca o código ISO do país ignorando maiúsculas/minúsculas e acentos
iso_do_pais = function(pais) {
  tabela = setNames(pais_para_iso, chave_texto(names(pais_para_iso)))
  unname(tabela[chave_texto(pais)])
}

# Siglas oficiais válidas por país, no formato "ISO_PAIS SIGLA_ESTADO" (ex.: "BR SP")
siglas_validas = ISOcodes::ISO_3166_2 %>%
  filter(str_sub(Code, 1, 2) %in% pais_para_iso) %>%
  transmute(chave = paste(str_sub(Code, 1, 2), str_sub(Code, 4))) %>%
  pull(chave)

# Dicionário: múltiplas grafias de nomes -> sigla padrão
dic_estados = tribble(
  ~pais_iso, ~sigla, ~nomes,
  # Brasil
  "BR", "DF", "Federal District|Distrito Federal",
  # Reino Unido
  "GB", "ENG", "England",
  "GB", "SCT", "Scotland",
  "GB", "WLS", "Wales|Cymru",
  "GB", "NIR", "Northern Ireland",
  # Alemanha
  "DE", "BW", "Baden-Württemberg|Baden-Wuerttemberg",
  "DE", "BY", "Bavaria|Bayern",
  "DE", "BE", "Berlin|State of Berlin",
  "DE", "BB", "Brandenburg",
  "DE", "HB", "Bremen",
  "DE", "HH", "Hamburg",
  "DE", "HE", "Hesse|Hessen",
  "DE", "MV", "Mecklenburg-Vorpommern|Mecklenburg-West Pomerania",
  "DE", "NI", "Lower Saxony|Niedersachsen",
  "DE", "NW", "North Rhine-Westphalia|Nordrhein-Westfalen",
  "DE", "RP", "Rheinland-Pfalz|Rhineland-Palatinate",
  "DE", "SL", "Saarland",
  "DE", "SN", "Saxony|Sachsen",
  "DE", "ST", "Saxony-Anhalt|Sachsen-Anhalt",
  "DE", "SH", "Schleswig-Holstein",
  "DE", "TH", "Thuringia|Thüringen",
  # França
  "FR", "ARA", "Auvergne-Rhône-Alpes|Rhône-Alpes|Auvergne",
  "FR", "BFC", "Bourgogne-Franche-Comté|Bourgogne|Franche-Comté",
  "FR", "BRE", "Brittany|Bretagne",
  "FR", "CVL", "Centre-Val de Loire|Centre",
  "FR", "COR", "Corsica|Corse",
  "FR", "GES", "Grand Est|Alsace|Champagne-Ardenne|Lorraine",
  "FR", "HDF", "Hauts-de-France|Nord-Pas-de-Calais|Picardie",
  "FR", "IDF", "Île-de-France",
  "FR", "NOR", "Normandy|Normandie|Basse-Normandie|Haute-Normandie",
  "FR", "NAQ", "Nouvelle-Aquitaine|New Aquitaine|Aquitaine|Limousin|Poitou-Charentes",
  "FR", "OCC", "Occitania|Occitanie|Languedoc-Roussillon|Midi-Pyrénées",
  "FR", "PDL", "Pays de la Loire",
  "FR", "PAC", "Provence-Alpes-Côte d'Azur",
  # Espanha
  "ES", "AN", "Andalusia|Andalucía",
  "ES", "AR", "Aragon|Aragón",
  "ES", "AS", "Asturias|Principality of Asturias|Principado de Asturias",
  "ES", "IB", "Balearic Islands|Illes Balears|Islas Baleares",
  "ES", "PV", "Basque Country|País Vasco|Euskadi",
  "ES", "CN", "Canary Islands|Canarias|Islas Canarias",
  "ES", "CB", "Cantabria",
  "ES", "CM", "Castille-La Mancha|Castilla-La Mancha|Castile-La Mancha",
  "ES", "CL", "Castille and León|Castilla y León|Castile and León|Castile and Leon",
  "ES", "CT", "Catalonia|Cataluña|Catalunya",
  "ES", "CE", "Ceuta",
  "ES", "EX", "Extremadura",
  "ES", "GA", "Galicia",
  "ES", "RI", "La Rioja",
  "ES", "MD", "Madrid|Comunidad de Madrid",
  "ES", "ME", "Melilla",
  "ES", "MC", "Murcia|Región de Murcia",
  "ES", "NC", "Navarre|Navarra",
  "ES", "VC", "Valencia|Comunidad Valenciana|Comunitat Valenciana",
  # Itália
  "IT", "21", "Piedmont|Piemonte",
  "IT", "23", "Aosta Valley|Valle d'Aosta",
  "IT", "25", "Lombardy|Lombardia",
  "IT", "32", "Trentino-Alto Adige|Trentino-Südtirol",
  "IT", "34", "Veneto",
  "IT", "36", "Friuli Venezia Giulia|Friuli-Venezia Giulia",
  "IT", "42", "Liguria",
  "IT", "45", "Emilia-Romagna",
  "IT", "52", "Tuscany|Toscana",
  "IT", "55", "Umbria",
  "IT", "57", "Marche|The Marches",
  "IT", "62", "Latium|Lazio",
  "IT", "65", "Abruzzo",
  "IT", "67", "Molise",
  "IT", "72", "Campania",
  "IT", "75", "Apulia|Puglia",
  "IT", "77", "Basilicate|Basilicata",
  "IT", "78", "Calabria",
  "IT", "82", "Sicily|Sicilia",
  "IT", "88", "Sardinia|Sardegna",
  # Portugal
  "PT", "01", "Aveiro",
  "PT", "02", "Beja",
  "PT", "03", "Braga",
  "PT", "04", "Bragança|Braganca",
  "PT", "05", "Castelo Branco",
  "PT", "06", "Coimbra",
  "PT", "07", "Évora",
  "PT", "08", "Faro",
  "PT", "09", "Guarda",
  "PT", "10", "Leiria",
  "PT", "11", "Lisbon|Lisboa",
  "PT", "12", "Portalegre",
  "PT", "13", "Porto",
  "PT", "14", "Santarém",
  "PT", "15", "Setúbal",
  "PT", "16", "Viana do Castelo",
  "PT", "17", "Vila Real",
  "PT", "18", "Viseu",
  "PT", "20", "Azores|Açores|Região Autónoma dos Açores",
  "PT", "30", "Madeira|Região Autónoma da Madeira",
  # México
  "MX", "AGU", "Aguascalientes",
  "MX", "BCN", "Baja California",
  "MX", "BCS", "Baja California Sur",
  "MX", "CAM", "Campeche",
  "MX", "CHP", "Chiapas",
  "MX", "CHH", "Chihuahua",
  "MX", "CMX", "Mexico City|Ciudad de México|Distrito Federal",
  "MX", "COA", "Coahuila|Coahuila de Zaragoza",
  "MX", "COL", "Colima",
  "MX", "DUR", "Durango",
  "MX", "GUA", "Guanajuato",
  "MX", "GRO", "Guerrero",
  "MX", "HID", "Hidalgo",
  "MX", "JAL", "Jalisco",
  "MX", "MEX", "México|Estado de México|State of Mexico",
  "MX", "MIC", "Michoacán|Michoacán de Ocampo",
  "MX", "MOR", "Morelos",
  "MX", "NAY", "Nayarit",
  "MX", "NLE", "Nuevo León",
  "MX", "OAX", "Oaxaca",
  "MX", "PUE", "Puebla",
  "MX", "QUE", "Querétaro|Querétaro de Arteaga",
  "MX", "ROO", "Quintana Roo",
  "MX", "SLP", "San Luis Potosí",
  "MX", "SIN", "Sinaloa",
  "MX", "SON", "Sonora",
  "MX", "TAB", "Tabasco",
  "MX", "TAM", "Tamaulipas",
  "MX", "TLA", "Tlaxcala",
  "MX", "VER", "Veracruz|Veracruz de Ignacio de la Llave",
  "MX", "YUC", "Yucatán",
  "MX", "ZAC", "Zacatecas",
  # Argentina
  "AR", "A", "Salta",
  "AR", "B", "Buenos Aires|Provincia de Buenos Aires",
  "AR", "C", "Ciudad Autónoma de Buenos Aires|Buenos Aires F.D.|Buenos Aires Federal District|Capital Federal",
  "AR", "D", "San Luis",
  "AR", "E", "Entre Ríos",
  "AR", "F", "La Rioja",
  "AR", "G", "Santiago del Estero",
  "AR", "H", "Chaco",
  "AR", "J", "San Juan",
  "AR", "K", "Catamarca",
  "AR", "L", "La Pampa",
  "AR", "M", "Mendoza",
  "AR", "N", "Misiones",
  "AR", "P", "Formosa",
  "AR", "Q", "Neuquén",
  "AR", "R", "Río Negro",
  "AR", "S", "Santa Fe",
  "AR", "T", "Tucumán",
  "AR", "U", "Chubut",
  "AR", "V", "Tierra del Fuego",
  "AR", "W", "Corrientes",
  "AR", "X", "Córdoba",
  "AR", "Y", "Jujuy",
  "AR", "Z", "Santa Cruz"
)

# Dicionário em formato longo: uma grafia por linha
partes = strsplit(dic_estados$nomes, "|", fixed = TRUE)

dic_long = data.frame(
  pais_iso = rep(dic_estados$pais_iso, lengths(partes)),
  sigla    = rep(dic_estados$sigla, lengths(partes)),
  chave    = chave_texto(unlist(partes)),
  stringsAsFactors = FALSE
) %>% distinct(pais_iso, chave, sigla)

# Integridade: uma mesma chave não pode apontar para siglas diferentes no mesmo país
conflitos = dic_long %>% group_by(pais_iso, chave) %>% filter(n_distinct(sigla) > 1)
stopifnot(nrow(conflitos) == 0)

# Vetor nomeado para busca rápida. Ex.: "BR distrito federal" = "DF"
dic_vec = setNames(dic_long$sigla, paste(dic_long$pais_iso, dic_long$chave))

corrigir_estados = function(df) {
  iso      = iso_do_pais(df$pais)
  estado   = str_squish(df$estado)
  sigla_up = str_to_upper(estado)

  # Já é uma sigla válida (ISOcodes)?
  ja_sigla = !is.na(estado) & !is.na(iso) & paste(iso, sigla_up) %in% siglas_validas

  # Caso contrário, busca pelo nome no dicionário
  por_nome = unname(dic_vec[paste(iso, chave_texto(estado))])

  novo          = ifelse(ja_sigla, sigla_up, por_nome)
  nao_resolvido = !is.na(estado) & is.na(novo)

  cat("Estado - já era sigla:", sum(ja_sigla),
      "| convertidos pelo dicionário:", sum(!is.na(novo) & !ja_sigla),
      "| não resolvidos:", sum(nao_resolvido), "\n")

  # Lista os não resolvidos para manutenção do dicionário
  if (any(nao_resolvido)) {
    cat("\nNão resolvidos (adicione em dic_estados):\n")
    print(count(data.frame(pais = df$pais[nao_resolvido], estado = estado[nao_resolvido]),
                pais, estado))
  }

  return(novo)
}

jogadores_limpos$estado = corrigir_estados(jogadores_limpos)


# ------------------------------------------------------------------------------
# 4. VALIDAÇÃO (a desenvolver - Etapa 5 do relatório)
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# 5. LOAD - EXPORTAÇÃO DOS DATASETS LIMPOS
# ------------------------------------------------------------------------------

pasta_saida = file.path(base_repo, "gerador", "gerador", "output", "limpos")
dir.create(pasta_saida, showWarnings = FALSE, recursive = TRUE)

saidas = list(
  compras       = compras_limpas,
  itens         = itens_limpos,
  itens_compras = itens_compras_limpos,
  jogadores     = jogadores_limpos,
  partidas      = partidas_limpas,
  sessoes       = sessoes_limpas
)

for (nome in names(saidas)) {
  destino = file.path(pasta_saida, paste0(nome, "_limpo.csv"))
  write.csv(saidas[[nome]], destino, row.names = FALSE, fileEncoding = "UTF-8")
  message("Exportado: ", destino)
}


# ------------------------------------------------------------------------------
# 6. GRÁFICOS (a desenvolver - Etapa 6 do relatório, com ggplot2)
# ------------------------------------------------------------------------------