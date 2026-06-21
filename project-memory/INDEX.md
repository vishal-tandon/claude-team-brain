# Project Memory: Index

Project memory is **opt-in**. Not every project needs a dedicated context
slice here. Add a sub-directory (`project-memory/<project-slug>/`) only when
a project is active enough that its context would otherwise pollute the main
shared memory tier.

## When to add project memory

- The project has its own vocabulary, conventions, or decisions that differ
  from the team's shared baseline.
- Multiple people are working on it and need a common context anchor.
- The project will run long enough that context will accumulate.

## Structure

```
project-memory/
└── <project-slug>/
    ├── INDEX.md         ← pointer list for this project's facts
    ├── _TEMPLATE.md     ← copy from shared-memory/_TEMPLATE.md
    └── [fact files]
```

## Entries

<!-- Add entries below when projects are registered. -->

