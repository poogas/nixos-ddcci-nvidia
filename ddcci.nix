{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.ddcci;
in
{
  options.hardware.ddcci = {
    enable = mkEnableOption "DDCCI Setup for external monitors on NVIDIA systems";
  };

  config = mkIf cfg.enable {

    boot.extraModulePackages = with config.boot.kernelPackages; [ ddcci-driver ];
    boot.kernelModules = [ "ddcci-backlight" "i2c-dev" ];

    environment.systemPackages = [ pkgs.ddcutil ];

    systemd.services.ddcci-setup = {
      description = "DDCCI Setup for external monitors";

      wantedBy = [ "display-manager.service" ];
      after = [ "display-manager.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = let
          ddcciSetupScript = pkgs.writeShellScript "ddcci-setup" ''
            ${lib.getExe pkgs.ddcutil} --disable-dynamic-sleep detect | ${lib.getExe pkgs.ripgrep} -o 'I2C bus.*(/dev/i2c-\d+)' --replace '$1' | while read dev; do
              bus_path=$(basename "$dev")
              echo "Enabling DDCCI on ''${bus_path}"
              echo ddcci 0x37 > "/sys/bus/i2c/devices/''${bus_path}/new_device" || true
            done
            echo "DDCCI setup finished."
          '';
        in "${ddcciSetupScript}";
      };
    };
  };
}
