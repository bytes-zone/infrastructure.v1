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

resource "cloudflare_record" "bytes_zone" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = ""
  type    = "A"
  value   = digitalocean_droplet.gitea.ipv4_address
  ttl     = 1 # automatic
  proxied = false
}

resource "cloudflare_record" "www_bytes_zone" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "www"
  type    = "A"
  value   = digitalocean_droplet.gitea.ipv4_address
  ttl     = 1 # automatic
  proxied = false
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

resource "cloudflare_record" "datalog_bytes_zone" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "datalog"
  type    = "A"
  value   = digitalocean_droplet.gitea.ipv4_address
  ttl     = 1 # automatic
  proxied = false
}

resource "cloudflare_record" "stats_bytes_zone" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "stats"
  type    = "A"
  value   = digitalocean_droplet.gitea.ipv4_address
  ttl     = 1 # automatic
  proxied = false
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

## Google Verification

resource "cloudflare_record" "bytes_zone_verification" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  type    = "TXT"
  name    = "@"
  value   = "google-site-verification=56ARNdYATpXCvRV8MdmtBd_6LI5iLpzs2MfUuDs3FYo"
  ttl     = 1 # automatic
}

## elm-conf

data "cloudflare_zones" "elm_conf" {
  filter {
    name = "elm-conf.com"
  }
}

resource "cloudflare_record" "_2020_elm_conf" {
  zone_id = data.cloudflare_zones.elm_conf.zones[0].id
  name    = "2020"
  type    = "A"
  value   = digitalocean_droplet.gitea.ipv4_address
  ttl     = 1 # automatic
  proxied = false
}

resource "cloudflare_record" "apex_elm_conf" {
  zone_id = data.cloudflare_zones.elm_conf.zones[0].id
  name    = "@"
  type    = "A"
  value   = digitalocean_droplet.gitea.ipv4_address
  ttl     = 1 # automatic
  proxied = true
}

resource "cloudflare_record" "www_elm_conf" {
  zone_id = data.cloudflare_zones.elm_conf.zones[0].id
  name    = "www"
  type    = "A"
  value   = digitalocean_droplet.gitea.ipv4_address
  ttl     = 1 # automatic
  proxied = true
}

resource "cloudflare_record" "_2019_elm_conf" {
  zone_id = data.cloudflare_zones.elm_conf.zones[0].id
  name    = "2019"
  type    = "CNAME"
  value   = "elm-conf-2019.netlify.com"
  ttl     = 1 # automatic
  proxied = true
}

# elm-conf mail

resource "cloudflare_record" "k1_domainkey_elm_conf" {
  zone_id = data.cloudflare_zones.elm_conf.zones[0].id
  name    = "k1._domainkey"
  type    = "CNAME"
  value   = "dkim.mcsv.net"
  ttl     = 1 # automatic
  proxied = true
}

resource "cloudflare_record" "mx_10_elm_conf" {
  zone_id  = data.cloudflare_zones.elm_conf.zones[0].id
  name     = "@"
  type     = "MX"
  value    = "mail.protonmail.ch"
  priority = 10
  ttl      = 1 # automatic
}

resource "cloudflare_record" "mx_20_elm_conf" {
  zone_id  = data.cloudflare_zones.elm_conf.zones[0].id
  name     = "@"
  type     = "MX"
  value    = "mailsec.protonmail.ch"
  priority = 20
  ttl      = 1 # automatic
}

resource "cloudflare_record" "_dmarc_elm_conf" {
  zone_id = data.cloudflare_zones.elm_conf.zones[0].id
  name    = "_dmarc"
  type    = "TXT"
  value   = "v=DMARC1; p=none; rua=mailto:hey@elm-conf.com"
  ttl     = 1 # automatic
}

resource "cloudflare_record" "spf_elm_conf" {
  zone_id = data.cloudflare_zones.elm_conf.zones[0].id
  name    = "elm-conf.com"
  type    = "TXT"
  value   = "v=spf1 include:_spf.protonmail.ch mx include:servers.mcsv.net ~all"
  ttl     = 1 # automatic
}

resource "cloudflare_record" "protonmail_verification_elm_conf" {
  zone_id = data.cloudflare_zones.elm_conf.zones[0].id
  name    = "elm-conf.com"
  type    = "TXT"
  value   = "protonmail-verification=a957cb0a0974d0b39dcc9b05cb84defa3268d456"
  ttl     = 1 # automatic
}

resource "cloudflare_record" "protonmail_domainkey_elm_conf" {
  zone_id = data.cloudflare_zones.elm_conf.zones[0].id
  name    = "protonmail._domainkey"
  type    = "TXT"
  value   = "v=DKIM1;k=rsa;p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAk7jO/4l4nHQqj1tPMZrL+Zg+pFW5xoJe8ZVwu/FUWxcuUwOd3l3CacuRig8GoniNnNZZPVQ8X/i7RANP/aGIiTcDHah74RB2oFzJ7ykeK8OxyRZuLsORTK7PFH/ac8EUQ3HXGY7j13z7ltLW3wMlPrVE43OIb4R/yUDqEm5ZmfTIeB8qOpUKLyuduOx+BMEuJDYQNM+iBN2T2ZYZP0GJz1Y+t2AUsPQdbwz3yjKculeBcdNbNZO84yup6WwTIYpvRTgFbS7oYqPBporN2vofNjhrCLxhiXZGr7gNsg/b2UJuiwPcWM4e426URJMtltmw10JqlYSUi5vuDMEK+bmxFQIDAQAB;"
  ttl     = 1 # automatic
}
