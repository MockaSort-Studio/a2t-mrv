{ pkgs, lib, config, inputs, ... }:

let
  # GitHub Actions mounts host Node.js binaries (glibc-compiled) into the
  # container at /__e. They need /lib64/ld-linux-x86-64.so.2 to execute.
  # Nix containers have no FHS paths — copyToRoot creates the symlink directly.
  fhs-compat = pkgs.runCommand "fhs-compat" { } ''
    mkdir -p $out/lib64
    ln -sf ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \
      $out/lib64/ld-linux-x86-64.so.2
  '';
in
{
  # https://devenv.sh/languages/
  languages.elixir.enable = true;
  languages.erlang.enable = true;
  languages.javascript = {
    enable = true;
    npm.enable = true;
  };

  # https://devenv.sh/packages/
  packages = [
    pkgs.git
  ] ++ lib.optionals (config.containers.ci.isBuilding or false) [
    pkgs.gh
    pkgs.curl
    pkgs.jq
    pkgs.yq-go
  ];

  # https://devenv.sh/services/
  # Vanilla PostgreSQL. devenv runs it on a Unix socket and exports
  # PGHOST (socket dir) / PGDATA. Phoenix connects via socket_dir
  # (see livedata/config/dev.exs and livedata/config/test.exs) — no
  # TCP/password needed.
  # Port 5433 avoids clashing with a system PostgreSQL on the default 5432.
  # devenv exports PGPORT; Phoenix reads it (see the livedata/config files).
  # Databases (livedata_dev / livedata_test) are created by `mix ecto.create`,
  # which is run from inside the livedata/ app directory.
  services.postgres = {
    enable = true;
    port = 5433;
    extensions = extensions: [
      extensions.postgis
    ];
  };

  # https://devenv.sh/basics/
  enterShell = ''
    mix local.hex --force --if-missing
    mix local.rebar --force --if-missing
  '';

  # https://devenv.sh/containers/
  containers.ci = {
    name = "a2t-mrv-env";
    registry = "docker://ghcr.io/mockasort-studio/";
    layers = [{
      copyToRoot = [ fhs-compat ];
    }];
  };

  # See full reference at https://devenv.sh/reference/options/
}
