# Infraestrutura

IaC + Ansible

[Equipe](/README.md#-equipe)

## Como executar

Baixar repositório (instruções no [README](/README.md#-clonando-o-repositório) principal)
Verificar dependências:
- OpenTofu >= 1.12.6
- Ansible >= 2.16.x
- virsh, libvirt, qemu-system
Corrigir erro de permissão (security_driver qemu.conf)

Criar chaves ssh com `ssh-keygen`

Acessar pasta de infra (infraestrutura/iac)
Baixar providers com `tofu init`
Validar configuração com `tofu validate`
Planejar com `tofu plan [-out=plan]`
Aplicar plano com `tofu apply [plan]`
Verificar conectividade ssh com `ssh user@host`

Verificar conectividade do Ansible com `ansible all -i \[inventory.ini\] -m ping --private-key ~/.ssh/chave_ssh`
Executar playbooks do Ansible
