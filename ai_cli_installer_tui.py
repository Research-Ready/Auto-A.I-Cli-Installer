#!/usr/bin/env python3
from __future__ import annotations

import curses
import os
import platform
import shutil
import subprocess
import sys
import textwrap
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional


APP_TITLE = "Auto-A.I CLI Installer"
GEMINI_NPM_PACKAGE = "@google/gemini-cli"
CODEX_NPM_PACKAGE = "@openai/codex"


@dataclass
class ToolInfo:
    name: str
    command: str
    version_cmd: list[str] = field(default_factory=lambda: ["--version"])
    installed: bool = False
    version: str = "Not Installed"
    install_cmd: Optional[list[str]] = None
    should_install: bool = False


@dataclass
class AppState:
    gemini_api_key: str = ""
    gemini_model: str = ""
    openai_api_key: str = ""
    openrouter_api_key: str = ""
    install_node_if_missing: bool = True
    shell_rc: Optional[Path] = None
    logs: List[str] = field(default_factory=list)
    dry_run: bool = False
    yolo_mode: bool = False
    codex_auth_mode: str = "api_key"
    tools: dict[str, ToolInfo] = field(default_factory=lambda: {
        "node": ToolInfo("Node.js", "node"),
        "npm": ToolInfo("npm", "npm"),
        "python3": ToolInfo("Python 3", "python3"),
        "pip3": ToolInfo("pip 3", "pip3"),
        "go": ToolInfo("Go", "go", ["version"]),
        "curl": ToolInfo("curl", "curl", ["--version"]),
        "gemini": ToolInfo("Gemini CLI", "gemini", install_cmd=["npm", "install", "-g", "@google/gemini-cli"]),
        "codex": ToolInfo("Codex CLI", "codex", install_cmd=["npm", "install", "-g", "@openai/codex"]),
        "opencode": ToolInfo("OpenCode", "opencode", install_cmd=["go", "install", "github.com/opencode-ai/opencode@latest"]),
        "aider": ToolInfo("Aider", "aider", ["--version"], install_cmd=["pip3", "install", "-U", "aider-chat"]),
        "interpreter": ToolInfo("Open Interpreter", "interpreter", ["--version"], install_cmd=["pip3", "install", "-U", "open-interpreter"]),
        "sgpt": ToolInfo("ShellGPT", "sgpt", ["--version"], install_cmd=["pip3", "install", "-U", "shell-gpt"]),
        "fabric": ToolInfo("Fabric", "fabric", ["--version"], install_cmd=["go", "install", "github.com/danielmiessler/fabric@latest"]),
        "goose": ToolInfo("Goose", "goose", ["version"], install_cmd=["bash", "-c", "curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | bash"]),
        "gh": ToolInfo("GitHub CLI", "gh", ["version"]),
    })


def backup_file(file_path: Path, state: AppState) -> None:
    if file_path.exists():
        bak_path = file_path.with_suffix(file_path.suffix + ".bak")
        state.logs.append(f"Creating backup: {bak_path}")
        if not state.dry_run:
            try:
                shutil.copy2(file_path, bak_path)
            except Exception as e:
                state.logs.append(f"Backup failed: {e}")


def run_command(
    cmd: list[str],
    *,
    input_text: Optional[str] = None,
    env: Optional[dict[str, str]] = None,
    check: bool = False,
    state: Optional[AppState] = None,
) -> subprocess.CompletedProcess:
    if state and state.dry_run:
        state.logs.append(f"[DRY-RUN] Would run: {' '.join(cmd)}")
        return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

    return subprocess.run(
        cmd,
        input=input_text,
        text=True,
        capture_output=True,
        env=env,
        check=check,
    )


def command_exists(cmd: str) -> bool:
    return shutil.which(cmd) is not None


def detect_shell_rc() -> Path:
    shell = os.environ.get("SHELL", "")
    home = Path.home()

    if shell.endswith("zsh"):
        return home / ".zshrc"
    if shell.endswith("bash"):
        if sys.platform == "darwin":
            return home / ".bash_profile" if (home / ".bash_profile").exists() else home / ".bashrc"
        return home / ".bashrc"
    if shell.endswith("fish"):
        return home / ".config" / "fish" / "config.fish"

    return home / ".bashrc"


