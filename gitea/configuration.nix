{ pkgs, lib, ... }:
let
  sources = import ../nix/sources.nix;
  elo-anything = import sources.elo-anything { };
in {
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

  # utilities
  environment.systemPackages = [ pkgs.kakoune-unwrapped ];

  ## Security Stuff
  networking.firewall.allowedTCPPorts = [
    22 # admin ssh
    80
    443
    2222 # gitea ssh
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
      nixos root     concourse
    '';
    authentication = "local all all ident map=nixos";

    # I could have done all this by hand, but I didn't have to because Nixos is
    # nice. ❤️
    ensureDatabases = [ "gitea" "concourse" ];
    ensureUsers = [
      {
        name = "gitea";
        ensurePermissions = { "DATABASE gitea" = "ALL PRIVILEGES"; };
      }
      {
        name = "concourse";
        ensurePermissions = { "DATABASE concourse" = "ALL PRIVILEGES"; };
      }
    ];
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
      SSH_PORT = 2222

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

      [log]
      LEVEL = Warning
      ENABLE_XORM_LOG = false
      ENABLE_ACCESS_LOG = false
    '';
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

      root = "${elo-anything}/share/elo-anything";
    };

    virtualHosts."ci.bytes.zone" = {
      forceSSL = true;
      enableACME = true;

      locations."/".proxyPass = "http://localhost:8080";
    };
  };

  security.acme = {
    email = "brian@brianthicks.com";
    acceptTerms = true;
  };

  ## CI with Concourse
  users.groups.concourse = { };
  users.users.concourse = {
    group = "concourse";
    home = "/home/concourse";
    createHome = true;
  };
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  docker-containers = let concourse-image = "concourse/concourse:6.5.1";
  in {
    concourse-web = {
      image = "${concourse-image}";
      cmd = [ "web" ];
      ports = [ "8079:8079" "8080:8080" ];
      volumes = [
        "/home/concourse:/home/concourse:ro"
        "/var/run/postgresql:/var/run/postgresql"
      ];
      environment = {
        CONCOURSE_CLUSTER_NAME = "bytes.zone";
        CONCOURSE_ADD_LOCAL_USER =
          "brian:${builtins.readFile ./concourse_password}";
        CONCOURSE_MAIN_TEAM_LOCAL_USER = "brian";
        CONCOURSE_EXTERNAL_URL = "https://ci.bytes.zone";

        # keys
        CONCOURSE_SESSION_SIGNING_KEY = "/home/concourse/session_signing_key";
        CONCOURSE_TSA_HOST_KEY = "/home/concourse/tsa_host_key";
        CONCOURSE_TSA_AUTHORIZED_KEYS =
          "/home/concourse/authorized_worker_keys";

        # database
        CONCOURSE_POSTGRES_SOCKET = "/var/run/postgresql";
        CONCOURSE_POSTGRES_USER = "concourse";
        CONCOURSE_POSTGRES_DATABASE = "concourse";
      };
    };

    concourse-worker = {
      image = "${concourse-image}";
      cmd = [ "worker" ];
      ports = [ "7777:7777" "7788:7788" ];
      extraDockerOptions = [ "--privileged" "--link=concourse-web" ];
      volumes = [ "/home/concourse:/home/concourse:ro" ];
      environment = {
        CONCOURSE_TSA_HOST = "concourse-web:2222";
        CONCOURSE_TSA_PUBLIC_KEY = "/home/concourse/tsa_host_key.pub";
        CONCOURSE_TSA_WORKER_PRIVATE_KEY = "/home/concourse/worker_key";
      };
    };
  };

  ## backups
  services.postgresqlBackup = {
    enable = true;
    backupAll = true;
    location = "/mnt/db/backups";
    startAt = "*-*-* 01:15:00";
  };

  nixpkgs.config.allowUnfree = true;
  services.tarsnap = {
    enable = true;
    archives.everything = {
      cachedir = "/var/cache/tarsnap";
      directories = [ "/mnt/objects/gitea" "/mnt/db/backups" ];
      keyfile = "/root/backups.key";
      period = "02:15";
    };
  };
}
