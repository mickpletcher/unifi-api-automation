# GitHub Spec Workflow

This repo uses a three-file spec workflow per feature. Each feature gets its own folder under `.github/specs/`.

1. `spec.md` defines scope, requirements, and acceptance criteria.
2. `plan.md` defines implementation approach, file changes, and validation commands.
3. `tasks.md` tracks execution status.

## Folder Layout

```
.github/specs/
  <feature-slug>/
    spec.md
    plan.md
    tasks.md
  templates/
    spec-template.md
    plan-template.md
    tasks-template.md
```

## How To Use

Each step has a corresponding prompt file in the `prompts/` folder. Open the prompt in Claude and run it.

1. Run `prompts/01-create-spec.md` to generate `spec.md`.
2. Review and edit `spec.md`. Resolve all open questions before moving on.
3. Run `prompts/02-create-plan.md` to generate `plan.md`.
4. Review and edit `plan.md`. Confirm validation commands are copy-paste ready.
5. Run `prompts/03-implement-plan.md` to execute the plan and generate `tasks.md`.
6. Track work in `tasks.md` until all tasks are Done or Blocked with a clear reason.

## Task Status Values

| Status | Meaning |
| --- | --- |
| Not Started | Work has not begun |
| In Progress | Actively being worked |
| Done | Complete and validated |
| Blocked | Cannot proceed without external input |
