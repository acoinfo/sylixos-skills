# SylixOS 调试参考

当用户提到“调试”“上传后验证”“telnet 登录”“Shell 命令”“做个 app/ko 试一下”时，读这份参考。

## 调试边界

- 构造工程、编译、上传都只用 `sydev`
- 不要引导用户切到 `RealEvo-IDE`、`rl-build`、`rl-project` 或其他旁路工具
- `sydev` 当前没有单独的 `debug` 子命令；通常是 `build` / `upload` 之后，通过 telnet 登录设备做验证
- SylixOS 运行时行为、Shell 命令和 OS 侧调试技巧，按 `official-doc-routing.md` 进入官方 `shell` / `app` / `drv` / `ecs` 文档

## 先解析设备登录信息

优先级：

1. `.realevo/devicelist.json`
2. `.realevo/config.json`

字段映射：

| 含义 | `devicelist.json` | `config.json` / `device add --config` |
| --- | --- | --- |
| IP | `ip` | `ip` |
| Telnet 端口 | `telnet` | `telnet` |
| 用户名 | `user` | `username` |
| 密码 | `password` | `password` |

调试登录默认值：

- telnet 端口缺失：`23`
- 用户名缺失：`root`
- 密码缺失：`root`

## 最小调试闭环

### 1. 编译

```bash
sydev build <project> --quiet -- -j$(nproc)
```

### 2. 上传

```bash
sydev upload <project> --device <device> --quiet
```

注意：

- 单工程上传可以依赖 `.reproject` 默认设备，但 Agent 更稳妥的做法通常仍是显式传 `--device`
- 多工程上传或 `--all` 上传时，必须显式传 `--device`

### 3. telnet 登录

```bash
telnet <ip> <telnet-port>
```

登录凭据优先取设备配置；缺失时用 `root/root`。

### 4. 登录后先做最小验证

优先检查这些事情：

- 上传目录是否存在
- 上传后的文件是否在预期路径
- 二进制、库、脚本或模块是否能被系统识别
- 运行或装载后的输出是否符合预期

常见 Shell 检查方向：

- 当前目录和文件：`pwd`、`cd`、`ls`
- 进程和任务：`ps`、`kill`
- 网络：`ifconfig`、`ping`、`route`
- 文件查看：`cat`
- 动态装载：`insmod`、`rmmod`、`lsmod`

具体命令用法和边界，按需从 `official-doc-routing.md` 选对应文档域，不要凭记忆硬编。

## 何时构造临时测试工程

### 优先复用现有工程

如果用户是在查现有工程的上传路径、运行行为或设备兼容性，先直接复用现有工程。

### 需要最小复现时

优先用 `sydev project create` 新建最小工程。

应用程序：

```bash
sydev project create \
  --mode create \
  --name dbg-app \
  --template app \
  --type cmake \
  --debug-level debug \
  --make-tool make
```

内核模块：

```bash
sydev project create \
  --mode create \
  --name dbg-ko \
  --template ko \
  --type cmake \
  --debug-level debug \
  --make-tool make
```

然后继续：

```bash
sydev build <project> --quiet -- -j$(nproc)
sydev upload <project> --device <device> --quiet
```

## app 和 ko 的选择

- 只是验证用户态逻辑、二进制运行、共享库加载或文件路径时，优先 `app`
- 需要验证内核态行为、模块装载卸载，或要把能力挂到系统里时，再选 `ko`
- 如果目的是注册或扩展 Shell 命令，先去 `shell` 文档里的 `添加自定义 Shell 命令`，再决定是继续走现有工程、临时 `ko`，还是需要 BSP 侧改动

## 文档查找路线

优先按任务去找对应子文档，入口和规则见 `official-doc-routing.md`：

- Shell 命令和系统观测：先 `shell`
- 用户态应用和动态装载：先 `app`
- 驱动、模块、BSP、设备树：先 `drv`
- 容器运行、镜像、日志、节点：先 `ecs`

当你需要给出具体命令、语义或限制时，先读对应页面再回答。
