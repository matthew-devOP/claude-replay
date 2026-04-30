# claude-mtw-replay sidecar

A small Node.js helper that bridges the Swift Chats UI to
[`@anthropic-ai/claude-agent-sdk`](https://www.npmjs.com/package/@anthropic-ai/claude-agent-sdk)
over stdio.

## Wire format

- **stdin** — line-delimited JSON commands:
  - `{"type":"send","text":"<message>"}`
  - `{"type":"stop"}`
- **stdout** — line-delimited JSON events:
  - `{"type":"ready", ...}` — emitted once on startup
  - `{"type":"echo","input":...}` — skeleton mode only
  - `{"type":"agent_event","event":<SDK event>}` — agent mode
  - `{"type":"error","message":...}`
  - `{"type":"exit","code":0}`

## Build

```sh
./build.sh
```

This installs production-only dependencies, then copies `sidecar.js`,
`package.json`, and `node_modules/` into
`../Claude-MTW-Replay/Resources/sidecar/` so xcodebuild bundles them.

## Run (skeleton, used until step 5)

```sh
node sidecar.js --skeleton
{"type":"send","text":"hello"}
{"type":"stop"}
```

## Run (agent, step 5+)

```sh
node sidecar.js \
  --resume <sessionId> \
  --cwd /path/to/project \
  --permission-mode default \
  --allowed-tools "Read,Edit,Bash"
```
