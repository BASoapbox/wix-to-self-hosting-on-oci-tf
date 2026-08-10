# OCI provider configuration.
#
# This configuration supports either:
# - OCI CLI config profile authentication, or
# - explicit API key authentication through variables.
#
# For day-to-day local use, config_file_profile = "DEFAULT" is usually the
# simplest option if your ~/.oci/config file is already configured.
#
# No backend block is declared here, so Terraform state is kept locally
# (terraform.tfstate in this directory) — the simplest option to clone and
# run. Configure a remote backend (e.g. an OCI Object Storage bucket via the
# S3-compatible API) once you're managing this beyond a single machine.
provider "oci" {
  region = var.region

  # API key auth. These can also be provided by environment variables or
  # ~/.oci/config. Leave them null when you are using only a config profile.
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path

  # Optional, only needed when your API private key is encrypted.
  private_key_password = var.private_key_password

  # Optional OCI CLI config profile, for example DEFAULT.
  config_file_profile = var.config_file_profile
}
