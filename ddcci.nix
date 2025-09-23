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

      path = [ pkgs.kmod ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          ddcciSetupScript = pkgs.writeShellScript "ddcci-setup" ''
            #! ${pkgs.bash}/bin/bash
            set -e
            modprobe ddcci-backlight || true

            echo "Waiting for NVIDIA I2C buses to become available..."

            for i in $(seq 1 15); do
              if ${lib.getExe pkgs.ddcutil} --disable-dynamic-sleep detect 2>/dev/null | ${lib.getExe pkgs.ripgrep} -q '/dev/i2c-'; then
                echo "I2C buses are ready."
                break
              fi
              if [ $i -eq 15 ]; then
                echo "Timed out waiting for I2C buses. Aborting."
                exit 1
              fi
              sleep 2
            done

            echo "Forcibly recreating DDCCI devices to fix kernel probe failures..."

            ${lib.getExe pkgs.ddcutil} --disable-dynamic-sleep detect | ${lib.getExe pkgs.ripgrep} -o 'I2C bus.*(/dev/i2c-\d+)' --replace '$1' | while read dev; do
              bus_path=$(basename "$dev")
              echo "Re-creating device on ''${bus_path}..."
              echo 0x37 > "/sys/bus/i2c/devices/''${bus_path}/delete_device" 2>/dev/null || true
              sleep 0.1
              echo ddcci 0x37 > "/sys/bus/i2c/devices/''${bus_path}/new_device"
            done

            echo "DDCCI setup finished successfully."
          '';
        in "${ddcciSetupScript}";
      };
    };
  };
}
