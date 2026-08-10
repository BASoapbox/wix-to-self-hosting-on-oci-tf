output "vcn_ocid" {
  description = "VCN OCID."
  value       = oci_core_vcn.vcn.id
}

output "subnet_ocid" {
  description = "Public subnet OCID."
  value       = oci_core_subnet.public.id
}

output "route_table_ocid" {
  value = oci_core_route_table.public.id
}

output "security_list_ocid" {
  value = oci_core_security_list.public.id
}
