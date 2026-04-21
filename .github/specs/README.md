# GitHub Spec Workflow

This repo uses a simple spec workflow with three files per feature.

1. `spec.md` defines scope and acceptance criteria.
2. `plan.md` defines implementation approach and file changes.
3. `tasks.md` tracks execution status.

## Folder Layout

Place each feature in its own folder under `.github/specs/`.

Example:

`.github/specs/unifiops-export-action/spec.md`
`.github/specs/unifiops-export-action/plan.md`
`.github/specs/unifiops-export-action/tasks.md`

## How To Use

1. Open prompt file `prompts/01-create-spec.md` in Copilot Chat and run it.
2. Review and edit the generated `spec.md`.
3. Open prompt file `prompts/02-create-plan.md` in Copilot Chat and run it.
4. Review and edit the generated `plan.md`.
5. Open prompt file `prompts/03-implement-plan.md` in Copilot Chat and run it.
6. Track work in `tasks.md` until all items are complete.
