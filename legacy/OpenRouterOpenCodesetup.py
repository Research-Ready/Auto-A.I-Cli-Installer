#!/usr/bin/env python3
"""
OpenCode + OpenRouter setup TUI.

What it does
- Installs OpenCode if it is missing
- Accepts an OpenRouter API key securely
- Queries OpenRouter for free text models
- Prefers free models that support tool calling
- Tests one or more free models with a tiny prompt before saving config
- Writes a global OpenCode config that defaults to the tested free model
- Stores the OpenRouter key in a separate file referenced by OpenCode config

Notes
- This script avoids guessing OpenCode's internal auth.json layout.
- Instead, it uses OpenCode's documented config support for provider options and
  file/env substitutions.

Tested target: Linux/macOS terminals with Python 3.10+.
"""

from __future__ import annotations

import curses
import getpass
import json
import os
import pathlib
import shutil
import subprocess
import textwrap
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any

APP_TITLE = "OpenCode + OpenRouter Setup"
OPENROUTER_MODELS_URL = "https://openrouter.ai/api/v1/models"
OPENROUTER_CHAT_URL = "https://openrouter.ai/api/v1/chat/completions"
CONFIG_DIR = pathlib.Path.home() / ".config" / "opencode"
CONFIG_PATH = CONFIG_DIR / "opencode.json"
KEY_PATH = CONFIG_DIR / "openrouter.key"


@dataclass
class ModelCandidate:
    model_id: str
    name: str
    context_length: int
    supports_tools: bool
    supports_structured: bool
    prompt_price: str
    completion_price: str
    request_price: str

    @property
    def opencode_full_id(self) -> str:
        return f"openrouter/{self.model_id}"


class SetupError(Exception):
    pass


