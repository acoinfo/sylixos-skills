# Workspace 文件与可编辑区域

这里汇总 Agent 真正需要稳定依赖的 workspace 文件结构、`.reproject` 规则和 `.sydev/Makefile` 可编辑边界。

## 目录结构

```text
<workspace>/
├── .realevo/
│   ├── config.json
│   ├── workspace.json
│   ├── projects.json
│   ├── devicelist.json
│   └── base/
├── .sydev/
│   └── Makefile
├── <project-a>/
│   ├── .project
│   ├── Makefile
│   ├── config.mk
│   └── .reproject
└── <project-b>/
    ├── .project
    ├── Makefile
    ├── config.mk
    └── .reproject
```

判定规则：

- workspace：目录下存在 `.realevo/`
- 项目：workspace 一级子目录同时包含 `.project` 和 `Makefile`

## `.realevo/` 中的关键文件

### `workspace.json`

优先作为 workspace 元数据来源。

常见字段：

```json
{
  "platform": ["ARM64_GENERIC"],
  "version": "lts_3.6.5",
  "debugLevel": "release",
  "os": "sylixos",
  "createbase": true,
  "build": false
}
```

### `config.json`

主要提供 base 路径、平台、调试级别，以及设备回退信息。

常见字段：

```json
{
  "base": "/path/to/workspace/.realevo/base",
  "base_type": "lts_3.6.5",
  "platforms": ["ARM64_GENERIC"],
  "debug_level": "release",
  "devices": [
    {
      "name": "board1",
      "ip": "192.168.1.100",
      "platforms": ["ARM64_GENERIC"],
      "username": "root",
      "password": "root",
      "ssh": 22,
      "telnet": 23,
      "ftp": 21,
      "gdb": 1234
    }
  ]
}
```

### `devicelist.json`

`device add` 优先写这个文件。

典型结构：

```json
{
  "devices": [
    {
      "name": "board1",
      "ip": "10.13.3.201",
      "platform": "ARM64_GENERIC",
      "ssh": "22",
      "telnet": "23",
      "ftp": "21",
      "gdb": "1234",
      "user": "root",
      "password": "root"
    }
  ]
}
```

和 `config.json` 的差异：

| 字段 | `devicelist.json` | `config.json` |
| --- | --- | --- |
| 平台 | `platform` 字符串 | `platforms` 数组 |
| 端口 | 字符串 | 数字 |
| 用户名 | `user` | `username` |

设备加载优先级：

1. `.realevo/devicelist.json`
2. `.realevo/config.json`

## `.reproject` 的真实解析规则

上传器并不关心 XML root 名称，当前实现只靠正则抓 3 类内容：

- `DevName="..."`
- `<file local="..." remote="..."/>`
- `<PairItem key="..." value="..."/>`

因此推荐结构写成：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<reproject>
  <DeviceSetting DevName="board1"/>
  <upload>
    <file local="$(WORKSPACE_libcpu)/$(Output)/lib/libcpu.so"
          remote="/system/lib/libcpu.so"/>
  </upload>
</reproject>
```

兼容旧格式：

```xml
<PairItem key="$(WORKSPACE_libcpu)/$(Output)/lib/libcpu.so"
          value="/system/lib/libcpu.so"/>
```

建议：

- 新内容统一写 `<file>`
- 默认设备写在 `DevName`
- `remote` 路径使用设备上的绝对路径

## `.reproject` 宏替换

### `$(WORKSPACE_<project>)`

会替换成对应项目的绝对路径。

项目名中的 `-` 会改成 `_`：

| 项目目录名 | 宏名 |
| --- | --- |
| `libcpu` | `$(WORKSPACE_libcpu)` |
| `my-app` | `$(WORKSPACE_my_app)` |
| `bsp-rk3568` | `$(WORKSPACE_bsp_rk3568)` |

### `$(Output)`

根据项目 `config.mk` 中的 `DEBUG_LEVEL` 转换：

- `debug` -> `Debug`
- 其他或缺失 -> `Release`

### base 特殊处理

如果路径里包含 `libsylixos`，上传器会把所有 `$(WORKSPACE_xxx)` 替换成 base 路径，而不是普通项目路径。

## `.sydev/Makefile` 的生成逻辑

`sydev build init` 会生成或更新 `.sydev/Makefile`。

典型结构：

```makefile
# SylixOS Workspace Makefile
# 由 sydev 自动生成/更新
# __ 开头的 target 为用户编译模板，sydev 不会修改

