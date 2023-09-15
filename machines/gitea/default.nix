{ config, pkgs, lib, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./networking.nix # generated at runtime by nixos-infect
  ];

  system.stateVersion = "19.09";

  boot.tmp.cleanOnBoot = true;
  networking.hostName = "gitea";
  networking.firewall.allowPing = true;

  users.users.brian = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCtdJAHUm6TlJnze9qBiGgGG/ZnZ4YizV+AkERuR5qXpQ5Ug4A9tre+al3T+uQgfoZyIUVNeRd0oSW9T2GSuBmRiWkUT0MOCOcHhXUueO7C6BRDONRb4KXvhJpZlAAYBolVeXyo5JtqDo58ODMpoh7owybFD9ZNjDF/P3ppaI6/zqbTIRyagAT/T7+eCO+IW+/74qgBh600OaVdqt8lueZ4A5R/I//b3CoWetCp/y94vYiNItzyWansd4V7swBZjh0fJ488TZ9Z/CkZjbfkYZj1kILqpYCsQN5NVfS4wfa1YX62MXkU45MOsGhpM22sqoPtDbftR9zJyoH/oB5lKKUIxKoroeC9Tw7NWGeGzDnn4H/2HAWbGQ366jLavzES7gRt4xZlJTKb1V1QVAW7kEJ1Yoo7BTCktBwSVmN/p1JYktn1ClwvahNvDxgPHdq+IMtMeNA3iWq1ibGL3o/xyBB5f84SFpD5o0jD20Ow8KDwmeIVfEzfg4REvHrV2tzHMKpfKDptDv1fDDmFGlo30Tq77d4kLSO/VSBfAXnXr3bTKdG0Rz8f5XdxUPk76NlKjttt5cCHU8SiyhMktSiAPPCzfD60TokPNSuUWbwjYsrXAUrF0eirAeGbcW+1dhTOlVEfLyIztea4+XGPt4EOK7keoPYG/dNAGxnOjjJaR3aMZQ== brianhicks@flame.local"
    ];
  };

  services.openssh = {
    enable = true;
    settings.LogLevel = "ERROR";
  };

  # utilities
  environment.systemPackages = [
    pkgs.comma
    pkgs.goaccess
    pkgs.goatcounter
    pkgs.kakoune-unwrapped
    pkgs.sysz
    (
      # from https://nixos.org/manual/nixos/stable/index.html#module-services-postgres-upgrading
      let newPostgres = pkgs.postgresql_15;
      in pkgs.writeScriptBin "upgrade-pg-cluster" ''
        set -eux
        # XXX it's perhaps advisable to stop all services that depend on postgresql
        systemctl stop postgresql

        export NEWDATA="/var/lib/postgresql/${newPostgres.psqlSchema}"

        export NEWBIN="${newPostgres}/bin"

        export OLDDATA="${config.services.postgresql.dataDir}"
        export OLDBIN="${config.services.postgresql.package}/bin"

        install -d -m 0700 -o postgres -g postgres "$NEWDATA"
        cd "$NEWDATA"
        sudo -u postgres $NEWBIN/initdb -D "$NEWDATA"

        sudo -u postgres $NEWBIN/pg_upgrade \
          --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
          --old-bindir $OLDBIN --new-bindir $NEWBIN \
          "$@"
      ''
    )
  ];

  ## nix
  nix = {
    gc.automatic = true;
    settings.trusted-users = [ "root" "@wheel" ];
  };

  ## Security Stuff
  networking.firewall.allowedTCPPorts = [
    22 # admin ssh
    80
    443
    2222 # gitea ssh
  ];
  security.sudo.wheelNeedsPassword = false;

  ## PostgreSQL
  # primary metadata storage for gitea (e.g. logins, permissions... but not
  # repo data itself.)
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_15;

    # we don't allow network login, even over localhost. That means that all
    # our logins are tied to system users.
    enableTCPIP = false;
    identMap = ''
      nixos root        postgres
      nixos postgres    postgres
      nixos gitea       gitea
      nixos goatcounter goatcounter
    '';
    authentication = "local all all ident map=nixos";

    # I could have done all this by hand, but I didn't have to because Nixos is
    # nice. ❤️
    ensureDatabases = [ "gitea" "goatcounter" ];
    ensureUsers = [
      {
        name = "gitea";
        ensurePermissions = { "DATABASE gitea" = "ALL PRIVILEGES"; };
      }
      {
        name = "goatcounter";
        ensurePermissions = { "DATABASE goatcounter" = "ALL PRIVILEGES"; };
      }
    ];
  };

  ## Redis
  # used for gitea sessions and cache. That's why there are only two databases!
  services.redis.servers.ephemeral = {
    enable = true;
    port = 6379;
    databases = 2;
    logLevel = "warning";
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

    settings = {
      # only for people I invite!
      service.DISABLE_REGISTRATION = true;

      ui.DEFAULT_THEME = "gitea";

      server = {
        ROOT_URL = "https://git.bytes.zone";

        LANDING_PAGE = "explore";

        # ssh
        START_SSH_SERVER = true;
        SSH_PORT = 2222;
        BUILTIN_SSH_SERVER_USER = "git";
      };

      lfs = {
        enable = true;
        PATH = "/mnt/objects/gitea/lfs";
      };

      attachment = {
        ENABLED = true;
        PATH = "/mnt/objects/gitea/attachments";
      };

      cache = {
        ADAPTER = "redis";
        HOST = "network:tcp,addr=:6379,db=0";
      };

      session = {
        PROVIDER = "redis";
        PROVIDER_CONFIG = "network=tcp,addr=:6379,db=1";
      };

      log = {
        LEVEL = "Error";
        ENABLE_XORM_LOG = false;
        ENABLE_ACCESS_LOG = false;
      };

      other.SHOW_FOOTER_BRANDING = false;
    };
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

    commonHttpConfig = ''
      log_format vcombined '$host:$server_port $remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"';
      access_log /var/log/nginx/access.log vcombined;
    '';

    virtualHosts."git.bytes.zone" = {
      default = true;

      enableACME = true;
      forceSSL = true;

      locations."/".proxyPass = "http://localhost:3000";
    };

    virtualHosts."elm-conf.com" = {
      serverAliases = [ "www.elm-conf.com" ];
      extraConfig = "return 307 $scheme://2020.elm-conf.com$request_uri;";
    };

    virtualHosts."2020.elm-conf.com" = {
      forceSSL = true;
      enableACME = true;

      root = ./2020.elm-conf.com;
    };

    virtualHosts."elo.bytes.zone" = {
      forceSSL = true;
      enableACME = true;

      root = "${pkgs.elo-anything}/share/elo-anything";
    };

    virtualHosts."datalog.bytes.zone" = {
      forceSSL = true;
      enableACME = true;

      root = "${pkgs.bad-datalog}/share/bad-datalog";
      extraConfig = ''
        try_files $uri /index.html;
      '';
    };

    virtualHosts."mazes.bytes.zone" = {
      forceSSL = true;
      enableACME = true;

      root = "${pkgs.nates-mazes}/share/nates-mazes";
      extraConfig = ''
        try_files $uri /index.html;
      '';
    };

    virtualHosts."bytes.zone" = {
      forceSSL = true;
      enableACME = true;

      root = "${pkgs.bytes-zone}/share/bytes.zone";

      extraConfig = ''
        add_header Strict-Transport-Security max-age=15768000 always;
        add_header Content-Security-Policy "default-src 'none'; child-src https:; script-src 'self' https://stats.bytes.zone; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://stats.bytes.zone/count" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
      '';
    };

    virtualHosts."www.bytes.zone" = {
      forceSSL = true;
      enableACME = true;

      globalRedirect = "https://bytes.zone";
    };

    virtualHosts."stats.bytes.zone" = {
      enableACME = true;
      forceSSL = true;

      locations."/".proxyPass = "http://localhost:8081";
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "brian@brianthicks.com";
  };

  ## backups
  services.postgresqlBackup = {
    enable = true;
    backupAll = true;
    location = "/mnt/db/backups";
    startAt = "*-*-* 01:15:00";
  };

  services.borgbackup.jobs.everything = {
    repo = "t3a40wda@t3a40wda.repo.borgbase.com:repo";

    startAt = "02:15";

    paths = [ "/mnt/objects/gitea" "/mnt/db/backups" ];
    compression = "auto,zlib,6";

    encryption.mode = "repokey-blake2";
    encryption.passCommand = "cat /root/.ssh/borgbackup_key";
    environment.BORG_RSH = "ssh -i /root/.ssh/borgbackup_ed25519";

    prune.keep = {
      within = "1d";
      daily = 7;
      weekly = 4;
      monthly = -1;
    };
  };

  ## goatcounter
  users.groups.goatcounter = { };
  users.users.goatcounter = {
    isSystemUser = true;
    group = "goatcounter";
  };

  systemd.services.goatcounter = {
    description = "goatcounter, privacy-preserving web analytics";
    documentation = [ "https://github.com/zgoat/goatcounter" ];

    enable = true;

    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    path = [ pkgs.goatcounter ];
    script =
      "goatcounter serve -automigrate -db 'postgres://user=goatcounter dbname=goatcounter host=/run/postgresql' -listen localhost:8081 -tls none";

    serviceConfig = {
      User = "goatcounter";
      Group = "goatcounter";
    };
  };
}
