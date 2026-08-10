# Root local values.
locals {
  # Use the tenancy/root compartment when a separate parent compartment is not
  # supplied.
  parent_compartment_ocid = coalesce(var.parent_compartment_ocid, var.tenancy_ocid)
}
