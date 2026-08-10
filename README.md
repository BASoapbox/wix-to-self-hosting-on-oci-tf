# Grav on OCI — reference Terraform

Minimal Terraform to run a single self-hosted [Grav](https://getgrav.org)
instance on Oracle Cloud Infrastructure's Always Free tier: one compartment,
one VCN with one public subnet, one `VM.Standard.A1.Flex` instance running
Grav in Docker behind Nginx, a DNS zone, and OCI Email Delivery for outbound
mail.

This is a trimmed-down, single-purpose companion repo — it's what's left
after stripping a larger multi-project Terraform codebase down to just what's
needed to run Grav on its own. There's no multi-environment compartment
split, no VCN peering/DRG, no databases, and no generic bucket/instance maps.
See the [architecture diagram](./architecture.png) for how the pieces fit
together.

## What this creates

| Resource | Purpose |
|---|---|
| Compartment (`cmp-<environment>`) | Holds everything below |
| VCN + public subnet | `192.168.0.0/24` by default, one subnet |
| Security list + NSG | Two independent firewall layers — see note below |
| Compute instance (A1.Flex) | Runs Docker: ufw → nginx → Grav container |
| Block volume | Dedicated volume for Grav's content, survives instance rebuilds |
| DNS zone | Apex A record, `www` CNAME, DKIM CNAME, any extra records you add |
| Email Delivery | Sender address, DKIM key, SMTP user + credential |

Not included, and not needed to run Grav: Oracle Autonomous Database, Object
Storage buckets, VCN peering/DRG, a generic multi-instance map, or a Vault
(this stack only ever *writes into* an existing one — see below).

## Prerequisites

- An OCI tenancy with the Always Free Arm allowance available. Check the
  Console's **Limits, Quotas and Usage** page for your actual OCPU/memory
  allowance before assuming the commonly-cited 4 OCPU / 24GB — some tenancies
  get half that.
- [Terraform](https://developer.hashicorp.com/terraform) >= 1.3.0
- An OCI CLI config profile (`~/.oci/config`), or API key values to pass
  explicitly via variables
- An existing OCI Vault + encryption key (this stack stores the generated
  SMTP credential there; it does not create the Vault itself)
- A domain you control, with access to its registrar's nameserver settings
- An SSH key pair

## Setup

1. Copy the example tfvars and fill in your own values:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Export the values that shouldn't live in a file:

   ```bash
   export TF_VAR_tenancy_ocid="ocid1.tenancy.oc1..aaa..."
   export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
   ```

3. Init and apply:

   ```bash
   terraform init
   terraform plan -out=grav.tfplan
   terraform apply grav.tfplan
   ```

4. Take the `dns_nameservers` output and set it at your domain's registrar —
   this is the one step Terraform can't do for you. Propagation is typically
   15 minutes to a few hours; verify with `dig yourdomain.com NS`.

5. SSH to the instance (`terraform output grav_host`) and deploy Grav + Nginx:

   ```bash
   scp docker/grav/docker-compose.yml ubuntu@<public_ip>:/mnt/grav-data/grav/compose/
   scp docker/nginx/yourdomain-http.conf ubuntu@<public_ip>:/tmp/
   ssh ubuntu@<public_ip>
   sudo cp /tmp/yourdomain-http.conf /etc/nginx/sites-available/yourdomain.com
   sudo ln -s /etc/nginx/sites-available/yourdomain.com /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl reload nginx
   cd /mnt/grav-data/grav/compose && docker compose up -d
   ```

6. Once DNS has propagated, get a real certificate:

   ```bash
   sudo bash docker/scripts/go-live.sh yourdomain.com
   ```

## Two firewall layers, not one

OCI enforces both the subnet's **security list** and the instance's **NSG**
on inbound traffic — both have to independently allow a port or nothing gets
through. This bundle opens 22/80/443 on both layers by default
(`admin_ssh_source_cidrs` controls SSH on both), but if you tighten one
without the other, traffic will silently stop reaching the instance with no
obvious error on either side. Check both `sl-<environment>-public` and
`nsg-<environment>-grav-host` if something that should be reachable isn't.

## Naming convention

Resources follow `<type>-<environment>-<role>`, e.g. `nsg-stage-grav-host`,
`sl-stage-public`, `bv-pub-stage-grav-data`. Change `environment` in
`terraform.tfvars` to reuse this for a second environment (e.g. `prod`) by
running it as a separate Terraform workspace or a separate state file — this
bundle is intentionally single-environment, not multi-environment via
`for_each`.

## State and secrets

No remote backend is configured — state stays local
(`terraform.tfstate` in this directory) for simplicity. Configure a remote
backend before using this beyond a single machine or a single contributor.
`terraform.tfvars` and `*.tfstate*` are already gitignored; don't commit them,
since state contains resource details in plaintext.
