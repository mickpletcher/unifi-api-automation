Implement a feature from its plan and track work in tasks.md.

Steps:
1. Read .github/specs/<feature-slug>/spec.md and plan.md.
2. Read UnifiOps.ps1, UnifiOps/UnifiOps.Functions.ps1, the module manifest, and current tests before touching anything.
3. Create or update .github/specs/<feature-slug>/tasks.md using .github/specs/templates/tasks-template.md.
4. Work through plan tasks in order. Mark each task In Progress before starting it, Done immediately when complete.
5. If implementation diverges from the plan, update plan.md to reflect the actual approach before continuing.
6. Commit in small logical units. Commit message format: <type>: <what changed and why in one line>.
7. Run every validation command from plan.md, including ./Invoke-Validation.ps1, and record pass or fail for each one.
8. If any validation fails, fix it before moving to the next task.
9. Update tests, README.md, CHANGELOG.md, and module metadata when behavior changes.

Output:
1. List completed tasks.
2. List changed files.
3. Report each validation command and its result.
4. List remaining tasks.
