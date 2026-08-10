output "instance_ocid" {
  description = "Grav host compute instance OCID."
  value       = oci_core_instance.grav_host.id
}

output "display_name" {
  value = oci_core_instance.grav_host.display_name
}

output "public_ip" {
  description = "Grav host instance public IP. Feed this into the DNS module's A record."
  value       = oci_core_instance.grav_host.public_ip
}

output "private_ip" {
  value = oci_core_instance.grav_host.private_ip
}

output "state" {
  value = oci_core_instance.grav_host.state
}

output "nsg_ocid" {
  description = "Grav host NSG OCID, in case other resources need to reference it."
  value       = oci_core_network_security_group.grav_host.id
}

output "block_volume_ocid" {
  value = oci_core_volume.grav_data.id
}

output "block_volume_attachment_device" {
  description = "Device path of the attached block volume, used when mounting it on the instance."
  value       = oci_core_volume_attachment.grav_data.device
}
