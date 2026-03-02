---
name: sylixos-dev
description: Assist SylixOS and RealEvo-Stream command-line development workflows. Use when users need to initialize a workspace, choose platform compile parameters, or work with `rl-workspace init` commands for kernel, BSP, driver, or middleware development. Trigger phrases include "创建 workspace", "初始化工作空间", "create workspace", "init workspace", "准备 Base 工程".
---

# SylixOS Dev

## Scope

Use this skill for workspace bootstrapping through RealEvo-Stream CLI (`rl-workspace init`).
Parameter collection and execution are handled by a Bash script. Claude extracts parameters from the user's request and calls the script in CLI mode.

## Workspace Modes

| Mode | When to use |
|------|-------------|
| `product` | User mentions a specific product name/series |
| `prepared-base` | Most common: user wants a fresh SylixOS workspace from a prepared Base |
| `research-base` | User wants to do kernel research/development on libsylixos source |
| `existing-base` | User already has a compiled Base directory |
| `linux` | User wants a Linux cross-compilation workspace |
| `custom` | User wants to manually specify arbitrary parameters |

## Workflow

When the user requests workspace initialization:

1. **Extract parameters**: From the user's message, determine mode and any explicitly mentioned parameters (platform, version, etc.)
2. **First run with `--dry-run`**: Call the script to validate and preview the command:
   ```bash
   bash .agents/skills/sylixos-dev/scripts/workspace_init.sh \
     --mode=<mode> --platform=<platform> [other params...] --dry-run
   ```
3. **Show the dry-run output** to the user and ask for confirmation
4. **Execute**: After user confirms, run again with `--yes` to execute:
   ```bash
   bash .agents/skills/sylixos-dev/scripts/workspace_init.sh \
     --mode=<mode> --platform=<platform> [other params...] --yes
   ```
5. **Report result**: Summarize success or failure

## Script CLI Parameters

Required per mode:

| Mode | Required | Optional |
|------|----------|----------|
| `product` | `--product` | |
| `prepared-base` | `--version`, `--platform` | `--debug_level`, `--createbase`, `--build`, `--base` |
| `research-base` | `--platform` | `--debug_level`, `--base`, `--research_repo`, `--research_branch` |
| `existing-base` | `--base`, `--platform` | `--build`, `--debug_level` |
| `linux` | `--linux_platform`, `--toolchain` | |
| `custom` | `--custom_args` | |

Defaults applied by script: `debug_level=release`, `createbase=true`, `build=false` (prepared-base & existing-base).

Research-base forces: `version=default`, `createbase=true`, `build=false`. Post-init patches the Makefile (SUBDIR → `libsylixos libcextern`, all target make → `make -j16`) but does **not** build by default.

Common `--workspace=<dir>` parameter sets the workspace directory.

Flags: `--dry-run` (preview only), `--yes` (skip confirmation).

## Platform Mapping Hints

When users say informal platform names, map them:
- "arm7" / "a7" / "cortex-a7" → `ARM_A7`
- "arm9" / "920t" → `ARM_920T`
- "arm64" / "aarch64" / "a53" → `ARM64_A53` or `ARM64_GENERIC`
- "x86" / "pentium" → `x86_PENTIUM`
- "x64" / "x86_64" → `X86_64`
- "riscv" / "riscv64" → `RISCV_GC64`
- "loongarch" → `LOONGARCH64`

Full platform list: see `references/platform_compile_parameter.md`

## References

- Workspace command options: `references/workspace_command.md`
- Platform compile parameters: `references/platform_compile_parameter.md`
