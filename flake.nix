{
  # references:
  # https://nixos.wiki/wiki/Creating_a_NixOS_live_CD
  description = "tiny NixOS netboot thing";
  inputs.nixpkgs.url = "nixpkgs/nixos-24.05";
  outputs = { self, nixpkgs }: {
    netboot = { targetSystem, hostSystem, netbootUrlbase, rootDiskSize ? "10M", extraModules ? [ ] }:
      let
        netbootsystem = nixpkgs.lib.nixosSystem {
          system = targetSystem;
          modules = [
            {
              _module.args = {
                nixpkgs = nixpkgs;
                netbootUrlbase = netbootUrlbase;
                rootDiskSize = rootDiskSize;
              };
            }
            ./netboot.nix
          ] ++ extraModules;
        };
      in
      {
        netbootsystem = netbootsystem;
        webroot = nixpkgs.legacyPackages.${hostSystem}.stdenv.mkDerivation
          {
            name = "webroot";

            buildCommand =
              ''
                mkdir -p "$out"
                ln -s "${netbootsystem.config.system.build.kernel}/${netbootsystem.pkgs.stdenv.hostPlatform.linux-kernel.target}" "$out"
                ln -s "${netbootsystem.config.system.build.netbootRamdisk}/initrd" "$out"
                ln -s "${netbootsystem.config.system.build.netbootIpxeScript}/netboot.ipxe" "$out/init.ipxe"
                ln -s "${netbootsystem.config.system.build.ipxe}" "$out/ipxe_bin"
              '';
          };
      };
  };
}
