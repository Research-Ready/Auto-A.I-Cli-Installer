#!/usr/bin/env python3
from __future__ import annotations
import curses
import os
import sys
from pathlib import Path
import textwrap
from installer_core import AppState, InstallerCore, APP_TITLE

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
            if value: value.pop()
            continue
        if 32 <= ch <= 126: value.append(chr(ch))

def wrap_lines(text: str, width: int) -> list[str]:
    lines: list[str] = []
    for raw in text.splitlines() or [""]:
        wrapped = textwrap.wrap(raw, width=width) or [""]
        lines.extend(wrapped)
    return lines

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
        if ch == curses.KEY_UP: selected = (selected - 1) % len(installable_keys)
        elif ch == curses.KEY_DOWN: selected = (selected + 1) % len(installable_keys)
        elif ch == ord(" "):
            key = installable_keys[selected]
            state.tools[key].should_install = not state.tools[key].should_install
        elif ch in (10, 13): break

def select_model_menu(stdscr, state: AppState, core: InstallerCore):
    if not state.available_models:
        stdscr.clear()
        stdscr.addstr(1, 2, "Fetching models from OpenRouter... please wait.")
        stdscr.refresh()
        if not core.fetch_available_models():
            stdscr.addstr(3, 2, "Failed to fetch models. Check API key and internet.")
            stdscr.addstr(5, 2, "Press any key to return.")
            stdscr.getch()
            return

    selected = 0
    offset = 0
    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        title = "Select OpenRouter Model"
        stdscr.addstr(1, max(0, (w - len(title)) // 2), title, curses.A_BOLD)
        
        visible_count = h - 6
        visible_models = state.available_models[offset : offset + visible_count]
        
        for idx, model in enumerate(visible_models):
            attr = curses.A_REVERSE if idx + offset == selected else curses.A_NORMAL
            label = f"{model['id']} ({model.get('context_length', 'unk')} context)"
            stdscr.addstr(3 + idx, 4, label[: w - 8], attr)
            
        stdscr.addstr(h - 2, 4, "Arrows to scroll, Enter to select, q to cancel")
        stdscr.refresh()
        
        ch = stdscr.getch()
        if ch == curses.KEY_UP:
            if selected > 0:
                selected -= 1
                if selected < offset: offset = selected
        elif ch == curses.KEY_DOWN:
            if selected < len(state.available_models) - 1:
                selected += 1
                if selected >= offset + visible_count: offset = selected - visible_count + 1
        elif ch in (10, 13):
            model_id = state.available_models[selected]["id"]
            stdscr.clear()
            stdscr.addstr(1, 2, f"Testing capabilities for {model_id}...")
            stdscr.addstr(2, 2, "Checking basic request and tool-use compatibility...")
            stdscr.refresh()
            
            results = core.test_model_capabilities(model_id)
            
            stdscr.clear()
            stdscr.addstr(1, 2, f"Capability results for {model_id}:")
            stdscr.addstr(3, 4, f"Basic Request: {'PASSED ✅' if results['request'] else 'FAILED ❌'}")
            stdscr.addstr(4, 4, f"Tool-use:      {'PASSED ✅' if results['tools'] else 'FAILED ❌'}")
            
            if not results["request"]:
                stdscr.addstr(6, 2, "Warning: This model failed basic request test.")
                stdscr.addstr(7, 2, "It may be broken or currently unavailable.")
            
            stdscr.addstr(9, 2, "Press 'y' to select anyway, 'n' to go back.")
            stdscr.refresh()
            
            while True:
                choice = stdscr.getch()
                if choice in (ord('y'), ord('Y')):
                    state.selected_model = model_id
                    return
                if choice in (ord('n'), ord('N')):
                    break
        elif ch == ord("q"):
            break


def main_menu(stdscr, state: AppState, core: InstallerCore):
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
            f"OpenRouter Model: {state.selected_model or '(not selected)'}",
            f"Install Node if missing: {'yes' if state.install_node_if_missing else 'no'}",
            "Select Tools to Install",
            f"Codex auth mode: {state.codex_auth_mode}",
            f"Shell profile: {state.shell_rc or core.detect_shell_rc()}",
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
        info = ["", "Notes:", "- Codex API-key login can be automated.", "- YOLO mode sets AIDER_YES=1, SGPT_DANGEROUS=true, etc.", "- OpenRouter key is validated during installation."]
        y = 5 + len(items) + 1
        for line in info:
            if y < h - 1:
                stdscr.addstr(y, 2, line[: w - 4])
                y += 1
        stdscr.refresh()
        ch = stdscr.getch()
        if ch == curses.KEY_UP: selected = (selected - 1) % len(items)
        elif ch == curses.KEY_DOWN: selected = (selected + 1) % len(items)
        elif ch in (10, 13):
            if selected == 0: state.gemini_api_key = prompt_input(stdscr, "Gemini API key", state.gemini_api_key, secret=True)
            elif selected == 1: state.gemini_model = prompt_input(stdscr, "Gemini model", state.gemini_model, secret=False)
            elif selected == 2: state.openai_api_key = prompt_input(stdscr, "OpenAI API key", state.openai_api_key, secret=True)
            elif selected == 3: state.openrouter_api_key = prompt_input(stdscr, "OpenRouter API key", state.openrouter_api_key, secret=True)
            elif selected == 4: select_model_menu(stdscr, state, core)
            elif selected == 5: state.install_node_if_missing = not state.install_node_if_missing
            elif selected == 6: select_tools_menu(stdscr, state)
            elif selected == 7:
                modes = ["api_key", "browser", "device", "skip"]
                current = modes.index(state.codex_auth_mode)
                state.codex_auth_mode = modes[(current + 1) % len(modes)]
            elif selected == 8:
                current = str(state.shell_rc or core.detect_shell_rc())
                value = prompt_input(stdscr, "Shell profile path", current, secret=False)
                state.shell_rc = Path(value).expanduser()
            elif selected == 9: state.dry_run = not state.dry_run
            elif selected == 10: state.yolo_mode = not state.yolo_mode
            elif selected == 11:
                core.perform_install_and_configure()
                show_logs(stdscr, state)
            elif selected == 12: show_tool_status(stdscr, state, core)
            elif selected == 13: break

def show_tool_status(stdscr, state: AppState, core: InstallerCore):
    core.refresh_tool_status()
    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        title = "Current Tool Status"
        stdscr.addstr(1, max(0, (w - len(title)) // 2), title, curses.A_BOLD)
        y = 3
        for key, tool in state.tools.items():
            if y >= h - 2: break
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
        if ch == curses.KEY_UP and offset > 0: offset -= 1
        elif ch == curses.KEY_DOWN and offset < max(0, len(wrapped) - (h - 3)): offset += 1
        elif ch in (ord("q"), ord("Q"), 27): break

def curses_main(stdscr):
    state = AppState()
    core = InstallerCore(state)
    state.shell_rc = core.detect_shell_rc()
    core.refresh_tool_status()
    main_menu(stdscr, state, core)

if __name__ == "__main__":
    try: curses.wrapper(curses_main)
    except KeyboardInterrupt: pass
