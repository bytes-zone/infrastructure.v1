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
  ]
}

resource "digitalocean_project" "git" {
  name        = "git"
  environment = "production"
  resources = [
    "${digitalocean_droplet.gitea.urn}",
    "${digitalocean_volume.gitea_db.urn}",
    "${digitalocean_volume.gitea_objects.urn}",
  ]
}
