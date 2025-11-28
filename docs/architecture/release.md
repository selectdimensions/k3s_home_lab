# New Workflow Design

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   create-tag    │────▶│ build-artifacts │────▶│  security-scan  │
│ (workflow_disp) │     │ (Docker + Helm) │     │    (Trivy)      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                │                        │
                                └────────┬───────────────┘
                                         ▼
                        ┌─────────────────────────────┐
                        │    create-github-release    │
                        │ (changelog + attach assets) │
                        └─────────────────────────────┘
                                         │
                                         ▼
                        ┌─────────────────────────────┐
                        │          notify             │
                        │  (summary + optional Slack) │
                        └─────────────────────────────┘
```

### How to Use

**Option 1: Tag Push**
```bash
git tag v1.0.0
git push origin v1.0.0
```

**Option 2: Manual Trigger**
1. Go to Actions → Release Management → Run workflow
2. Enter version (e.g., `v1.0.0`)
3. Click "Run workflow"
