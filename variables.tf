# =============================================================================
# Grav blog sample — root variables
# =============================================================================

# -----------------------------------------------------------------------------
# OCI connection
# -----------------------------------------------------------------------------

variable "region" {
  description = "OCI region identifier, for example us-ashburn-1."
  type        = string
}

variable "tenancy_ocid" {
  description = "OCI tenancy OCID. Set via TF_VAR_tenancy_ocid — do not commit to tfvars."
  type        = string
  sensitive   = true
}

variable "parent_compartment_ocid" {
  description = "Parent compartment OCID under which this stack's compartment is created. Defaults to the tenancy root."
  type        = string
  default     = null
}

variable "user_ocid" {
  description = "OCI user OCID. Leave null when using a config file profile."
  type        = string
  default     = null
}

variable "fingerprint" {
  description = "API key fingerprint. Leave null when using a config file profile."
  type        = string
  default     = null
}

variable "private_key_path" {
  description = "Path to OCI API private key PEM. Leave null when using a config file profile."
  type        = string
  default     = null
}

variable "private_key_password" {
  description = "Passphrase for the API private key if encrypted."
  type        = string
  default     = null
  sensitive   = true
}

variable "config_file_profile" {
  description = "OCI CLI config profile name, for example DEFAULT."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------

variable "enable_compartment_delete" {
  description = "Allow terraform destroy to delete the compartment created by this stack. False is safer."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Environment / naming
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Environment label used throughout resource names and tags, e.g. stage or prod."
  type        = string
  default     = "stage"
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

variable "vcn_cidr" {
  description = "CIDR block for this stack's VCN."
  type        = string
  default     = "192.168.0.0/24"

  validation {
    condition     = can(cidrhost(var.vcn_cidr, 0))
    error_message = "vcn_cidr must be a valid CIDR block."
  }
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet the Grav host lives in. Must fall inside vcn_cidr."
  type        = string
  default     = "192.168.0.0/25"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid CIDR block."
  }
}

# -----------------------------------------------------------------------------
# SSH
# -----------------------------------------------------------------------------

variable "admin_ssh_source_cidrs" {
  description = "CIDR ranges allowed to SSH into the Grav host's public subnet. Empty list means no SSH ingress rule is created."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.admin_ssh_source_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "Each entry must be a valid CIDR block, for example 203.0.113.10/32."
  }
}

variable "ssh_public_key" {
  description = "SSH public key string injected into the Grav host's authorized_keys. Set via: export TF_VAR_ssh_public_key=\"$(cat ~/.ssh/id_ed25519.pub)\""
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Grav host — one A1.Flex instance running Grav in Docker
# -----------------------------------------------------------------------------

variable "availability_domain_name" {
  description = "Availability domain for the Grav host. Check your own tenancy's name on the Console's Limits/Availability Domains page."
  type        = string
}

variable "grav_host_image_ocid" {
  description = "Ubuntu 22.04 Arm boot image OCID (A1.Flex compatible)."
  type        = string
}

variable "grav_host_ocpus" {
  description = "OCPUs for the Grav host A1.Flex instance."
  type        = number
  default     = 2
}

variable "grav_host_memory_in_gbs" {
  description = "Memory in GB for the Grav host A1.Flex instance. Check the Console's Limits page for your own tenancy's actual Always Free Arm allowance before assuming the commonly-cited 4 OCPU / 24GB — some tenancies get less."
  type        = number
  default     = 12
}

variable "grav_host_boot_volume_size_gb" {
  description = "Boot volume size in GB for the Grav host."
  type        = number
  default     = 50
}

variable "grav_host_block_volume_size_gb" {
  description = "Size of the dedicated block volume for Grav's content, kept separate from the boot volume so content survives an instance rebuild."
  type        = number
  default     = 50
}

variable "grav_host_block_volume_vpus_per_gb" {
  description = "Block volume performance tier in VPUs/GB. 0 = Lower Cost (default here), 10 = Balanced (OCI's own default if unset). A low-traffic blog has no IOPS need that justifies paying for the Balanced tier — it bills separately from storage capacity."
  type        = number
  default     = 0
}

# -----------------------------------------------------------------------------
# DNS
# -----------------------------------------------------------------------------

variable "dns_zone_name" {
  description = "DNS zone name for the blog, e.g. yourdomain.com."
  type        = string
}

variable "additional_dns_records" {
  description = "Extra DNS records for the zone beyond the apex/www records — e.g. MX/SPF/CNAME records for whichever provider handles inbound mail for this domain."
  type = list(object({
    domain = string
    rtype  = string
    rdata  = string
    ttl    = optional(number, 3600)
  }))
  default = []
}

# -----------------------------------------------------------------------------
# Email Delivery — outbound mail for the blog's domain
# -----------------------------------------------------------------------------

variable "vault_ocid" {
  description = "OCID of an existing Vault to store the Email Delivery SMTP credential in. Referenced as a data source only — not managed by this Terraform."
  type        = string
}

variable "key_ocid" {
  description = "OCID of an existing encryption key in that Vault."
  type        = string
}

variable "email_sender_address" {
  description = "Approved sender email address for outbound mail. noreply@ by default since OCI only needs domain ownership verified via DKIM, not the address itself existing."
  type        = string
}

variable "email_smtp_user_name" {
  description = "IAM user name for the SMTP-only service user used by Email Delivery."
  type        = string
  default     = "svc-email-grav"
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "freeform_tags" {
  description = "Freeform tags applied to all resources."
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Project   = "grav-blog"
  }
}
