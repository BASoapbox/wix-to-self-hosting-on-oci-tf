# Inputs for the network module — one VCN, one public subnet.

variable "environment" {
  description = "Environment key, for example stage or prod."
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment OCID where VCN resources will be created."
  type        = string
}

variable "vcn_name" {
  description = "VCN display name."
  type        = string
}

variable "vcn_cidr" {
  description = "VCN CIDR block."
  type        = string

  validation {
    condition     = can(cidrhost(var.vcn_cidr, 0))
    error_message = "vcn_cidr must be a valid CIDR block."
  }
}

variable "vcn_dns_label" {
  description = "VCN DNS label."
  type        = string
}

variable "subnet_name" {
  description = "Public subnet display name."
  type        = string
}

variable "subnet_cidr" {
  description = "Public subnet CIDR block. Must fall inside vcn_cidr."
  type        = string

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid CIDR block."
  }
}

variable "subnet_dns_label" {
  description = "Public subnet DNS label."
  type        = string
}

# SSH is opened only to these trusted CIDRs. Empty list means no internet SSH
# ingress rule is created.
variable "admin_ssh_source_cidrs" {
  description = "List of CIDR ranges allowed to SSH into the public subnet. Empty list means no internet SSH ingress rule is created."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.admin_ssh_source_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "Each admin_ssh_source_cidrs value must be a valid CIDR block."
  }
}

# HTTP/HTTPS ingress on the public subnet's security list — needed for Grav.
# NSGs alone are not sufficient in OCI: traffic must be allowed by both the
# subnet's security list and the instance's NSG. Empty list means no web
# ingress rule is created.
variable "web_ingress_cidrs" {
  description = "List of CIDR ranges allowed to reach 80/443 on the public subnet. Empty list means no internet web ingress rule is created."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.web_ingress_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "Each web_ingress_cidrs value must be a valid CIDR block."
  }
}

variable "freeform_tags" {
  description = "Freeform tags applied to created network resources."
  type        = map(string)
  default     = {}
}
