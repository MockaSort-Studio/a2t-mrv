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

    # Images built from devenv.nix bake in the app's full Nix closure and run
    # 5-6GB+ each; the root EBS volume is a fixed 20GB system disk that fills
    # up after a couple of deploys. fileSystems."/data" (declared alongside
    # this import in configuration.nix) is the dedicated data volume — point
    # Docker's storage there instead of /var/lib/docker on root.
    daemon.settings = {
      data-root = "/data/docker";
    };
  };
}
