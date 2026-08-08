# `.github/scripts/`

Shell helpers sourced by workflows in [`../workflows/`](../workflows/). They are
libraries, not entry points: each defines functions and is pulled in with
`source`, so nothing here is executable and nothing runs on its own.

- [`render-api.sh`](render-api.sh) — `render_api`, a
  curl wrapper around the Render REST API used by
  [`preview.yml`](../workflows/preview.yml) to move `DATABASE_URL_PR`, repoint
  the service's git branch, and trigger and poll deploys. It reads
  `RENDER_API_KEY` from the environment and surfaces the response body on
  failure, which is where Render explains a rejected request.

Anything shared by more than one workflow step belongs here rather than being
repeated inline; a helper used in exactly one place is usually clearer left in
the step that uses it.
