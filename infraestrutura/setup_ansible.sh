#!/usr/bin/bash

case $TERM in
xterm-color | *-256color)
    error_color='\e[01;31m'
    warn_color='\e[01;33m'
    ok_color='\e[01;32m'
    default_color='\e[0m'
    ;;
esac

msg()
{
    echo
    for i in "$@"; do echo -e "$i"; done
    echo
}

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
    sleep 4
    ansible all -i ansible/inventory.ini -m ping --private-key ~/.ssh/devops_lab
    if [[ $? -eq 0 ]]; then finished=true; fi
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
msg "Executando playbook..."
ansible-playbook ansible/playbook.yml -i ansible/inventory.ini --private-key ~/.ssh/devops_lab
cod_erro=$?
if [[ cod_erro -ne 0 ]]; then
    msg "${error_color}ERROR: Houve um erro ao executar o playbook${default_color}"
    exit $cod_erro
fi

msg "${ok_color}OK: Playbook executado"
msg "SUCCESS: As VMs estão configuradas."