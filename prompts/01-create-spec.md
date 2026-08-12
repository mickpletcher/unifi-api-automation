Create or update a feature spec for this repository.

Context: UnifiOps is a PowerShell 7 module with a thin standalone script. Shared behavior belongs in UnifiOps/UnifiOps.Functions.ps1. UnifiOps.ps1 delegates to Invoke-UnifiOperation. Specs live in .github/specs/<feature-slug>/.

Steps:
1. Read UnifiOps.ps1, UnifiOps/UnifiOps.Functions.ps1, the module manifest, and current tests before writing anything.
2. Ask for the feature name if not provided.
3. Create the folder .github/specs/<feature-slug>/ if it does not exist.
4. Use .github/specs/templates/spec-template.md as the base.
5. Write spec.md with concrete, testable content in every section.
6. Scope the spec to one feature. If the request is too broad, split it and flag that.
7. Every acceptance criterion must be independently verifiable with a specific command or observable result.
8. Every open question must block implementation or force a design decision. Remove cosmetic questions.
9. Use the official version-specific UniFi OpenAPI document for API behavior. Do not specify private legacy endpoints.

Output:
1. Show the spec file path.
2. List acceptance criteria.
3. List open questions that block implementation.
