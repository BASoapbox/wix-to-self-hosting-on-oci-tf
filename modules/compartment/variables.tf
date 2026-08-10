variable "parent_compartment_ocid" {
  description = "Parent compartment OCID where this compartment will be created."
  type        = string
}

variable "compartment_name" {
  description = "Name of the compartment."
  type        = string
}

variable "environment" {
  description = "Environment key, for example stage or prod. Used in tags and the description."
  type        = string
}

variable "enable_compartment_delete" {
  description = "Set true only if you want terraform destroy to delete this compartment."
  type        = bool
  default     = false
}

variable "freeform_tags" {
  description = "Freeform tags applied to the compartment."
  type        = map(string)
  default     = {}
}
