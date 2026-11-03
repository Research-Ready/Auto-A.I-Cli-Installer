# Auto A.I CLI Installer — Project Plan

## Goal

A single-command bash installer that sets up all major AI CLI tools on Linux, one at a time,
with a single `api_keys.env` file for all API keys. Every tool is configured for maximum
autonomy (permissions bypassed / auto-approved). OpenRouter is the priority first integration
since the user already has a key and it unlocks free models too.

---

## Where to Run AI Models

### Already Paid (existing subscriptions)
> `claude.ai Pro` and `ChatGPT Plus` are **chat** subscriptions — API keys are billed separately.

| Subscription | Where to get the API key |
|---|---|
| Claude Pro | console.anthropic.com → API Keys |
| OpenAI Plus/Pro | platform.openai.com → API Keys |

### Free Cloud Inference

| Provider | Free Tier | Best For | Env Var |
|---|---|---|---|
| **OpenRouter** | 50 req/day free; free models always free | Multi-model routing + free models | `OPENROUTER_API_KEY` |
| **Google AI Studio / Gemini CLI** | 1,000 req/day, Gemini 2.5 Pro/Flash | Best free quality | `GOOGLE_API_KEY` |
| **Groq** | ~8,000 TPM free, fastest cloud (LPU) | Speed-critical tasks | `GROQ_API_KEY` |
| **Cerebras** | Free developer tier, 2nd fastest | Fast reasoning | `CEREBRAS_API_KEY` |
| **SambaNova** | Free developer tier | Fast open models | `SAMBANOVA_API_KEY` |
| **Fireworks AI** | 10 RPM free (no card needed) | Open model hosting | `FIREWORKS_API_KEY` |
| **Hugging Face** | Free inference for thousands of models | OSS model access | `HUGGINGFACE_TOKEN` |
| **DeepSeek API** | ~$0.001/1M tokens — near-free | Coding / reasoning | `DEEPSEEK_API_KEY` |
| **Mistral** | Free tier on La Plateforme | European open models | `MISTRAL_API_KEY` |
| **Cohere** | Free trial tier | RAG / embeddings | `COHERE_API_KEY` |
| **Cloudflare Workers AI** | Free tier | Edge/serverless AI | `CLOUDFLARE_API_KEY` |
| **Perplexity** | Limited free tier | Web-grounded answers | `PERPLEXITY_API_KEY` |

### Free Local (offline, no key, unlimited)

| Tool | Models Available | Min Hardware |
|---|---|---|
| **Ollama** | Llama 3.2, DeepSeek R1, Qwen3-Coder, Mistral, Phi, Gemma | 8 GB RAM (7B models) |
| **LM Studio** | Same as Ollama, GUI-based | 8 GB RAM (7B models) |

**Best free local models:**
- General: `llama3.2:8b`, `mistral:7b`
- Coding: `qwen3-coder:3b`, `deepseek-r1:14b`
- Reasoning: `deepseek-r1:7b`
- Lightweight: `phi3:mini`, `gemma2:2b`

### Free Model Priority Order
1. **OpenRouter free models** — user already has key, many permanently-free models
2. **Gemini CLI** — 1,000 free req/day, high quality
3. **Groq / Cerebras** — when speed matters, both free tier
4. **Ollama local** — unlimited, offline, private
5. **DeepSeek API** — near-zero cost when API needed
6. **Anthropic / OpenAI API** — paid fallback

---

## Project File Structure

```
Auto-A.I-Cli-Installer/
├── CLAUDE.md                  # Project plan (this file)
├── README.md                  # User-facing usage docs
├── install.sh                 # Main orchestrator script
├── api_keys.env               # User's keys — NEVER committed
├── api_keys.env.example       # Template — committed to repo
├── .gitignore                 # Excludes api_keys.env and secrets
└── modules/                   # One file per tool
    ├── common.sh              # Shared: colors, OS detection, dep checks, shell-rc writer
    ├── openrouter.sh          # FIRST — user already has key, unlocks free models
    ├── ollama.sh              # SECOND — local, free, no key
    ├── aider.sh               # THIRD — works with openrouter as backend
    ├── claude_code.sh
    ├── opencode.sh
    ├── codex.sh
    ├── gemini_cli.sh
    ├── goose.sh
    ├── huggingface.sh
    ├── groq.sh
    ├── cerebras.sh
    ├── sambanova.sh
    ├── fireworks.sh
    ├── deepseek.sh
    ├── mistral.sh
    ├── cohere.sh
    ├── github_copilot.sh
    ├── lm_studio.sh
    └── aws_bedrock.sh
```