export WORKSPACE_project_name = /absolute/path/to/project
export WORKSPACE_another = /absolute/path/to/another
export SYLIXOS_BASE_PATH = /path/to/base

# ─── 工程 Targets ───────────────────────────────────────────────

.PHONY: proj1 clean-proj1 rebuild-proj1 cp-proj1 proj2 ...

#*******************************************************************************
# proj1
#*******************************************************************************
proj1:
	bear --append -- rl-build build --project=proj1 $(RL_BUILD_ARGS)

clean-proj1:
	rl-build clean --project=proj1 $(RL_CLEAN_ARGS)

rebuild-proj1: clean-proj1 proj1

cp-proj1:
	# TODO: 配置产物复制路径
	# cp /path/to/proj1/Debug/proj1.so /path/to/destination

# ─── 编译模板（__ 开头，可自行修改） ─────────────────────────────
# 使用 SELF 变量引用本 Makefile，确保子 make 能找到正确的 target
SELF := $(firstword $(MAKEFILE_LIST))

__demo:
	$(MAKE) -f $(SELF) proj1
```

规则：

- 每个项目 block 都有 `<name>`、`clean-<name>`、`rebuild-<name>`
- 非 base 项目额外有 `cp-<name>`
- 默认生成的新工程 block 会用 `bear --append -- rl-build build --project=<name> $(RL_BUILD_ARGS)`
- 默认生成的 clean target 会用 `rl-build clean --project=<name> $(RL_CLEAN_ARGS)`
- base 项目不会生成 `cp-base`

## 哪些区域可以安全修改

| 区域 | 是否建议手改 | 说明 |
| --- | --- | --- |
| 头部注释 | 否 | 重新生成时会被覆盖 |
| `export WORKSPACE_*` | 否 | 自动维护 |
| `export SYLIXOS_BASE_PATH` | 否 | 自动维护 |
| `.PHONY` | 否 | 自动维护 |
| 工程 block 的 build / clean / rebuild | 谨慎 | 默认增量更新会原样保留已有工程 block；`--default` 会全部覆盖 |
| `cp-<name>` | 是 | 推荐放产物复制逻辑 |
| `__` 用户模板区域 | 是 | 推荐放多目标编译模板 |

## `build init` 的两种更新模式

### 默认模式

```bash
sydev build init
```

- 不存在 Makefile 时全新生成
- 已存在时做增量更新
- 刷新头部注释、`export WORKSPACE_*`、`export SYLIXOS_BASE_PATH`、`.PHONY`
- 已有工程 block 原样保留，不重写其中的 build / clean / rebuild / cp 逻辑
- 保留用户模板区
- 项目新增时只追加缺失 block
- 项目删除时只删除对应 block

### 强制重生

```bash
sydev build init --default
```

- 从头生成整份 `.sydev/Makefile`
- 用户手改的 block 和模板区都会被覆盖

## `config.mk` 的自动修补

`sydev build init` 只维护 `.sydev/Makefile`，不会同步项目 `config.mk`。

真正会修补 `config.mk` 的是执行目标前的 `build` / `clean` / `rebuild`：

- 普通工程：只同步当前目标工程的 `config.mk`
- `sydev build __template`：会同步当前 workspace 中已识别的所有工程
- 当前实现只更新或追加 `SYLIXOS_BASE_PATH`
- 当前实现不会自动插入 `PLATFORM_NAME`

因此：

- 改了 base 路径后，如需刷新 `.sydev/Makefile`，先跑 `sydev build init`
- 如需把项目 `config.mk` 同步到当前 base，再跑 `sydev build <project>` / `sydev clean <project>` / `sydev rebuild <project>` 或对应模板
- 如果项目 `config.mk` 明显与当前 base 脱节，不要只手改 `.sydev/Makefile`
