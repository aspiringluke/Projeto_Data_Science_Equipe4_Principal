#!/usr/bin/bash

for vm in vm-gerador-python vm-tratamento-R;
do
    if ! virsh destroy $vm; then
        echo Algo deu errado ao desligar a VM $vm
    fi
done