---

## Autonomous / Permission Bypass Per Tool

| Tool | Autonomous Flag | Notes |
|---|---|---|
| Claude Code | `--auto` | AI classifier approves safe actions (March 2026) |
| Claude Code (full) | `--dangerously-skip-permissions` | Full bypass — sandbox/Docker only |
| OpenAI Codex CLI | `--approval-policy full-auto` | Auto-approves all edits + shell commands |
| Gemini CLI | `--yolo` | Skips all confirmation prompts |
| Aider | `--yes` | Auto-yes to all prompts |
| Goose | `--no-confirmation` | No confirmation mode |
| HuggingFace CLI | `--yes` | Auto-yes |
| GitHub Copilot CLI | `--yes` | Auto-yes |
| Ollama | N/A | Always autonomous (local) |
| LM Studio | N/A | Always autonomous (local) |
| OpenRouter | N/A | API library, no prompt |

Shell aliases with autonomy flags pre-applied are written to `~/.bashrc` / `~/.zshrc` by each module.

---

## api_keys.env Key Slots

```
ANTHROPIC_API_KEY          Claude Code, Aider, OpenCode
OPENAI_API_KEY             Codex CLI, Aider, OpenCode, OpenRouter compat
GOOGLE_API_KEY             Gemini CLI
GITHUB_TOKEN               GitHub Copilot CLI
OPENROUTER_API_KEY         OpenRouter (+ free models)
GROQ_API_KEY               Groq
CEREBRAS_API_KEY           Cerebras
SAMBANOVA_API_KEY          SambaNova
FIREWORKS_API_KEY          Fireworks AI
DEEPSEEK_API_KEY           DeepSeek
MISTRAL_API_KEY            Mistral
HUGGINGFACE_TOKEN          Hugging Face CLI
COHERE_API_KEY             Cohere
PERPLEXITY_API_KEY         Perplexity
CLOUDFLARE_ACCOUNT_ID      Cloudflare Workers AI
CLOUDFLARE_API_KEY         Cloudflare Workers AI
AWS_ACCESS_KEY_ID          AWS Bedrock
AWS_SECRET_ACCESS_KEY      AWS Bedrock
AWS_DEFAULT_REGION         AWS Bedrock (default: us-east-1)
```

---

## install.sh Flow (detailed)

```
start
  ├─ print_banner()           — ASCII art header + version
  ├─ check_bash_version()     — require bash 4+
  ├─ source modules/common.sh
  ├─ detect_os()              — set $OS_TYPE, $PKG_MANAGER
  ├─ check_core_deps()        — node/npm, python3/pip, curl, git
  │    └─ install_missing_deps() — auto-install via detected pkg manager
  ├─ load_api_keys()          — source api_keys.env; warn if missing key slots
  │    └─ if not found: offer to cp api_keys.env.example api_keys.env
  ├─ show_menu()              — numbered list of tools + [A]ll + [Q]uit
  ├─ for each selected tool:
  │    ├─ source modules/<tool>.sh
  │    ├─ install_<tool>()
  │    ├─ configure_<tool>()  — write env exports + aliases to shell RC
  │    └─ verify_<tool>()     — run version check, record OK/FAIL
  └─ print_summary()          — table of tool | status | version
```

---

## modules/common.sh Contents (detailed)

Functions to implement, in order:

