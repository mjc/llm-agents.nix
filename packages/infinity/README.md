# infinity

The package installs the Infinity Code CLI, the Bedrock provider, and the local sandbox server. `infinity daemon` runs the agent daemon in the CLI process. `nix shell github:numtide/llm-agents.nix#infinity` puts `infinity`, `infinity-provider-bedrock`, and `sandbox-local` on `PATH`.

## Model provider

The daemon requires `~/.infinity/providers.json` and will not start when that file is missing. `command` is an argument vector. The daemon executes it and reads a Unix socket path from the first stdout line. Providers are registered in file order, and the first model of the first provider is the default. Bedrock uses the standard AWS credential chain for region, credentials, and profiles.

```json
{
  "bedrock": {
    "command": ["infinity-provider-bedrock"]
  }
}
```

`infinity provider install` runs `cargo install`. Write this file directly. Omit `crate_name`, `git`, and `path`. `infinity provider update` uses those fields to run `cargo install` again.

`infinity-provider-bedrock` takes no arguments. Running it prints the socket path and serves until the process is stopped.

## Sandbox

`~/.infinity/rap.json` is the user tool config. A checkout can add `.infinity/rap.json`. The daemon merges the checkout file with the user file. `command` is a shell string. The daemon runs it with `sh -c` and `RAP_EMBEDDED=1` in `<repo>/.infinity`, and reads `{"port": <port>}` from the first stdout line.

```json
{
  "tool_sets": [
    {
      "type": "toolset_command",
      "command": "sandbox-local"
    }
  ]
}
```

`infinity rap install` runs `cargo install`. Write this file directly, and omit `crate_name`, `git`, and `path` on the toolset entry.

The `sandbox-local` wrapper puts `bash`, `git`, `jj`, `rg`, and on Linux `bwrap`, on `PATH`. Grep needs `rg`. Worktrees use `git` or `jj`. Command execution uses `bash`. The Linux filesystem sandbox is `bwrap`.

## Web UI

The web UI is the separate `infinity-webui` package. Set its `webSocketPort` argument to the daemon's `INFINITY_WS_PORT`. Both default to 8080.
