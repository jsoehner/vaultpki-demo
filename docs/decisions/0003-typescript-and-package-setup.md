# ADR-003: TypeScript and Package Configuration

## Status
Accepted

## Date
2026-07-11

## Context
As the repository grows from simple shell scripts to full application layers (like the Node.js dashboard, helper utilities, or future client apps), there is a need to support a structured JavaScript/TypeScript development environment. Static typing via TypeScript helps maintain type safety, while `package.json` configures dependencies and development commands uniformly.

## Decision
Introduce a standard Node.js project root layout including:
1. `package.json` and `package-lock.json` defining developer packages (e.g., `@types/node`, `typescript`).
2. A generic `tsconfig.json` defining standard TypeScript compiler settings (target `ES2022`, module resolution, and strict checks).
3. A source folder `src/` with a sample `index.ts` showing simple TypeScript interface declarations and helper execution.

## Alternatives Considered
### Keep Everything as Vanilla JavaScript/Shell
- **Pros**: Zero compilation step, simple execution.
- **Cons**: Prone to runtime errors as the codebase grows. Harder to maintain API contracts and share data interfaces.

## Consequences
- The project is now structured to support full TypeScript compilation.
- Dependencies can be managed through npm package manifests rather than manual script downloads.
