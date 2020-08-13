# Gitea

This is the configuration for the instance of Gitea you're probably looking at right now!

Here's how to build it:

1. have a `x86_64-linux` builder locally. I use [LnL7/nix-docker](https://github.com/LnL7/nix-docker).
2. `cd` here and run `nix-build` to create the system configuration
3. deploy using `./deploy.sh HOST PATH` where `PATH` is the path to deploy (hint: `./deploy.sh wherever $(nix-build)` works great.)

To build successfully, you'll need a mailgun user/password in `smtp_password`.
Grab it from the mailgun dashboard or `terraform show` in `../terraform`.

Instructions in `deploy.sh` from [*Industrial-strength Deployments in Three Commands* by Vaibhav Sagar](https://vaibhavsagar.com/blog/2019/08/22/industrial-strength-deployments/)