def append_export_if_missing(rc_file: Path, key: str, value: str, state: Optional[AppState] = None) -> None:
    rc_file.parent.mkdir(parents=True, exist_ok=True)
    if not rc_file.exists():
        if state and state.dry_run:
            state.logs.append(f"[DRY-RUN] Would create {rc_file}")
            return
        rc_file.touch()

    content = rc_file.read_text(encoding="utf-8")
    marker = f"# added by {APP_TITLE}"

    if rc_file.name == "config.fish":
        line = f'set -gx {key} "{value}"'
    else:
        line = f'export {key}="{value}"'

    if f"{key}=" in content or line in content:
        return

    if state and state.dry_run:
        state.logs.append(f"[DRY-RUN] Would append to {rc_file}: {line}")
        return

    with rc_file.open("a", encoding="utf-8") as f:
        f.write(f"\n{marker}\n{line}\n")


def install_node(state: AppState) -> bool:
    system = platform.system().lower()

    if command_exists("npm") and command_exists("node"):
        state.logs.append("Node.js and npm already available.")
        return True

    if not state.install_node_if_missing:
        state.logs.append("Node.js/npm missing and auto-install disabled.")
        return False

    candidates: list[list[str]] = []

    if system == "linux":
        if command_exists("apt-get"):
            candidates = [
                ["sudo", "apt-get", "update"],
                ["sudo", "apt-get", "install", "-y", "nodejs", "npm"],
            ]
        elif command_exists("dnf"):
            candidates = [["sudo", "dnf", "install", "-y", "nodejs", "npm"]]
        elif command_exists("yum"):
            candidates = [["sudo", "yum", "install", "-y", "nodejs", "npm"]]
        elif command_exists("pacman"):
            candidates = [["sudo", "pacman", "-Sy", "--noconfirm", "nodejs", "npm"]]
        elif command_exists("zypper"):
            candidates = [["sudo", "zypper", "install", "-y", "nodejs", "npm"]]
    elif system == "darwin":
        if command_exists("brew"):
            candidates = [["brew", "install", "node"]]

    if not candidates:
        state.logs.append("Could not find a supported package manager to install Node.js/npm.")
        return False

    for cmd in candidates:
        state.logs.append(f"Running: {' '.join(cmd)}")
        result = run_command(cmd, state=state)
        if result.stdout.strip():
            state.logs.append(result.stdout.strip())
        if result.stderr.strip():
            state.logs.append(result.stderr.strip())
        if result.returncode != 0:
            state.logs.append(f"Command failed with exit code {result.returncode}")
            return False

    ok = command_exists("npm") and command_exists("node")
    state.logs.append("Node.js/npm installed." if ok else "Node.js/npm installation did not succeed.")
    return ok


def npm_install_global(package: str, state: AppState) -> bool:
    cmd = ["npm", "install", "-g", package]
    state.logs.append(f"Running: {' '.join(cmd)}")
    result = run_command(cmd, state=state)
    if result.stdout.strip():
        state.logs.append(result.stdout.strip())
    if result.stderr.strip():
        state.logs.append(result.stderr.strip())
    if result.returncode != 0:
        state.logs.append(f"Install failed for {package}")
        return False
    state.logs.append(f"Installed {package}")
    return True


