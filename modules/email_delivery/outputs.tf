output "sender_ocid" {
  value = oci_email_sender.this.id
}

output "dkim_cname_target" {
  description = "CNAME target value to publish for the DKIM DNS record (OCI's preferred DKIM setup method). Feed into the DNS module's dkim_cname_record input."
  value       = oci_email_dkim.this.cname_record_value
}

output "dkim_dns_record_name" {
  description = "DNS subdomain name (host) the DKIM CNAME record must be published under."
  value       = oci_email_dkim.this.dns_subdomain_name
}

output "dkim_txt_record_value" {
  description = "Fallback TXT record value for DKIM, only needed if the CNAME method can't be used."
  value       = oci_email_dkim.this.txt_record_value
}

output "smtp_username" {
  description = "SMTP username for the outbound mail configuration."
  value       = oci_identity_smtp_credential.this.username
}

output "smtp_credential_vault_secret_ocid" {
  description = "Vault secret OCID holding the SMTP password. Retrieve the value via OCI Console or `oci secrets secret-bundle get`."
  value       = oci_vault_secret.smtp_credential.id
}

output "smtp_username_vault_secret_ocid" {
  description = "Vault secret OCID holding the SMTP username (pairs with smtp_credential_vault_secret_ocid)."
  value       = oci_vault_secret.smtp_username.id
}

output "smtp_host" {
  description = "OCI Email Delivery SMTP endpoint for this region."
  value       = "smtp.email.${var.region}.oci.oraclecloud.com"
}