1. `color_setup` — define `RED GREEN YELLOW BLUE BOLD RESET` using tput or ANSI codes
2. `log_info MSG` — print `[INFO]` in blue
3. `log_ok MSG` — print `[OK]` in green
4. `log_warn MSG` — print `[WARN]` in yellow
5. `log_err MSG` — print `[ERR]` in red, to stderr
6. `detect_os` — set `$OS_TYPE` (debian|arch|fedora|macos|unknown), `$PKG_MANAGER` (apt|pacman|dnf|brew)
7. `has_cmd CMD` — returns 0 if command exists on PATH
8. `require_cmd CMD` — calls `log_err` and exits 1 if command missing
9. `install_pkg PKG` — installs a system package via `$PKG_MANAGER` with sudo
10. `check_node` — check node ≥18; if missing install via nvm or system pkg
11. `check_npm` — check npm exists; install if missing
12. `check_python` — check python3 exists; install if missing
13. `check_pip` — check pip3 exists; install if missing
14. `check_curl` — check curl; install if missing
15. `check_git` — check git; install if missing
16. `check_core_deps` — calls all check_* functions above
17. `load_api_keys FILE` — source FILE; log which keys are set vs empty
18. `write_shell_rc LINE` — append LINE to ~/.bashrc and ~/.zshrc if they exist, idempotent (skip if already present)
19. `write_env_export VAR` — call `write_shell_rc "export VAR=VALUE"` using current env value
20. `write_alias NAME CMD` — call `write_shell_rc "alias NAME='CMD'"` idempotently
21. `verify_cmd CMD` — run `CMD --version` or `CMD version`, capture output, return version string or FAIL

---

## Per-Module Structure (each modules/*.sh file)

Every module must expose exactly three functions:

```bash
install_<toolname>()   # download + install the binary/package
configure_<toolname>() # write env exports + aliases to shell RC
verify_<toolname>()    # print version or FAIL; set VERIFY_STATUS="ok"|"fail"
```

---

## Module Implementation Plan (one at a time, in order)

### PHASE 0 — Foundation (build first, everything depends on these)

#### Step 0.1 — `.gitignore`
- Exclude: `api_keys.env`, `*.env`, `*.secret`, `.DS_Store`, `__pycache__/`

#### Step 0.2 — `api_keys.env.example`
- All 19 key slots listed above
- Each slot empty (`KEY=`)
- Comments explaining where to get each key + free tier link
- Warning header: "DO NOT commit api_keys.env — only commit this .example file"

#### Step 0.3 — `modules/common.sh`
- All 21 functions listed in the section above
- Fully commented
- Tested manually: `source modules/common.sh && detect_os && echo $OS_TYPE`

#### Step 0.4 — `install.sh` skeleton
- Shebang `#!/usr/bin/env bash`, `set -euo pipefail`
- `print_banner` with ASCII header
- Source `modules/common.sh`
- Stub calls: `detect_os`, `check_core_deps`, `load_api_keys`, `show_menu`, `print_summary`
- `show_menu` lists all tool names with numbers + [A]ll + [Q]uit; reads user input
- `print_summary` prints a table of results at the end
- `chmod +x install.sh` note in plan

---

### PHASE 1 — OpenRouter (user already has key)

#### Step 1.1 — `modules/openrouter.sh` — `install_openrouter`
- Check if `pip3` available (require_cmd)
- `pip3 install --upgrade openai` (OpenRouter uses OpenAI-compatible SDK)
- Print note: OpenRouter uses OpenAI SDK pointed at openrouter.ai base URL

#### Step 1.2 — `modules/openrouter.sh` — `configure_openrouter`
- Write `export OPENROUTER_API_KEY=...` to shell RC
- Write helper env vars:
  ```
  export OPENROUTER_BASE_URL="https://openrouter.ai/api/v1"
  ```
- Write convenience alias:
  ```
  alias openrouter-free='python3 -c "import openai; ..."'
  ```
- Print list of popular free models available on OpenRouter

#### Step 1.3 — `modules/openrouter.sh` — `verify_openrouter`
- Import openai in python3 and check version
- Set `VERIFY_STATUS`

#### Step 1.4 — Wire openrouter into `install.sh` menu

---

### PHASE 2 — Ollama (local, free, no key)

#### Step 2.1 — `modules/ollama.sh` — `install_ollama`
- Check if `ollama` already installed (`has_cmd ollama`)
- If not: `curl -fsSL https://ollama.ai/install.sh | sh`
- Start ollama service: `systemctl --user enable --now ollama` or detect init system

