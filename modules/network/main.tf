# One VCN, one public subnet — everything a single public-facing Grav host
# needs. No private subnet/NAT/Service Gateway and no DRG/VCN-peering here;
# add those back if you outgrow a single instance.
#
# The host is public because nothing sits in front of it: there is no load
# balancer, the DNS A record points straight at the instance, and Certbot
# proves domain ownership over port 80. None of that is a Grav requirement.
# See "Why the instance is in a public subnet" in the README for what a
# private-subnet version would need, and why this bundle skips it.

resource "oci_core_vcn" "vcn" {
  compartment_id = var.compartment_ocid
  display_name   = var.vcn_name
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = var.vcn_dns_label

  freeform_tags = merge(var.freeform_tags, {
    Environment = var.environment
  })
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "igw-${var.environment}"
  enabled        = true

  freeform_tags = merge(var.freeform_tags, {
    Environment = var.environment
  })
}

resource "oci_core_dhcp_options" "dhcp" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "dhcp-${var.environment}"

  options {
    type        = "DomainNameServer"
    server_type = "VcnLocalPlusInternet"
  }

  # Search domain uses the VCN DNS label, for example stage.oraclevcn.com.
  options {
    type                = "SearchDomain"
    search_domain_names = ["${var.vcn_dns_label}.oraclevcn.com"]
  }

  freeform_tags = merge(var.freeform_tags, {
    Environment = var.environment
  })
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "rt-${var.environment}-public"

  route_rules {
    description       = "Public internet egress through Internet Gateway"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }

  freeform_tags = merge(var.freeform_tags, {
    Environment = var.environment
    Visibility  = "public"
  })
}

# -----------------------------------------------------------------------------
# Security list
# -----------------------------------------------------------------------------
# Note: OCI enforces both this subnet-level security list AND the Grav host's
# own NSG (see modules/grav_host) on inbound traffic — both layers have to
# agree on a rule or nothing gets through.

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "sl-${var.environment}-public"

  egress_security_rules {
    description      = "Allow all outbound traffic"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }

  ingress_security_rules {
    description = "Allow traffic from inside the ${var.environment} VCN"
    source      = var.vcn_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "all"
  }

  # Optional internet SSH rule. One ingress rule is created for each trusted
  # source CIDR. Empty list means no SSH rule is created.
  dynamic "ingress_security_rules" {
    for_each = toset(var.admin_ssh_source_cidrs)
    iterator = ssh_source

    content {
      description = "Allow SSH from admin source CIDR ${ssh_source.value}"
      source      = ssh_source.value
      source_type = "CIDR_BLOCK"
      protocol    = "6"

      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  # Optional internet web rule (HTTP/HTTPS). One pair of ingress rules per
  # trusted source CIDR. Empty list means no web ingress rule is created.
  dynamic "ingress_security_rules" {
    for_each = toset(var.web_ingress_cidrs)
    iterator = web_source

    content {
      description = "Allow HTTP from ${web_source.value}"
      source      = web_source.value
      source_type = "CIDR_BLOCK"
      protocol    = "6"

      tcp_options {
        min = 80
        max = 80
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = toset(var.web_ingress_cidrs)
    iterator = web_source

    content {
      description = "Allow HTTPS from ${web_source.value}"
      source      = web_source.value
      source_type = "CIDR_BLOCK"
      protocol    = "6"

      tcp_options {
        min = 443
        max = 443
      }
    }
  }

  freeform_tags = merge(var.freeform_tags, {
    Environment = var.environment
    Visibility  = "public"
  })
}

# -----------------------------------------------------------------------------
# Subnet
# -----------------------------------------------------------------------------

resource "oci_core_subnet" "public" {
  compartment_id  = var.compartment_ocid
  vcn_id          = oci_core_vcn.vcn.id
  display_name    = var.subnet_name
  cidr_block      = var.subnet_cidr
  dns_label       = var.subnet_dns_label
  dhcp_options_id = oci_core_dhcp_options.dhcp.id

  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]

  freeform_tags = merge(var.freeform_tags, {
    Environment = var.environment
    Tier        = "app"
    Visibility  = "public"
  })
}
