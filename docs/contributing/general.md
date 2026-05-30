# General contributing guidelines

## Maintaining these guidelines

When a new package or sub-technology is introduced, create a corresponding file in `docs/contributing/` (e.g. `docs/contributing/elixir.md`). Keep rules that apply across all packages in this file; keep technology-specific rules in the relevant file. When adding a new file, add a matching `@` import in `CLAUDE.md`.

## Ground rules

### Project

- Every new folder or package must include a `README.md` and a `CONTRIBUTING.md`.

### AI agents

- Do not commit coding agent artefacts: local `CLAUDE.md` overrides, `.claude/` settings folders, or cache/context files from coding assistant plugins.
- `CLAUDE.md` contains only common general rules and facts — no project-specific state or agent session data.

## Requirement traceability

Every requirement must carry a `@req:` annotation as a comment in code:

```
@req: REQ-ID
```

A test or step covering multiple requirements takes one annotation per requirement.

## Source of truth

For development discussion, plans, deeply technical topics, and team sync: the [GitHub project board](https://github.com/orgs/MockaSort-Studio/projects/6).

For product vision and design choices: the [design document on Google Drive](https://docs.google.com/document/d/1JlFrkYvBwnmYHMFnf0Zy8dtvFSPlZAFl46y-3q5NlIQ/edit?usp=sharing).
