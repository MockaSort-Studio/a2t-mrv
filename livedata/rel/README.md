# `rel/` — Mix release overlays

> **Temporary.** This directory and `livedata/Dockerfile` are part of the
> example deployment on Render (see [`docs/contributing/deployment.md`](../../docs/contributing/deployment.md)).
> Development uses devenv and Nix, not Mix releases.

`mix release` copies everything under `rel/overlays/` into the root of the
assembled release, preserving paths and permission bits. Files here are
therefore not compiled or templated — they are shipped verbatim. The release
itself is configured by the `releases/0` block in [`mix.exs`](../mix.exs); this
directory only adds files alongside the generated `bin/livedata` launcher.

Three scripts land in the release's `bin/` directory. `bin/server` starts the
app with `PHX_SERVER=true`, which is what flips
`LivedataWeb.Endpoint`'s `server: true` in
[`config/runtime.exs`](../config/runtime.exs) — a release does not start the
HTTP listener otherwise. `bin/migrate` and `bin/seed` call
`Livedata.Release.migrate/0` and `Livedata.Release.seed/0` (see
[`lib/livedata/release.ex`](../lib/livedata/release.ex)) through `eval`, so they
run without Mix and without booting the endpoint. The Render start command
chains all three; see [deployment.md](../../docs/contributing/deployment.md).

All three must stay mode `755` in git (`git ls-files -s livedata/rel` should
show `100755`) — a lost exec bit surfaces on the platform as `permission
denied` at boot, not at build time.
