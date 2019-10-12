terraform {
  required_version = "~> 0.12"

  backend "remote" {
    organization = "brianhicks"
    workspaces {
      name = "gitea"
    }
  }
}
