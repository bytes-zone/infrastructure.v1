{ lib, ... }: {
  # This file was populated at runtime with the networking
  # details gathered from the active system.
  networking = {
    nameservers = [ "67.207.67.2" "67.207.67.3" ];
    defaultGateway = "167.99.144.1";
    defaultGateway6 = "2604:a880:400:d1::1";
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce true;
    interfaces = {
      eth0 = {
        ipv4.addresses = [
          {
            address = "167.99.156.113";
            prefixLength = 20;
          }
          {
            address = "10.10.0.5";
            prefixLength = 16;
          }
        ];
        ipv6.addresses = [
          {
            address = "2604:a880:400:d1::ab1:1";
            prefixLength = 64;
          }
          {
            address = "fe80::a09a:5eff:fee5:1c37";
            prefixLength = 64;
          }
        ];
        ipv4.routes = [{
          address = "167.99.144.1";
          prefixLength = 32;
        }];
        ipv6.routes = [{
          address = "2604:a880:400:d1::1";
          prefixLength = 32;
        }];
      };

    };
  };
  services.udev.extraRules = ''
    ATTR{address}=="a2:9a:5e:e5:1c:37", NAME="eth0"

  '';
}
