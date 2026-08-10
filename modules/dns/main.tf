# OCI-managed DNS zone.
#
# What Terraform manages: the zone itself and its records.
# What stays manual (cannot be automated here — it's a registrar-side
# change): delegating your domain's nameservers to the four OCI nameservers
# output below. Run `terraform apply`, take the dns_nameservers output, and
# update them at your registrar. Propagation is typically 15 minutes to a
# few hours — verify with `dig yourdomain.com NS`.

resource "oci_dns_zone" "zone" {
  compartment_id = var.compartment_ocid
  name           = var.zone_name
  zone_type      = "PRIMARY"
  scope          = "GLOBAL"

  freeform_tags = merge(var.freeform_tags, {
    Service = "dns-zone"
  })
}

resource "oci_dns_rrset" "apex_a" {
  zone_name_or_id = oci_dns_zone.zone.id
  domain          = var.zone_name
  rtype           = "A"

  items {
    domain = var.zone_name
    rtype  = "A"
    rdata  = var.target_public_ip
    ttl    = 300
  }
}

resource "oci_dns_rrset" "www_cname" {
  zone_name_or_id = oci_dns_zone.zone.id
  domain          = "www.${var.zone_name}"
  rtype           = "CNAME"

  items {
    domain = "www.${var.zone_name}"
    rtype  = "CNAME"
    rdata  = "${var.zone_name}."
    ttl    = 300
  }
}

# -----------------------------------------------------------------------------
# Additional records (mail provider SPF/DKIM/MX/CNAME/DMARC, etc.)
# -----------------------------------------------------------------------------
# Grouped by domain+rtype so multiple records sharing both (e.g. two MX
# entries) land in a single rrset, matching how OCI DNS actually models this.

locals {
  additional_grouped = {
    for r in var.additional_dns_records : "${r.domain}|${r.rtype}" => r...
  }
}

resource "oci_dns_rrset" "additional" {
  for_each = local.additional_grouped

  zone_name_or_id = oci_dns_zone.zone.id
  domain          = each.value[0].domain
  rtype           = each.value[0].rtype

  dynamic "items" {
    for_each = each.value
    content {
      domain = items.value.domain
      rtype  = items.value.rtype
      rdata  = items.value.rdata
      ttl    = items.value.ttl
    }
  }
}

# -----------------------------------------------------------------------------
# Email Delivery DKIM record — kept separate from "additional" on purpose
# -----------------------------------------------------------------------------
# var.additional_dns_records is user-supplied and fully known at plan time
# (static strings in terraform.tfvars), so grouping it by "${domain}|${rtype}"
# for for_each works fine. The DKIM record's domain comes from
# module.email_delivery's output instead, which isn't known until that
# resource is actually created — using it as a for_each MAP KEY (even
# indirectly, via the group-by expression) fails at plan time with "Invalid
# for_each argument", because Terraform must enumerate every key before
# applying anything. A single resource selected by count doesn't have that
# problem: only the resource's VALUES need to be unknown-safe, not its
# existence.

resource "oci_dns_rrset" "dkim" {
  count = var.dkim_cname_record != null ? 1 : 0

  zone_name_or_id = oci_dns_zone.zone.id
  domain          = var.dkim_cname_record.domain
  rtype           = "CNAME"

  items {
    domain = var.dkim_cname_record.domain
    rtype  = "CNAME"
    rdata  = var.dkim_cname_record.rdata
    ttl    = var.dkim_cname_record.ttl
  }
}
