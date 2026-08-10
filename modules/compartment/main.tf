# A single compartment holding every resource in this stack.
resource "oci_identity_compartment" "this" {
  compartment_id = var.parent_compartment_ocid
  name           = var.compartment_name
  description    = "${title(var.environment)} environment compartment for the Grav blog stack"

  # enable_delete is intentionally controlled by a variable so normal destroy
  # operations can leave the compartment in place unless you explicitly opt in.
  enable_delete = var.enable_compartment_delete

  freeform_tags = merge(var.freeform_tags, {
    Environment = var.environment
  })
}
