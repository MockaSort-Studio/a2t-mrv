# General contributing guidelines

## Ground rules

- Do not commit coding agent artefacts: local `CLAUDE.md` overrides, `.claude/` settings folders, or cache/context files from coding assistant plugins.
- `CLAUDE.md` contains only common general rules and facts — no project-specific state or agent session data.
- Source of truth for design, requirements, tasks, and goals: the GitHub project board for a2t-mrv.
- Every new folder or package must include a `README.md` and a `CONTRIBUTING.md`.

## Requirement traceability

Every test and CI step covering a CRCF or AUTH requirement must carry a `@req:` annotation:

```
@req: CRCF-28
```

A test covering multiple requirements takes one annotation per requirement. Apply it in the language's native syntax:

**Elixir**
```elixir
# @req: REQ-ID
test "duplicate submission is rejected" do
  ...
end
```
or
```elixir
@tag req: "REQ-ID"
test "duplicate submission is rejected" do
  ...
end
```

**Python**
```python
# @req: REQ-ID
def test_duplicate_submission_rejected():
    ...
```

**GitHub Actions**
```yaml
- name: Validate content hash uniqueness
  # @req: REQ-ID
  run: mix test --only crcf_28
```

The traceability report is derived by running `grep -r "@req:" .` — never maintained manually.

## Design documents

Technical decisions, design rationale, and authoritative requirements: [Design Document](https://docs.google.com/document/d/1JlFrkYvBwnmYHMFnf0Zy8dtvFSPlZAFl46y-3q5NlIQ/edit?usp=sharing). Read the relevant section before implementing any entity.

---

// Indiana-Docs 🤠 — CONTRIBUTING.md was present from the start; CLAUDE.md appeared later and quietly duplicated a subset of the same rules. Both now point here.