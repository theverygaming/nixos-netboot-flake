{
  # references:
  # https://sidhion.com/blog/posts/nixos_server_issues/
  description = "tiny NixOS iso";
  inputs.nixpkgs.url = "nixpkgs/nixos-24.05";
  inputs.netboot.url = "github:theverygaming/nixos-netboot-flake";
  outputs = { self, nixpkgs, netboot }: {
    webroot = (netboot.netboot {
      targetSystem = "x86_64-linux";
      hostSystem = "x86_64-linux";
      netbootUrlbase = "http://192.168.2.131:8081";
      extraModules = [
        # for the QEMU VM
        "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
        # to reduce size
        "${nixpkgs}/nixos/modules/profiles/minimal.nix"
        # .. sadly couldn't get perlless to work (something something stage 1 init??)
        "${nixpkgs}/nixos/modules/profiles/perlless.nix" # NOTE: this forbids perl from being used anywhere, so if you need perl, remove this line
        ({ lib, pkgs, ... }: {
          nix.enable = false;

          # do not pull in nix (caused by the iso build)
          # https://github.com/NixOS/nixpkgs/blob/21008834ed1708bc7b2b112afbe56644f6432619/nixos/modules/installer/cd-dvd/iso-image.nix#L882
          boot.postBootCommands = lib.mkForce "";

          services.udev.enable = false;
          services.lvm.enable = false;
          security.sudo.enable = false;

          # disable some big kernel drivers (probably works, didn't want to wait for it to compile)
          /*boot.kernelPatches = [{
              name = "no-unused-modules";
              patch = null;
              extraStructuredConfig = with lib.kernel; {
                MEDIA_SUPPORT = lib.mkForce no;
                WLAN = lib.mkForce no;
                DRM = lib.mkForce no;

                # unused options we have to remove resulting from this
                ATH10K_DFS_CERTIFIED = lib.mkForce unset;
                ATH9K_AHB = lib.mkForce unset;
                ATH9K_DFS_CERTIFIED = lib.mkForce unset;
                ATH9K_PCI = lib.mkForce unset;
                B43_PHY_HT = lib.mkForce unset;
                BRCMFMAC_PCIE = lib.mkForce unset;
                BRCMFMAC_USB = lib.mkForce unset;
                DRM_ACCEL = lib.mkForce unset;
                DRM_AMDGPU_CIK = lib.mkForce unset;
                DRM_AMDGPU_SI = lib.mkForce unset;
                DRM_AMDGPU_USERPTR = lib.mkForce unset;
                DRM_AMD_ACP = lib.mkForce unset;
                DRM_AMD_DC_FP = lib.mkForce unset;
                DRM_AMD_DC_SI = lib.mkForce unset;
                DRM_AMD_SECURE_DISPLAY = lib.mkForce unset;
                DRM_DP_AUX_CHARDEV = lib.mkForce unset;
                DRM_DP_CEC = lib.mkForce unset;
                DRM_FBDEV_EMULATION = lib.mkForce unset;
                DRM_GMA500 = lib.mkForce unset;
                DRM_HYPERV = lib.mkForce unset;
                DRM_I915_GVT = lib.mkForce unset;
                DRM_I915_GVT_KVMGT = lib.mkForce unset;
                DRM_LEGACY = lib.mkForce unset;
                DRM_LOAD_EDID_FIRMWARE = lib.mkForce unset;
                DRM_NOUVEAU_SVM = lib.mkForce unset;
                DRM_SIMPLEDRM = lib.mkForce unset;
                DRM_VBOXVIDEO = lib.mkForce unset;
                DVB_DYNAMIC_MINORS = lib.mkForce unset;
                HOSTAP_FIRMWARE = lib.mkForce unset;
                HOSTAP_FIRMWARE_NVRAM = lib.mkForce unset;
                HSA_AMD = lib.mkForce unset;
                IPW2100_MONITOR = lib.mkForce unset;
                IPW2200_MONITOR = lib.mkForce unset;
                MEDIA_ANALOG_TV_SUPPORT = lib.mkForce unset;
                MEDIA_ATTACH = lib.mkForce unset;
                MEDIA_CAMERA_SUPPORT = lib.mkForce unset;
                MEDIA_CEC_RC = lib.mkForce unset;
                MEDIA_CONTROLLER = lib.mkForce unset;
                MEDIA_DIGITAL_TV_SUPPORT = lib.mkForce unset;
                MEDIA_PCI_SUPPORT = lib.mkForce unset;
                MEDIA_USB_SUPPORT = lib.mkForce unset;
                POWER_RESET_GPIO = lib.mkForce unset;
                POWER_RESET_GPIO_RESTART = lib.mkForce unset;
                RT2800USB_RT53XX = lib.mkForce unset;
                RT2800USB_RT55XX = lib.mkForce unset;
                RTW88 = lib.mkForce unset;
                RTW88_8822BE = lib.mkForce unset;
                RTW88_8822CE = lib.mkForce unset;
              };
            }];*/
        })
        # other stuff
        ({ lib, pkgs, ... }: {
          # tehee evil :3c (if ur wondering why the bash promt is so broken, this is why :3)
          environment.systemPackages = lib.mkForce [ pkgs.busybox pkgs.bash pkgs.ncdu ];

          services.getty.autologinUser = "root";

          system.stateVersion = "24.05";
        })
      ];
    }).webroot;
  };
}
