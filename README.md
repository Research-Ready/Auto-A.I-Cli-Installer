# Auto-A.I CLI Installer

## Outstanding tasks

This repository should be treated as **two related tools**, not one combined installer.

### Script 1: CLI and tool installer

Role: install the command-line tools and system dependencies.

This script should focus on:

- Installing Node.js and npm when needed.
- Installing Gemini CLI.
- Installing Codex CLI.
- Installing OpenCode.
- Detecting whether tools are already available.
- Verifying tool versions after installation.
- Avoiding provider-specific configuration unless it is required for installation.

Outstanding installer tasks:

- [ ] Add OpenCode installation and detection.
- [ ] Detect existing `node`, `npm`, `gemini`, `codex`, and `opencode` installations.
- [ ] Show installed versions in the TUI.
- [ ] Separate pure installation tasks from API-key and model-configuration tasks.
- [ ] Add a dry-run mode that shows what would be installed.
- [ ] Create backups only when editing files.
- [ ] Keep installer logs clean and avoid printing secrets.

### Script 2: configuration, API keys, and model selection

Role: configure provider credentials, OpenCode settings, model selection, and safe defaults.

This script should focus on:

- Setting API keys.
- Testing API keys.
- Fetching available models.
- Selecting a model.
- Writing OpenCode configuration.
- Setting safe context and output limits.
- Testing model capabilities before recommending a model.

Outstanding configuration tasks:

- [ ] Add OpenRouter API key input.
- [ ] Validate the OpenRouter API key before writing config.
- [ ] Store the OpenRouter key safely, for example in `~/.config/opencode/openrouter.key` with restricted permissions.
- [ ] Fetch the full OpenRouter model list from the API.
- [ ] Load each model's maximum context window size.
- [ ] Load each model's maximum output token limit when available.
- [ ] Load model pricing and detect free models reliably.
- [ ] Detect whether a model supports text, chat, tools, images, structured output, and reasoning where possible.
- [ ] Configure OpenCode to use the selected OpenRouter model.
- [ ] Write OpenCode configuration to `~/.config/opencode/opencode.json` or `~/.config/opencode/opencode.jsonc`.
- [ ] Back up existing OpenCode config before writing changes.
- [ ] Set the model context limit in OpenCode based on the model's actual maximum context window.
- [ ] Set the router or provider configuration to respect that model-specific context limit.
- [ ] Set a safe default output limit for the selected model.
- [ ] Avoid defaulting to `32000` output tokens on 128k context models.
- [ ] Enable OpenCode compaction by default.
- [ ] Enable pruning of old tool output by default.

Recommended future OpenCode defaults:

```json
{
  "compaction": {
    "auto": true,
    "prune": true,
    "reserved": 20000
  }
}
```

### Model capability testing

The configuration script should not trust model metadata blindly. It should test each selected model before recommending it.

Required tests:

- [ ] Basic chat request.
- [ ] Coding-style request.
- [ ] Tool-use request.
- [ ] OpenCode-style tool calling compatibility.
- [ ] Output token limit behavior.
- [ ] Practical context-window behavior with a controlled large-context prompt.
- [ ] Failure detection before the advertised context window is reached.
- [ ] Error classification for context size, unsupported tools, rate limits, provider errors, and unsupported parameters.
- [ ] Local result caching so the same model is not retested unnecessarily.

The test system should answer questions like:

- Can this model actually be used through OpenRouter?
- Can this model handle tool calls?
- Can this model handle OpenCode-style workflows?
- Does the model really support the advertised context window?
- What is the safe context limit for this model in practice?
- What output limit should the configuration tool choose?

### Free-model benchmark script

Add an additional script that automatically goes through all available free OpenRouter models, tests them, and updates the recommended model selection.

Planned script:

```text
benchmark_free_openrouter_models.py
```

This script should:

- [ ] Fetch all OpenRouter models.
- [ ] Filter free models.
- [ ] Run a basic chat test for every free model.
- [ ] Run a coding prompt test for every free model.
- [ ] Run a tool-use compatibility test for every free model.
- [ ] Run a controlled context-window test.
- [ ] Save raw results to a local JSON file.
- [ ] Save a readable Markdown report.
- [ ] Rank models by usefulness for OpenCode.
- [ ] Update the recommended model list used by the configuration TUI.
- [ ] Mark broken, rate-limited, unreliable, or non-tool-capable models.
- [ ] Record practical context limits, not only advertised metadata.

Suggested outputs:

```text
openrouter_free_model_results.json
openrouter_free_model_report.md
recommended_models.json
```

### Context length safety

The configuration tool should prevent errors like:

```text
This endpoint's maximum context length is 131072 tokens. However, you requested about 242419 tokens.
```

To prevent this, it should:

- [ ] Calculate a safe input budget for each selected model.
- [ ] Reserve output tokens conservatively.
- [ ] Warn when the selected output limit is too high for the model context window.
- [ ] Warn when OpenCode sessions need `/compact` or `/new`.
- [ ] Prefer models with larger context windows for agentic coding workflows.
- [ ] Prevent known bad combinations of model, output limit, and tool-heavy sessions.
- [ ] Set the router/provider context limit to match the selected model's real limit.
- [ ] Keep model-specific limits in the generated OpenCode config.

