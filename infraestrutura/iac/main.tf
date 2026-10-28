terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

locals {
  # Mapeamento com os nomes das máquinas, configurações de hardware e rede
  vms = {
    "servidor-app" = {
      memory = 2048
      vcpu   = 2
      size   = 10737418240  # 10GB
      ip     = "192.168.122.10"
      mac    = "52:54:00:00:00:01"
    },
    "servidor-dados" = {
      memory = 2048#4096
      vcpu   = 2#4
      size   = 21474836480  # 20GB
      ip     = "192.168.122.11"
      mac    = "52:54:00:00:00:02"
    }
  }
}

resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-24.04-base.qcow2"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_volume" "vm_disk" {
  for_each = local.vms

  name   = "${each.key}.qcow2"
  pool   = "default"
  format = "qcow2"
  size   = each.value.size

  base_volume_id = libvirt_volume.ubuntu_base.id
}

resource "libvirt_cloudinit_disk" "init" {
  for_each = local.vms

  name = "${each.key}-cloudinit.iso"
  pool = "default"

  user_data = templatefile("${path.module}/cloud_init.cfg", {
    hostname = each.key
    ssh_key  = trimspace(file(pathexpand("~/.ssh/devops_lab.pub")))
  })
}

resource "libvirt_domain" "vm" {
  for_each = local.vms

  name   = each.key
  memory = each.value.memory
  vcpu   = each.value.vcpu

  cloudinit = libvirt_cloudinit_disk.init[each.key].id

  network_interface {
    network_name   = "default"
    addresses      = [each.value.ip]
    mac            = each.value.mac
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.vm_disk[each.key].id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}

output "ips" {
  value = {
    for key, vm in libvirt_domain.vm :
    key => try(vm.network_interface[0].addresses[0], null)
  }
}
