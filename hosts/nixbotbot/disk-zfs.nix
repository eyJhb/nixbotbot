{ lib, ... }:

let
  makeZFSDatasets = datasets: (lib.mapAttrs' (n: v: lib.nameValuePair v.dataset {
      type = "zfs_fs";
      mountpoint = n;
      options.mountpoint = "legacy";
  } // (if v ? extra then v.extra else {})) datasets);
in {
  disko.devices = {
    disk.disk1 = {
      type = "disk";
      device = lib.mkDefault "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "boot";
            size = "1M";
            type = "EF02";
          };
          esp = {
            name = "ESP";
            size = "500M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };
        };
      };
    };

    zpool = {
      rpool = {
        type = "zpool";
        # rootFsOptions.compression = "zstd";
        rootFsOptions = {
          compression = "on";
          atime = "off";
          acltype = "posixacl";
          xattr = "sa";

          # test
          # "com.sun:auto-snapshot" = "false";
          # "com.klarasystems:vdev_zaps_v2" = "false";
        };

        datasets = let
          baseDatasets = {
            "/" = { dataset = "root"; extra = { postCreateHook = "zfs snapshot rpool/root@blank"; }; };
            "/nix".dataset = "local/nix";
            "/state/stash".dataset = "local/stash";
            "/state/home".dataset = "safe/home";
            "/state/root".dataset = "safe/persistent";
          };
        in (makeZFSDatasets baseDatasets);
      };
    };
  };
}
