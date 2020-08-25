terraform {
  required_version = "~> 0.12"

  backend "remote" {
    organization = "brianhicks"
    workspaces {
      name = "git"
    }
  }
}

# PROVIDERS

variable "digitalocean_token" {}

provider "digitalocean" {
  version = "1.14.0"

  token = var.digitalocean_token
}

variable "cloudflare_token" {}

provider "cloudflare" {
  version = "~> 2.0"

  api_token = var.cloudflare_token
}

variable "mailgun_token" {}

provider "mailgun" {
  version = "~> 0.2"

  api_key = var.mailgun_token
}

# INFRASTRUCTURE

variable "region" { default = "nyc1" }

resource "digitalocean_ssh_key" "gitea" {
  name       = "gitea root"
  public_key = file("${path.module}/keys/gitea.id_rsa.pub")
}

resource "digitalocean_volume" "gitea_db" {
  name                     = "gitea_db"
  size                     = 5
  description              = "postgres storage for gitea"
  initial_filesystem_type  = "ext4"
  initial_filesystem_label = "db"
  region                   = var.region
}

resource "digitalocean_volume" "gitea_objects" {
  name                     = "gitea_objects"
  size                     = 10
  description              = "git+lfs object storage for gitea"
  initial_filesystem_type  = "ext4"
  initial_filesystem_label = "objects"
  region                   = var.region
}

resource "digitalocean_droplet" "gitea" {
  name      = "gitea"
  region    = var.region
  size      = "s-1vcpu-1gb"
  image     = "ubuntu-16-04-x64" # not worried that this is old; we'll soon infect it with NixOS
  backups   = true
  ipv6      = true
  user_data = file("${path.module}/nixos_infect.yaml")
  ssh_keys  = [digitalocean_ssh_key.gitea.id]
  volume_ids = [
    digitalocean_volume.gitea_db.id,
    digitalocean_volume.gitea_objects.id,
  ]
}

resource "digitalocean_project" "git" {
  name        = "git"
  environment = "production"
  resources = [
    digitalocean_droplet.gitea.urn,
    digitalocean_volume.gitea_db.urn,
    digitalocean_volume.gitea_objects.urn,
  ]
}

# DNS

data "cloudflare_zones" "bytes_zone" {
  filter {
    name = "bytes.zone"
  }
}

resource "cloudflare_record" "git_bytes_zone" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "git"
  type    = "A"
  value   = digitalocean_droplet.gitea.ipv4_address
  ttl     = 1     # automatic
  proxied = false # git push over SSH doesn't work otherwise
}

resource "cloudflare_record" "elo_bytes_zone" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "elo"
  type    = "A"
  value   = digitalocean_droplet.gitea.ipv4_address
  ttl     = 1 # automatic
  proxied = false
}

# Mail

resource "mailgun_domain" "git_bytes_zone" {
  name        = cloudflare_record.git_bytes_zone.hostname
  region      = "us"
  spam_action = "disabled"
}

resource "cloudflare_record" "git_bytes_zone_spf" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "git"
  type    = "TXT"
  value   = "v=spf1 include:mailgun.org ~all"
  ttl     = 1 # automatic
}

resource "cloudflare_record" "git_bytes_zone_domainkey" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "k1._domainkey.git"
  type    = "TXT"
  value   = "k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCrpdr7dT7MIv5L/yCvX2et+EMuAZtOa+PcZGc7DEPKNHlHJnp11db+syhFxLG1NkGd1hFW/TPXWPpoHXmJa4PQx0S+4UnC0cHaYwbTE1xMJRijRps1XsfmA9a7p9bD60xOTGb5EoO3wMxUbhuvDZfBtVwEjCBdJ8ZqWvkOFfyBKQIDAQAB"
  ttl     = 1 # automatic
}

resource "cloudflare_record" "git_bytes_zone_mxa" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "git"
  type    = "MX"
  value   = "mxa.mailgun.org"
  ttl     = 1 # automatic
}

resource "cloudflare_record" "git_bytes_zone_mxb" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "git"
  type    = "MX"
  value   = "mxb.mailgun.org"
  ttl     = 1 # automatic
}

resource "cloudflare_record" "git_bytes_zone_return" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "email.git"
  type    = "CNAME"
  value   = "mailgun.org"
  ttl     = 1 # automatic
}

# Netlify Blog

resource "cloudflare_record" "bytes_zone_cname" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "@"
  type    = "CNAME"
  value   = "bytes-zone.netlify.com"
  ttl     = 1     # automatic
  proxied = false # Netlify does their own SSL so we don't need CloudFlare's
}

resource "cloudflare_record" "www_bytes_zone_cname" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "www"
  type    = "CNAME"
  value   = "bytes-zone.netlify.com"
  ttl     = 1     # automatic
  proxied = false # Netlify does their own SSL so we don't need CloudFlare's
}

# SSL

resource "cloudflare_record" "git_bytes_zone_caa" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "git"
  type    = "CAA"
  ttl     = 1 # automatic

  data = {
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org"
  }
}
