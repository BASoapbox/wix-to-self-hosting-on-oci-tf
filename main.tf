# =============================================================================
# Grav blog sample — Root Module
# =============================================================================
# Minimal Terraform to run a single self-hosted Grav instance on OCI's
# Always Free tier: one compartment, one VCN/public subnet, one A1.Flex
# instance running Grav in Docker behind Nginx, a DNS zone, and OCI Email
# Delivery for outbound mail. This is a trimmed-down, single-purpose
# companion to a larger multi-project Terraform codebase — it deliberately
# leaves out anything that isn't needed to run Grav on its own (no
# multi-environment compartments, no VCN peering/DRG, no databases, no
# generic buckets/instances maps).

# -----------------------------------------------------------------------------
# Compartment
# -----------------------------------------------------------------------------

module "compartment" {
  source = "./modules/compartment"

  parent_compartment_ocid   = local.parent_compartment_ocid
  compartment_name          = "cmp-${var.environment}"
  environment               = var.environment
  enable_compartment_delete = var.enable_compartment_delete
  freeform_tags             = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Network — one VCN, one public subnet
# -----------------------------------------------------------------------------

module "network" {
  source = "./modules/network"

  environment            = var.environment
  compartment_ocid       = module.compartment.compartment_ocid
  vcn_name               = "vcn-${var.environment}"
  vcn_cidr               = var.vcn_cidr
  vcn_dns_label          = var.environment
  subnet_name            = "sn-pub-${var.environment}-app"
  subnet_cidr            = var.subnet_cidr
  subnet_dns_label       = "${var.environment}app"
  admin_ssh_source_cidrs = var.admin_ssh_source_cidrs
  web_ingress_cidrs      = ["0.0.0.0/0"]
  freeform_tags          = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Grav host — one A1.Flex instance, its own NSG, and a dedicated block volume
# -----------------------------------------------------------------------------
# Kept as its own module (rather than a generic instances map) because it
# owns resources a generic compute module doesn't — a dedicated NSG and a
# dedicated block volume — so it stays a single "clean destroy" unit.

module "grav_host" {
  source = "./modules/grav_host"

  compartment_ocid         = module.compartment.compartment_ocid
  subnet_ocid              = module.network.subnet_ocid
  vcn_ocid                 = module.network.vcn_ocid
  availability_domain      = var.availability_domain_name
  environment              = var.environment
  image_ocid               = var.grav_host_image_ocid
  ocpus                    = var.grav_host_ocpus
  memory_in_gbs            = var.grav_host_memory_in_gbs
  boot_volume_size_gb      = var.grav_host_boot_volume_size_gb
  block_volume_size_gb     = var.grav_host_block_volume_size_gb
  block_volume_vpus_per_gb = var.grav_host_block_volume_vpus_per_gb
  admin_ssh_source_cidrs   = var.admin_ssh_source_cidrs
  ssh_public_key           = var.ssh_public_key
  freeform_tags            = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Email Delivery — outbound mail for the blog's domain
# -----------------------------------------------------------------------------

module "email_delivery" {
  source = "./modules/email_delivery"

  compartment_ocid     = module.compartment.compartment_ocid
  tenancy_ocid         = var.tenancy_ocid
  region               = var.region
  domain_name          = var.dns_zone_name
  sender_email_address = var.email_sender_address
  smtp_user_name       = var.email_smtp_user_name
  vault_ocid           = var.vault_ocid
  key_ocid             = var.key_ocid
  freeform_tags        = var.freeform_tags
}

# -----------------------------------------------------------------------------
# DNS — one zone, pointed at the Grav host
# -----------------------------------------------------------------------------

module "dns" {
  source = "./modules/dns"

  compartment_ocid       = module.compartment.compartment_ocid
  zone_name              = var.dns_zone_name
  target_public_ip       = module.grav_host.public_ip
  additional_dns_records = var.additional_dns_records

  dkim_cname_record = {
    domain = module.email_delivery.dkim_dns_record_name
    rdata  = module.email_delivery.dkim_cname_target
    ttl    = 3600
  }

  freeform_tags = var.freeform_tags
}
