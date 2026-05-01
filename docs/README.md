# KoreForge Documentation

This folder is the documentation home for the KoreForge workspace. The workspace is special because it describes many independent repos, shared standards, scripts, release workflows, and ecosystem-level decisions.

## Document Types

KoreForge documentation uses a small set of document types:

| Type | Purpose |
| --- | --- |
| Specification | Defines required behavior, contracts, scope, and acceptance criteria. |
| Detailed design | Explains implementation choices, architecture, state, data flow, and tradeoffs. |
| User guide | Shows consumers how to install, configure, and use a package, tool, template, or app. |
| Developer guide | Shows contributors how to build, test, extend, debug, and release a repo. |
| Structure | Describes folder layouts, repo boundaries, dependency direction, or application interactions. |
| Deeper explanation | Captures complex context that does not belong in the other types. These should be rare and clearly named. |

## Workspace Documentation

| Area | Location | Purpose |
| --- | --- | --- |
| Documentation standard | [ecosystem/documentation-standard.md](ecosystem/documentation-standard.md) | Canonical document types, names, and placement rules. |
| Documentation inventory | [ecosystem/documentation-inventory.md](ecosystem/documentation-inventory.md) | Current docs classified by repo and type. |
| Skills catalog | [skills/README.md](skills/README.md) | Human and LLM workflows for common ecosystem tasks. |
| Layout | [ecosystem/layout.md](ecosystem/layout.md) | Workspace and repo folder structure. |
| Naming | [ecosystem/naming.md](ecosystem/naming.md) | Repo, package, assembly, namespace, and branch naming. |
| Build and release | [ecosystem/build-and-release.md](ecosystem/build-and-release.md) | Scripts, artifacts, local feed, and release workflow. |
| Docker development | [development/docker.md](development/docker.md) | Local infrastructure workflow. |

## Per-Repo Documentation

Each child repo should keep its own docs in `doc/` unless the repo already has a strong reason to use `docs/`. New repos should use `doc/`.

The root `README.md` in a child repo is the entry point. It should link to the repo's standard docs instead of trying to hold every detail itself.

Canonical per-repo docs are:

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
```

Not every repo needs every document. A small package may only need `README.md`, `doc/specification.md`, and `doc/user-guide.md`. Complex apps and generators can add detailed design, structure, and notes.

## Rules

1. Do not create new document categories casually. Use the standard types first.
2. Put generated output under `artifacts/`, not under `docs/` or child repo roots.
3. Generated API documentation belongs under `docs/ecosystem/Api/` or `artifacts/reports/`, depending on whether it is checked in.
4. Main workspace docs may have more types than child repos, but they must still identify their purpose clearly.
5. When touching an old doc with a non-standard name, either rename it to the canonical name or list it in [ecosystem/documentation-inventory.md](ecosystem/documentation-inventory.md) with its document type.
