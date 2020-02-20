# RPG Server

This one is more manual than I'd like, since Discourse has really strong opinions on how their software should be set up.
So this server is going to be more decision-log-based than configuration-based.
Oh well.

## 2020-02-20: Plugins

I added a new plugin to `/var/discourse/containers/app.yaml` and ran `/var/discourse/launcher rebuild app` to install it.

I'm also configuring ufw today.
Should only need 22, 80, and 443.

```
ufw default deny incoming
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

output of `ufw status`:

```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
22/tcp (v6)                ALLOW       Anywhere (v6)
80/tcp (v6)                ALLOW       Anywhere (v6)
443/tcp (v6)               ALLOW       Anywhere (v6)
```

## 2020-02-16: Initial Setup

Things done:

- [x] Invite DM
- [ ] [Post-Install Maintenance](https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md#post-install-maintenance)
  - [x] Set up backups (tarsnap, probably) ([discourse side](https://meta.discourse.org/t/configure-automatic-backups-for-discourse/14855))
  - [x] add [Mutant Standard](https://mutant.tech) emoji.
  - [ ] set up [reply via email support](https://meta.discourse.org/t/set-up-reply-via-email-support/14003)
  - [ ] look at [plugins](https://meta.discourse.org/t/install-plugins-in-discourse/19157)
- [ ] Invite initial users

I'm following [Discourse's install directions](https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md) after the initial cloud setup.

Files are in `/var/discourse`, the setup/update script is at `/var/discourse/discourse-setup` and may need to be run from inside that directory.

Their instructions right now say:

> If you need to change these settings after bootstrapping, you can run ./discourse-setup again (it will re-use your previous values from the file) or edit /containers/app.yml manually with nano and then ./launcher rebuild app, otherwise your changes will not take effect.

Gonna get a basic setup going now and resume at [Post-Install Maintenance](https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md#post-install-maintenance) later today.

... time passes ...

Setting up unattended upgrades: `dpkg-reconfigure -plow unattended-upgrades`

Noting that `/var/discourse/launcher` exists and can be used for various sysadmin tasks.

### Setting up Backups

Looks like backups output to `/var/discourse/shared/standalone/backups`.
I'm going to configure tarsnap to just back up that whole directory.

Creating a tarsnap key, encrypted and stored in git (next to this file.)
Also creating a read/write key to actually go on the machine.

Downloading from [the .deb tarsnap page](https://www.tarsnap.com/pkg-deb.html)

Plan is to create a systemd unit to run the backup, and a systemd timer to trigger it an hour after the configured backup time (4:30 UTC.)

Command goal is to run `tarsnap -f discourse -c /var/discourse/shared/standalone/backups`.

Corrected paths in the default `/etc/tarsnap.conf` and turned human times on.

Output:

`/root/backup.sh`:

```sh
#!/bin/sh
/usr/bin/tarsnap -c -f discourse-$(date "+%Y-%m-%d-%H-%M-%S") /var/discourse/shared/standalone/backups/
```

`/etc/systemd/system/tarsnap-discourse.service`:

```systemd
[Unit]
After=network-online.target
Description=Tarsnap archive 'discourse'
Requires=network-online.target

[Service]
ExecStart=/root/backup.sh
Type=oneshot
```

`/etc/systemd/system/tarsnap-discourse.timer`:

```systemd
[Unit]

[Timer]
OnCalendar=05:30
Persistent=true
```

Will check tomorrow morning to see if everything ran on time.

## Adding Mutant Standard

Downloaded the latest archive from [mutant.tech](https://mutant.tech)

I uploaded a bunch without any discretion as to what they were, and it seems to have broken image upload on the server.
Boo!

I was able to get the ones I wanted uploaded eventually by rebuilding the server every time I had an issue.
This feels like a rate-limiting thing to me.
I've got an [open ticket on meta.discourse.org](https://meta.discourse.org/t/cant-upload-new-images-or-emoji/141785/2) about it.
