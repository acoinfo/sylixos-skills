# sydev 命令参考

以当前 `sydev` 文档和 `apps/cli/src/commands/` 实现为准，面向 Agent 的重点是“哪些命令适合自动化”和“哪些参数容易写错”。

## 命令总览

| 命令 | 形式 | 说明 | 自动化建议 |
| --- | --- | --- | --- |
| `workspace` | `init`, `status` | 初始化 workspace / 检查状态 | 高 |
| `project` | `create`, `list` | 创建工程 / 列出工程 | 高 |
| `device` | `add`, `list` | 添加设备 / 列出设备 | 高 |
| `build` | `[project]`, `init` | 编译工程或模板 / 生成 Makefile | 高 |
| `clean` | `[project]` | 清理工程 | 高 |
| `rebuild` | `[project]` | 重建工程 | 高 |
| `upload` | `[projects]` | 上传产物到设备 | 高 |
| `template` | `create`, `list`, `show`, `apply`, `delete`, `export`, `import` | 配置模板管理 | 部分 |
| `init` | `--config <file>` | 一次性初始化 workspace + projects + devices | 高 |

## 自动化通用规则

- 当前目录通常就是 workspace 根目录
- `workspace init`、`project create`、`device add` 传了业务参数或 `--config` 就会进入非交互模式
- `build`、`clean`、`rebuild` 支持 `-- <args>` 透传给 `make`
- 项目识别规则：workspace 一级子目录同时包含 `.project` 和 `Makefile`
- `build` / `clean` / `rebuild` 当前都没有 `--all`
- `build` 可以执行 `.sydev/Makefile` 里的 `__` 用户模板，`template` 管理的是另一套“配置模板”

## workspace

### `sydev workspace init`

```bash
sydev workspace init [options]
```

关键选项：

- `--cwd <path>`
- `--base-path <path>`
- `--version <version>`
- `--platforms <platforms>`
- `--os <os>`
- `--debug-level <level>`
- `--custom-repo <repo>`
- `--custom-branch <branch>`
- `--research-branch <branch>`
- `--create-base` / `--no-create-base`
- `--build`
- `--config <file>`

说明：

- `version=custom` 时需要 `--custom-repo` 和 `--custom-branch`
- `version=research` 时需要 `--research-branch`
- `--config` 字段格式见 `config-schema.md`

常用写法：

```bash
sydev workspace init --config workspace.json
```

```bash
sydev workspace init \
  --cwd /ws \
  --base-path /ws/.realevo/base \
  --version lts_3.6.5 \
  --platforms ARM64_GENERIC,X86_64 \
  --os sylixos \
  --debug-level release \
  --create-base \
  --build
```

### `sydev workspace status`

```bash
sydev workspace status
```

只适合人看。需要结构化状态时直接读 `.realevo/`。

## project

### `sydev project create`

```bash
sydev project create [options]
```

导入模式：

- `--mode import`
- `--name <name>`
- `--source <git-url>`
- `--branch <branch>`
- `--make-tool <make|ninja>`

创建模式：

- `--mode create`
- `--name <name>`
- `--template <template>`
- `--type <type>`
- `--debug-level <release|debug>`
- `--make-tool <make|ninja>`

共用：

- `--config <file>`

常用写法：

```bash
sydev project create --config project.json
```

```bash
sydev project create \
  --mode import \
  --name bsp-rk3568 \
  --source https://git.example.com/bsp/rk3568.git \
  --branch main \
  --make-tool make
```

### `sydev project list`

```bash
sydev project list
```

输出给人看。需要稳定项目列表时，按“一级子目录同时包含 `.project` + `Makefile`”自己扫描。

## device

### `sydev device add`

```bash
sydev device add [options]
```

关键选项：

- `--name <name>`
- `--ip <ipv4>`
- `--platforms <platforms>`
- `--username <name>`
- `--password <password>`
- `--ssh <port>`
- `--telnet <port>`
- `--ftp <port>`
- `--gdb <port>`
- `--config <file>`

常用写法：

```bash
sydev device add --config device.json
```

### `sydev device list`

```bash
sydev device list
```

自动化场景优先读取：

1. `.realevo/devicelist.json`
2. `.realevo/config.json`

## build / clean / rebuild

### `sydev build [project]`

```bash
sydev build [project] [--quiet] [-- make-args]
```

规则：