class TUI:
    def __init__(self, stdscr: curses.window):
        self.stdscr = stdscr
        self.height, self.width = self.stdscr.getmaxyx()
        self.log_lines: list[str] = []
        self.status = "Ready"
        self.footer = "Arrows not required. Enter to continue. q to quit when prompted."
        curses.curs_set(0)
        self.stdscr.keypad(True)

    def refresh_size(self) -> None:
        self.height, self.width = self.stdscr.getmaxyx()

    def draw(self) -> None:
        self.refresh_size()
        self.stdscr.erase()
        title = f" {APP_TITLE} "
        self.stdscr.addnstr(0, max(0, (self.width - len(title)) // 2), title, self.width - 1, curses.A_BOLD)
        self.stdscr.hline(1, 0, curses.ACS_HLINE, self.width)

        status_line = f"Status: {self.status}"
        self.stdscr.addnstr(2, 1, status_line, self.width - 2, curses.A_REVERSE)

        top = 4
        bottom = self.height - 3
        visible = max(1, bottom - top)
        lines = self.log_lines[-visible:]
        row = top
        for line in lines:
            wrapped = textwrap.wrap(line, max(10, self.width - 2)) or [""]
            for sub in wrapped:
                if row >= bottom:
                    break
                self.stdscr.addnstr(row, 1, sub, self.width - 2)
                row += 1
            if row >= bottom:
                break

        self.stdscr.hline(self.height - 2, 0, curses.ACS_HLINE, self.width)
        self.stdscr.addnstr(self.height - 1, 1, self.footer, self.width - 2, curses.A_DIM)
        self.stdscr.refresh()

    def log(self, message: str) -> None:
        for line in message.splitlines() or [""]:
            self.log_lines.append(line)
        self.draw()

    def set_status(self, message: str) -> None:
        self.status = message
        self.draw()

    def pause(self, prompt: str = "Press Enter to continue") -> None:
        self.footer = prompt
        self.draw()
        while True:
            ch = self.stdscr.getch()
            if ch in (10, 13, curses.KEY_ENTER):
                break
            if ch in (ord("q"), ord("Q")):
                raise KeyboardInterrupt
        self.footer = "Arrows not required. Enter to continue. q to quit when prompted."
        self.draw()

    def ask_yes_no(self, question: str, default: bool = True) -> bool:
        suffix = "[Y/n]" if default else "[y/N]"
        self.footer = f"{question} {suffix}"
        self.draw()
        while True:
            ch = self.stdscr.getch()
            if ch in (10, 13, curses.KEY_ENTER):
                return default
            if ch in (ord("y"), ord("Y")):
                return True
            if ch in (ord("n"), ord("N")):
                return False
            if ch in (ord("q"), ord("Q")):
                raise KeyboardInterrupt

    def choose_from_list(
        self,
        title: str,
        items: list[str],
        start_index: int = 0,
    ) -> int:
        if not items:
            raise SetupError("No items available to choose from.")

        index = max(0, min(start_index, len(items) - 1))

        while True:
            self.refresh_size()
            self.stdscr.erase()

            header = f" {APP_TITLE} "
            self.stdscr.addnstr(0, max(0, (self.width - len(header)) // 2), header, self.width - 1, curses.A_BOLD)
            self.stdscr.hline(1, 0, curses.ACS_HLINE, self.width)
            self.stdscr.addnstr(2, 1, title, self.width - 2, curses.A_REVERSE)

            top = 4
            bottom = self.height - 3
            visible = max(1, bottom - top)

            start = max(0, index - visible // 2)
            end = min(len(items), start + visible)
            start = max(0, end - visible)

            row = top
            for i in range(start, end):
                prefix = "➜ " if i == index else "  "
                attr = curses.A_BOLD if i == index else curses.A_NORMAL
                self.stdscr.addnstr(row, 1, prefix + items[i], self.width - 2, attr)
                row += 1

            self.stdscr.hline(self.height - 2, 0, curses.ACS_HLINE, self.width)
            footer = "Up/Down to choose, Enter to test, q to quit"
            self.stdscr.addnstr(self.height - 1, 1, footer, self.width - 2, curses.A_DIM)
            self.stdscr.refresh()

            ch = self.stdscr.getch()
            if ch in (curses.KEY_UP, ord("k"), ord("K")):
                index = (index - 1) % len(items)
            elif ch in (curses.KEY_DOWN, ord("j"), ord("J")):
                index = (index + 1) % len(items)
            elif ch in (10, 13, curses.KEY_ENTER):
                self.footer = "Arrows not required. Enter to continue. q to quit when prompted."
                self.draw()
                return index
            elif ch in (ord("q"), ord("Q")):
                raise KeyboardInterrupt


def run_command(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, text=True, capture_output=True, check=False)


def choose_install_command() -> list[str]:
    if shutil.which("npm"):
        return ["npm", "install", "-g", "opencode-ai"]
    if shutil.which("bun"):
        return ["bun", "install", "-g", "opencode-ai"]
    if shutil.which("brew"):
        return ["brew", "install", "opencode"]
    if shutil.which("bash") and shutil.which("curl"):
        return ["bash", "-lc", "curl -fsSL https://opencode.ai/install | bash"]
    raise SetupError(
        "Could not find a supported installer. Install one of: npm, bun, brew, or curl+bash first."
    )


def ensure_opencode_installed(tui: TUI) -> None:
    if shutil.which("opencode"):
        result = run_command(["opencode", "--version"])
        version = (result.stdout or result.stderr).strip() or "installed"
        tui.log(f"OpenCode already present: {version}")
        return

    cmd = choose_install_command()
    tui.log("OpenCode was not found in PATH.")
    tui.log(f"Installing with: {' '.join(cmd)}")
    tui.set_status("Installing OpenCode")
    result = run_command(cmd)
    if result.returncode != 0:
        raise SetupError(
            "Install failed.\n"
            f"Command: {' '.join(cmd)}\n"
            f"STDOUT:\n{result.stdout}\n\nSTDERR:\n{result.stderr}"
        )
    if not shutil.which("opencode"):
        raise SetupError(
            "Installer completed but 'opencode' is still not in PATH. You may need to restart your shell or add npm's global bin directory to PATH."
        )
    tui.log("OpenCode installed successfully.")


def http_json(
    url: str,
    headers: dict[str, str] | None = None,
    data: dict[str, Any] | None = None,
) -> dict[str, Any]:
    body = None
    final_headers = {"Accept": "application/json"}
    if headers:
        final_headers.update(headers)
    if data is not None:
        final_headers["Content-Type"] = "application/json"
        body = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers=final_headers)
    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        payload = exc.read().decode("utf-8", errors="replace")
        raise SetupError(f"HTTP {exc.code} calling {url}:\n{payload}") from exc
    except urllib.error.URLError as exc:
        raise SetupError(f"Network error calling {url}: {exc}") from exc


def is_free_priced(model: dict[str, Any]) -> bool:
    pricing = model.get("pricing", {}) or {}
    prompt = str(pricing.get("prompt", "1"))
    completion = str(pricing.get("completion", "1"))
    request = pricing.get("request")
    request_ok = True if request is None else str(request) == "0"
    return prompt == "0" and completion == "0" and request_ok


def supports_text(model: dict[str, Any]) -> bool:
    arch = model.get("architecture", {}) or {}
    input_modalities = arch.get("input_modalities", []) or []
    output_modalities = arch.get("output_modalities", []) or []
    return "text" in input_modalities and "text" in output_modalities


def extract_candidates(models_payload: dict[str, Any]) -> list[ModelCandidate]:
    candidates: list[ModelCandidate] = []
    for item in models_payload.get("data", []):
        if not is_free_priced(item):
            continue
        if not supports_text(item):
            continue

        model_id = str(item.get("id", "")).strip()
        if not model_id:
            continue

        params = set(item.get("supported_parameters", []) or [])
        candidates.append(
            ModelCandidate(
                model_id=model_id,
                name=str(item.get("name") or model_id),
                context_length=int(item.get("context_length") or 0),
                supports_tools=("tools" in params),
                supports_structured=("response_format" in params or "structured_outputs" in params),
                prompt_price=str((item.get("pricing") or {}).get("prompt", "")),
                completion_price=str((item.get("pricing") or {}).get("completion", "")),
                request_price=str((item.get("pricing") or {}).get("request", "")),
            )
        )

    def sort_key(m: ModelCandidate) -> tuple[int, int, int, str]:
        return (
            0 if m.supports_tools else 1,
            0 if ":free" in m.model_id else 1,
            -m.context_length,
            m.model_id,
        )

    candidates.sort(key=sort_key)
    return candidates


def validate_api_key(api_key: str) -> list[ModelCandidate]:
    models_payload = http_json(
        OPENROUTER_MODELS_URL,
        headers={"Authorization": f"Bearer {api_key}"},
    )
    candidates = extract_candidates(models_payload)

    if not candidates:
        sample = []
        for item in (models_payload.get("data", []) or [])[:10]:
            pricing = item.get("pricing", {}) or {}
            arch = item.get("architecture", {}) or {}
            sample.append(
                {
                    "id": item.get("id"),
                    "prompt": pricing.get("prompt"),
                    "completion": pricing.get("completion"),
                    "request": pricing.get("request"),
                    "input_modalities": arch.get("input_modalities"),
                    "output_modalities": arch.get("output_modalities"),
                }
            )
        raise SetupError(
            "The API key worked, but no free text models were returned from OpenRouter.\n\n"
            "Sample model metadata from the API response:\n"
            f"{json.dumps(sample, indent=2)}"
        )

    return candidates


def test_model(api_key: str, model_id: str) -> str:
    payload = {
        "model": model_id,
        "messages": [
            {"role": "user", "content": "Reply with exactly: OK"}
        ],
        "max_tokens": 8,
        "temperature": 0,
    }
    response = http_json(
        OPENROUTER_CHAT_URL,
        headers={
            "Authorization": f"Bearer {api_key}",
            "HTTP-Referer": "https://localhost/opencode-setup",
            "X-Title": "OpenCode Setup TUI",
        },
        data=payload,
    )

    try:
        content = response["choices"][0]["message"]["content"]
        used_model = response.get("model") or model_id
    except Exception as exc:
        raise SetupError(
            f"Unexpected response while testing model {model_id}:\n{json.dumps(response, indent=2)}"
        ) from exc

    if not str(content).strip():
        raise SetupError(f"Model {model_id} returned an empty response.")

    return str(used_model)


def write_secret_file(api_key: str) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    KEY_PATH.write_text(api_key.strip() + "\n", encoding="utf-8")
    os.chmod(KEY_PATH, 0o600)


def write_opencode_config(model: ModelCandidate) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    config = {
        "$schema": "https://opencode.ai/config.json",
        "provider": {
            "openrouter": {
                "options": {
                    "apiKey": f"{{file:{KEY_PATH.as_posix()}}}"
                }
            }
        },
        "model": model.opencode_full_id,
        "small_model": model.opencode_full_id,
    }
    CONFIG_PATH.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")


def mask_key(key: str) -> str:
    key = key.strip()
    if len(key) <= 8:
        return "*" * len(key)
    return key[:4] + "..." + key[-4:]


def prompt_hidden_input(prompt_text: str) -> str:
    curses.endwin()
    try:
        value = getpass.getpass(prompt_text)
    finally:
        stdscr = curses.initscr()
        curses.noecho()
        curses.cbreak()
        stdscr.keypad(True)
    return value.strip()


def choose_and_test_model(
    tui: TUI,
    api_key: str,
    candidates: list[ModelCandidate],
) -> tuple[ModelCandidate, str]:
    if not candidates:
        raise SetupError("No candidate models available.")

    menu_items = [
        f"{m.model_id} | tools={'yes' if m.supports_tools else 'no'} | context={m.context_length}"
        for m in candidates
    ]

    current_index = 0
    tested_failures: dict[str, str] = {}

    while True:
        tui.set_status("Choose a free model to test")
        selected_index = tui.choose_from_list(
            "Select a model to test",
            menu_items,
            start_index=current_index,
        )
        current_index = selected_index
        model = candidates[selected_index]

        tui.set_status(f"Testing {model.model_id}")
        tui.log(f"Testing {model.model_id} ...")

        try:
            actual_used_model = test_model(api_key, model.model_id)
            tui.log(f"Success with {model.model_id}. OpenRouter reported model: {actual_used_model}")

            keep_model = tui.ask_yes_no(
                f"Use {model.model_id} as the default model?",
                default=True,
            )
            if keep_model:
                return model, actual_used_model

            tui.log(f"Rejected {model.model_id}. You can now choose a different model.")
        except Exception as exc:
            message = str(exc)
            tested_failures[model.model_id] = message
            tui.log(f"Failed: {message}")

            try_again = tui.ask_yes_no(
                "That test failed. Do you want to choose another model?",
                default=True,
            )
            if not try_again:
                joined = "\n\n".join(f"{mid}: {err}" for mid, err in tested_failures.items())
                raise SetupError(f"No model selected.\n\nTest results so far:\n{joined}")

        current_index = (current_index + 1) % len(candidates)


def setup_flow(stdscr: curses.window) -> int:
    tui = TUI(stdscr)
    tui.draw()
    tui.log(
        "This wizard will install OpenCode, validate your OpenRouter key, save it, "
        "let you test free models, and only set a default model after you confirm it."
    )
    tui.pause()

    ensure_opencode_installed(tui)
    tui.pause()

    tui.set_status("Waiting for API key")
    tui.log("You will now enter your OpenRouter API key.")
    tui.log("It will be saved to ~/.config/opencode/openrouter.key with 0600 permissions after validation.")
    tui.pause("Press Enter to enter your API key in the terminal")

    api_key = prompt_hidden_input("OpenRouter API key: ")
    if not api_key:
        raise SetupError("No API key was entered.")
    tui.log(f"Received API key: {mask_key(api_key)}")

    tui.set_status("Validating API key")
    tui.log("Fetching model catalog from OpenRouter and filtering free text models...")
    candidates = validate_api_key(api_key)
    tui.log(f"Found {len(candidates)} free text models.")

    write_secret_file(api_key)
    tui.log(f"Saved API key to: {KEY_PATH}")

    tested_model, actual_used_model = choose_and_test_model(tui, api_key, candidates)

    write_opencode_config(tested_model)

    tui.set_status("Done")
    tui.log("")
    tui.log("Configuration written:")
    tui.log(f"  Key file:    {KEY_PATH}")
    tui.log(f"  Config file: {CONFIG_PATH}")
    tui.log("")
    tui.log(f"Default model set to: {tested_model.opencode_full_id}")
    tui.log(f"OpenRouter test returned: {actual_used_model}")
    tui.log("")
    tui.log("Next steps:")
    tui.log("  1. Run: opencode")
    tui.log("  2. If you want to inspect available models later, run: opencode models openrouter")
    tui.log("  3. If you want a different free model later, edit ~/.config/opencode/opencode.json")
    tui.pause("Setup complete. Press Enter to exit")
    return 0


def main() -> int:
    try:
        return curses.wrapper(setup_flow)
    except KeyboardInterrupt:
        print("\nCancelled.")
        return 130
    except SetupError as exc:
        print("\nERROR:\n")
        print(exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())