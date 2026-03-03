# Build Command Parameters

Source:
- https://docs.acoinfo.com/realevo-stream/guide/command/build_command.html
- Page update time: 2026-03-03

## `rl-build`

Manages project compilation workflows.

Core syntax:

```bash
rl-build <subcommand> [--project=<name>] [--parallel=<n>] [--strip=<true|false>] [--installdir=<path>]
```

## Subcommands

### `rl-build all`

Executes clean → config → build → install sequentially:

```bash
rl-build all --project=<name> --parallel=<n> [--strip=<true|false>] [--installdir=<path>]
```

### `rl-build clean`

Remove all build artifacts, reset project to initial state:

```bash
rl-build clean --project=<name>
```

### `rl-build config`

Configure the project build:

```bash
rl-build config --project=<name> [--installdir=<path>]
```

### `rl-build build`

Compile the project:

```bash
rl-build build --project=<name> [--parallel=<n>]
```

### `rl-build install`

Install build outputs:

```bash
rl-build install --project=<name> [--strip=<true|false>]
```

### `rl-build uninstall`

Remove build artifacts from install directories:

```bash
rl-build uninstall --project=<name>
```

### `rl-build symbolcheck`

Validate ELF symbol integrity:

```bash
rl-build symbolcheck --path=<file_path>
rl-build symbolcheck --project=<name>
```

## Parameters

- `--project`: Project name. Optional if cwd is inside the project directory.
- `--parallel`: Compilation thread count. Default: `1`.
- `--strip`: Strip binaries after install. Default: `true`.
- `--installdir`: Installation prefix directory. Default: `/`.
- `--path`: Single file path for symbolcheck.
