# Upload Command Parameters

Source:
- https://docs.acoinfo.com/realevo-stream/guide/command/upload_command.html
- Page update time: 2026-03-03

## `rl-upload`

Deploys local build outputs to target devices via FTP.

## Subcommands

### `rl-upload project`

Deploy a project's build outputs to a device:

```bash
rl-upload project --device=<device_name> [--project=<project_name>]
```

Source: project's `install-sylixos/<platform>/` directory.
Transfers: apps, boot, etc, lib, qt, root, sbin, usr, bin, home, tmp, var.

`--project` is optional if cwd is inside the project directory.

### `rl-upload workspace`

Deploy the workspace rootfs to a device:

```bash
rl-upload workspace --device=<device_name>
```

Source: `.realevo/arch/<platform>/rootfs/` directory (platform matches the device's platform setting).
Transfers the same directory set as project upload.

## Parameters

- `--device`: Target device name (required). Must be a device registered via `rl-device add`.
- `--project`: Project name (optional for `rl-upload project` if cwd is inside the project).

## Notes

- File exclusions during project deployment can be configured via the project's `upload-ignore` setting (set during `rl-project create` with `--upload-ignore`).
- The device must be reachable and have FTP enabled on the configured port.
