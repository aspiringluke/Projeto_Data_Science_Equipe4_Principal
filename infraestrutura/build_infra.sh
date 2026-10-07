#!/usr/bin/bash

case $TERM in
xterm-color | *-256color)
    error_color='\e[01;31m'
    warn_color='\e[01;33m'
    ok_color='\e[01;32m'
    default_color='\e[0m'
    ;;
esac

SCRIPT_NAME=${0##*/}
VERSION="$SCRIPT_NAME: 0.1 - Equipe 4"
HELP_MSG="
$VERSION

Este script verifica e prepara o ambiente para executar a infraestrutura.
Opções:

  -h, --help                    Mostra essa página de ajuda
  -v, --version                 Mostra a versão atual
  -p, --plan-only               Apenas planeja, não aplica
  -r, --rebuild                 Destrói a infraestrutura existente sem perguntar
"

###############
##  FUNÇÕES  ##
###############

msg()
{
    echo
    for i in "$@"; do echo -e "$i"; done
    echo
}



#########################
##  PARSING DE OPÇÕES  ##
#########################

for arg in "$@"; do
    if [[ "${arg:0:2}" = "--" ]]; then
        opt=${arg:2}
        case $opt in
            help)
                echo "$HELP_MSG"
                exit 0
                ;;
            version)
                echo "$VERSION"
                exit 0
                ;;
            plan-only)
                PLAN_ONLY=1
                ;;
            rebuild)
                REBUILD=1
                ;;
            *)
                echo Opção desconhecida
                exit 1
                ;;
        esac
    elif [[ "${arg:0:1}" = "-" ]]; then
        opt=${arg:1}
        case $opt in
            h)
                echo "$HELP_MSG"
                exit 0
                ;;
            v)
                echo "$VERSION"
                exit 0
                ;;
            p)
                PLAN_ONLY=1
                ;;
            r)
                REBUILD=1
                ;;
            *)
                echo Opção desconhecida
                exit 1
                ;;
        esac
    fi
done



###########################
##  CONSTRUINDO A INFRA  ##
###########################

if [[ REBUILD -eq 1 ]]; then
    cd iac
    echo yes | tofu destroy

    for i in {1..255}; do ssh-keygen -R 192.168.122.${i}; done > /dev/null 2>&1

    cd ..
    ./build_infra.sh
fi


cd iac

if [[ ! -f "cloud_init.cfg" || ! -f "main.tf" ]]; then
    msg "${error_color}ERROR: Os arquivos necessários para executar a infraestrutura não foram encontrados neste diretório. Abortando${default_color}"
    exit 1
fi

msg "Baixando providers"
tofu init
msg "${ok_color}OK: Providers baixados${default_color}"

msg "Validando..."
tofu validate
[[ $? -ne 0 ]] && msg "${error_color}ERROR: Validação falhou${default_color}" && exit 1

msg "Planejando..."
tofu plan -out=tofu_plan
[[ $? -ne 0 ]] && msg "${error_color}ERROR: Planejamento falhou${default_color}" && exit 1
msg "${ok_color}OK: Planejamento feito${default_color}"

if [[ PLAN_ONLY -ne 1 ]]; then
    msg "Aplicando o plano..."
    tofu apply tofu_plan
    [[ $? -ne 0 ]] && msg "${error_color}ERROR: Algo deu errado${default_color}" && exit 1
    msg "${ok_color}SUCCESS: Infraestrutura construída.${default_color}"
    msg "Teste o acesso com: ssh aluno@192.168.122.X -i ~/.ssh/devops_lab"
fi
