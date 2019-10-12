terraform {
  required_version = "~> 0.12"

  backend "remote" {
    organization = "brianhicks"
    workspaces {
      name = "gitea"
    }
  }
}

# PROVIDERS

variable "digitalocean_token" {}

provider "digitalocean" {
  version = "~> 1.9"

  token = "${var.digitalocean_token}"
}
