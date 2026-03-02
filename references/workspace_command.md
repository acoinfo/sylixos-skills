# Workspace Command Parameters

Source:
- https://docs.acoinfo.com/realevo-stream/guide/command/workspace_command.html
- Page update time: 2026-01-23

## `rl-workspace init`

Core syntax:

```bash
rl-workspace init --base=<base_path> --version=<prepared_base> --platform=<platform_name> \
  [--createbase=<true|false>] [--build=<true|false>] [--debug_level=<debug|release>] \
  [--product=<product>] [--os=<sylixos|linux|all>] [--linux_platform=<ARM64|X86>] \
  [--toolchain=<toolchain_path>]
```

## Parameters

- `--base`: Existing or target Base path.
- `--version`: Prepared Base version.
  - `default`
  - `ecs_3.6.5`
  - `lts_3.6.5`
  - `lts_3.6.5_compiled`
- `--platform`: Target platform(s), multi-value with `:`.
- `--createbase`: Create Base project during init (`true|false`).
- `--build`: Build Base during init (`true|false`).
- `--debug_level`: Build type (`debug|release`), default `debug`.
- `--product`: Product series for product-based initialization.
- `--os`: Workspace OS type (`sylixos|linux|all`).
- `--linux_platform`: Linux architecture (`ARM64|X86`).
- `--toolchain`: Toolchain CMake configuration file path.

## Common Patterns

Product mode:

```bash
rl-workspace init --product=<product>
```

Prepared Base mode:

```bash
rl-workspace init --version=<prepared_base> --platform=<platform> --createbase=true --build=true
```

Existing Base mode:

```bash
rl-workspace init --base=<base_path> --platform=<platform>
```

Linux mode:

```bash
rl-workspace init --os=linux --linux_platform=<ARM64|X86> --toolchain=<toolchain_path>
```

## `lts_3.6.5_compiled` Supported Platforms

`ARM_920T`, `ARM_V7A`, `ARM64_GENERIC`, `PPC_E500MC`, `PPC_E5500`, `PPC_750`, `LOONGARCH64`, `MIPS32_R2`, `MIPS64_LS3A`, `x86_PENTIUM`, `X86_64`, `RISCV_GC64`, `PPC_E500V2`, `SPARC_LEON3`, `CSKY_CK810`.
