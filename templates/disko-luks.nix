{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "NIXOS_TARGET_DISK";
        content = {
          type = "gpt";
          partitions = {
            efi = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            crypt = {
              size = "100%";
              label = "disko_luks";
              content = {
                type = "luks";
                name = "cryptroot";
                content = {
                  type = "lvm_pv";
                  vg = "nixos";
                };
              };
            };
          };
        };
      };
    };
    lvm_vg = {
      nixos = {
        type = "lvm_vg";
        lvs = {
          swap = {
            size = "8G";
            content = { type = "swap"; };
          };
          root = {
            size = "100%FREE";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}