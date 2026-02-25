# Contributing

> How to add new examples to this repo.

## Workflow

1. **Prototype in `playground/`** — Create a subdirectory for the engagement (e.g., `playground/acme-corp/`). This directory is gitignored, so partner-specific content is never committed.

2. **Generalize** — When a pattern is reusable, strip partner-specific details (names, IPs, subscription IDs, etc.) and move it to the appropriate top-level directory.

3. **Follow the directory template** below.

4. **Submit a PR** with descriptive commit messages.

## Directory Template

Every new example directory should follow this structure:

```
aks-<topic>/
  README.md           # Required — see template below
  *.drawio            # Architecture diagram (Draw.io format)
  *.png or *.svg      # Exported diagram for README embedding
  *.yaml              # Kubernetes manifests (if applicable)
  *.sh                # Scripts (if applicable)
```

## README Template

```markdown
# Title

> One-line description of what this example demonstrates.

## Architecture Diagram

![Architecture](architecture.png)

Open [architecture.drawio](architecture.drawio) in [Draw.io](https://app.diagrams.net/) to view and edit.

## When to Use This

- Scenario 1
- Scenario 2

## Prerequisites

- AKS cluster running
- (other requirements)

## Walkthrough

Step-by-step instructions...

## Related

- [Related Example](../related-example/) — Brief description
```

## Naming Conventions

- **Directories**: lowercase, hyphenated. Prefix AKS-specific examples with `aks-`.
- **Files**: lowercase, hyphenated. Use `.drawio` for diagrams, `.yaml` for manifests, `.sh` for scripts.
- **READMEs**: Always `README.md` (uppercase).

## What NOT to Commit

- Partner-specific content (use `playground/` instead)
- Credentials, subscription IDs, tenant IDs, or real IP addresses
- Terraform state files, `.terraform/` directories
- Binary files larger than 5MB (use a link instead)
