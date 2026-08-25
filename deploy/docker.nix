# Importable NixOS module — declares Docker for the a2t-mrv production VM.
# Do NOT use this file as a standalone /etc/nixos/configuration.nix replacement.
# It must be imported from the existing system configuration; see deploy/README.md Step 2.
#
# This replaces any imperative `nix-env -iA nixpkgs.docker` invocation.
# Docker enabled here survives reboots without any further manual steps.

{ config, pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    # Pin the Docker package for full reproducibility. Update this attribute
    # path when upgrading Docker (check `nix-env -qaP | grep docker`).
    package = pkgs.docker;
  };
}