def validate_openrouter_key(key: str) -> bool:
    if not key.strip():
        return False
    # Simple validation check against OpenRouter models endpoint
    cmd = [
        "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
        "-H", f"Authorization: Bearer {key}",
        "https://openrouter.ai/api/v1/models"
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.stdout.strip() == "200"
    except Exception:
        return False


def save_openrouter_config(state: AppState) -> None:
    if not state.openrouter_api_key:
        return

    config_dir = Path.home() / ".config" / "opencode"
    key_file = config_dir / "openrouter.key"
    
    state.logs.append(f"Configuring OpenRouter in {config_dir}...")
    
    if state.dry_run:
        state.logs.append(f"[DRY-RUN] Would create {key_file} with 600 permissions")
        return

    try:
        config_dir.mkdir(parents=True, exist_ok=True)
        key_file.write_text(state.openrouter_api_key.strip(), encoding="utf-8")
        key_file.chmod(0o600)
        state.logs.append(f"Stored OpenRouter key securely in {key_file}")
    except Exception as e:
        state.logs.append(f"Failed to store OpenRouter key: {e}")


def setup_env_vars(state: AppState) -> None:
    rc_file = state.shell_rc or detect_shell_rc()
    state.shell_rc = rc_file

    backup_file(rc_file, state)

    if state.gemini_api_key:
        append_export_if_missing(rc_file, "GEMINI_API_KEY", state.gemini_api_key, state)
        state.logs.append(f"Stored GEMINI_API_KEY in {rc_file}")

    if state.gemini_model:
        append_export_if_missing(rc_file, "GEMINI_MODEL", state.gemini_model, state)
        state.logs.append(f"Stored GEMINI_MODEL in {rc_file}")

    if state.openai_api_key:
        append_export_if_missing(rc_file, "OPENAI_API_KEY", state.openai_api_key, state)
        state.logs.append(f"Stored OPENAI_API_KEY in {rc_file}")

    if state.openrouter_api_key:
        append_export_if_missing(rc_file, "OPENROUTER_API_KEY", state.openrouter_api_key, state)
        state.logs.append(f"Stored OPENROUTER_API_KEY in {rc_file}")

    if state.yolo_mode:
        state.logs.append("Applying YOLO mode configurations...")
        append_export_if_missing(rc_file, "AIDER_YES", "1", state)
        append_export_if_missing(rc_file, "INTERPRETER_YOLO", "true", state)
        append_export_if_missing(rc_file, "SGPT_DANGEROUS", "true", state)
        
        if rc_file.name != "config.fish":
            line = 'alias interpreter="interpreter --yolo"'
            content = rc_file.read_text(encoding="utf-8") if rc_file.exists() else ""
            if line not in content:
                if state.dry_run:
                    state.logs.append(f"[DRY-RUN] Would add alias to {rc_file}")
                else:
                    with rc_file.open("a", encoding="utf-8") as f:
                        f.write(f"\n# added by {APP_TITLE}\n{line}\n")


def codex_login_with_api_key(state: AppState) -> bool:
    if not state.openai_api_key.strip():
        state.logs.append("No OpenAI API key provided for Codex login.")
        return False

    cmd = ["codex", "login", "--with-api-key"]
    state.logs.append("Running Codex API-key login.")
    result = run_command(cmd, input_text=state.openai_api_key.strip() + "\n", state=state)
    if result.stdout.strip():
        state.logs.append(result.stdout.strip())
    if result.stderr.strip():
        state.logs.append(result.stderr.strip())
    if result.returncode != 0:
        state.logs.append(f"Codex login failed with exit code {result.returncode}")
        return False
    state.logs.append("Codex login completed.")
    return True


def codex_login_browser(state: AppState, device: bool = False) -> bool:
    cmd = ["codex", "login", "--device-auth"] if device else ["codex", "login"]
    state.logs.append(f"Launching: {' '.join(cmd)}")
    if state.dry_run:
        state.logs.append("[DRY-RUN] Would launch Codex login flow.")
        return True
    try:
        subprocess.run(cmd, check=False)
        return True
    except Exception as e:
        state.logs.append(f"Failed to launch Codex login: {e}")
        return False


def refresh_tool_status(state: AppState) -> None:
    for key, tool in state.tools.items():
        path = shutil.which(tool.command)
        if path:
            tool.installed = True
            try:
                cmd = [tool.command] + tool.version_cmd
                result = run_command(cmd)
                output = (result.stdout or result.stderr).strip()
                if output:
                    tool.version = output.split("\n")[0].strip()
                else:
                    tool.version = "Installed"
            except Exception:
                tool.version = "Installed (Version Error)"
        else:
            tool.installed = False
            tool.version = "Not Installed"


def verify_installation(state: AppState) -> None:
    refresh_tool_status(state)
    for key, tool in state.tools.items():
        state.logs.append(f"{tool.name}: {tool.version}")

    if command_exists("codex"):
        result = run_command(["codex", "login", "status"])
        out = "\n".join(x for x in [result.stdout.strip(), result.stderr.strip()] if x).strip()
        state.logs.append(f"codex login status: {out or f'exit={result.returncode}'}")


def select_tools_menu(stdscr, state: AppState):
    selected = 0
    installable_keys = [k for k, v in state.tools.items() if v.install_cmd]

    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        title = "Select Tools to Install"
        stdscr.addstr(1, max(0, (w - len(title)) // 2), title, curses.A_BOLD)

        for idx, key in enumerate(installable_keys):
            tool = state.tools[key]
            attr = curses.A_REVERSE if idx == selected else curses.A_NORMAL
            status = "[X]" if tool.should_install else "[ ]"
            label = f"{status} {tool.name}"
            stdscr.addstr(5 + idx, 4, label[: w - 8], attr)

        stdscr.addstr(h - 2, 4, "Space to toggle, Enter to confirm")
        stdscr.refresh()

        ch = stdscr.getch()
        if ch == curses.KEY_UP:
            selected = (selected - 1) % len(installable_keys)
        elif ch == curses.KEY_DOWN:
            selected = (selected + 1) % len(installable_keys)
        elif ch == ord(" "):
            key = installable_keys[selected]
            state.tools[key].should_install = not state.tools[key].should_install
        elif ch in (10, 13):
            break


def perform_install_and_configure(state: AppState) -> None:
    state.logs.clear()
    state.logs.append("Starting installation and configuration.")
    if state.dry_run:
        state.logs.append("!!! DRY-RUN MODE ENABLED - No changes will be made !!!")

    # Validate OpenRouter key if provided
    if state.openrouter_api_key:
        state.logs.append("Validating OpenRouter API key...")
        if validate_openrouter_key(state.openrouter_api_key):
            state.logs.append("OpenRouter key: VALID")
        else:
            state.logs.append("OpenRouter key: INVALID (Check your key or internet connection)")

    if not install_node(state):
        state.logs.append("Warning: Node.js/npm missing. Some tools may fail to install.")

    for key, tool in state.tools.items():
        if tool.should_install and tool.install_cmd:
            state.logs.append(f"Installing {tool.name}...")
            result = run_command(tool.install_cmd, state=state)
            if result.stdout.strip():
                state.logs.append(result.stdout.strip())
            if result.stderr.strip():
                state.logs.append(result.stderr.strip())
            if result.returncode != 0:
                state.logs.append(f"Failed to install {tool.name}")
            else:
                state.logs.append(f"Successfully installed {tool.name}")

    setup_env_vars(state)
    save_openrouter_config(state)

    if state.tools["codex"].should_install and command_exists("codex"):
        if state.codex_auth_mode == "api_key":
            codex_login_with_api_key(state)
        elif state.codex_auth_mode == "browser":
            codex_login_browser(state, device=False)
        elif state.codex_auth_mode == "device":
            codex_login_browser(state, device=True)

    verify_installation(state)


def draw_box(stdscr, y, x, h, w, title=""):
    stdscr.addstr(y, x, "+" + "-" * (w - 2) + "+")
    for i in range(1, h - 1):
        stdscr.addstr(y + i, x, "|")
        stdscr.addstr(y + i, x + w - 1, "|")
    stdscr.addstr(y + h - 1, x, "+" + "-" * (w - 2) + "+")
    if title:
        title_text = f" {title} "
        if len(title_text) < w - 2:
            stdscr.addstr(y, x + 2, title_text)


def prompt_input(stdscr, title: str, initial: str = "", secret: bool = False) -> str:
    curses.curs_set(1)
    h, w = stdscr.getmaxyx()
    width = min(80, w - 4)
    height = 7
    y = max(0, (h - height) // 2)
    x = max(0, (w - width) // 2)

    value = list(initial)

    while True:
        stdscr.clear()
        draw_box(stdscr, y, x, height, width, title)
        shown = "*" * len(value) if secret else "".join(value)
        stdscr.addstr(y + 2, x + 2, shown[: width - 4])
        stdscr.addstr(y + 4, x + 2, "Enter to save, Esc to cancel, Backspace to delete")
        stdscr.refresh()

        ch = stdscr.getch()
        if ch in (10, 13):
            curses.curs_set(0)
            return "".join(value)
        if ch == 27:
            curses.curs_set(0)
            return initial
        if ch in (curses.KEY_BACKSPACE, 127, 8):
            if value:
                value.pop()
            continue
        if 32 <= ch <= 126:
            value.append(chr(ch))


def wrap_lines(text: str, width: int) -> list[str]:
    lines: list[str] = []
    for raw in text.splitlines() or [""]:
        wrapped = textwrap.wrap(raw, width=width) or [""]
        lines.extend(wrapped)
    return lines


def main_menu(stdscr, state: AppState):
    curses.curs_set(0)
    selected = 0
    curses.start_color()
    curses.init_pair(1, curses.COLOR_GREEN, curses.COLOR_BLACK)
    curses.init_pair(2, curses.COLOR_YELLOW, curses.COLOR_BLACK)

    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()

        items = [
            f"Gemini API key: {'set' if state.gemini_api_key else 'not set'}",
            f"Gemini model: {state.gemini_model or '(default)'}",
            f"OpenAI API key: {'set' if state.openai_api_key else 'not set'}",
            f"OpenRouter API key: {'set' if state.openrouter_api_key else 'not set'}",
            f"Install Node if missing: {'yes' if state.install_node_if_missing else 'no'}",
            "Select Tools to Install",
            f"Codex auth mode: {state.codex_auth_mode}",
            f"Shell profile: {state.shell_rc or detect_shell_rc()}",
            f"Dry-run mode: {'ON' if state.dry_run else 'OFF'}",
            f"YOLO mode: {'ON' if state.yolo_mode else 'OFF'}",
            "Run install and configure",
            "Show Tool Status",
            "Quit",
        ]

        title = APP_TITLE
        stdscr.addstr(1, max(0, (w - len(title)) // 2), title, curses.A_BOLD)
        stdscr.addstr(3, 2, "Use arrows. Enter to edit/select.")

        for idx, item in enumerate(items):
            attr = curses.A_REVERSE if idx == selected else curses.A_NORMAL
            stdscr.addstr(5 + idx, 4, item[: w - 8], attr)

        info = [
            "",
            "Notes:",
            "- Codex API-key login can be automated.",
            "- YOLO mode sets AIDER_YES=1, SGPT_DANGEROUS=true, etc.",
            "- OpenRouter key is validated during installation.",
        ]
        y = 5 + len(items) + 1
        for line in info:
            if y < h - 1:
                stdscr.addstr(y, 2, line[: w - 4])
                y += 1

        stdscr.refresh()
        ch = stdscr.getch()

        if ch == curses.KEY_UP:
            selected = (selected - 1) % len(items)
        elif ch == curses.KEY_DOWN:
            selected = (selected + 1) % len(items)
        elif ch in (10, 13):
            if selected == 0:
                state.gemini_api_key = prompt_input(stdscr, "Gemini API key", state.gemini_api_key, secret=True)
            elif selected == 1:
                state.gemini_model = prompt_input(stdscr, "Gemini model", state.gemini_model, secret=False)
            elif selected == 2:
                state.openai_api_key = prompt_input(stdscr, "OpenAI API key", state.openai_api_key, secret=True)
            elif selected == 3:
                state.openrouter_api_key = prompt_input(stdscr, "OpenRouter API key", state.openrouter_api_key, secret=True)
            elif selected == 4:
                state.install_node_if_missing = not state.install_node_if_missing
            elif selected == 5:
                select_tools_menu(stdscr, state)
            elif selected == 6:
                modes = ["api_key", "browser", "device", "skip"]
                current = modes.index(state.codex_auth_mode)
                state.codex_auth_mode = modes[(current + 1) % len(modes)]
            elif selected == 7:
                current = str(state.shell_rc or detect_shell_rc())
                value = prompt_input(stdscr, "Shell profile path", current, secret=False)
                state.shell_rc = Path(value).expanduser()
            elif selected == 8:
                state.dry_run = not state.dry_run
            elif selected == 9:
                state.yolo_mode = not state.yolo_mode
            elif selected == 10:
                perform_install_and_configure(state)
                show_logs(stdscr, state)
            elif selected == 11:
                show_tool_status(stdscr, state)
            elif selected == 12:
                break


def show_tool_status(stdscr, state: AppState):
    refresh_tool_status(state)
    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        title = "Current Tool Status"
        stdscr.addstr(1, max(0, (w - len(title)) // 2), title, curses.A_BOLD)

        y = 3
        for key, tool in state.tools.items():
            if y >= h - 2:
                break
            status_color = curses.color_pair(1) if tool.installed else curses.color_pair(2)
            stdscr.addstr(y, 4, f"{tool.name:20}: ")
            stdscr.addstr(y, 25, tool.version[: w - 26], status_color)
            y += 1

        help_line = "Press any key to return"
        stdscr.addstr(h - 1, 2, help_line[: w - 4])
        stdscr.refresh()
        stdscr.getch()
        break


def show_logs(stdscr, state: AppState):
    offset = 0
    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        title = "Logs"
        stdscr.addstr(0, max(0, (w - len(title)) // 2), title, curses.A_BOLD)

        wrapped: list[str] = []
        for line in state.logs:
            wrapped.extend(wrap_lines(line, max(20, w - 4)))

        visible = wrapped[offset : offset + h - 3]
        for i, line in enumerate(visible, start=1):
            stdscr.addstr(i, 2, line[: w - 4])

        help_line = "Up/Down scroll, q to return"
        stdscr.addstr(h - 1, 2, help_line[: w - 4])
        stdscr.refresh()

        ch = stdscr.getch()
        if ch == curses.KEY_UP and offset > 0:
            offset -= 1
        elif ch == curses.KEY_DOWN and offset < max(0, len(wrapped) - (h - 3)):
            offset += 1
        elif ch in (ord("q"), ord("Q"), 27):
            break


def curses_main(stdscr):
    state = AppState(shell_rc=detect_shell_rc())
    refresh_tool_status(state)
    main_menu(stdscr, state)


if __name__ == "__main__":
    try:
        curses.wrapper(curses_main)
    except KeyboardInterrupt:
        pass
