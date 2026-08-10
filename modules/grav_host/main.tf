# Grav host module.
#
# One self-contained module owning an instance, a dedicated block volume, and
# its own NSG, so it stays a single "clean destroy" unit.

# -----------------------------------------------------------------------------
# Network Security Group
# -----------------------------------------------------------------------------

resource "oci_core_network_security_group" "grav_host" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_ocid
  display_name   = "nsg-${var.environment}-grav-host"

  freeform_tags = merge(var.freeform_tags, {
    Environment = var.environment
    Service     = "grav-host"
  })
}

resource "oci_core_network_security_group_security_rule" "http_ingress" {
  network_security_group_id = oci_core_network_security_group.grav_host.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "Allow inbound HTTP (Let's Encrypt challenge + redirect to HTTPS)"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "https_ingress" {
  network_security_group_id = oci_core_network_security_group.grav_host.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "Allow inbound HTTPS"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "ssh_ingress" {
  for_each = toset(var.admin_ssh_source_cidrs)

  network_security_group_id = oci_core_network_security_group.grav_host.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  source_type               = "CIDR_BLOCK"
  description               = "Allow SSH from admin source CIDR ${each.value}"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "all_egress" {
  network_security_group_id = oci_core_network_security_group.grav_host.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow all outbound traffic (image pulls, apt, Let's Encrypt, etc.)"
}

# -----------------------------------------------------------------------------
# Compute instance (A1.Flex — Always Free Arm)
# -----------------------------------------------------------------------------

resource "oci_core_instance" "grav_host" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "inst-pub-${var.environment}-grav-host-01"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = var.image_ocid
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = var.subnet_ocid
    assign_public_ip = "true"
    hostname_label   = "gravhost${var.environment}"
    nsg_ids          = [oci_core_network_security_group.grav_host.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    # Runs automatically on first boot: Docker, Nginx, Certbot, ufw, and
    # dynamic detection + mount of the dedicated block volume at
    # /mnt/grav-data. See templates/bootstrap.sh.tftpl.
    user_data = base64encode(templatefile("${path.module}/templates/bootstrap.sh.tftpl", {
      block_volume_device = "/dev/oracleoci/oraclevdb"
      environment         = var.environment
    }))
  }

  freeform_tags = merge(var.freeform_tags, {
    Environment = var.environment
    Shape       = "VM.Standard.A1.Flex"
    Service     = "grav-host"
    Tier        = "app"
  })

  # user_data only matters at first boot — cloud-init doesn't re-run it on an
  # already-running instance, so a bootstrap script edit should never force
  # a replacement on its own. To apply a bootstrap script change to an
  # already-running instance, either re-run it manually over SSH (it's
  # idempotent) or force it deliberately:
  #   terraform apply -replace='module.grav_host.oci_core_instance.grav_host'
  lifecycle {
    ignore_changes = [metadata["user_data"]]
  }
}

# -----------------------------------------------------------------------------
# Dedicated block volume for Grav's content
# -----------------------------------------------------------------------------
# Kept separate from the boot volume so content survives an instance rebuild,
# and so backup policy can be applied to content independently of the OS disk.

resource "oci_core_volume" "grav_data" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "bv-pub-${var.environment}-grav-data"
  size_in_gbs         = var.block_volume_size_gb
  # 0 VPUs/GB ("Lower Cost") — the default "Balanced" tier (10 VPUs/GB) is a
  # paid performance tier that bills separately from storage capacity. A
  # low-traffic Grav blog has no real IOPS requirement that justifies it.
  vpus_per_gb = var.block_volume_vpus_per_gb

  freeform_tags = merge(var.freeform_tags, {
    Environment = var.environment
    Service     = "grav-host"
  })
}

resource "oci_core_volume_attachment" "grav_data" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.grav_host.id
  volume_id       = oci_core_volume.grav_data.id
  display_name    = "va-${var.environment}-grav-data"
}
