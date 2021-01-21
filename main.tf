locals {
  name       = "myname"
  network_id = "internal"
  username   = "${local.name}-${random_string.username_suffix.result}"
}

resource "tls_private_key" "internal" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "random_string" "username_suffix" {
  length  = 8
  upper   = false
  special = false
}

// requires terraform-provider-libvirt in
// ~/.local/share/terraform/plugins/registry.terraform.io/dmacvicar/libvirt/0.6.2/linux_amd64/
provider "libvirt" {
  uri = "qemu:///system"
}

resource "random_string" "name" {
  length  = 8
  upper   = false
  special = false
}

resource "libvirt_volume" "debian" {
  name   = "debian_buster"
  source = "https://cdimage.debian.org/cdimage/cloud/buster/20201214-484/debian-10-genericcloud-amd64-20201214-484.qcow2"
}

resource "libvirt_volume" "main_disk" {
  name           = "main_disk.qcow2"
  base_volume_id = libvirt_volume.debian.id
}

resource "random_string" "temp_password" {
  length  = 32
  upper   = true
  special = false
}

resource "libvirt_cloudinit_disk" "cloud_init" {
  name           = "cloud_init"
  #user_data      = data.template_file.cloud_init.rendered
  user_data      = <<-EOT
#cloud-config
users:
  - name: ${local.username}
    ssh-authorized-keys:
      - ${tls_private_key.internal.public_key_openssh}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
EOT
  network_config = <<-EOT
version: 2
ethernets:
  ens3:
    dhcp4: true
EOT
  pool           = libvirt_pool.debian.name
}

resource "libvirt_pool" "debian" {
  name = "debian"
  type = "dir"
  path = "/tmp"
}

resource "libvirt_domain" "debian" {
  name = "test-${random_string.name.result}"
  cloudinit = libvirt_cloudinit_disk.cloud_init.id
  disk {
    volume_id = libvirt_volume.main_disk.id
  }
  network_interface {
    network_name   = "default"
    wait_for_lease = true
    hostname       = "test-${random_string.name.result}"
  }
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  connection {
    type        = "ssh"
    user        = local.username
    private_key = tls_private_key.internal.private_key_pem
    host        = self.network_interface[0].addresses[0]
  }

  provisioner "remote-exec" {
    inline = [
      "whoami",
    ]
  }
}
