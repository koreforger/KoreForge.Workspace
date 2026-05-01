# Documentation Standard

KoreForge docs should make the reader's next action obvious. The same small taxonomy is used across the workspace and child repos so humans and LLMs can find the right context quickly.

## Standard Types

### Specification

Defines what must be true.

Use for:

- Product or package behavior
- Public contracts and compatibility rules
- Acceptance criteria
- Non-goals and constraints
- Versioned requirements

Canonical names:

- `doc/specification.md` in child repos
- `docs/ecosystem/specifications/<topic>.md` in the workspace when a spec spans repos

### Detailed Design

Explains how the implementation should work.

Use for:

- Architecture and component responsibilities
- Data flow, state flow, and lifecycle diagrams
- Storage schema and migration choices
- Tradeoffs and alternatives considered
- Failure modes and recovery behavior

Canonical names:

- `doc/detailed-design.md`
- `docs/ecosystem/design/<topic>.md`

### User Guide

Shows a consumer how to use the thing.

Use for:

- Installation
- Configuration
- Examples
- Runtime behavior
- Troubleshooting from a consumer's point of view

Canonical names:

- `doc/user-guide.md`
- `docs/ecosystem/guides/<topic>-user-guide.md`

### Developer Guide

Shows a contributor how to work on the thing.

Use for:

- Build and test commands
- Repo-specific scripts
- Local package development
- Debugging
- Release steps
- Extension points

Canonical names:

- `doc/developer-guide.md`
- `docs/ecosystem/guides/<topic>-developer-guide.md`

### Structure

Explains layout and interactions.

Use for:

- Workspace or repo folder layout
- Application interaction diagrams
- Dependency direction
- Runtime topology
- Script discovery rules

Canonical names:

- `doc/structure.md`
- `docs/ecosystem/structure/<topic>.md`

### Deeper Explanation

Captures complex context that does not fit the other document types.

Use sparingly for:

- Complex background reasoning
- Deep troubleshooting notes
- Historical migration notes that still matter
- Advanced implementation explanations

Canonical names:

- `doc/notes/<topic>.md`
- `docs/ecosystem/notes/<topic>.md`

## Child Repo Layout

New and renovated repos should use this layout:

```text
README.md
LICENSE.md
doc/
  specification.md
  detailed-design.md
  user-guide.md
  developer-guide.md
  structure.md
  notes/<topic>.md
scr/
src/
tst/
```

Rules:

1. `README.md` is a short entry point, not a full design archive.
2. `doc/` contains durable checked-in documentation.
3. `docs/` is allowed only when a repo already has external tooling or platform conventions that expect it.
4. Generated reports, coverage, extracted API docs, zips, and package outputs go under the workspace `artifacts/` folder.
5. Analyzer release manifests such as `AnalyzerReleases.Shipped.md` stay beside the analyzer project because their tooling expects that location.
6. Template sample READMEs stay inside the template folders because they are part of template content.

## Workspace Layout

The workspace docs can be broader because the root repo coordinates many repos:

```text
docs/
  README.md
  development/
  ecosystem/
    Api/
    Introduction/
    documentation-standard.md
    documentation-inventory.md
    build-and-release.md
    layout.md
    naming.md
  skills/
```

Workspace docs use existing folders where they are already meaningful:

- `docs/ecosystem/Introduction/` holds publishable narrative introduction docs.
- `docs/ecosystem/Api/` holds checked-in API reference docs.
- `docs/development/` holds local development infrastructure docs.
- `docs/skills/` holds workflow skills for humans and LLMs.

## Naming Rules

1. Prefer lowercase kebab-case for new markdown filenames.
2. Keep package names capitalized only when the package name is the filename, such as `KoreForge.Time.md`.
3. Avoid numbered filenames except in generated or publish-ordered introduction docs.
4. Avoid duplicate names with different casing, such as `UsageGuide.md` and `UserGuide.md`.
5. If a doc is obsolete but historically useful, move it to `doc/notes/` or mark it as superseded at the top.

## Minimum Docs By Repo Type

| Repo type | Required docs |
| --- | --- |
| Runtime package | `README.md`, `doc/specification.md`, `doc/user-guide.md`, `doc/developer-guide.md` |
| Source generator or analyzer | Runtime package docs plus `doc/detailed-design.md` |
| CLI or language server | `README.md`, `doc/user-guide.md`, `doc/developer-guide.md`, `doc/structure.md` |
| Template package | `README.md`, `doc/user-guide.md`, template-scoped READMEs |
| App or harness | `README.md`, `doc/structure.md`, `doc/developer-guide.md` |
| Workspace root | `README.md`, `docs/README.md`, standards, skills, build/release, layout, naming |

## Migration Rule

Do not rename every old document mechanically unless the content has been reviewed. For now, classify legacy files in `documentation-inventory.md`. When a repo is touched for a real feature or renovation, rename its docs to the canonical names and update links in the same commit.
