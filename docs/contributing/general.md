# General contributing guidelines

## Maintaining these guidelines

When a new package or sub-technology is introduced, create a corresponding file in `docs/contributing/` (e.g. `docs/contributing/livedata.md`). Keep rules that apply across all packages in this file; keep technology-specific rules in the relevant file. When adding a new file, add a matching `@` import in `CLAUDE.md`.

## Ground rules

### Development environment

devenv is used as development environment, docker folder contains environment specification (Dockerfile, activate_env script, entrypoint script) to enable env aware hall of automata dispatch (for TDD implementations). Any change to development environment should also be applied to docker folder

### Project

- Every new folder or package must include a `README.md`.

### AI agents

- Do not commit coding agent artefacts: local `CLAUDE.md` overrides, `.claude/` settings folders, or cache/context files from coding assistant plugins.
- `CLAUDE.md` contains only common general rules and facts — no project-specific state or agent session data.

## Requirement traceability

Every requirement must carry a `@req:` annotation as a comment in code:

```
@req: REQ-ID
```

A test or step covering multiple requirements takes one annotation per requirement.

## Design documents and implementation plans

Design documents and implementation plans are **not committed to the codebase**.
They live in the GitHub discussion for the work:

- **Design and plan** → posted as **comments on the source issue** (the KR or
  Item issue). Keep the design and the plan as separate comments.
- **Implementation summary** → the **PR body** ("What changed" + an acceptance
  criteria checklist), as in PRs #28 and #32.

Do not add `docs/` design/spec/plan files for feature work. A PR that committed a
design file (#18) was closed for this reason: *"The recommendation belongs as a
comment on the source issue … the deliverable content was correct; the delivery
mechanism was not."* Committed Markdown under `docs/` is reserved for durable
guidance (contributing rules, setup), not per-feature design state.

## Source of truth

For development discussion, plans, deeply technical topics, and team sync: the [GitHub project board](https://github.com/orgs/MockaSort-Studio/projects/6).

For product vision and design choices: the [design document on Google Drive](https://docs.google.com/document/d/1JlFrkYvBwnmYHMFnf0Zy8dtvFSPlZAFl46y-3q5NlIQ/edit?usp=sharing).
