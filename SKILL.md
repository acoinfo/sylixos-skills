---
name: sylixos-dev
description: Assist SylixOS and RealEvo-Stream command-line development workflows. Use when users need to initialize a workspace, create projects, build, manage devices, or deploy. Trigger phrases include "创建 workspace", "初始化工作空间", "create workspace", "init workspace", "准备 Base 工程", "创建工程", "创建项目", "create project", "新建 BSP 工程", "新建应用", "工程记录", "project registry", "编译", "构建", "build", "make", "创建设备", "add device", "设备管理", "device", "部署", "上传", "deploy", "upload".
---

# SylixOS Dev

## Scope

Use this skill for:
- **Workspace bootstrapping** through `rl-workspace init`
- **Project creation** through `rl-project create` (BSP, apps, libraries, kernel modules, etc.)
- **Project registry** management — persistent mapping of project names to git repos
- **Building** — Base (`make`) and projects (`rl-build`)
- **Device management** — adding, listing, updating, deleting target devices (`rl-device`)
- **Deployment** — uploading projects/workspace to devices (`rl-upload`)

Parameter collection and execution are handled by Bash scripts. Claude extracts parameters from the user's request and calls the scripts in CLI mode.

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

---

## Project Creation

### Project Types & Templates

| Type | Description |
|------|-------------|
| `cmake` | CMake build system |
| `automake` | Automake build system |
| `realevo` | RealEvo-IDE compatible |
| `python` | Python project |
| `cython` | Cython project |
| `go` | Go project |
| `javascript` | JavaScript project |
| `ros2` | ROS2 project |

| Template | Description |
|----------|-------------|
| `app` | C/C++ application |
| `lib` | C/C++ dynamic library |
| `ko` | Kernel module |
| `common` | General-purpose |
| `shared_lib` | RealEvo-IDE compatible dynamic library |

### Project Creation Workflow

When the user requests project creation:

1. **Extract parameters**: From the user's message, determine name, type, template, source (repo URL), branch, and other options
2. **Check registry**: Read `data/projects.json` and look for an existing entry
   - If found and user didn't provide a new repo → use the registered repo URL and saved defaults
   - If not found → require user to provide repo (or create without source)
3. **Infer name**: If `--name` not provided but `--source` is a git URL, the script infers the name from the last path segment (strips `.git`)
4. **First run with `--dry-run`**: Call the script to validate and preview:
   ```bash
   bash .agents/skills/sylixos-dev/scripts/project_create.sh \
     --name=<name> --type=<type> [other params...] --dry-run
   ```
5. **Show the dry-run output** to the user and ask for confirmation
6. **Execute**: After user confirms, run again with `--yes`:
   ```bash
   bash .agents/skills/sylixos-dev/scripts/project_create.sh \
     --name=<name> --type=<type> [other params...] --yes
   ```
7. **Save to registry**: After successful creation, update `data/projects.json` with the project entry (see Registry Management below)
8. **Report result**: Summarize success or failure

### Script CLI Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `--name` | Yes* | Project name (*can be inferred from `--source`) |
| `--type` | Yes | Build type: cmake, automake, realevo, python, cython, go, javascript, ros2 |
| `--template` | No | Template: app, lib, ko, common, shared_lib |
| `--source` | No | Local path or Git repo URL |
| `--branch` | No | Git branch (requires `--source`) |
| `--debug-level` | No | debug or release |
| `--make-tool` | No | make or ninja |
| `--quiet` | No | Skip interactive config file selection |

Flags: `--dry-run` (preview only), `--yes` (skip confirmation).

### Default Type

If the user does not specify a build type, **default to `realevo`**.

### Mapping User Intent to Parameters

Common user requests and how to map them:

- "创建一个 BSP 工程" → `--type=realevo --template=app`
- "创建一个应用" → `--type=realevo --template=app`
- "创建一个动态库" → `--type=realevo --template=lib`
- "创建一个内核模块" → `--type=realevo --template=ko`
- "创建一个 RealEvo 兼容库" → `--type=realevo --template=shared_lib`
- "创建一个 Python 工程" → `--type=python --template=common`

---

## Project Registry

