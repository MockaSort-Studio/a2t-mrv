{ pkgs, lib, config, inputs, ... }:

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
  ];

  # https://devenv.sh/services/
  # Vanilla PostgreSQL. devenv runs it on a Unix socket and exports
  # PGHOST (socket dir) / PGDATA. Phoenix connects via socket_dir
  # (see config/dev.exs and config/test.exs) — no TCP/password needed.
  # Port 5433 avoids clashing with a system PostgreSQL on the default 5432.
  # devenv exports PGPORT; Phoenix reads it (see config/dev.exs, config/test.exs).
  # Databases (a2t_mrv_dev / a2t_mrv_test) are created by `mix ecto.create`.
  services.postgres = {
    enable = true;
    port = 5433;
  };

  # https://devenv.sh/basics/
  enterShell = ''
    mix local.hex --force --if-missing
    mix local.rebar --force --if-missing
  '';

  # See full reference at https://devenv.sh/reference/options/
}
