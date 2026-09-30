# Infraestrutura

Para garantir a idempotência da infraestrutura, poupar tempo de implantação e reduzir erros humanos, foram utilizadas ferramentas e técnicas de IaC:
- Criação automática de máquinas virtuais com OpenTofu
- Configuração de primeiro boot com cloud-init
- Instalação de software e demais configurações com Ansible

As máquinas virtuais são executadas em ambientes Linux utilizando a biblioteca libvirt, o módulo KVM e o emulador QEMU

Seguem abaixo as instruções de implantação.

[Equipe](/README.md#-equipe)

## Como executar

### 1. Baixar repositório

Instruções completas encontram-se no [README](/README.md#-clonando-o-repositório) principal, sob "Clonando o Repositório"

---

### 2. Verificar dependências

> [!TIP]
> O script [install_dep.sh](./install_dep.sh) instala as dependências necessárias automaticamente, basta executar com `./install_dep.sh`. Funciona apenas em sistemas baseados em Ubuntu. Testado no Linux Mint.

- OpenTofu >= 1.12.6
- Ansible >= 2.16.x
- Virtualização:
    - cpu-checker
    - qemu-kvm
    - libvirt-daemon-system
    - libvirt-clients
    - virt-manager
    - virtinst

Primeiro verifique o status do KVM no sistema:
```bash
sudo apt install -y cpu-checker
kvm-ok # INFO: /dev/kvm exists
```

Então instale as dependencias para virtualização:
```bash
sudo apt install -y qemu-kvm \
                    libvirt-daemon-system \
                    libvirt-clients \
                    virt-manager \
                    virtinst
```

Instale o Ansible e verifique sua versão:
```bash
sudo apt install -y ansible
ansible --version
```

Para instalar o OpenTofu, deve-se baixar e executar o script oficial:
```bash
curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh

chmod +x install-opentofu.sh

./install-opentofu.sh --install-method deb

# Remova o instalador depois
rm install-opentofu.sh

# Verifique a instalação e a versão
tofu version
```

> [!NOTE]
> A instalação via deb pode falhar se der algum erro no apt. Se for este o caso, utilize essa abordagem para contornar o erro: `./install-opentofu.sh --install-method standalone --skip-verify)`

> [!WARNING]
> Após instalar as ferramentas de virtualização, pode ser que o daemon e a rede do QEMU não iniciem corretamente, então `encerre a sessão` e `realize o log-in novamente`. Depois, certifique-se que tudo iniciou corretamente:

```bash
systemctl status libvirtd # deve mostrar "active" e "enabled"
virsh net-list --all # default active yes yes
```

Caso algum dos dois (ou ambos) esteja mostrando "inactive", os quatro comandos seguintes corrigem isso:
```bash
# Inicia e habilita libvirt
sudo systemctl start libvirtd
sudo systemctl enable libvirtd

# Inicia e habilita a rede de virtualização
virsh net-start default
virsh net-autostart default
```

---

### 3. Corrigir erro de permissão

Se o seu ambiente linux estiver utilizando AppArmor, um erro (ou bug?) pode fazer com que o disco das VMs fique inacessível por problemas de permissão, conforme [esta issue](https://github.com/dmacvicar/terraform-provider-libvirt/issues/1163). Se isso ocorrer, é provável que seja preciso alterar a opção `security_driver` no arquivo `/etc/libvirt/qemu.conf`. Se não souber como fazer isso, eis o passo a passo:

1. Acesse o arquivo com Nano (ou seu editor de texto de preferência). O arquivo exige permissões elevadas:
```bash
sudo nano /etc/libvirt/qemu.conf`
```
2. Depois dê `Ctrl+W` para pesquisar (no Nano) e digite `security_driver`. Pressione ENTER.
3. Na linha que diz `#security_driver = “selinux”`, remova o jogo da velha (**#**), apague a palavra ***selinux*** e digite ***none*** no lugar. A linha deve ficar assim:
```
security_driver = "none"
```
4. Digite `Ctrl+O` e ENTER para salvar
5. `Ctrl+X` para sair
6. Reinicie o daemon da libvirt:
```bash
sudo systemctl restart libvirtd
```

---

### 4. Criar chaves ssh

A conectividade com a VM é feita via SSH, cujas chaves são inseridas pelo cloud-init. Antes de construir a infraestrutura, é preciso criar as chaves.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/devops_lab -N ""
```

> [!NOTE]
> O nome da chave foi definido como `devops_lab`, se alterá-lo, deve alterar também a linha que a referencia no arquivo `iac/main.tf`. Note que sistemas Linux normalmente são case-sensitive, então uma alteração simples como `DevOps_lab` é considerado diferente

Note que esse comando não cria nenhuma senha para a chave.

---

### 5. Construir infraestrutura

> [!TIP]
> Esta etapa foi automatizada no script [build_infra.sh](./build_infra.sh)
> Você pode executá-lo simplesmente com `./build_infra.sh`, mas o script oferece algumas opções úteis:
> ```
>   --rebuild,      destrói a infraestrutura e limpa as chaves antes de buildar
>   --plan-only,    apenas faz o plano tofu e salva num arquivo, sem aplicar
>   --help,         mostra as opções disponíveis
>   --version,      mostra a versão
> ```
> Todas as opções têm versões curtas que podem ser vistas com `./build_infra.sh --help`

> [!IMPORTANT]
> O script mencionado não cria chaves SSH nem instala dependências

1. Considerando que está na raiz do repositório, acesse a pasta de infra
```bash
cd infraestrutura/
```
2. Baixe os providers do Tofu
```bash
tofu init
```
3. Valide a configuração
```bash
tofu validate
```
4. Planeje com `tofu plan [-out=plan]`
5. Aplique o plano com `tofu apply [plan]`

> [!NOTE]
> Nos passos 4 e 5, os colchetes indicam que aquela parte do comando é opcional. Embora, no contexto atual, não seja necessário garantir que o Tofu siga o planejamento original à risca, é interessante realçar essa opção

Observe os IPs retornados quando o `tofu apply` terminar. Se quiser verificar novamente, pode tanto utilizar `tofu output ips` quanto procurar no início do arquivo `terraform.tfstate` criado pelo Tofu.

Por fim, verifique a conectividade ssh com a chave criada e os IPs recuperados:
```bash
ssh aluno@IP -i ~/.ssh/devops_lab
```

Se o seu prompt final for algo como:
```bash
aluno@devops-NUMERO ~$
```
Você se conectou com sucesso à máquina. Certifique-se de testar as duas.

---

### 6. Executar o Ansible

Acesse o diretório do ansible:
```bash
cd infraestrutura/ansible
```

Verificar conectividade das máquinas:
```bash
ansible all -i inventory.ini -m ping --private-key ~/.ssh/devops_lab
```

Se o ping funcionar, executar playbooks
```bash
ansible-playbook playbook.yml -i inventory.ini --private-key ~/.ssh/devops_lab
```

---

## Reconstruindo a infraestrutura

Para resetar a infraestrutura, destrua todos os objetos do tofu:
```bash
cd infraestrutura/iac
tofu destroy
```

Limpe os hosts SSH conhecidos (~/.ssh/known_hosts), para evitar erros na reconexão:
```bash
# execute com todos os IPs atribuídos anteriormente
ssh-keygen -R 192.168.122.10

# se estiver usando DHCP e tiver hosts demais para lembrar, esse comando limpa todos os que estiverem na sub-rede do libvirt
for i in {1..255}; do ssh-keygen -R 192.168.122.${i}; done
```