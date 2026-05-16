# Project: Auto-A.I CLI Installer

This project provides a practical toolkit for local AI CLI workflows, focused on a **CLI Installer** and a **Configuration Tool**.

## Primary Mandates

- **Separate Installer from Configuration**: Installation logic (binaries) vs. Configuration logic (API keys, model tuning).
- **Security**: Zero tolerance for logging/printing secrets. Restricted permissions on config files.
- **Platform Support**: Unix-like systems (Linux, macOS).
- **Tool Detection**: Empirical verification of tool existence and versions.

---

## Roadmap & Milestones

### Milestone 1: Unified Detection & Version Reporting
*Upgrade the TUI to recognize and report the status of the entire tool ecosystem.*

- **Tasks**:
    - [ ] Implement Prerequisite Check for: `node`, `npm`, `python3`, `pip3`, `go`, `curl`.
    - [ ] Expand detection logic (using `command -v`) for: Gemini, Codex, OpenCode, Aider, Open-Interpreter, ShellGPT, Fabric, Goose, gh-models, gh-copilot, openclaw.
    - [ ] Implement version extraction (e.g., `aider --version`, `interpreter --version`).
- **Definition of Done**: The TUI accurately reflects the state of all tools and their versions on launch.
- **Verification Tests**:
    - Compare TUI display against manual `tool --version` output for each tool.
    - Verify that "Not Installed" correctly triggers for tools removed from the PATH.

### Milestone 2: Multi-Provider Installation Engine
*Enable the installation of the expanded toolset across multiple package managers.*

- **Tasks**:
    - [ ] Add installation paths for: Aider (`pip3 install -U aider-chat`), Open-Interpreter (`pip3 install -U open-interpreter`), ShellGPT (`pip3 install -U shell-gpt`), Fabric (`go install github.com/danielmiessler/fabric@latest`), Goose (`curl | bash`), OpenCode (`go install`).
    - [ ] Add GitHub CLI extensions (`gh extension install github/gh-models`, `gh extension install github/gh-copilot`).
    - [ ] Support `npm`, `pip`, `go`, and system package managers (`apt`, `brew`, etc.).
- **Definition of Done**: Users can select and successfully install any tool in the list directly from the TUI.
- **Verification Tests**:
    - Run an installation for a missing tool and verify it becomes executable.
    - Verify that the TUI updates its status to "Installed" immediately after a successful run.

### Milestone 3: Safety & "YOLO" Features
*Implement operational safety and the "YOLO" autonomous mode.*

- **Tasks**:
    - [ ] **Dry-run Mode**: Implementation of a flag/toggle that logs all intended commands.
    - [ ] **Auto-Backup**: Copy shell profiles/configs to `.bak` before modification.
    - [ ] **YOLO Mode Configuration**:
        - [ ] Aider: Set `AIDER_YES=1` in shell profile.
        - [ ] Open-Interpreter: Configure alias for `interpreter --yolo`.
        - [ ] OpenCode: Enable `auto-confirm` in config.
        - [ ] ShellGPT: Configure `SGPT_DANGEROUS=true`.
- **Definition of Done**: 
    - Dry-run mode produces a complete log of actions.
    - Every file edit is preceded by a backup.
    - YOLO mode successfully bypasses "Are you sure?" prompts in supported tools.
- **Verification Tests**:
    - Run installer in dry-run; verify no changes to the system but a full log output.
    - Verify existence of `.bashrc.bak` (or similar) after an API key update.
    - Launch Aider/Interpreter and verify they don't prompt for confirmation during edits.

### Milestone 4: OpenRouter & Model Configuration
*Transition to a specialized configuration tool for advanced model routing.*

- **Tasks**:
    - [ ] OpenRouter API key input with real-time validation (ping `/models`).
    - [ ] Secure storage: `~/.config/opencode/openrouter.key` with `600` permissions.
    - [ ] OpenCode configuration generator (JSON/JSONC).
    - [ ] Model selector with context window and pricing metadata.
- **Definition of Done**: A valid OpenRouter configuration is generated and accepted by OpenCode/Aider.
- **Verification Tests**:
    - Try to save an invalid API key; verify the tool rejects it.
    - Check file permissions on the stored key.
    - Verify OpenCode loads the generated config without errors.

### Milestone 5: Model Capability Testing & Benchmarking
*Automate the evaluation of models to ensure they meet engineering standards.*

- **Tasks**:
    - [ ] Create `benchmark_free_openrouter_models.py`.
    - [ ] Implement tests for: Chat, Coding, Tool-use, and Context Window limits.
    - [ ] Generate `openrouter_free_model_report.md`.
- **Definition of Done**: The benchmark script runs to completion and produces a ranked report of models suitable for agentic work.
- **Verification Tests**:
    - Run the benchmark; verify the output JSON contains latency and success metrics.
    - Confirm the report identifies which models failed the "Tool-use" test.

### Milestone 6: Continuous Integration & Automated Testing
*Setup GitHub Actions to automate testing and validation.*

- **Tasks**:
    - [ ] Create `.github/workflows/test.yml` to run syntax checks and unit tests.
    - [ ] Implement a "mock" mode for detection logic to allow CI testing without all tools installed.
    - [ ] Automate linting for Python and Shell scripts.
- **Definition of Done**: Every push or PR triggers an automated test suite that verifies the core installer logic.
- **Verification Tests**:
    - Push a change and verify the GitHub Action completes successfully.
    - Intentionally introduce a syntax error and verify the action fails.

---

## Skills

- **skill-creator**: Use for creating new specialized skills or updating existing ones.

## Development Workflow

- **Primary TUI**: `ai_cli_installer_tui.py`
- **Git Operations**: Use HTTPS (authenticated via `gh` credential helper) to ensure password-less and passphrase-less pushes.
- **Verification**: Always run `python3 -m py_compile` and manual verification tests before declaring a milestone complete.
