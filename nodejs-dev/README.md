# Node.js Development

Modern Node.js setup with fast tooling.

## What it installs

- **nvm** - Node version management
- **Node.js LTS** - Latest long-term support version
- **pnpm** - Fast package manager (faster than npm), properly configured
- **TypeScript** - Type-safe JavaScript (global)
- **tsx** - Run TypeScript directly (global)
- **ESLint** - Code linter (global)
- **Prettier** - Code formatter (global)

## Usage

```bash
bash setup.sh
```

Takes ~2-3 minutes.

**Note:** pnpm is automatically configured with a global bin directory. Global tools (`tsc`, `tsx`, `eslint`, `prettier`) are immediately available.

## What you get

```bash
node --version          # Node.js v20.x
pnpm --version          # Fast package manager
tsc --version           # TypeScript compiler
tsx script.ts           # Run TypeScript directly
```

## Quick project

```bash
mkdir my-project && cd my-project
pnpm init
pnpm add express
pnpm add -D typescript @types/node
```

## Switch Node versions

```bash
nvm install 18
nvm use 18
nvm list
```

