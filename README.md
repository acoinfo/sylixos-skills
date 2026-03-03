# sylixos-dev

An [open agent skill](https://github.com/anthropics/agent-skills-spec) for SylixOS embedded development using the RealEvo-Stream CLI toolchain.

Works with **Claude Code**, **OpenAI Codex**, **OpenClaw**, and any agent that follows the open agent skills standard.

## What it does

| Capability | Commands |
|------------|----------|
| Workspace initialization | `rl-workspace init` — 6 modes (product, prepared-base, research-base, existing-base, linux, custom) |
| Project creation | `rl-project create` — BSP, app, library, kernel module, Python, Go, etc. |
| Project registry | Persistent JSON mapping of project names to git repos |
| Build | Base system (`make`) and projects (`rl-build`) with dependency ordering and pre-build checks |
| Device management | `rl-device add/list/update/delete` — auto-generates name from IP, infers platform |
| Deployment | `rl-upload project/workspace` — upload build outputs to target devices via FTP |

## Install

```bash
git clone https://github.com/SeanPcWoo/sylixos-dev.git
cd sylixos-dev
bash install.sh
```

This installs the skill to `~/.agents/skills/sylixos-dev/`, making it available globally from any directory.

## Usage

Once installed, just talk to your agent naturally:

```
创建一个 ARM64 的 workspace
创建 BSP 工程，仓库是 ssh://git@example.com/bsprk3568.git
编译所有工程
添加设备 192.168.1.100
部署 bsprk3568 到设备
```

The agent will match your intent to the appropriate workflow, show a preview, and execute after your confirmation.

## File Structure

```
├── SKILL.md              # Skill definition (workflows + triggers)
├── AGENTS.md             # Generic agent entry point (Codex / OpenClaw)
├── install.sh            # Global installer
├── scripts/
│   ├── workspace_init.sh # Workspace initialization (interactive + CLI)
│   └── project_create.sh # Project creation (interactive + CLI)
├── data/
│   └── projects.json     # Project registry
└── references/
    ├── workspace_command.md
    ├── project_command.md
    ├── build_command.md
    ├── device_command.md
    ├── upload_command.md
    └── platform_compile_parameter.md
```

## Supported Platforms

ARM920T, ARM_A7, ARM_A8, ARM_A9, ARM_A7_MP, ARM_A15_MP, ARM_A53, ARM64_A53, ARM64_GENERIC, x86_PENTIUM, X86_64, MIPS32, MIPS64, PowerPC, SPARC, C-SKY, RISCV_GC64, LOONGARCH64, and more.

Full list: [references/platform_compile_parameter.md](references/platform_compile_parameter.md)

## License

MIT
