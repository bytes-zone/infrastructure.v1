# RPG Server

This one is more manual than I'd like, since Discourse has really strong opinions on how their software should be set up.
So this server is going to be more decision-log-based than configuration-based.
Oh well.

Things that need to be done:

- [x] Invite DM
- [ ] [Post-Install Maintenance](https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md#post-install-maintenance)
  - [ ] Set up backups (tarsnap, probably) ([discourse side](https://meta.discourse.org/t/configure-automatic-backups-for-discourse/14855))
  - [ ] set up [reply via email support](https://meta.discourse.org/t/set-up-reply-via-email-support/14003)
  - [ ] look at [plugins](https://meta.discourse.org/t/install-plugins-in-discourse/19157)
- [ ] Invite initial users

## 2020-02-16: Initial Setup

I'm following [Discourse's install directions](https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md) after the initial cloud setup.

Files are in `/var/discourse`, the setup/update script is at `/var/discourse/discourse-setup` and may need to be run from inside that directory.

Their instructions right now say:

> If you need to change these settings after bootstrapping, you can run ./discourse-setup again (it will re-use your previous values from the file) or edit /containers/app.yml manually with nano and then ./launcher rebuild app, otherwise your changes will not take effect.

Gonna get a basic setup going now and resume at [Post-Install Maintenance](https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md#post-install-maintenance) later today.

... time passes ...

Setting up unattended upgrades: `dpkg-reconfigure -plow unattended-upgrades`

Noting that `/var/discourse/launcher` exists and can be used for various sysadmin tasks.
