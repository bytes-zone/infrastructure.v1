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

  environment.systemPackages = [ pkgs.tree ];

  # Security Stuff
  services.openssh.ports = [ 2200 ];
  networking.firewall.allowedTCPPorts = [
    22 # gitea ssh
    80
    443
    2200 # admin ssh
  ];

  # PostgreSQL
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_11;

    dataDir = "/mnt/db/data";

    # security
    identMap = ''
      nixos root     postgres
      nixos postgres postgres
      nixos gitea    gitea
    '';
    authentication = "local all all ident map=nixos";
    enableTCPIP = false;

    # initial setup
    ensureDatabases = [ "gitea" ];
    ensureUsers = [{
      name = "gitea";
      ensurePermissions = { "DATABASE gitea" = "ALL PRIVILEGES"; };
    }];
  };

  # Gitea
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

      [attachment]
      ENABLED = true
      PATH = /mnt/objects/gitea/attachments

      [other]
      SHOW_FOOTER_BRANDING = false
    '';

    # TODO: mailer settings
  };
  systemd.services.gitea.serviceConfig = {
    AmbientCapabilities = "cap_net_bind_service";
    CapabilityBoundingSet = "cap_net_bind_service";
  };

  # Nginx reverse proxy
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

  # backups
  services.duplicity = {
    enable = true;
    root = "/mnt/objects/gitea";
    targetUrl = "file:///mnt/backups/gitea";
  };
  services.postgresqlBackup = {
    enable = true;
    backupAll = true;
    location = "/mnt/backups/postgresql";
  };
}
