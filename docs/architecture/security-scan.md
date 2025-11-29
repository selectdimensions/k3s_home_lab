# Key Design Pattern Applied

All workflows now follow a **validation + artifact pattern**:

```
[Validate in Cloud] → [Create Downloadable Artifacts] → [Download & Deploy Locally via Make.ps1]
```

This respects that GitHub Actions cannot reach your local Raspberry Pi cluster.
