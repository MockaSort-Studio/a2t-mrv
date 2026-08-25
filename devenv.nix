{ pkgs, lib, config, inputs, ... }:

let
  # Fixed-output derivation containing all Mix dependencies for the production
  # release build. The hash must be computed once and committed:
  #
  #   devenv container build livedata --copy
  #
  # The first run fails with a hash mismatch; copy the "got:" value from the
  # error and replace lib.fakeHash below, then rebuild.
  #
  mixFodDeps = pkgs.beamPackages.fetchMixDeps {
    pname = "livedata-mix-deps";
    version = "0.1.0";
    src = ./livedata;
    hash = "sha256-2UrgFFrFYUO9CLTGKvlh9ngO+D/doY3FFaOkEKUMGOA=";
  };

  # Tailwind v4.1.12 standalone CLI for Linux x86_64.
  # pkgs.tailwindcss in the pinned nixpkgs resolves to v3, which is
  # incompatible with the v4 CLI syntax and config in livedata/assets/css/app.css.
  # Tailwind publishes prebuilt executables on GitHub releases; fetch directly.
  # The binary is dynamically linked against glibc/libstdc++ and expects the
  # standard FHS dynamic linker path, which doesn't exist in the Nix sandbox —
  # autoPatchelfHook rewrites its interpreter/rpath to Nix store paths.
  tailwindcssV4 = pkgs.stdenv.mkDerivation {
    pname = "tailwindcss-v4-cli";
    version = "4.1.12";
    src = pkgs.fetchurl {
      url = "https://github.com/tailwindlabs/tailwindcss/releases/download/v4.1.12/tailwindcss-linux-x64";
      hash = "sha256-Xu7mbqI36umhYPozFP0M92q5k1Uamfr7Fvodtsa5Aok=";
    };
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/tailwindcss
      chmod +x $out/bin/tailwindcss
    '';
  };

  # Production Mix release.
  # Assets are compiled using nixpkgs-provided esbuild and the Tailwind v4
  # standalone binary (tailwindcssV4 above) instead of the Mix-managed
  # binaries, which download at runtime and are unavailable in the Nix sandbox.
  #
  livedataRelease = pkgs.beamPackages.mixRelease {
    pname = "livedata";
    version = "0.1.0";
    src = ./livedata;
    inherit mixFodDeps;
    nativeBuildInputs = [ pkgs.nodejs pkgs.git ];

    # Run after `mix compile`, before `mix release` (installPhase).
    # deps/ is available (symlinked from mixFodDeps by configurePhase).
    # _build/prod/ is also present — phoenix-colocated/livedata is compiled
    # there by `mix compile` and must be on NODE_PATH for the esbuild bundle.
    postBuild = ''
      NODE_PATH="$PWD/deps:$PWD/_build/prod" \
        ${pkgs.esbuild}/bin/esbuild assets/js/app.js \
          --bundle --target=es2022 \
          --outdir=priv/static/assets/js \
          --external:/fonts/* --external:/images/* \
          --alias:@=. \
          --define:process.env.NODE_ENV=\"production\"

      ${tailwindcssV4}/bin/tailwindcss \
        --input=assets/css/app.css \
        --output=priv/static/assets/css/app.css \
        --minify
    '';
  };
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
    pkgs.terraform
    pkgs.tflint
  ];

  # Environment variables set in both the dev shell and the built container.
  env.LANG = "en_US.UTF-8";
  env.LC_ALL = "en_US.UTF-8";

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
      extensions.timescaledb
    ];
    settings = {
      shared_preload_libraries = "timescaledb";
    };
  };

  # Production OCI image, built via `devenv container build livedata`.
  # Contains only the compiled Mix release and its Nix-tracked runtime
  # dependencies — not the Elixir/Erlang toolchain or dev shell.
  #
  # Build:  devenv container build livedata --copy
  # Load:   docker load < result
  # Start:  see deploy/README.md
  #
  containers.livedata = {
    name = "livedata";

    copyToRoot = pkgs.buildEnv {
      name = "livedata-root";
      paths = [
        livedataRelease
        pkgs.cacert   # CA bundle for TLS verify-peer (Repo ssl: true on Neon)
        pkgs.bash     # /bin/sh for release overlay scripts
        pkgs.coreutils
      ];
      pathsToLink = [ "/" ];
    };

    # Points directly at the release derivation's own store path rather than
    # the buildEnv-merged /bin/start — the merge produced no resolvable file
    # at the container-root path (stat failed at container start), while
    # ${livedataRelease}/bin/start is guaranteed to exist: Mix always copies
    # rel/overlays/ into the release root, and postFixup's wrapProgram
    # preserves the "start" name (renames the original to .start-wrapped).
    entrypoint = [ "${livedataRelease}/bin/start" ];
  };

  # https://devenv.sh/basics/
  enterShell = ''
    mix local.hex --force --if-missing
    mix local.rebar --force --if-missing
    git config core.hooksPath .githooks
  '';

  # See full reference at https://devenv.sh/reference/options/
}
