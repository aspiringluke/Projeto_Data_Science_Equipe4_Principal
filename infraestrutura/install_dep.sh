#!/usr/bin/bash

# O script talvez não seja o mais adequado, mas ele deveria funcionar bem num sistema Ubuntu,
# e ele não deve remover nem atrapalhar nada se os softwares já estiverem instalados, apenas
# atualizar o OpenTofu

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

msg "Atualizando lista de pacotes..."
sudo apt-get update > /dev/null

msg "Verificando KVM..."
sudo apt-get install -y cpu-checker > /dev/null
[[ -z "$(kvm-ok | grep 'exists')" ]] && msg "${error_color}ERROR${default_color}: KVM não encontrado" && exit 1

msg "${ok_color}OK${default_color}: KVM habilitado"

msg "Instalando libvirt, virsh e qemu..."
sudo apt-get install -y qemu-kvm \
                    libvirt-daemon-system \
                    libvirt-clients \
                    virt-manager \
                    virtinst > /dev/null
virsh --version || msg "${error_color}ERROR${default_color}: virsh não encontrado" && exit 1
msg "${ok_color}OK${default_color}: Virsh instalado"
libvirtd --version || msg "${error_color}ERROR${default_color}: libvirtd não encontrado" && exit 1
msg "${ok_color}OK${default_color}: Libvirt instalado"

msg "Habilitando rede pelo virsh..."
virsh net-start default || msg "${warn_color}WARN${default_color}: Não foi possível iniciar a rede pelo virsh. Ela pode já estar ativa, verifique com ${warn_color}virsh net-list --all${default_color}"
virsh net-autostart default || msg "${warn_color}WARN${default_color}: Não foi possível habilitar autostart pelo virsh"

msg "Instalando ansible..."
sudo apt-get install -y ansible > /dev/null
ansible --version || msg "${error_color}ERROR${default_color}: Ansible não encontrado" && exit 1
msg "${ok_color}OK${default_color}: Ansible instalado"

msg "Instalado OpenTofu..."
curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh > /dev/null
chmod +x install-opentofu.sh
./install-opentofu.sh --install-method deb > /dev/null
rm install-opentofu.sh

tofu version || msg "${error_color}ERROR${default_color}: OpenTofu não encontrado" && exit 1
msg "${ok_color}OK${default_color}: OpenTofu instalado"

msg "${warn_color}WARN${default_color}: Se os comandos de rede do virsh falharam, talvez você precise ${warn_color}encerrar a sessão e realizar log in novamente${default_color}"
