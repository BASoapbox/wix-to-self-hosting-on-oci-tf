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

   Grav auto-installs into the empty volume on first run. Once you start
   copying real content in, read **Content ownership** below first — the
   container writes as `www-data` and your `scp` does not, and the mismatch
   surfaces as an unexplained "Couldn't save" in the admin UI rather than as
   a permissions error.

6. Once DNS has propagated, get a real certificate:

   ```bash
   sudo bash docker/scripts/go-live.sh yourdomain.com
   ```

7. Pick a canonical hostname. Certbot leaves both `yourdomain.com` and
   `www.yourdomain.com` serving identical content with no redirect between
   them — see **Making the apex canonical** in
   [docker/nginx/ssl-reference.md](./docker/nginx/ssl-reference.md). Skipping
   this is not fatal, but it splits inbound links, reads as duplicate content
   to search engines, and makes any analytics property miss whichever
   hostname it isn't pointed at.

8. Confirm your content is actually on the block volume:

   ```bash
   df -h /mnt/grav-data/grav/user-data   # want the block device, not the boot disk
   ```

   See **Verify the volume is really being used** below for why this is worth
   thirty seconds.

## Content ownership: the container is `www-data`, you are not

The single most confusing failure in this stack, and worth understanding
before you copy any content in.

The Grav container serves everything as **`www-data`** (uid/gid 33 in the
official image, and the same on Ubuntu — the ids lining up is what makes the
bind mount work). Anything you copy in from outside — an `scp` from your
laptop, a migration script, an editor over SSH — lands owned by **whoever
ran the copy**, normally `ubuntu`.

When those disagree, Grav's admin UI reports a flat **"Couldn't save"** on
every edit. It does not say "permission denied", it does not name a file,
and the real cause appears only in the container log. It is easy to spend an
afternoon suspecting the application.

The bootstrap script sets this up correctly to begin with: `user-data` is
owned by `www-data`, group-writable, with setgid on directories so new files
inherit the `www-data` group, and the `ubuntu` user is added to that group.
(Group membership applies at next login — reconnect your SSH session.)

**What bootstrap cannot do is keep it correct.** A bulk copy still lands
files owned by you, and `umask 022` means group-write is not granted even
though the group is right. After any migration, restore, or bulk `scp` into
`user-data`, run both halves:

```bash
sudo chown -R www-data:www-data /mnt/grav-data/grav/user-data
sudo chmod -R g+rwX          /mnt/grav-data/grav/user-data
docker exec -u www-data grav-app bin/grav clearcache
```

`chown` alone is the common mistake — it fixes ownership but not the mode
bits, so newly created files still arrive without group-write and the
problem comes back in a different shape.

Better still, avoid the whole class of problem by writing as the right user
in the first place:

```bash
sudo -u www-data cp -r /tmp/incoming/* /mnt/grav-data/grav/user-data/user/pages/
```

To confirm what the container actually sees:

```bash
docker exec grav-app ls -la /var/www/html/user/pages | head
```

## Verify the volume is really being used

The block volume exists so your content survives the instance being rebuilt —
including via `terraform apply -replace='module.grav_host.oci_core_instance.grav_host'`,
which this repo documents as the way to re-run a changed bootstrap script.
That guarantee is only real if the content is actually *on* the volume.

It is easy for this to drift and produce no symptom at all. The bootstrap
script mounts the volume at `/mnt/grav-data`, but nothing stops a later
deploy — a migration from another platform, a hand-run `docker compose`, a
path typo — from writing content somewhere on the boot disk instead. The
site works perfectly either way. You find out at rebuild time, which is the
worst possible moment.

```bash
# The device backing your content. Want /dev/sdb (or whatever the data
# volume is) — NOT /dev/sda1, the boot disk.
df -h /mnt/grav-data/grav/user-data

# What every running container actually reads from
docker ps --format '{{.Names}}' | while read c; do echo "[$c]"; \
  docker inspect "$c" --format '{{range .Mounts}}  {{.Source}} -> {{.Destination}}{{println}}{{end}}'; done
```

The second command is also how you catch a stack you forgot was running.
A container left over from a previous platform can sit for weeks holding
the volume and consuming memory, with no DNS record or nginx site pointing
at it to remind you it exists.

If you do need to relocate content onto the volume later, two things matter:
copy with `rsync -aHAX --numeric-ids` (database data directories are owned
by container UIDs that have no matching named user on the host — without
`--numeric-ids` the database will not restart), and rename the old
directory aside instead of deleting it, so rollback stays trivial until
you have verified the move.

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
