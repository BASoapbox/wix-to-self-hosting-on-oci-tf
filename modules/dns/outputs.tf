output "zone_ocid" {
  value = oci_dns_zone.zone.id
}

output "nameservers" {
  description = "OCI nameservers to set at your registrar — manual step, see main.tf comment."
  value       = oci_dns_zone.zone.nameservers[*].hostname
}
