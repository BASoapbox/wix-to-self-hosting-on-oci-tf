# Inputs for the OCI Email Delivery module.
#
# Manual prerequisite this module cannot do for you: OCI Email Delivery
# requires the sending domain/tenancy to be approved for production sending
# limits (new tenancies start in a low-limit trial mode) — request the
# limit increase via Console: Governance -> Limits, Quotas and Usage ->
# Email Delivery, before relying on this for real outbound volume.

variable "compartment_ocid" {
  description = "Compartment OCID for Email Delivery resources."
  type        = string
}

variable "tenancy_ocid" {
  description = "Tenancy OCID. IAM users are always created at the tenancy level regardless of compartment_ocid."
  type        = string
}

variable "region" {
  description = "OCI region identifier, e.g. us-ashburn-1. Used to build the SMTP endpoint hostname output."
  type        = string
}

variable "domain_name" {
  description = "Domain to send mail from, e.g. yourdomain.com."
  type        = string
}

variable "sender_email_address" {
  description = "Approved sender email address, e.g. noreply@yourdomain.com."
  type        = string
}

variable "smtp_user_name" {
  description = "IAM user name for the SMTP-only service user."
  type        = string
  default     = "svc-email-grav"
}

variable "vault_ocid" {
  description = "Existing Vault OCID to store the SMTP credential in (referenced as a data source, not managed here)."
  type        = string
}

variable "key_ocid" {
  description = "Existing encryption key OCID for the Vault secret."
  type        = string
}

variable "freeform_tags" {
  description = "Freeform tags applied to all Email Delivery resources."
  type        = map(string)
  default     = {}
}