---

## Current status

This repository currently contains a Python curses-based installer:

```text
ai_cli_installer_tui.py
```

The script is currently titled:

```text
Gemini + Codex CLI Installer
```

It currently focuses on:

- Gemini CLI
- OpenAI Codex CLI
- Node.js and npm setup when missing
- API key environment variable setup
- Basic install verification

The repository should now evolve toward two separate scripts:

| Script role | Responsibility |
| --- | --- |
| CLI installer | Install tools such as Gemini CLI, Codex CLI, OpenCode, Node.js, and npm |
| Configuration tool | Configure API keys, provider settings, model selection, OpenCode settings, and OpenRouter limits |

A bash-based multi-tool installer (`install.sh` + `modules/`) is also present, targeting a broader set of AI CLI tools with autonomy flags pre-applied. See the **Bash installer** section below.

---

## What the installer does now

The current installer can:

- Detect whether `node` and `npm` are installed.
- Install Node.js and npm using a supported system package manager.
- Install Gemini CLI globally with npm.
- Install Codex CLI globally with npm.
- Store `GEMINI_API_KEY` in your shell profile.
- Store `GEMINI_MODEL` in your shell profile.
- Store `OPENAI_API_KEY` in your shell profile.
- Run Codex login using an API key, browser login, device login, or skip login.
- Verify whether `node`, `npm`, `gemini`, and `codex` are available.
- Show install logs inside the terminal UI.

Some of the API-key behavior currently lives in the installer. Long term, this should move into the configuration tool so the installer remains focused on installing tools.

---

## Supported platforms

The script is designed for Unix-like systems.

Intended targets:

- Linux
- Fedora
- Ubuntu
- Debian
- Arch Linux
- openSUSE
- macOS with Homebrew

Windows is not currently supported because the interface uses Python `curses` and writes to Unix-style shell profiles.

---

## Requirements

You need:

- Python 3.10 or newer
- A terminal that supports curses
- `sudo` access if Node.js needs to be installed through the system package manager
- Internet access for npm installs

The script can install Node.js and npm for you if they are missing and if a supported package manager is available.

Supported package managers in the current script:

- `apt-get`
- `dnf`
- `yum`
- `pacman`
- `zypper`
- `brew`

---

## Quick start

Clone the repository:

```bash
git clone https://github.com/Research-Ready/Auto-A.I-Cli-Installer.git
cd Auto-A.I-Cli-Installer
```

Run the Python TUI installer:

```bash
python3 ai_cli_installer_tui.py
```

Use the arrow keys to move through the menu. Use Enter to edit or select an option.

---

## Bash installer (multi-tool)

For the broader bash-based installer that covers 13+ AI tools:

```bash
cp api_keys.env.example api_keys.env
# edit api_keys.env and fill in your keys
bash install.sh
```

### Tools installed by bash installer

| Tool | Install method | Autonomy flag |
|---|---|---|
| OpenRouter | `pip install openai` | N/A (API library) |
| Ollama | curl installer | N/A (always autonomous) |
| Aider | `pip install aider-chat` | `--yes` |
| Claude Code | `npm i -g @anthropic-ai/claude-code` | `--auto` |
| OpenCode | curl / npm | `--auto-approve` |
| Codex CLI | `npm i -g @openai/codex` | `--approval-policy full-auto` |
| Gemini CLI | `npm i -g @google/gemini-cli` | `--yolo` |
| Goose | GitHub binary release | `--no-confirmation` |
| Groq | `pip install groq` | N/A |
| Hugging Face | `pip install huggingface_hub` | `--yes` |
| Cerebras | `pip install cerebras-cloud-sdk` | N/A |
| DeepSeek | uses openai SDK | N/A |
| Mistral | `pip install mistralai` | N/A |

### API key priority (free inference)

1. OpenRouter free models — user already has key, many permanently-free models
2. Gemini CLI — 1,000 free req/day
3. Groq / Cerebras — free tier, fastest cloud
4. Ollama local — unlimited, offline, private
5. DeepSeek API — near-zero cost
6. Anthropic / OpenAI — paid fallback

---

## Menu options

The TUI currently lets you configure:

| Option | Purpose |
| --- | --- |
| Gemini API key | Stores `GEMINI_API_KEY` in your shell profile |
| Gemini model | Stores `GEMINI_MODEL` in your shell profile |
| OpenAI API key | Stores `OPENAI_API_KEY` in your shell profile |
| Install Node if missing | Allows automatic Node.js and npm installation |
| Install Gemini CLI | Installs `@google/gemini-cli` globally |
| Install Codex CLI | Installs `@openai/codex` globally |
| Codex auth mode | Chooses API key, browser, device, or skip |
| Shell profile | Selects where environment variables are written |
| Run install and configure | Runs the installation workflow |

---

## Shell profile behavior

The script tries to detect your shell profile automatically.

| Shell | File |
| --- | --- |
| Bash on Linux | `~/.bashrc` |
| Bash on macOS | `~/.bash_profile` or `~/.bashrc` |
| Zsh | `~/.zshrc` |
| Fish | `~/.config/fish/config.fish` |

