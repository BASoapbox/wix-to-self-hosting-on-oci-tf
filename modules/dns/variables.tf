# Inputs for the DNS module. Called once for the blog's domain.

variable "compartment_ocid" {
  description = "Compartment OCID where the DNS zone will be created."
  type        = string
}

variable "zone_name" {
  description = "DNS zone name, e.g. yourdomain.com."
  type        = string
}

variable "target_public_ip" {
  description = "Public IP of the Grav host instance that the apex A record should point to."
  type        = string
}

variable "freeform_tags" {
  description = "Freeform tags applied to the DNS zone."
  type        = map(string)
  default     = {}
}

# Generic extra records — SPF/DKIM/MX/CNAME/DMARC for a mail provider, or
# anything else the zone needs beyond the apex A/CNAME. Must be fully known
# at plan time (static values from terraform.tfvars) — these are grouped by
# "${domain}|${rtype}" for for_each, so an unknown domain/rtype here would
# hit the same "Invalid for_each argument" problem the DKIM record below is
# specifically kept separate to avoid. For MX records, include the priority
# directly in rdata (OCI's format is "<priority> <exchange>.", e.g.
# "10 mxa.mailgun.org.") — there's no separate priority field. Multiple
# entries with the same domain+rtype (e.g. two MX records) are grouped into
# one rrset automatically.
variable "additional_dns_records" {
  description = "Extra DNS records to add to the zone, e.g. mail provider SPF/DKIM/MX/CNAME/DMARC records. Must be statically known — see dkim_cname_record for values that depend on another resource's output."
  type = list(object({
    domain = string
    rtype  = string
    rdata  = string
    ttl    = optional(number, 3600)
  }))
  default = []
}

# Email Delivery's DKIM CNAME record, kept as its own single optional
# resource (selected via count, not for_each) specifically because its
# domain/rdata values come from module.email_delivery's output and aren't
# known until that resource is created. A single resource only needs its
# VALUES to tolerate being unknown at plan time; a for_each map needs its
# KEYS known up front, which is what additional_dns_records above can
# guarantee and this can't.
variable "dkim_cname_record" {
  description = "Optional DKIM CNAME record (domain, rdata, ttl) sourced from the email_delivery module's outputs. Pass null to skip it."
  type = object({
    domain = string
    rdata  = string
    ttl    = optional(number, 3600)
  })
  default = null
}
