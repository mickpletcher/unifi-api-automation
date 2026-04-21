Create or update an implementation plan for a completed spec.

Context: UnifiOps is a single-file PowerShell script. Plans must account for the fact that all changes land in UnifiOps.ps1 unless a new file is explicitly required by the spec.

Steps:
1. Read UnifiOps.ps1 to understand current structure before planning anything.
2. Read .github/specs/<feature-slug>/spec.md.
3. Create or update .github/specs/<feature-slug>/plan.md using .github/specs/templates/plan-template.md.
4. List design decisions explicitly. A design decision is a choice that could have gone another way. Explain the tradeoff for each.
5. List every file that changes, what changes in it, and why.
6. Write implementation steps in the exact order they must be executed.
7. Write validation steps as exact PowerShell commands that can be copy-pasted and run without modification.
8. Write rollout and backout steps specific to this repo. No generic advice.

Output:
1. Show implementation order.
2. Show files to edit.
3. Show exact validation commands.
