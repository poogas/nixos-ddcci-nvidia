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

      wantedBy = [ "graphical.target" ];
      after = [ "display-manager.service" ];

      path = [ pkgs.kmod pkgs.ddcutil pkgs.ripgrep pkgs.coreutils ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "3s";

        ExecStart = let
          ddcciSetupScript = pkgs.writeShellScript "ddcci-setup" ''
            #! ${pkgs.bash}/bin/bash
            set -euo pipefail

            if ls /sys/class/backlight/ddcci* 1>/dev/null 2>&1; then
              echo "DDCCI backlight device already exists. Exiting."
              exit 0
            fi

            echo "Attempting to find I2C buses..."
            i2c_buses=$(ddcutil --disable-dynamic-sleep detect | rg -o 'I2C bus.*(/dev/i2c-\d+)' --replace '$1')

            if [ -z "$i2c_buses" ]; then
              echo "No I2C buses found yet. Will retry..."
              exit 1
            fi

            echo "I2C buses found. Forcibly recreating DDCCI devices..."
            for dev in $i2c_buses; do
              bus_path=$(basename "$dev")
              device_path="/sys/bus/i2c/devices/''${bus_path}"

              if [ ! -w "''${device_path}/new_device" ]; then
                echo "Sysfs interface 'new_device' not yet ready for ''${bus_path}. Will retry..."
                exit 1
              fi

              echo "-> Re-creating device on ''${bus_path}..."
              echo 0x37 > "''${device_path}/delete_device" || true
              echo ddcci 0x37 > "''${device_path}/new_device"
            done

            if ls /sys/class/backlight/ddcci* 1>/dev/null 2>&1; then
              echo "DDCCI setup successful. Backlight device is now available."
              exit 0
            else
              echo "Error: DDCCI device recreation seems to have failed. Will retry..."
              exit 1
            fi
          '';
        in "${ddcciSetupScript}";
      };
    };
  };
}
