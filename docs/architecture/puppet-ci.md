# New Workflow Design

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────────┐
│    validate     │────▶│      test       │────▶│      package        │
│ (lint + syntax) │     │ (rspec-puppet)  │     │ (create artifact)   │
└─────────────────┘     └─────────────────┘     └─────────────────────┘
                                                           │
                                                           ▼
                                               ┌─────────────────────┐
                                               │  📦 Download from   │
                                               │  GitHub Actions UI  │
                                               │  & deploy locally   │
                                               └─────────────────────┘
```

### How to Deploy

1. **Push changes** → GitHub validates and packages Puppet code
2. **Download artifact** from the workflow run
3. **Deploy locally**:
   ```powershell
   ./Make.ps1 puppet-deploy
   ```
   Or:
   ```bash
   bolt plan run deploy_simple --targets pi-cluster
   ```
