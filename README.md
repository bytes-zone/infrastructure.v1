# Infrastructure

These are the configs and infra stuff for this site (name TBD)!

- `gitea`: system configuration for the gitea instance
- `nix`: pinned nix stuff, both tools and upstreams for nixos
- `terraform`: terraform configuration for compute/DNS resources

## Local Setup

- `git clone` using the instructions on the unnamed site.
- `direnv allow` to get the versions of tools

If you're working with Terraform stuff, `cd terraform && terraform init`.
Contact Brian for access to the remote states and the with-great-power-comes-great-responsibility speech.

To update software versions, run `niv update`.

For making changes to instances after provision, see instructions in `gitea`.

## License

Feel free to use this for learning purposes, but any other use needs my explicit permission.
See `LICENSE`.
