# Inputs for the Grav host module.

variable "compartment_ocid" {
  description = "Compartment OCID where the instance and block volume will be created."
  type        = string
}

variable "subnet_ocid" {
  description = "Public subnet OCID where the instance VNIC will be placed."
  type        = string
}

variable "vcn_ocid" {
  description = "VCN OCID that the subnet belongs to. Used to scope the Grav host NSG."
  type        = string
}

variable "availability_domain" {
  description = "Availability domain name, for example GrEI:US-ASHBURN-AD-1."
  type        = string
}

variable "environment" {
  description = "Environment key (stage or prod). Used in resource names and tags."
  type        = string
}

variable "image_ocid" {
  description = "Ubuntu 22.04 Arm boot image OCID (A1.Flex compatible)."
  type        = string
}

variable "ocpus" {
  description = "OCPUs for the A1.Flex Grav host instance."
  type        = number
  default     = 2
}

variable "memory_in_gbs" {
  description = "Memory in GB for the A1.Flex Grav host instance."
  type        = number
  default     = 12
}

variable "boot_volume_size_gb" {
  description = "Boot volume size in GB. A1.Flex supports custom sizing."
  type        = number
  default     = 50
}

variable "block_volume_size_gb" {
  description = "Size of the dedicated block volume for Grav's content."
  type        = number
  default     = 50
}

variable "block_volume_vpus_per_gb" {
  description = "Block volume performance tier in VPUs/GB. 0 = Lower Cost, 10 = Balanced (OCI's default if unset), 20 = Higher Performance, 30-120 = Ultra High Performance. Defaults to 0 — a low-traffic blog has no real IOPS requirement that justifies the extra billing on the 'Balanced' default tier."
  type        = number
  default     = 0
}

variable "admin_ssh_source_cidrs" {
  description = "CIDRs allowed to SSH into the Grav host instance. Empty list means no SSH rule is created."
  type        = list(string)
  default     = []
}

variable "ssh_public_key" {
  description = "SSH public key string injected into the instance's authorized_keys. Pass the key content directly, not a file path."
  type        = string
  sensitive   = true
}

variable "freeform_tags" {
  description = "Freeform tags applied to all Grav host resources."
  type        = map(string)
  default     = {}
}
