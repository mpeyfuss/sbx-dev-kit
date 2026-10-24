# sbx-dev-kit

A [Docker Sandboxes (`sbx`)](https://docs.docker.com/ai/sandboxes/) kit that installs my dev toolchain into any agent's sandbox, plus a `sbx-dev` command that makes using it a one-liner.

| Tool | Notes |
|---|---|
| [uv](https://docs.astral.sh/uv/) | Python and tools |
| [fnm](https://github.com/Schniz/fnm) + Node.js | Node LTS by default. Bash switches to a project's `.nvmrc` / `.node-version` automatically |
| [Bun](https://bun.sh) | |
| [Foundry](https://getfoundry.sh) | forge, cast, anvil, chisel |
| [Slither](https://github.com/crytic/slither) | via `uv tool`, with `crytic-compile` and `solc-select` |
| [Aderyn](https://aderyn.cyfrin.io/overview) | |
| [Echidna](https://github.com/crytic/echidna) | |

Each tool installs at its **latest stable release** when a sandbox is created or upgraded. The kit also brings the agent's own CLI (Claude Code, Codex) up to its latest release, because the built-in agent images lag behind.

## Setup (once per machine)

```sh
git clone https://github.com/mpeyfuss/sbx-dev-kit.git ~/sbx-dev-kit
~/sbx-dev-kit/install.sh
```

`install.sh` is safe to rerun. It:
- installs `sbx` with Homebrew if it's missing, and signs you in
- sets the `balanced` network policy if you don't have one yet (the kit allows its own hosts)
- validates the kit
- links `sbx-dev` into `~/.local/bin` and adds that folder to your `PATH` if needed

Then sign in to your agents. You only do this once, since the tokens are stored on the host:
- **Claude Code:** run `/login` inside Claude Code in any sandbox
- **Codex:** `sbx secret set openai --oauth`

## Daily use

From anywhere in a repo:

```sh
sbx-dev claude                     # or codex, opencode, or any sbx agent
sbx-dev claude -- --continue       # args after -- go to the agent
sbx-dev codex -e ETH_RPC_URL       # pass an env var from your shell
```

The first run creates a sandbox for that repo and agent (`claude-<repo>`), which takes about 3 minutes while the toolchain installs. Later runs reattach right away, with your files and agent sessions still there.

What `sbx-dev` does for you:
- **Mounts the repo root**, even if you're in a subfolder. It refuses to run in `~` or `/`.
- **Mounts `.git` read-only.** The agent can read history and diffs but can't commit, so it can't plant a git hook that later runs on your Mac. Commit on the host.
- **Uses one sandbox per repo and agent.** Two repos with the same folder name get separate sandboxes.

To update or remove a sandbox:

```sh
sbx-dev upgrade claude   # reinstall every tool, and the agent CLI, at the latest release. Keeps files and sessions
sbx-dev rm claude        # delete this repo's sandbox
sbx ls                   # list all sandboxes
```

To pull changes to the kit itself, run `git pull` in `~/sbx-dev-kit`. New sandboxes pick them up, and `sbx-dev upgrade` applies them to existing ones.

## Staying current

| What | How it stays current |
|---|---|
| Toolchain | Resolved to the latest GitHub/PyPI release at create and at `sbx-dev upgrade` |
| Agent image | `sbx create` pulls the agent's image fresh for every new sandbox |
| Claude Code | Updates itself in the background. The kit also runs `claude update` at create and upgrade |
| Codex | The built-in image ships an older Codex and doesn't update it, so the kit runs `npm install -g @openai/codex@latest` at create and upgrade |

**Docker's agent kits.** Docker publishes standalone kits that track each agent's releases: [`sbx/claude-kit`](https://hub.docker.com/r/sbx/claude-kit) and [`sbx/codex-kit`](https://hub.docker.com/r/sbx/codex-kit), from [docker/sbx-kits-contrib](https://github.com/docker/sbx-kits-contrib). They don't load yet: as of sbx v0.49.2, `sbx run sbx/claude-kit:latest` fails with `agent "claude" is already registered`, because `claude` and `codex` are still built-in agents and sbx won't let a kit override them. `sbx-dev` checks for this. Once an sbx release drops the built-in, `sbx-dev` creates new sandboxes from Docker's kit with no change on your side.

## Using the kit without `sbx-dev`

The kit is a normal `sbx` mixin, so you can stack it with any agent or other kits:

```sh
KIT="git+https://github.com/mpeyfuss/sbx-dev-kit.git#dir=kit"

sbx run claude --kit "$KIT"
sbx run codex --kit "$KIT" --kit "git+https://github.com/docker/sbx-kits-contrib.git#dir=code-server"

# Once sbx drops the built-in agents, with Docker's agent kits:
sbx run sbx/claude-kit:latest --kit "$KIT"
sbx run sbx/codex-kit:latest --kit "$KIT"

# Add or reapply it on an existing sandbox (this is what `sbx-dev upgrade` runs)
sbx kit add <sandbox> "$KIT"
```

Kits only apply when a sandbox is created, so `sbx run --kit ...` does nothing on a sandbox that already exists. Use `sbx kit add` for that. To pin a commit, add `ref`: `...sbx-dev-kit.git#ref=<sha>&dir=kit` (quote the URL).

### Pinning a version

Every tool defaults to `latest`. To pin one for a sandbox, pass a kit arg when you create or upgrade it:

```sh
sbx run claude --kit "$KIT" --kit-arg dev.foundry_version=1.8.6
sbx kit add <sandbox> "$KIT" --kit-arg dev.foundry_version=1.8.6
```

| Arg | Default |
|---|---|
| `uv_version`, `fnm_version`, `bun_version`, `foundry_version`, `slither_version`, `aderyn_version`, `echidna_version` | `latest`, or an exact `X.Y.Z` |
| `node_version` | `lts`, a major (`24`) or an exact version |
| `update_agent` | `true`. Set it to `false` to keep the agent CLI version the image shipped |

## Network

The kit's `permissions.network.allow` in [`kit/spec.yaml`](kit/spec.yaml) lists what the tools need: GitHub releases, PyPI, npm/JSR, Node, solc binaries, Soldeer, a few docs sites, block explorers and RPC providers for forks. These rules apply only to sandboxes that have the kit, on top of your global policy. If something is blocked mid-session:

```sh
sbx policy log                       # what was blocked
sbx policy allow network <host>      # allow it everywhere
```

Or add the host to the kit and run `sbx-dev upgrade`.

## Hygiene

- The sandbox can read everything in the repo folder, including untracked `.env` files. Keep private keys out of them.
- Pass secrets per run (`-e ETH_RPC_URL`) rather than committing them, and only ones you don't mind losing. Use throwaway keys for forks.
- The sandbox is Linux. Install dependencies (`node_modules`, `.venv`) on one side only, or reinstall when you switch between host and sandbox. Foundry's `out/` and `cache/` are fine either way.
- Run `git status` after a session. The agent can still edit files your machine runs later, such as `foundry.toml` (`ffi = true`), `package.json` scripts, `Makefile` or `.envrc`.

## Layout

```
kit/spec.yaml   the kit: install steps, version args, network allow-list
bin/sbx-dev     the launcher
install.sh      one-time machine setup
```
