
## Requirement traceability

Every test and CI step that covers a CRCF or AUTH requirement must carry a `@req:` annotation:

```
@req: CRCF-28
```

Apply it in the language's native comment or tag syntax. A test covering multiple requirements takes one annotation per requirement. The traceability report is generated from it by grep, never maintained manually.