- 指定 `project` 时，先按工程名找，再按 `.sydev/Makefile` 里的 `__` 模板名找
- 执行前会先确保 `.sydev/Makefile` 存在；默认增量更新只补齐缺失工程，不改写已有工程 block
- 执行普通工程前会同步该工程 `config.mk` 里的 `SYLIXOS_BASE_PATH`
- 执行 `__` 模板前会同步当前 workspace 全部已识别工程的 `config.mk`
- 不传参数时进入交互式多选
- 推荐 Agent 模式使用 `--quiet`

常用写法：

```bash
sydev build libcpu --quiet -- -j$(nproc)
sydev build __demo
```

### `sydev build init`

```bash
sydev build init [--default]
```

规则：

- 默认是增量更新 `.sydev/Makefile`，只刷新头部并补齐缺失工程 block
- 已有工程 block 会原样保留
- `--default` 会整份重生，覆盖用户手改内容
- 生成后可直接 `make -f .sydev/Makefile <target>`

### `sydev clean [project]`

```bash
sydev clean [project] [--quiet] [-- make-args]
```

### `sydev rebuild [project]`

```bash
sydev rebuild [project] [--quiet] [-- make-args]
```

`rebuild` 本质上是 `clean + build`。

## upload

### `sydev upload [projects]`

```bash
sydev upload [projects] [--device <name>] [--all] [--quiet]
```

规则：

- 单工程上传：可不传 `--device`，命令会尝试从该工程 `.reproject` 读取默认设备
- 多工程上传：必须显式传 `--device`
- `--all`：必须显式传 `--device`
- `projects` 支持单项、逗号分隔和冒号分隔
- 若 base 路径可解析且 base 目录下有 `.reproject`，`base` 会作为可上传项目

常用写法：

```bash
sydev upload libcpu --device board1 --quiet
sydev upload libcpu,libnet --device board1 --quiet
sydev upload libcpu:libnet --device board1 --quiet
sydev upload --all --device board1 --quiet
sydev upload base --device board1 --quiet
```

`.reproject` 的实际格式和变量替换规则见 `workspace-files.md`。

## template

模板库目录：

```text
~/.sydev/templates/
```

模板类型：

- `workspace`
- `project`
- `device`
- `full`

### `sydev template create`

```bash
sydev template create
```

交互式创建，全自动化场景一般不使用它。

### `sydev template list`

```bash
sydev template list [--type <type>]
```

### `sydev template show <id>`

```bash
sydev template show <id>
```

### `sydev template apply <source>`

```bash
sydev template apply <source> [--cwd <path>] [--base-path <path>] [-y]
```

规则：

- `<source>` 可以是模板 ID，也可以是 JSON 文件路径
- `-y` 时，未显式提供 `--cwd` / `--base-path` 会分别回退到 `process.cwd()` 和 `${cwd}/.realevo/base`
- `workspace` 和 `full` 模板可直接初始化
- `project` 和 `device` 模板不会单独拉起完整环境
- 即使 JSON 里有 `workspace.cwd` / `workspace.basePath`，`apply` 也会用本次命令解析出的路径覆盖

### `sydev template export`

```bash
sydev template export [-o <file>] [-d <path>]
```

规则：

- 优先读 `.realevo/workspace.json`，回退 `.realevo/config.json`
- 扫描当前 workspace 的项目和设备
- 默认导出为“原始 full 配置”

### `sydev template import <file>`

```bash
sydev template import <file> [-y]
```

规则：

- 自动识别 `workspace` / `project` / `device` / `full`
- 不带 `-y` 时会询问是否保存为全局模板

## init

### `sydev init --config <file>`

```bash
sydev init --config full-config.json
```

适合“一次性把 workspace、projects、devices 全部初始化好”。

关键点：

- 使用 full 配置风格，不是 `workspace init --config` 的字段名
- `workspace.cwd` / `workspace.basePath` 缺失时会提示输入
- 适合 Agent 构造一份可复用的完整环境描述

## 调试相关

- `sydev` 当前没有单独的 `debug` 命令；常见闭环是 `build` / `upload` 之后，通过设备配置里的 telnet 参数登录目标机做验证
- 调试时，设备信息优先读 `.realevo/devicelist.json`，缺失时回退 `.realevo/config.json`
- 如果设备没有显式写 telnet 端口、用户名或密码，技能默认回退 `23`、`root`、`root`
- 需要最小复现时，可以继续用 `sydev project create --mode create --template app|ko ...` 构造临时测试工程
- 详细调试流程和 SylixOS 文档查找路线见 `sylixos-debugging.md`
