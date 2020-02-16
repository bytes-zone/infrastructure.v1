resource "digitalocean_ssh_key" "rpg" {
  name       = "gitea root"
  public_key = file("${path.module}/keys/rpg.id_rsa.pub")
}

resource "digitalocean_droplet" "rpg" {
  name     = "rpg"
  region   = var.region
  size     = "s-1vcpu-1gb"
  image    = "ubuntu-18-04-x64"
  backups  = true
  ipv6     = true
  ssh_keys = [digitalocean_ssh_key.rpg.id]
}

resource "digitalocean_project" "rpg" {
  name        = "rpg"
  environment = "production"
  resources = [
    digitalocean_droplet.rpg.urn
  ]
}

# DNS

resource "cloudflare_record" "rpg_bytes_zone" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "rpg"
  type    = "A"
  value   = digitalocean_droplet.rpg.ipv4_address
  ttl     = 1 # automatic
}

# Mail

resource "mailgun_domain" "rpg_bytes_zone" {
  name        = cloudflare_record.rpg_bytes_zone.hostname
  region      = "us"
  spam_action = "disabled"
}

resource "cloudflare_record" "rpg_bytes_zone_mxa" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "rpg"
  type    = "MX"
  value   = "mxa.mailgun.org"
  ttl     = 1 # automatic
}

resource "cloudflare_record" "rpg_bytes_zone_mxb" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "rpg"
  type    = "MX"
  value   = "mxb.mailgun.org"
  ttl     = 1 # automatic
}

resource "cloudflare_record" "rpg_bytes_zone_spf" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "rpg"
  type    = "TXT"
  value   = "v=spf1 include:mailgun.org ~all"
  ttl     = 1 # automatic
}

resource "cloudflare_record" "rpg_bytes_zone_domainkey" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "krs._domainkey.rpg"
  type    = "TXT"
  value   = "k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDg8A2T5pmHUI4QXtDestgGVkv/66AuNyVo+ywGL3wt3s/4LFRfAX9iBC0II7RNY4GFVW2KBlKTKyxCrSNOUY/pPFFIWMlZO2WcTuilaJXuP5W7nXHopBMhH75AVz+FVrTQHGg4v67T1NEZ2GVTe0MNBTDNrOy8FXMVy03Sqqn2UwIDAQAB"
  ttl     = 1 # automatic
}

resource "cloudflare_record" "email_rpg_bytes_zone_cname" {
  zone_id = data.cloudflare_zones.bytes_zone.zones[0].id
  name    = "email.rpg"
  type    = "CNAME"
  value   = "mailgun.org"
  ttl     = 1 # automatic
}
