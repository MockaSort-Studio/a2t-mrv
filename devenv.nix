{ pkgs, lib, config, inputs, ... }:

let
  # GitHub Actions mounts host Node.js binaries (glibc-compiled) into the
  # container at /__e. These binaries need standard FHS library paths that
  # don't exist in Nix containers. We create /lib64 symlinks pointing into
  # the Nix store so the dynamic linker can resolve all dependencies.
  fhs-compat = pkgs.runCommand "fhs-compat" { } ''
    mkdir -p $out/lib64
    # Dynamic linker
    ln -s ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \
      $out/lib64/ld-linux-x86-64.so.2
    # glibc runtime
    ln -s ${pkgs.glibc}/lib/libc.so.6      $out/lib64/libc.so.6
    ln -s ${pkgs.glibc}/lib/libm.so.6      $out/lib64/libm.so.6
    ln -s ${pkgs.glibc}/lib/libdl.so.2     $out/lib64/libdl.so.2
    ln -s ${pkgs.glibc}/lib/libpthread.so.0 $out/lib64/libpthread.so.0
    # gcc runtime (libstdc++, libgcc_s)
    ln -s ${pkgs.gcc-unwrapped.lib}/lib/libstdc++.so.6 $out/lib64/libstdc++.so.6
    ln -s ${pkgs.gcc-unwrapped.lib}/lib/libgcc_s.so.1  $out/lib64/libgcc_s.so.1
    # zlib (node built-in compression)
    ln -s ${pkgs.zlib}/lib/libz.so.1 $out/lib64/libz.so.1
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

  # Tell the Nix glibc dynamic linker to search /lib64 at runtime.
  # Nix builds glibc without standard FHS search paths — the loader does
  # not look in /lib64 by default. Without this, our fhs-compat symlinks
  # exist but are never found when the GitHub Actions node binary runs.
  env = lib.optionalAttrs (config.containers.ci.isBuilding or false) {
    LD_LIBRARY_PATH = "/lib64";
  };

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
