# Project Command Parameters

Source:
- https://docs.acoinfo.com/realevo-stream/guide/command/project_command.html
- Page update time: 2026-03-03

## `rl-project create`

Core syntax:

```bash
rl-project create --name=<project_name> --type=<build_type> \
  [--template=<project_template>] [--source=<path_or_git_url>] \
  [--branch=<git_branch>] [--debug-level=<debug|release>] \
  [--make-tool=<make|ninja>] [--version=<project_version>] \
  [--upload-ignore=<ignore_paths>] [--quiet]
```

## Parameters

- `--name`: Project identifier (required).
- `--type`: Build system type (required).
  - `cmake` — CMake build system
  - `automake` — Automake build system
  - `realevo` — RealEvo-IDE compatible
  - `python` — Python project
  - `cython` — Cython project
  - `go` — Go project
  - `javascript` — JavaScript project
  - `ros2` — ROS2 project
- `--template`: Project template.
  - `app` — C/C++ application
  - `lib` — C/C++ dynamic library
  - `shared_lib` — RealEvo-IDE compatible dynamic library
  - `ko` — Kernel module
  - `common` — General-purpose template
- `--source`: Source code path, compressed archive, or Git repository URL.
- `--branch`: Git branch to clone (requires `--source` to be a Git URL).
- `--debug-level`: Build type (`debug` or `release`). Default: `release`.
- `--make-tool`: Build tool (`make` or `ninja`). Default: `make`.
- `--version`: Armory package version. Default: `0.0.1`.
- `--upload-ignore`: Regex patterns for deployment exclusion (`:` separated).
- `--quiet`: Skip interactive config file selection.

## Common Patterns

C/C++ Application (CMake):

```bash
rl-project create --name=myapp --type=cmake --template=app --make-tool=make
```

RealEvo-IDE Compatible Library:

```bash
rl-project create --name=mylib --type=realevo --template=shared_lib --make-tool=make
```

Kernel Module:

```bash
rl-project create --name=my-driver --type=cmake --template=ko
```

Python Project:

```bash
rl-project create --name=pyproject --type=python --template=common
```

Project from Git Repository:

```bash
rl-project create --name=bsp-example --type=cmake --template=app \
  --source=ssh://git@example.com/bsp-example.git --branch=main
```

Middleware Porting (local source):

```bash
rl-project create --name=middleware --source=/path/to/source --make-tool=make --quiet
```

## Related Commands

### `rl-project show`

Display project configuration:

```bash
rl-project show --project=<project_name>
```

### `rl-project update`

Update project build configuration:

```bash
rl-project update --debug-level=<level> --make-tool=<tool> [--project=<name>]
```