The project registry (`data/projects.json`) is a persistent mapping of project names to their git repos and creation parameters. Claude manages it directly using Read/Write tools.

### Registry Format

```json
{
  "projects": {
    "project-name": {
      "repo": "ssh://git@example.com/project-name.git",
      "type": "cmake",
      "template": "app",
      "branch": "main"
    }
  }
}
```

Fields: `repo` (git URL), `type` (build type), `template` (optional), `branch` (optional).

### When to Save

After a successful `rl-project create` execution (not dry-run), save the project entry to the registry. Only save entries that have a git `repo` — projects created without `--source` or from local paths are not registered.

### Registry Management Workflow

- **User asks to list projects** ("帮我看看已经记录了哪些工程", "show registered projects"):
  Read `data/projects.json` and display the entries in a readable table.

- **User asks to update a project** ("把 bsp-xxx 的仓库改成 ...", "update repo for ..."):
  Read the registry, update the specified entry, write back.

- **User asks to delete a project record** ("删除 bsp-xxx 的记录", "remove ... from registry"):
  Read the registry, remove the entry, write back.

- **User creates a project that already exists in registry**:
  Use the registered repo/type/template/branch as defaults. The user can override any value.

---

## Build

Two build paths: **Base build** (kernel/system libraries) and **Project build** (user projects).

### Base Build

Compiles the SylixOS base (libsylixos, libcextern, and other base libraries):

```bash
cd <workspace>/.realevo/base && make -j$(nproc)
```

Use when: after research-base setup, or when user needs to recompile the base system.

**Component selection**: The base Makefile (`.realevo/base/Makefile`) has a `SUBDIR` or `SUBDIRS` list of components. By default, some components are commented out. Before building base, review the list and **comment out** components that are not needed — but **always keep `libsylixos` and `libcextern` enabled** (these are essential). Ask the user if unsure which components to include.

### Project Build

Compiles a user project using `rl-build`:

```bash
rl-build all --project=<name> --parallel=$(nproc)
```

Individual steps are also available: `clean`, `config`, `build`, `install`, `uninstall`, `symbolcheck`.

The `--project` parameter is optional if cwd is inside the project directory.

### Build All Projects

When the user requests to build **all** projects ("编译所有工程", "全部编译", "build all"), follow this order:

1. **Base** — compile the base system first (`make -j$(nproc)` in `.realevo/base`)
2. **Compatibility layers** — e.g. `libdrv_linux_compat` (Linux 兼容层)
3. **Driver/middleware libraries** — NIC drivers, other libs that BSP depends on (e.g. `libdrv_vndbind`)
4. **BSP** — board support packages last (e.g. `bsprk3568`)

This ensures dependencies are satisfied: BSP depends on driver libs, driver libs may depend on the compat layer, and everything depends on base.

### Pre-Build Checks

**1. RK3568 ARM64 64KB page size**: When building an ARM64 RK3568 BSP (e.g. `bsprk3568`) and base has not been compiled yet, **before compiling base**, verify that:

- File: `.realevo/base/libsylixos/SylixOS/config/cpu/cpu_cfg_arm64.h`
- Macro `LW_CFG_ARM64_PAGE_SHIFT` must be set to `16` (64KB page size)

If the value is not `16`, modify it before building base. This is required for RK3568 ARM64 to function correctly.

**2. WORKSPACE_xxx variables**: For all projects **except base**, before building, scan the project's Makefile and any included sub-makefiles (e.g. `config.mk`) for variables like `WORKSPACE_<project_name>`. These variables follow the pattern:

- Variable name: `WORKSPACE_` + a project name that exists in the workspace directory
- Expected value: the absolute path to that project in the workspace

If any `WORKSPACE_xxx` variable is referenced but not defined, set it before building. Use `?=` to provide a default without overriding any existing value:

```makefile
WORKSPACE_libdrv_linux_compat ?= /path/to/workspace/libdrv_linux_compat
```

**3. BSP BOARD_LIST selection**: BSP Makefiles contain a `BOARD_LIST` variable listing available board variants. Some entries are enabled (uncommented) and some are commented out. Before building a BSP:

