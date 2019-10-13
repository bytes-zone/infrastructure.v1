{ lib, ... }: {
  # This file was populated at runtime with the networking
  # details gathered from the active system.
  networking = {
    nameservers = [ "67.207.67.3" "67.207.67.2" ];
    defaultGateway = "157.245.128.1";
    defaultGateway6 = "2604:a880:400:d0::1";
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce true;
    interfaces = {
      eth0 = {
        ipv4.addresses = [
          {
            address = "157.245.134.107";
            prefixLength = 20;
          }
          {
            address = "10.10.0.5";
            prefixLength = 16;
          }
        ];
        ipv6.addresses = [
          {
            address = "2604:a880:400:d0::4a9c:a001";
            prefixLength = 64;
          }
          {
            address = "fe80::1ccc:a5ff:fede:6281";
            prefixLength = 64;
          }
        ];
        ipv4.routes = [{
          address = "157.245.128.1";
          prefixLength = 32;
        }];
        ipv6.routes = [{
          address = "2604:a880:400:d0::1";
          prefixLength = 32;
        }];
      };

    };
  };
  services.udev.extraRules = ''
    ATTR{address}=="1e:cc:a5:de:62:81", NAME="eth0"

  '';
}
