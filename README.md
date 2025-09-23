# NixOS DDCCI Module for NVIDIA

[![Built with Nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A simple, declarative NixOS module to automatically configure DDC/CI, enabling software-based brightness control for external monitors on systems with NVIDIA GPUs.

---

## Table of Contents

- [The Problem](#the-problem)
- [The Solution](#the-solution)
- [Features](#features)
- [Requirements](#requirements)
- [Installation & Usage](#installation--usage)
- [How It Works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Acknowledgments](#acknowledgments)

## The Problem

By default, Linux environments like NixOS lack a straightforward, out-of-the-box way to control external monitor brightness, unlike the integrated controls found on laptops. This requires manually loading specific kernel modules, identifying the correct I2C bus provided by the GPU driver, and creating system devices on every boot—a complex and error-prone process, especially with proprietary NVIDIA drivers.

## The Solution

This module completely automates and abstracts away the entire setup process. It provides a single, simple option in your NixOS configuration. By enabling it, you get:
- Automatic loading of the required kernel drivers.
- An intelligent `systemd` service that reliably detects your monitor *after* the graphics stack is fully initialized.
- A ready-to-use device in `/sys/class/backlight/`, which can be controlled by standard desktop widgets and command-line utilities (e.g., `brightnessctl`).

All the complexity is hidden "under the hood."

## Features

- **Fully Automatic:** No need to manually find `i2c` bus numbers or write custom scripts.
- **Declarative:** Managed by a single line in your configuration: `hardware.ddcci.enable = true;`.
- **Reliable:** Uses a `systemd` service that runs after `display-manager.service` to prevent race conditions during boot.
- **Self-Contained:** Automatically installs all necessary dependencies, including `ddcutil` and the `ddcci-driver`.
- **Compatible:** Uses conservative `ddcutil` settings for maximum compatibility with a wide range of monitors.

## Requirements

- **NixOS** with **Flakes** enabled.
- An **NVIDIA** graphics card with the proprietary drivers installed.

## Installation & Usage

Integrating this module into your NixOS Flake configuration is a simple three-step process.

#### 1. Add the Module to Your `flake.nix` Inputs

```nix
# /path/to/your/flake.nix
{
  inputs = {
    # ... your other inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Add this module as a new input:
    nixos-ddcci-nvidia.url = "github:poogas/nixos-ddcci-nvidia";
  };

  # Ensure your outputs function uses the `@inputs` pattern to capture all inputs.
  # This makes them available to all your modules via `specialArgs`.
  outputs = { self, nixpkgs, ... }@inputs: {
    # ...
  };
}
```

#### 2. Import the Module into Your NixOS Configuration

The best practice is to create a small, local "wrapper" module that imports the real module from the flake. This keeps your main configuration files clean.

First, create a new file, for example at `/etc/nixos/modules/hardware/ddcci.nix`:
```nix
# /etc/nixos/modules/hardware/ddcci.nix
# This file acts as a bridge to the external flake.
{ inputs, ... }:

{
  imports = [
    # Import the actual module from the `inputs` attribute set.
    inputs.nixos-ddcci-nvidia.nixosModules.default
  ];
}
```
Then, import this local wrapper from your main configuration or a relevant `default.nix` file.

```nix
# /etc/nixos/configuration.nix or /etc/nixos/modules/hardware/default.nix
{
  imports = [
    # ... other module imports
    ./modules/hardware/ddcci.nix # Path to your new wrapper file
  ];
}
```

#### 3. Enable the Option

In your main `configuration.nix` or any other system module, add the following line to activate the module:

```nix
# /etc/nixos/configuration.nix
{
  # ...
  hardware.ddcci.enable = true;
  # ...
}
```

#### 4. Rebuild Your System

Run `sudo nixos-rebuild switch` and reboot. After rebooting, a new device should appear in `/sys/class/backlight/`, and brightness controls should now be available.

## How It Works

1.  **`boot.extraModulePackages`**: Installs the `ddcci-driver` package, which provides the necessary kernel modules.
2.  **`boot.kernelModules`**: Loads the `ddcci-backlight` and `i2c-dev` modules at boot time.
3.  **`environment.systemPackages`**: Installs the `ddcutil` package, which is required for monitor detection.
4.  **`systemd.services.ddcci-setup`**: Creates a `systemd` service that:
    - Runs **after** the graphical session is ready (`display-manager.service`).
    - Executes `ddcutil detect` to find all active I2C buses connected to monitors.
    - For each bus found, it creates a new `ddcci` device by writing to the appropriate path in `/sys/bus/i2c/devices/`.

## Troubleshooting

If brightness control is not working after installation and a reboot, the first step is to check the status of the `systemd` service:
```bash
sudo systemctl status ddcci-setup.service
```
If the service has failed, check its logs for errors to understand the cause.

## Acknowledgments

This module would not be possible without the great work of the following projects:
- [ddcci-driver-linux](https://gitlab.com/ddcci-driver-linux/ddcci-driver-linux)
- [ddcutil](https://www.ddcutil.com/)

---
Made with ❤️ for the NixOS community.
