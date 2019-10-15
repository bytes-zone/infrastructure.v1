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
  version = "~> 1.9"

  token = "${var.digitalocean_token}"
}

variable "cloudflare_token" {}

provider "cloudflare" {
  version = "~> 2.0"

  api_token = "${var.cloudflare_token}"
}

variable "mailgun_token" {}

provider "mailgun" {
  version = "~> 0.2"

  api_key = "${var.mailgun_token}"
}

# INFRASTRUCTURE

variable "region" { default = "nyc1" }

resource "digitalocean_ssh_key" "gitea" {
  name       = "gitea root"
  public_key = "${file("${path.module}/keys/gitea.id_rsa.pub")}"
}

resource "digitalocean_volume" "gitea_db" {
  name                     = "gitea_db"
  size                     = 5
  description              = "postgres storage for gitea"
  initial_filesystem_type  = "ext4"
  initial_filesystem_label = "db"
  region                   = "${var.region}"
}

resource "digitalocean_volume" "gitea_objects" {
  name                     = "gitea_objects"
  size                     = 10
  description              = "git+lfs object storage for gitea"
  initial_filesystem_type  = "ext4"
  initial_filesystem_label = "objects"
  region                   = "${var.region}"
}

resource "digitalocean_volume" "gitea_backups" {
  name                     = "gitea_backups"
  size                     = 15
  description              = "backup staging area for gitea services"
  initial_filesystem_type  = "ext4"
  initial_filesystem_label = "backups"
  region                   = "${var.region}"
}

resource "digitalocean_droplet" "gitea" {
  name      = "gitea"
  region    = "${var.region}"
  size      = "s-1vcpu-1gb"
  image     = "ubuntu-16-04-x64" # not worried that this is old; we'll soon infect it with NixOS
  backups   = true
  ipv6      = true
  user_data = "${file("${path.module}/nixos_infect.yaml")}"
  ssh_keys  = ["${digitalocean_ssh_key.gitea.id}"]
  volume_ids = [
    "${digitalocean_volume.gitea_db.id}",
    "${digitalocean_volume.gitea_objects.id}",
    "${digitalocean_volume.gitea_backups.id}",
  ]
}

resource "digitalocean_project" "git" {
  name        = "git"
  environment = "production"
  resources = [
    "${digitalocean_droplet.gitea.urn}",
    "${digitalocean_volume.gitea_db.urn}",
    "${digitalocean_volume.gitea_objects.urn}",
    "${digitalocean_volume.gitea_backups.urn}",
  ]
}

# DNS

data "cloudflare_zones" "bytes_zone" {
  filter {
    name = "bytes.zone"
  }
}

resource "cloudflare_record" "git_bytes_zone" {
  zone_id = "${data.cloudflare_zones.bytes_zone.zones[0].id}"
  name    = "git"
  type    = "A"
  value   = "${digitalocean_droplet.gitea.ipv4_address}"
  ttl     = 1 # automatic
  proxied = true
}