#### Step 2.2 — `modules/ollama.sh` — `configure_ollama`
- Write `export OLLAMA_HOST=http://localhost:11434`
- Offer to pull starter models interactively:
  - `ollama pull llama3.2` (general)
  - `ollama pull qwen3-coder:3b` (coding)
  - `ollama pull deepseek-r1:7b` (reasoning)
- Write alias: `alias ollama-code='ollama run qwen3-coder:3b'`

#### Step 2.3 — `modules/ollama.sh` — `verify_ollama`
- Run `ollama --version`, capture output

#### Step 2.4 — Wire ollama into `install.sh` menu

---

### PHASE 3 — Aider (AI coding agent, works with OpenRouter)

#### Step 3.1 — `modules/aider.sh` — `install_aider`
- `pip3 install --upgrade aider-chat`

#### Step 3.2 — `modules/aider.sh` — `configure_aider`
- If `OPENROUTER_API_KEY` is set: configure aider to use it
  - Write `export AIDER_OPENAI_API_BASE="https://openrouter.ai/api/v1"`
  - Write `export AIDER_OPENAI_API_KEY="$OPENROUTER_API_KEY"`
  - Write `export AIDER_MODEL="openrouter/meta-llama/llama-3.1-8b-instruct:free"`
- Else if `ANTHROPIC_API_KEY`: use Claude backend
- Else if `OPENAI_API_KEY`: use OpenAI backend
- Write alias: `alias aider='aider --yes'`

#### Step 3.3 — `modules/aider.sh` — `verify_aider`
- `aider --version`

#### Step 3.4 — Wire aider into `install.sh` menu

---

### PHASE 4 — Claude Code

#### Step 4.1 — `modules/claude_code.sh` — `install_claude_code`
- `require_cmd npm`
- `npm install -g @anthropic-ai/claude-code`

#### Step 4.2 — `modules/claude_code.sh` — `configure_claude_code`
- Write `export ANTHROPIC_API_KEY=...`
- Write alias: `alias claude='claude --auto'`
- Write commented-out alternative: `# alias claude='claude --dangerously-skip-permissions'`
- Print note about chat subscription vs API key

#### Step 4.3 — `modules/claude_code.sh` — `verify_claude_code`
- `claude --version`

#### Step 4.4 — Wire into `install.sh` menu

---

### PHASE 5 — OpenCode

#### Step 5.1 — `modules/opencode.sh` — `install_opencode`
- `curl -fsSL https://opencode.ai/install | bash`
- Fallback: `npm i -g opencode-ai`

#### Step 5.2 — `modules/opencode.sh` — `configure_opencode`
- If `OPENROUTER_API_KEY`: configure opencode to use OpenRouter
- Else: use whichever key is available (priority: ANTHROPIC > OPENAI > GOOGLE)
- Write alias: `alias opencode='opencode --auto-approve'`

#### Step 5.3 — `modules/opencode.sh` — `verify_opencode`
- `opencode --version`

#### Step 5.4 — Wire into `install.sh` menu

---

### PHASE 6 — OpenAI Codex CLI

#### Step 6.1 — `modules/codex.sh` — `install_codex`
- `npm install -g @openai/codex`

#### Step 6.2 — `modules/codex.sh` — `configure_codex`
- Write `export OPENAI_API_KEY=...`
- Write alias: `alias codex='codex --approval-policy full-auto'`

#### Step 6.3 — `modules/codex.sh` — `verify_codex`
- `codex --version`

#### Step 6.4 — Wire into `install.sh` menu

---

### PHASE 7 — Gemini CLI

#### Step 7.1 — `modules/gemini_cli.sh` — `install_gemini`
- `npm install -g @google/gemini-cli`

#### Step 7.2 — `modules/gemini_cli.sh` — `configure_gemini`
- Write `export GOOGLE_API_KEY=...`
- Write alias: `alias gemini='gemini --yolo'`
- Print note: 1,000 free req/day with Google AI Studio key

#### Step 7.3 — `modules/gemini_cli.sh` — `verify_gemini`
- `gemini --version`

#### Step 7.4 — Wire into `install.sh` menu

---

### PHASE 8 — Goose (Block)

