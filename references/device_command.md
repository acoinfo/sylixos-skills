# Device Command Parameters

Source:
- https://docs.acoinfo.com/realevo-stream/guide/command/device_command.html
- Page update time: 2026-03-03

## `rl-device`

Manages target device connections for deployment and debugging.

## Subcommands

### `rl-device add`

Register a new device:

```bash
rl-device add --name=<name> --ip=<ip> --platform=<platform> \
  [--user=<username>] [--password=<password>] [--os=<sylixos|linux>] \
  [--ssh=<port>] [--telnet=<port>] [--ftp=<port>] [--gdb=<port>] \
  [--hostname=<host_device_name>]
```

### `rl-device delete`

Remove a device:

```bash
rl-device delete --name=<name>
```

### `rl-device update`

Modify an existing device:

```bash
rl-device update --name=<name> [--ip=<ip>] [--platform=<platform>] \
  [--user=<username>] [--password=<password>] [--os=<sylixos|linux>] \
  [--ssh=<port>] [--telnet=<port>] [--ftp=<port>] [--gdb=<port>]
```

### `rl-device list`

Display all registered devices:

```bash
rl-device list
```

### `rl-device install`

Install runtime software on a device:

```bash
rl-device install --name=<name> --soft=<python|javascript>
```

## Parameters

### Required (for `add`)

- `--name`: Unique device identifier.
- `--ip`: Device IP address.
- `--platform`: Device platform (e.g. `ARM64_GENERIC`, `X86_64`).

### Optional (with defaults)

- `--user`: Login username. Default: `root`.
- `--password`: Login password. Default: `root`.
- `--os`: Device OS type. Default: `sylixos`. Values: `sylixos`, `linux`.
- `--ssh`: SSH port. Default: `22`.
- `--telnet`: Telnet port. Default: `23`.
- `--ftp`: FTP port. Default: `21`.
- `--gdb`: GDB debugging port. Default: `1234`.
- `--hostname`: ECS container's parent device name.
- `--soft`: Software to install (`python`, `javascript`).
