# @req: REQ-94
# NixOS system configuration for the a2t-mrv production VM.
# Apply with: sudo nixos-rebuild switch --flake /etc/nixos#default
# or imperatively: sudo nixos-rebuild switch -I nixos-config=/path/to/this/file
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

  # The EC2 key pair grants root SSH access; this mirrors the NixOS AMI default.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
}
