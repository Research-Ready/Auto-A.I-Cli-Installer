# Auto-A.I CLI Installer

## Outstanding tasks

The current script installs and configures Gemini CLI and Codex CLI. The next major milestone is to turn this repository into a proper OpenCode and OpenRouter setup assistant.

### OpenRouter model discovery and selection

- [ ] Add OpenRouter API key input.
- [ ] Validate the OpenRouter API key before writing any config.
- [ ] Fetch the full OpenRouter model list from the API.
- [ ] Load each model's maximum context window size.
- [ ] Load each model's maximum output token limit when available.
- [ ] Load model pricing and detect free models reliably.
- [ ] Detect whether a model supports text, chat, tools, images, structured output, and reasoning where possible.
- [ ] Score models based on context size, cost, coding usefulness, reliability, and test results.
- [ ] Show recommended models at the top of the TUI.
- [ ] Allow the user to choose between free-only mode and all-model mode.

### OpenCode configuration

- [ ] Add OpenCode installation and detection.
- [ ] Write OpenCode configuration to `~/.config/opencode/opencode.json` or `~/.config/opencode/opencode.jsonc`.
- [ ] Back up existing OpenCode config before writing changes.
- [ ] Store the OpenRouter key safely, for example in `~/.config/opencode/openrouter.key` with restricted file permissions.
- [ ] Configure OpenCode to use the selected OpenRouter model.
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

The installer should not trust model metadata blindly. It should test each selected model before recommending it.

- [ ] Test a basic chat request.
- [ ] Test a coding-style request.
- [ ] Test a tool-use request.
- [ ] Test whether the model can handle OpenCode-style tool calling.
- [ ] Test whether the model respects the selected output token limit.
- [ ] Test the practical context window with a controlled large-context prompt.
- [ ] Detect when a model fails before reaching its advertised context window.
- [ ] Record whether the model fails because of context size, tool use, rate limits, provider errors, or unsupported parameters.
- [ ] Store test results locally so the TUI can avoid repeatedly testing the same model.

### Free-model benchmark script

Add a second script that automatically tests all available free OpenRouter models.

Planned script:

```text
benchmark_free_openrouter_models.py
```

This script should:

- [ ] Fetch all OpenRouter models.
- [ ] Filter free models.
- [ ] Run a small basic chat test for every free model.
- [ ] Run a coding prompt test for every free model.
- [ ] Run a tool-use compatibility test for every free model.
- [ ] Run a controlled context-window test.
- [ ] Save results to a local JSON file.
- [ ] Save a readable Markdown report.
- [ ] Rank models by usefulness for OpenCode.
- [ ] Update the model selection data used by the TUI.
- [ ] Mark broken, rate-limited, unreliable, or non-tool-capable models.

Suggested outputs:

```text
openrouter_free_model_results.json
openrouter_free_model_report.md
recommended_models.json
```

### Context length safety

The project should prevent errors like:

```text
This endpoint's maximum context length is 131072 tokens. However, you requested about 242419 tokens.
```

To prevent this, the installer should:

- [ ] Calculate a safe input budget for each selected model.
- [ ] Reserve output tokens conservatively.
- [ ] Warn when the selected output limit is too high for the model context window.
- [ ] Warn when OpenCode sessions need `/compact` or `/new`.
- [ ] Prefer models with larger context windows for agentic coding workflows.
- [ ] Prevent known bad combinations of model, output limit, and tool-heavy sessions.

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

It does not yet configure OpenCode or OpenRouter.

## What it does now

The installer can:

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

## Quick start

Clone the repository:

```bash
git clone https://github.com/Research-Ready/Auto-A.I-Cli-Installer.git
cd Auto-A.I-Cli-Installer
```

Run the installer:

```bash
python3 ai_cli_installer_tui.py
```

Use the arrow keys to move through the menu.

Use Enter to edit or select an option.

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

## Shell profile behavior

The script tries to detect your shell profile automatically.

Examples:

| Shell | File |
| --- | --- |
| Bash on Linux | `~/.bashrc` |
| Bash on macOS | `~/.bash_profile` or `~/.bashrc` |
| Zsh | `~/.zshrc` |
| Fish | `~/.config/fish/config.fish` |

After the installer finishes, reload your shell profile.

Example:

```bash
source ~/.bashrc
```

Or open a new terminal.

## Codex login modes

The installer supports four Codex login modes:

| Mode | Behavior |
| --- | --- |
| `api_key` | Runs `codex login --with-api-key` and sends the provided key |
| `browser` | Runs the normal interactive `codex login` flow |
| `device` | Runs `codex login --device-auth` |
| `skip` | Installs Codex but does not log in |

## Gemini login note

Gemini CLI can be configured through the `GEMINI_API_KEY` environment variable.

If you prefer Google sign-in, run Gemini manually after installation:

```bash
gemini
```

Then follow the official interactive login flow.

## Verify installation

After running the installer, you can manually check:

```bash
node --version
npm --version
gemini --version
codex --version
codex login status
```

## Development

Run a syntax check:

```bash
python3 -m py_compile ai_cli_installer_tui.py
```

Run the TUI:

```bash
python3 ai_cli_installer_tui.py
```

## Repository purpose

This repository is meant to become a small, practical installer for local AI CLI workflows.

It should help with:

- Installing AI CLI tools.
- Testing API keys.
- Choosing sensible model defaults.
- Preventing fragile configuration mistakes.
- Making experimentation with AI developer tools easier.

## Security notes

Be careful with API keys.

The current script writes API keys to shell profile files. That is convenient, but anyone who can read those files can read the keys.

Future versions should consider:

- Using dedicated config files with restricted permissions.
- Creating backups before writing configuration.
- Avoiding accidental printing of API keys in logs.
- Supporting keychain or secret-manager storage where available.

## License

No license has been selected yet.

Add a license before reusing or distributing this project more broadly.