After the installer finishes, reload your shell profile:

```bash
source ~/.bashrc
```

---

## Codex login modes

| Mode | Behavior |
| --- | --- |
| `api_key` | Runs `codex login --with-api-key` and sends the provided key |
| `browser` | Runs the normal interactive `codex login` flow |
| `device` | Runs `codex login --device-auth` |
| `skip` | Installs Codex but does not log in |

---

## Verify installation

```bash
node --version
npm --version
gemini --version
codex --version
codex login status
```

---

## Testing (bash installer)

```bash
# Run all smoke tests after install:
bash tests/run_all.sh

# Single tool:
bash tests/test_aider.sh
```

---

## Deployed Infrastructure (for AI agents)

> **For AI assistants reading this:** The infrastructure below is the live environment this installer targets. You can connect to these services directly using the addresses listed. All services are on a private network — VPN or Tailscale access required from outside. Use these endpoints to run models, search the web, store vectors, or trigger workflows without needing external API keys.

### Network layout

```
Internet → Traefik (10.0.4.10) → LXC containers on 10.0.6.0/24
                                        ↑
                              Proxmox cluster (10.0.0.15–17)
```

- **Traefik** at `10.0.4.10` — all external traffic enters here
- Dynamic configs: `/opt/traefik-stack/dynamic/` on `10.0.4.10`
- **Rule:** always use direct `10.0.6.x` IPs in Traefik configs — no socat/Tailscale relays

### Proxmox nodes

| IP | Role |
|---|---|
| `10.0.0.15` | dev |
| `10.0.0.16` | test |
| `10.0.0.17` | acceptance |

### AI services — `10.0.6.10` (shared-ai-01)

This is the primary AI backend. Point your tools here.

| Service | Address | What it does |
|---|---|---|
| **LiteLLM** | `10.0.6.10:4000` | OpenAI-compatible proxy — route any model through here |
| **Ollama** | `10.0.6.10:11434` | Local LLM inference (Llama 3.2, DeepSeek R1, Qwen3-Coder, etc.) |
| **Qdrant** | `10.0.6.10:6333` | Vector database — embeddings and RAG |
| **Postgres** | `10.0.6.10:5432` | Relational database |
| **Neo4j** | `10.0.6.10:7474` (HTTP) / `10.0.6.10:7687` (Bolt) | Graph database |
| **SearXNG** | `10.0.6.10:8081` | Self-hosted web search (no API key needed) |
| **Langfuse** | `10.0.6.10:3002` | LLM observability and tracing |
| **MinIO** | `10.0.6.10:9000` (S3 API) / `10.0.6.10:9011` (console) | Object storage |

#### LiteLLM — OpenAI-compatible, routes any model

```bash
export OPENAI_API_BASE="http://10.0.6.10:4000"
export OPENAI_API_KEY="your-litellm-key"
# now any OpenAI SDK call hits the local proxy
```

#### Ollama — local inference, no key needed

```bash
export OLLAMA_HOST="http://10.0.6.10:11434"
ollama run llama3.2        # general
ollama run qwen3-coder:3b  # coding
ollama run deepseek-r1:7b  # reasoning
```

#### SearXNG — web search, no key, no rate limit

```bash
curl "http://10.0.6.10:8081/search?q=your+query&format=json"
```

#### Qdrant — vector search

```bash
# HTTP API
curl http://10.0.6.10:6333/collections
```

### Per-user services — `10.0.6.11`, `.12`, `.13`

| Port | Service | Use |
|---|---|---|
| `:3000` | Open WebUI | Chat UI for Ollama/LiteLLM |
| `:5678` | n8n | Workflow automation — trigger agents via webhooks |
| `:3001` | Flowise | Visual agent/chain builder |

### Auth & monitoring

| Service | Address |
|---|---|
| Authentik (SSO) | `10.0.6.5:9000` |
| Vaultwarden | `10.0.6.5:8080` |
| Grafana | `10.0.6.15:3100` |
| Prometheus | `10.0.6.15:9090` |
| Uptime Kuma | `10.0.6.15:3201` |
| Portainer | `10.0.6.15:9443` |

### Live service status

Checked every 30 minutes by GitHub Actions via Tailscale. 🟢 up · 🔴 down · 🟡 unexpected response.

<!-- SERVICE_STATUS_START -->
*Status not yet generated — workflow hasn't run yet.*
<!-- SERVICE_STATUS_END -->

---

## Development

Run a syntax check:

```bash
python3 -m py_compile ai_cli_installer_tui.py
```

Run the TUI:

```bash
python3 ai_cli_installer_tui.py
```

---

## Security notes

Be careful with API keys.

The current script writes API keys to shell profile files. That is convenient, but anyone who can read those files can read the keys.

Future versions should consider:

- Using dedicated config files with restricted permissions.
- Creating backups before writing configuration.
- Avoiding accidental printing of API keys in logs.
- Supporting keychain or secret-manager storage where available.

---

## License

No license has been selected yet.

Add a license before reusing or distributing this project more broadly.