#### Step 8.1 — `modules/goose.sh` — `install_goose`
- Detect arch (`uname -m`) → pick correct binary from GitHub releases
- `curl -fsSL https://github.com/block/goose/releases/latest/download/goose-linux-x86_64 -o ~/.local/bin/goose`
- `chmod +x ~/.local/bin/goose`
- Ensure `~/.local/bin` is on PATH

#### Step 8.2 — `modules/goose.sh` — `configure_goose`
- Write provider key (whichever is set: ANTHROPIC > OPENAI > OPENROUTER)
- Write alias: `alias goose='goose --no-confirmation'`

#### Step 8.3 — `modules/goose.sh` — `verify_goose`
- `goose --version`

#### Step 8.4 — Wire into `install.sh` menu

---

### PHASE 9 — Groq

#### Step 9.1 — `modules/groq.sh` — `install_groq`
- `pip3 install --upgrade groq`

#### Step 9.2 — `modules/groq.sh` — `configure_groq`
- Write `export GROQ_API_KEY=...`

#### Step 9.3 — `modules/groq.sh` — `verify_groq`
- `python3 -c "import groq; print(groq.__version__)"`

#### Step 9.4 — Wire into `install.sh` menu

---

### PHASE 10 — Hugging Face CLI

#### Step 10.1 — `modules/huggingface.sh` — `install_huggingface`
- `pip3 install --upgrade huggingface_hub`

#### Step 10.2 — `modules/huggingface.sh` — `configure_huggingface`
- Write `export HUGGINGFACE_TOKEN=...`
- `huggingface-cli login --token "$HUGGINGFACE_TOKEN"` (non-interactive)
- Write alias: `alias huggingface-cli='huggingface-cli --yes'`

#### Step 10.3 — `modules/huggingface.sh` — `verify_huggingface`
- `huggingface-cli --version`

#### Step 10.4 — Wire into `install.sh` menu

---

### PHASE 11 — Cerebras

#### Step 11.1 — `modules/cerebras.sh` — `install_cerebras`
- `pip3 install --upgrade cerebras-cloud-sdk`

#### Step 11.2 — `modules/cerebras.sh` — `configure_cerebras`
- Write `export CEREBRAS_API_KEY=...`

#### Step 11.3 — `modules/cerebras.sh` — `verify_cerebras`
- `python3 -c "import cerebras.cloud.sdk; print('ok')"`

#### Step 11.4 — Wire into `install.sh` menu

---

### PHASE 12 — DeepSeek

#### Step 12.1 — `modules/deepseek.sh` — `install_deepseek`
- Uses openai SDK (already installed via openrouter step or `pip3 install openai`)
- `pip3 install --upgrade openai`

#### Step 12.2 — `modules/deepseek.sh` — `configure_deepseek`
- Write `export DEEPSEEK_API_KEY=...`
- Write `export DEEPSEEK_BASE_URL="https://api.deepseek.com/v1"`

#### Step 12.3 — `modules/deepseek.sh` — `verify_deepseek`
- `python3 -c "import openai; print(openai.__version__)"`

#### Step 12.4 — Wire into `install.sh` menu

---

### PHASE 13 — Mistral

#### Step 13.1 — `modules/mistral.sh` — `install_mistral`
- `pip3 install --upgrade mistralai`

#### Step 13.2 — `modules/mistral.sh` — `configure_mistral`
- Write `export MISTRAL_API_KEY=...`

#### Step 13.3 — `modules/mistral.sh` — `verify_mistral`
- `python3 -c "import mistralai; print(mistralai.__version__)"`

#### Step 13.4 — Wire into `install.sh` menu

---

### PHASE 14 — SambaNova, Fireworks, Cohere, Perplexity, Cloudflare, GitHub Copilot CLI, LM Studio, AWS Bedrock

Each follows the same 4-step pattern (install / configure / verify / wire) as above.
These are lower priority and can be added iteratively after Phase 13 is complete.

---

### PHASE 15 — Final polish

#### Step 15.1 — Update `README.md`
- Prerequisites section
- Quick-start instructions (clone → copy .example → edit keys → run install.sh)
- Table of tools and their autonomous flags
- Troubleshooting section

#### Step 15.2 — End-to-end test on clean Debian/Ubuntu system
- Test `./install.sh` with only `OPENROUTER_API_KEY` set
- Verify aider + ollama work out of the box

