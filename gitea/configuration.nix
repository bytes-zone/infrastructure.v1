{ pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./networking.nix # generated at runtime by nixos-infect
  ];

  boot.cleanTmpDir = true;
  networking.hostName = "gitea";
  networking.firewall.allowPing = true;
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCtdJAHUm6TlJnze9qBiGgGG/ZnZ4YizV+AkERuR5qXpQ5Ug4A9tre+al3T+uQgfoZyIUVNeRd0oSW9T2GSuBmRiWkUT0MOCOcHhXUueO7C6BRDONRb4KXvhJpZlAAYBolVeXyo5JtqDo58ODMpoh7owybFD9ZNjDF/P3ppaI6/zqbTIRyagAT/T7+eCO+IW+/74qgBh600OaVdqt8lueZ4A5R/I//b3CoWetCp/y94vYiNItzyWansd4V7swBZjh0fJ488TZ9Z/CkZjbfkYZj1kILqpYCsQN5NVfS4wfa1YX62MXkU45MOsGhpM22sqoPtDbftR9zJyoH/oB5lKKUIxKoroeC9Tw7NWGeGzDnn4H/2HAWbGQ366jLavzES7gRt4xZlJTKb1V1QVAW7kEJ1Yoo7BTCktBwSVmN/p1JYktn1ClwvahNvDxgPHdq+IMtMeNA3iWq1ibGL3o/xyBB5f84SFpD5o0jD20Ow8KDwmeIVfEzfg4REvHrV2tzHMKpfKDptDv1fDDmFGlo30Tq77d4kLSO/VSBfAXnXr3bTKdG0Rz8f5XdxUPk76NlKjttt5cCHU8SiyhMktSiAPPCzfD60TokPNSuUWbwjYsrXAUrF0eirAeGbcW+1dhTOlVEfLyIztea4+XGPt4EOK7keoPYG/dNAGxnOjjJaR3aMZQ== brianhicks@flame.local"
  ];

  ## Security Stuff
  # we move operational login to `:2200` and git login to `:22`. Honestly, this
  # is *mostly* a quality-of-life improvement: I push with git way more than I
  # ssh in for admin stuff.
  services.openssh.ports = [ 2200 ];
  networking.firewall.allowedTCPPorts = [
    22 # gitea ssh
    80
    443
    2200 # admin ssh
  ];

  ## PostgreSQL
  # primary metadata storage for gitea (e.g. logins, permissions... but not
  # repo data itself.)
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_11;

    # it might not be the *best* to host this on an external volume but it
    # works OK for now. If things prove to be painfully slow as the server
    # grows, it may have to move.
    dataDir = "/mnt/db/data";

    # we don't allow network login, even over localhost. That means that all
    # our logins are tied to system users.
    enableTCPIP = false;
    identMap = ''
      nixos root     postgres
      nixos postgres postgres
      nixos gitea    gitea
    '';
    authentication = "local all all ident map=nixos";

    # I could have done all this by hand, but I didn't have to because Nixos is
    # nice. ❤️
    ensureDatabases = [ "gitea" ];
    ensureUsers = [{
      name = "gitea";
      ensurePermissions = { "DATABASE gitea" = "ALL PRIVILEGES"; };
    }];
  };

  ## Redis
  # used for gitea sessions and cache. That's why there are only two databases!
  services.redis = {
    enable = true;
    databases = 2;
  };

  ## Gitea
  services.gitea = {
    enable = true;
    package = pkgs.gitea;

    repositoryRoot = "/mnt/objects/gitea/repositories";
    stateDir = "/mnt/objects/gitea";

    database = {
      user = "gitea";
      name = "gitea";
      type = "postgres";
    };

    appName = "Git in the Bytes Zone";

    # only for people I invite!
    disableRegistration = true;

    extraConfig = ''
      [ui]
      DEFAULT_THEME = gitea

      [server]
      START_SSH_SERVER = true
      SSH_PORT = 22

      LANDING_PAGE = explore

      LFS_START_SERVER = true
      LFS_CONTENT_PATH = /mnt/objects/gitea/lfs

      ROOT_URL = https://git.bytes.zone/
      SSH_DOMAIN = git.bytes.zone
      BUILTIN_SSH_SERVER_USER = git

      [service]
      REGISTER_EMAIL_CONFIRM = true
      ENABLE_NOTIFY_MAIL = true

      [mailer]
      ENABLED = true
      HOST = smtp.mailgun.org:587
      FROM = git.bytes.zone <noreply@git.bytes.zone>
      USER = postmaster@git.bytes.zone
      PASSWD = ${builtins.readFile ./smtp_password}
      MAILER_TYPE = smtp

      [attachment]
      ENABLED = true
      PATH = /mnt/objects/gitea/attachments

      [cache]
      ADAPTER = redis
      HOST = network:tcp,addr=:6379,db=0

      [session]
      PROVIDER = redis
      PROVIDER_CONFIG = network=tcp,addr=:6379,db=1

      [other]
      SHOW_FOOTER_BRANDING = false
    '';
  };
  # by default, gitea can't bind to ports lower than 1024 since it runs at a
  # user, but we want to bind to :22 for git-over-ssh. These stanzas let the
  # systemd service do that.
  systemd.services.gitea.serviceConfig = {
    AmbientCapabilities = "cap_net_bind_service";
    CapabilityBoundingSet = "cap_net_bind_service";
  };

  ## Nginx
  # by reverse proxying, we get a lot more control over what gets bound where,
  # SSL settings, compression, etc. It's also trivially easy to set up Let's
  # Encrypt!
  services.nginx = {
    enable = true;
    package = pkgs.nginxMainline;
    enableReload = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."git.bytes.zone" = {
      default = true;

      enableACME = true;
      forceSSL = true;

      locations."/" = { proxyPass = "http://localhost:3000"; };
    };
  };

  ## backups
  # this is only local backups. I do remote backups by hand right now. I hope
  # to automate it soon!
  services.postgresqlBackup = {
    enable = true;
    backupAll = true;
    location = "/mnt/backups/postgresql";
  };

  systemd.services.rsync-gitea-objects = {
    description = "rsync gitea objects to the backup location";
    path = [ pkgs.rsync ];
    script = "rsync --recursive /mnt/objects/gitea/ /mnt/backups/gitea/";
  };
  systemd.timers.rsync-gitea-objects = {
    description = "update timer for rsync-gitea-objects";
    partOf = [ "rsync-gitea-objects.service" ];
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "daily";
  };
}
