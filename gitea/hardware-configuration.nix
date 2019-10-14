{ ... }: {
  imports = [ <nixpkgs/nixos/modules/profiles/qemu-guest.nix> ];
  boot.loader.grub.device = "/dev/vda";
  fileSystems = {
    "/" = {
      device = "/dev/vda1";
      fsType = "ext4";
    };
    "/mnt/db" = {
      device = "/dev/disk/by-label/db";
      fsType = "ext4";
      options = [ "discard" "defaults" "noatime" ];
    };
    "/mnt/objects" = {
      device = "/dev/disk/by-label/objects";
      fsType = "ext4";
      options = [ "discard" "defaults" "noatime" ];
    };
    "/mnt/backups" = {
      device = "/dev/disk/by-label/backups";
      fsType = "ext4";
      options = [ "discard" "defaults" "noatime" ];
    };
  };
}
