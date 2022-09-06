terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.22"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.22"
    }
  }
  required_version = ">= 0.13"
}
