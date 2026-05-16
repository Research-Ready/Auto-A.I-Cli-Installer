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


APP_TITLE = "Gemini + Codex CLI Installer"
GEMINI_NPM_PACKAGE = "@google/gemini-cli"
CODEX_NPM_PACKAGE = "@openai/codex"


@dataclass
class AppState:
    gemini_api_key: str = ""
    gemini_model: str = ""
    openai_api_key: str = ""
    install_node_if_missing: bool = True
    install_gemini: bool = True
    install_codex: bool = True
    codex_auth_mode: str = "api_key"  # api_key | browser | device | skip
    shell_rc: Optional[Path] = None
    logs: List[str] = field(default_factory=list)


def run_command(
    cmd: list[str],
    *,
    input_text: Optional[str] = None,
    env: Optional[dict[str, str]] = None,
    check: bool = False,
) -> subprocess.CompletedProcess:
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
            # Common on macOS bash setups
            return home / ".bash_profile" if (home / ".bash_profile").exists() else home / ".bashrc"
        return home / ".bashrc"
    if shell.endswith("fish"):
        return home / ".config" / "fish" / "config.fish"

    # Safe default
    return home / ".bashrc"


def append_export_if_missing(rc_file: Path, key: str, value: str) -> None:
    rc_file.parent.mkdir(parents=True, exist_ok=True)
    if not rc_file.exists():
        rc_file.touch()

    content = rc_file.read_text(encoding="utf-8")
    marker = f"# added by {APP_TITLE}"

    if rc_file.name == "config.fish":
        line = f'set -gx {key} "{value}"'
    else:
        line = f'export {key}="{value}"'

    if f"{key}=" in content or line in content:
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
        result = run_command(cmd)
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
    result = run_command(cmd)
    if result.stdout.strip():
        state.logs.append(result.stdout.strip())
    if result.stderr.strip():
        state.logs.append(result.stderr.strip())
    if result.returncode != 0:
        state.logs.append(f"Install failed for {package}")
        return False
    state.logs.append(f"Installed {package}")
    return True


def setup_env_vars(state: AppState) -> None:
    rc_file = state.shell_rc or detect_shell_rc()
    state.shell_rc = rc_file

    if state.gemini_api_key:
        append_export_if_missing(rc_file, "GEMINI_API_KEY", state.gemini_api_key)
        state.logs.append(f"Stored GEMINI_API_KEY in {rc_file}")

    if state.gemini_model:
        append_export_if_missing(rc_file, "GEMINI_MODEL", state.gemini_model)
        state.logs.append(f"Stored GEMINI_MODEL in {rc_file}")

    if state.openai_api_key:
        append_export_if_missing(rc_file, "OPENAI_API_KEY", state.openai_api_key)
        state.logs.append(f"Stored OPENAI_API_KEY in {rc_file}")


def codex_login_with_api_key(state: AppState) -> bool:
    if not state.openai_api_key.strip():
        state.logs.append("No OpenAI API key provided for Codex login.")
        return False

    cmd = ["codex", "login", "--with-api-key"]
    state.logs.append("Running Codex API-key login.")
    result = run_command(cmd, input_text=state.openai_api_key.strip() + "\n")
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
    state.logs.append("This hands control to the official Codex login flow.")
    try:
        subprocess.run(cmd, check=False)
        return True
    except Exception as e:
        state.logs.append(f"Failed to launch Codex login: {e}")
        return False


def verify_installation(state: AppState) -> None:
    for name in ["node", "npm", "gemini", "codex"]:
        path = shutil.which(name)
        if path:
            state.logs.append(f"{name}: OK -> {path}")
        else:
            state.logs.append(f"{name}: not found")

    if command_exists("gemini"):
        result = run_command(["gemini", "--version"])
        out = (result.stdout or result.stderr).strip()
        state.logs.append(f"gemini --version: {out or 'no version output'}")

    if command_exists("codex"):
        result = run_command(["codex", "--version"])
        out = (result.stdout or result.stderr).strip()
        state.logs.append(f"codex --version: {out or 'no version output'}")

        result = run_command(["codex", "login", "status"])
        out = "\n".join(x for x in [result.stdout.strip(), result.stderr.strip()] if x).strip()
        state.logs.append(f"codex login status: {out or f'exit={result.returncode}'}")


def perform_install_and_configure(state: AppState) -> None:
    state.logs.clear()
    state.logs.append("Starting installation and configuration.")

    if not install_node(state):
        state.logs.append("Stopping because Node.js/npm is required.")
        return

    if state.install_gemini:
        npm_install_global(GEMINI_NPM_PACKAGE, state)

    if state.install_codex:
        npm_install_global(CODEX_NPM_PACKAGE, state)

    setup_env_vars(state)

    if state.install_codex and command_exists("codex"):
        if state.codex_auth_mode == "api_key":
            codex_login_with_api_key(state)
        elif state.codex_auth_mode == "browser":
            codex_login_browser(state, device=False)
        elif state.codex_auth_mode == "device":
            codex_login_browser(state, device=True)
        else:
            state.logs.append("Skipped Codex login.")

    state.logs.append("")
    state.logs.append("Gemini note:")
    state.logs.append("If you set GEMINI_API_KEY, start `gemini` and choose the API key flow if prompted.")
    state.logs.append("If you prefer Google sign-in, just run `gemini` and complete the official browser login.")

    verify_installation(state)
    state.logs.append("")
    if state.shell_rc:
        state.logs.append(f"Reload your shell with: source {state.shell_rc}")


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

    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()

        items = [
            f"Gemini API key: {'set' if state.gemini_api_key else 'not set'}",
            f"Gemini model: {state.gemini_model or '(default)'}",
            f"OpenAI API key: {'set' if state.openai_api_key else 'not set'}",
            f"Install Node if missing: {'yes' if state.install_node_if_missing else 'no'}",
            f"Install Gemini CLI: {'yes' if state.install_gemini else 'no'}",
            f"Install Codex CLI: {'yes' if state.install_codex else 'no'}",
            f"Codex auth mode: {state.codex_auth_mode}",
            f"Shell profile: {state.shell_rc or detect_shell_rc()}",
            "Run install and configure",
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
            "- Gemini is configured via env vars here.",
            "- Google-account Gemini sign-in remains interactive inside `gemini`.",
        ]
        y = 17
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
                state.install_node_if_missing = not state.install_node_if_missing
            elif selected == 4:
                state.install_gemini = not state.install_gemini
            elif selected == 5:
                state.install_codex = not state.install_codex
            elif selected == 6:
                modes = ["api_key", "browser", "device", "skip"]
                current = modes.index(state.codex_auth_mode)
                state.codex_auth_mode = modes[(current + 1) % len(modes)]
            elif selected == 7:
                current = str(state.shell_rc or detect_shell_rc())
                value = prompt_input(stdscr, "Shell profile path", current, secret=False)
                state.shell_rc = Path(value).expanduser()
            elif selected == 8:
                perform_install_and_configure(state)
                show_logs(stdscr, state)
            elif selected == 9:
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
    main_menu(stdscr, state)


if __name__ == "__main__":
    try:
        curses.wrapper(curses_main)
    except KeyboardInterrupt:
        pass