- Read the Makefile and extract **all** `BOARD_LIST` entries (both enabled and commented out)
- Present the **complete list** to the user and ask which board(s) to build — every board must appear as an option, do not pre-filter or omit any
- Only enable the user's selected board(s), comment out all others

**4. BSP license macro**: BSP platform-specific code lives in `<BSP>/SylixOS/bsp/`. Each board subdirectory has a config header (e.g. `XSpirit2.h`, `evb1.h`) containing a `BSP_CFG_LICENSE_EN` macro that controls time-limited license enforcement. **Set this to `0`** (disabled) for all boards being built, unless the user explicitly wants licensing enabled.

### Build Workflow

1. **Determine build type**: Base build vs project build vs build-all based on user request
2. **Run pre-build checks**: Apply platform-specific checks (e.g. ARM64 page size for RK3568)
3. **Show command**: Present the command to the user and ask for confirmation
4. **Execute**: Run the build command
5. **Report result**: Summarize success or failure, highlight any build errors

### Mapping User Intent

- "编译 base" / "build base" / "make base" → Base build
- "编译 libdrv_vndbind" / "build project" / "构建工程" → Project build with `rl-build all`
- "清理工程" / "clean project" → `rl-build clean`
- "安装工程" / "install project" → `rl-build install`

---

## Device Management

Manages target device connections for deployment and debugging via `rl-device`.

### Device Creation

The user only needs to provide the **IP address**. All other parameters have defaults:

- `--name`: Auto-generate from IP → `dev-<ip-with-dashes>` (e.g. `dev-192-168-1-100`)
- `--ip`: User-provided (required)
- `--platform`: **Infer from workspace** — read the `platforms` array in `.realevo/config.json` (e.g. `ARM64_GENERIC`)
- `--user` / `--password`: Default `root` / `root` (rl-device defaults)
- `--os`: Default `sylixos` (rl-device default)
- Ports: All defaults (SSH 22, Telnet 23, FTP 21, GDB 1234)

```bash
rl-device add --name=dev-192-168-1-100 --ip=192.168.1.100 --platform=ARM64_GENERIC
```

The user can override any default (name, password, ports, etc.) by mentioning it.

### Other Device Operations

- **List**: `rl-device list` — show all devices
- **Delete**: `rl-device delete --name=<name>` — remove device
- **Update**: `rl-device update --name=<name> [options]` — modify device config
- **Install software**: `rl-device install --name=<name> --soft=<python|javascript>`

### Device Workflow

1. **Extract IP**: Get the IP address from the user's message
2. **Infer platform**: Read `.realevo/config.json` → `platforms[0]`
3. **Generate name**: Convert IP to `dev-<ip-with-dashes>` format
4. **Show command**: Present the `rl-device add` command and ask for confirmation
5. **Execute**: Run the command
6. **Report result**: Confirm device was added

---

## Deployment

Uploads project outputs or workspace rootfs to a target device via `rl-upload`.

### Upload Project

```bash
rl-upload project --device=<device_name> --project=<project_name>
```

Transfers the project's `install-sylixos/<platform>/` build outputs to the device.

### Upload Workspace

```bash
rl-upload workspace --device=<device_name>
```

Transfers the workspace's `.realevo/arch/<platform>/rootfs/` to the device.

### Deploy Workflow

1. **Check devices**: Run `rl-device list` to see available devices
   - If **one device** → use it automatically
   - If **multiple devices** → ask the user which one
   - If **no devices** → offer to create one (see Device Management)
2. **Determine upload type**: Project upload vs workspace upload based on user request
3. **Show command**: Present the `rl-upload` command and ask for confirmation
4. **Execute**: Run the upload
5. **Report result**: Summarize success or failure

### Mapping User Intent

- "部署 libdrv_vndbind" / "上传工程到设备" / "deploy project" → `rl-upload project`
- "部署 workspace" / "上传 rootfs" / "deploy workspace" → `rl-upload workspace`
- "上传到设备" (ambiguous) → ask if project or workspace upload

---

## References

- Workspace command options: `references/workspace_command.md`
- Project command options: `references/project_command.md`
- Build command options: `references/build_command.md`
- Device command options: `references/device_command.md`
- Upload command options: `references/upload_command.md`
- Platform compile parameters: `references/platform_compile_parameter.md`
