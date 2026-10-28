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
VERSION="$SCRIPT_NAME: 0.9 - Equipe 4"
HELP_MSG="
$VERSION

Este script verifica e prepara o ambiente para executar a infraestrutura.
Opções:

  -h, --help                    Mostra essa página de ajuda
  -v, --version                 Mostra a versão atual
  -s, --skip-checks             Pula as verificações de conexão e sintaxe

Opções de teste de conexão:

  XX, --wait=N                  Espera N segundos entre verificações de conexão. Padrão: 5
  XX, --retry=N                 Tenta a conexão N vezes. Padrão: 7

(As opções curtas dos teste de conexão ainda não foram implementadas)
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
            skip-checks)
                SKIP_CHECKS=1
                ;;
            wait*)
                WAIT=${opt##*=}
                ;;
            retry*)
                RETRY=${opt##*=}
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
            s)
                SKIP_CHECKS=1
                ;;
            w)
                echo "TODO: opção -w"
                exit 0
                ;;
            r)
                echo "TODO: opção -r"
                exit 0
                ;;
            *)
                echo Opção desconhecida
                exit 1
                ;;
        esac
    fi
done

if [[ -z "${WAIT}" ]]; then WAIT=5; fi
if [[ -z "${RETRY}" ]]; then RETRY=7; fi



###############
##  ANSIBLE  ##
###############

if [[ -z "$SKIP_CHECKS" ]]; then
    # Essa parte fica tentando conectar nas VMs indefinidamente, porque elas podem
    # demorar pra ligar e abrir as portas. É uma gambiarra feia, mas funciona.
    # 
    # Também é a única parte que não é 100% automática, pois o SSH exige que você
    # confie manualmente nas VMs digitando "yes" duas vezes quando for solicitado.
    # Eu tentei passar o input automaticamente via pipe, mas por alguma razão ele
    # não lê, e fica esperando a entrada do teclado.
    # Bom, por enquanto, apenas lembre-se de digitar yes nas duas vezes em que for
    # pedido
    while [[ -z "$finished" ]]; do
        msg "${warn_color}Verificando a conectividade dos hosts...${default_color}"
        sleep $WAIT
        ansible all -i ansible/inventory.ini -m ping --private-key ~/.ssh/devops_lab
        exit_code=$?
        ((RETRY--))
        if [[ $exit_code -eq 0 ]]; then finished=true; continue; fi
        if [[ $RETRY -lt 0 ]]; then msg "${warn_color}Limite de tentativas atingido${default_color}"; exit 1; fi
    done
    # cod_erro=$?
    # if [[ cod_erro -ne 0 ]]; then
    #     msg "${error_color}ERROR: Não foi possível conectar com os hosts, abortando${default_color}"
    #     exit $cod_erro
    # fi

    msg "${ok_color}OK: Conexão estabelecida${default_color}"
    msg "Verificando sintaxe do playbook..."
    ansible-playbook ansible/playbook.yml -i ansible/inventory.ini --syntax-check
    cod_erro=$?
    if [[ cod_erro -ne 0 ]]; then
        msg "${error_color}ERROR: A sintaxe do playbook está incorreta. Corrija-a antes de prosseguir${default_color}"
        exit $cod_erro
    fi

    msg "${ok_color}OK: Sintaxe do playbook correta.${default_color}"
fi

msg "Executando playbook..."
ansible-playbook ansible/playbook.yml -i ansible/inventory.ini --private-key ~/.ssh/devops_lab
cod_erro=$?
if [[ cod_erro -ne 0 ]]; then
    msg "${error_color}ERROR: Houve um erro ao executar o playbook${default_color}"
    exit $cod_erro
fi

msg "${ok_color}OK: Playbook executado"
msg "SUCCESS: As VMs estão configuradas."