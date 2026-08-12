Create or update an implementation plan for a completed spec.

Context: UnifiOps is a PowerShell 7 module with a thin standalone script. Shared behavior belongs in UnifiOps/UnifiOps.Functions.ps1 and public exports are declared in the module files.

Steps:
1. Read UnifiOps.ps1, UnifiOps/UnifiOps.Functions.ps1, the module manifest, and current tests before planning anything.
2. Read .github/specs/<feature-slug>/spec.md.
3. Create or update .github/specs/<feature-slug>/plan.md using .github/specs/templates/plan-template.md.
4. List design decisions explicitly. A design decision is a choice that could have gone another way. Explain the tradeoff for each.
5. List every file that changes, what changes in it, and why.
6. Write implementation steps in the exact order they must be executed.
7. Include ./Invoke-Validation.ps1 as the mandatory validation command. Add exact feature-specific commands when needed.
8. Write rollout and backout steps specific to this repo. No generic advice.

Output:
1. Show implementation order.
2. Show files to edit.
3. Show exact validation commands.
