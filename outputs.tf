output "domain_name" {
  value = libvirt_domain.debian.name
}

output "cloud_init_user_data" {
  value = libvirt_cloudinit_disk.cloud_init.user_data
}

output "network" {
  value = libvirt_domain.debian.network_interface
}

output "ssh_key" {
  value = tls_private_key.internal
}