#### Step 15.3 — End-to-end test on Arch Linux
- Same as 15.2

---

## Testing Strategy

### Test File Structure

```
tests/
├── run_all.sh             # Runs all tests, prints pass/fail summary
├── framework.sh           # Tiny test helpers: assert_eq, assert_cmd, assert_env, fail, pass
├── test_common.sh         # Unit tests for every function in modules/common.sh
├── test_openrouter.sh     # Smoke test: import openai, check OPENROUTER_API_KEY is exported
├── test_ollama.sh         # Smoke test: ollama --version, OLLAMA_HOST exported
├── test_aider.sh          # Smoke test: aider --version, alias written
├── test_claude_code.sh    # Smoke test: claude --version
├── test_opencode.sh       # Smoke test: opencode --version
├── test_codex.sh          # Smoke test: codex --version
├── test_gemini_cli.sh     # Smoke test: gemini --version
├── test_goose.sh          # Smoke test: goose --version
├── test_groq.sh           # Smoke test: python3 -c "import groq"
├── test_huggingface.sh    # Smoke test: huggingface-cli --version
├── test_cerebras.sh       # Smoke test: python3 -c "import cerebras"
├── test_deepseek.sh       # Smoke test: python3 -c "import openai; ..."
└── test_mistral.sh        # Smoke test: python3 -c "import mistralai"
```

### tests/framework.sh Functions

- `assert_cmd CMD` — pass if command exists on PATH, else fail with message
- `assert_eq ACTUAL EXPECTED` — pass if strings match
- `assert_env VAR` — pass if env var is set and non-empty
- `assert_file FILE` — pass if file exists
- `assert_alias NAME` — pass if alias NAME is defined in shell RC
- `run_test NAME FUNC` — runs FUNC, catches exit code, records pass/fail
- `print_results` — prints summary table of all test results

### What Each Module's verify_<tool>() Does

Each `verify_<tool>` function inside a module must:
1. Run the tool's version command (or python import check)
2. Print the version string if successful
3. Set `VERIFY_STATUS="ok"` or `VERIFY_STATUS="fail"`
4. Return 0 on success, 1 on failure

### Running Tests

```bash
# Run all tests after install:
bash tests/run_all.sh

# Run tests for a single tool:
bash tests/test_aider.sh

# Run common.sh unit tests only:
bash tests/test_common.sh
```

---

## Current Build Status

- [x] CLAUDE.md — plan written
- [x] Phase 0.1 — .gitignore
- [x] Phase 0.2 — api_keys.env.example
- [x] Phase 0.3 — modules/common.sh
- [x] Phase 0.4 — install.sh skeleton
- [x] tests/framework.sh + tests/test_common.sh + tests/run_all.sh
- [x] Phase 1 — OpenRouter module
- [x] Phase 2 — Ollama module
- [x] Phase 3 — Aider module
- [x] Phase 4 — Claude Code module
- [x] Phase 5 — OpenCode module
- [x] Phase 6 — Codex CLI module
- [x] Phase 7 — Gemini CLI module
- [ ] Phase 8 — Goose module
- [ ] Phase 9 — Groq module
- [ ] Phase 10 — Hugging Face module
- [ ] Phase 11 — Cerebras module
- [ ] Phase 12 — DeepSeek module
- [ ] Phase 13 — Mistral module
- [ ] Phase 14 — Remaining providers
- [ ] Phase 15 — Polish + testing

## Absolute Veracity & Real-World Deliverable Proof (Never False Completion)
- **Zero False Completion**: NEVER claim a feature, integration, or system is done, verified, or working based solely on isolated unit tests or files written to disk if the actual user-facing application (e.g., OpenWebUI, database, deployed service) is not genuinely configured, populated, and verified in reality.
- **Admit Gaps Explicitly**: Admitting an integration gap or failure immediately is mandatory. If assets exist on disk but have not been imported or wired into the running application/UI, state the exact truth: *"The assets exist on disk, but [Application/UI] is not yet configured and cannot use them yet."*
- **End-User Experience is Ground Truth**: A task is only complete when the user can open the target application and immediately use the functionality as intended.
