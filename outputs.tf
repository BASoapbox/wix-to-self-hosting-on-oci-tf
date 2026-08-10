# =============================================================================
# Grav blog sample — Root outputs
# =============================================================================

output "compartment_ocid" {
  description = "Compartment OCID holding all resources in this stack."
  value       = module.compartment.compartment_ocid
}

output "vcn_ocid" {
  value = module.network.vcn_ocid
}

output "subnet_ocid" {
  value = module.network.subnet_ocid
}

# -----------------------------------------------------------------------------
# Grav host
# -----------------------------------------------------------------------------

output "grav_host" {
  description = "Grav host instance details."
  value = {
    display_name = module.grav_host.display_name
    public_ip    = module.grav_host.public_ip
    private_ip   = module.grav_host.private_ip
    state        = module.grav_host.state
    ssh_connect  = "ssh ubuntu@${module.grav_host.public_ip}"
  }
}

# -----------------------------------------------------------------------------
# DNS
# -----------------------------------------------------------------------------

output "dns_nameservers" {
  description = "OCI nameservers to set at your domain's registrar (manual step — see modules/dns/main.tf)."
  value       = module.dns.nameservers
}

output "dns_zone_ocid" {
  value = module.dns.zone_ocid
}

# -----------------------------------------------------------------------------
# Email Delivery
# -----------------------------------------------------------------------------

output "email_delivery_smtp_username" {
  description = "SMTP username for the domain's outbound mail configuration."
  value       = module.email_delivery.smtp_username
}

output "email_delivery_smtp_host" {
  value = module.email_delivery.smtp_host
}

output "email_delivery_smtp_credential_vault_secret_ocid" {
  description = "Vault secret OCID holding the SMTP password. Retrieve via OCI Console or the CLI, not via terraform output."
  value       = module.email_delivery.smtp_credential_vault_secret_ocid
}
