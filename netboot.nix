# Copyright (c) 2003-2024 Eelco Dolstra and the Nixpkgs/NixOS contributors

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# This module creates netboot media containing the given NixOS
# configuration.

{ config, lib, pkgs, nixpkgs, netbootUrlbase, useSquashfs, ... }:

with lib;

{
  options = {
    netboot.squashfsCompression = mkOption {
      default = with pkgs.stdenv.hostPlatform; "xz -Xdict-size 100% "
        + lib.optionalString isx86 "-Xbcj x86"
        # Untested but should also reduce size for these platforms
        + lib.optionalString isAarch "-Xbcj arm"
        + lib.optionalString (isPower && is32bit && isBigEndian) "-Xbcj powerpc"
        + lib.optionalString (isSparc) "-Xbcj sparc";
      description = ''
        Compression settings to use for the squashfs nix store.
      '';
      example = "zstd -Xcompression-level 6";
      type = types.str;
    };

    netboot.storeContents = mkOption {
      example = literalExpression "[ pkgs.stdenv ]";
      description = ''
        This option lists additional derivations to be included in the
        Nix store in the generated netboot image.
      '';
    };

  };

  config = {
    # We don't need grub
    boot.loader.grub.enable = false;

    # !!! Hack - attributes expected by other modules.
    environment.systemPackages = [ pkgs.grub2_efi ]
      ++ (lib.optionals (pkgs.stdenv.hostPlatform.system != "aarch64-linux") [ pkgs.grub2 pkgs.syslinux ]);

    # file systems
    fileSystems = (if useSquashfs then {
      "/nix/store" = mkImageMediaOverride
        {
          fsType = "squashfs";
          device = "../nix-store.squashfs";
          options = [ "loop" ];
          neededForBoot = true;
        };
    } else { });

    boot.initrd.availableKernelModules = (if useSquashfs then [ "squashfs" ] else [ ]);
    boot.initrd.kernelModules = [ "loop" ];

    # Closures to be copied to the Nix store, namely the init
    # script and the top-level system configuration directory.
    netboot.storeContents =
      [ config.system.build.toplevel ];

    # Create the squashfs image that contains the Nix store.
    system.build.squashfsStore =
      if useSquashfs then
        pkgs.callPackage "${nixpkgs}/nixos/lib/make-squashfs.nix"
          {
            storeContents = config.netboot.storeContents;
            comp = config.netboot.squashfsCompression;
          }
      else null;

    # Create the initrd
    system.build.netbootRamdisk =
      if useSquashfs then
        pkgs.makeInitrdNG
          {
            inherit (config.boot.initrd) compressor;
            prepend = [ "${config.system.build.initialRamdisk}/initrd" ];

            contents =
              [{
                object = config.system.build.squashfsStore;
                symlink = "/nix-store.squashfs";
              }];
          }
      else
      # else use the default
        config.system.build.initialRamdisk;

    # ipxe boot script
    system.build.netbootIpxeScript = pkgs.writeTextDir "netboot.ipxe" ''
      #!ipxe
      # Use the cmdline variable to allow the user to specify custom kernel params
      # when chainloading this script from other iPXE scripts like netboot.xyz
      kernel ${pkgs.stdenv.hostPlatform.linux-kernel.target} initrd=initrd init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} ''${cmdline}
      initrd initrd
      boot
    '';

    # ipxe ISO etc.
    system.build.ipxe = pkgs.ipxe.override {
      embedScript = pkgs.stdenv.mkDerivation {
        name = "ipxe-embedscript";

        buildCommand = ''
          cat <<EOF > $out
          #!ipxe
          dhcp
          set cmdline boot.shell_on_fail # boot.trace
          chain ${netbootUrlbase}/init.ipxe
          EOF
        '';
      };
    };
  };
}
