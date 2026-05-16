#!/usr/bin/env python3
from __future__ import annotations
import os
import platform
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Dict, Any

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
    selected_model: str = ""
    available_models: List[Dict[str, Any]] = field(default_factory=list)
    install_node_if_missing: bool = True
    shell_rc: Optional[Path] = None
    logs: List[str] = field(default_factory=list)
    dry_run: bool = False
    yolo_mode: bool = False
    codex_auth_mode: str = "api_key"
    tools: Dict[str, ToolInfo] = field(default_factory=lambda: {
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

class InstallerCore:
    def __init__(self, state: AppState):
        self.state = state

    def run_command(
        self,
        cmd: list[str],
        *,
        input_text: Optional[str] = None,
        env: Optional[dict[str, str]] = None,
        check: bool = False,
    ) -> subprocess.CompletedProcess:
        if self.state.dry_run:
            self.state.logs.append(f"[DRY-RUN] Would run: {' '.join(cmd)}")
            return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

        return subprocess.run(
            cmd,
            input=input_text,
            text=True,
            capture_output=True,
            env=env,
            check=check,
        )

    def backup_file(self, file_path: Path) -> None:
        if file_path.exists():
            bak_path = file_path.with_suffix(file_path.suffix + ".bak")
            self.state.logs.append(f"Creating backup: {bak_path}")
            if not self.state.dry_run:
                try:
                    shutil.copy2(file_path, bak_path)
                except Exception as e:
                    self.state.logs.append(f"Backup failed: {e}")

    def detect_shell_rc(self) -> Path:
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

    def append_export_if_missing(self, rc_file: Path, key: str, value: str) -> None:
        rc_file.parent.mkdir(parents=True, exist_ok=True)
        if not rc_file.exists():
            if self.state.dry_run:
                self.state.logs.append(f"[DRY-RUN] Would create {rc_file}")
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

        if self.state.dry_run:
            self.state.logs.append(f"[DRY-RUN] Would append to {rc_file}: {line}")
            return

        with rc_file.open("a", encoding="utf-8") as f:
            f.write(f"\n{marker}\n{line}\n")

    def refresh_tool_status(self) -> None:
        is_mock = os.environ.get("MOCK_DETECTION") == "1"
        for key, tool in self.state.tools.items():
            if is_mock:
                tool.installed = True
                tool.version = "Mock Version 1.0.0"
                continue

            path = shutil.which(tool.command)
            if path:
                tool.installed = True
                try:
                    cmd = [tool.command] + tool.version_cmd
                    result = self.run_command(cmd)
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

    def install_node(self) -> bool:
        system = platform.system().lower()
        if shutil.which("npm") and shutil.which("node"):
            self.state.logs.append("Node.js and npm already available.")
            return True

        if not self.state.install_node_if_missing:
            self.state.logs.append("Node.js/npm missing and auto-install disabled.")
            return False

        candidates: list[list[str]] = []
        if system == "linux":
            if shutil.which("apt-get"):
                candidates = [["sudo", "apt-get", "update"], ["sudo", "apt-get", "install", "-y", "nodejs", "npm"]]
            elif shutil.which("dnf"):
                candidates = [["sudo", "dnf", "install", "-y", "nodejs", "npm"]]
            elif shutil.which("yum"):
                candidates = [["sudo", "yum", "install", "-y", "nodejs", "npm"]]
            elif shutil.which("pacman"):
                candidates = [["sudo", "pacman", "-Sy", "--noconfirm", "nodejs", "npm"]]
            elif shutil.which("zypper"):
                candidates = [["sudo", "zypper", "install", "-y", "nodejs", "npm"]]
        elif system == "darwin":
            if shutil.which("brew"):
                candidates = [["brew", "install", "node"]]

        if not candidates:
            self.state.logs.append("Could not find a supported package manager to install Node.js/npm.")
            return False

        for cmd in candidates:
            self.state.logs.append(f"Running: {' '.join(cmd)}")
            result = self.run_command(cmd)
            if result.stdout.strip(): self.state.logs.append(result.stdout.strip())
            if result.stderr.strip(): self.state.logs.append(result.stderr.strip())
            if result.returncode != 0:
                self.state.logs.append(f"Command failed with exit code {result.returncode}")
                return False

        ok = shutil.which("npm") is not None and shutil.which("node") is not None
        self.state.logs.append("Node.js/npm installed." if ok else "Node.js/npm installation did not succeed.")
        return ok

    def validate_openrouter_key(self, key: str) -> bool:
        if not key.strip(): return False
        cmd = ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "-H", f"Authorization: Bearer {key}", "https://openrouter.ai/api/v1/models"]
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            return result.stdout.strip() == "200"
        except Exception: return False

    def save_openrouter_config(self) -> None:
        if not self.state.openrouter_api_key: return
        config_dir = Path.home() / ".config" / "opencode"
        key_file = config_dir / "openrouter.key"
        self.state.logs.append(f"Configuring OpenRouter in {config_dir}...")
        if self.state.dry_run:
            self.state.logs.append(f"[DRY-RUN] Would create {key_file} with 600 permissions")
            return
        try:
            config_dir.mkdir(parents=True, exist_ok=True)
            key_file.write_text(self.state.openrouter_api_key.strip(), encoding="utf-8")
            key_file.chmod(0o600)
            self.state.logs.append(f"Stored OpenRouter key securely in {key_file}")
        except Exception as e: self.state.logs.append(f"Failed to store OpenRouter key: {e}")

    def setup_env_vars(self) -> None:
        rc_file = self.state.shell_rc or self.detect_shell_rc()
        self.state.shell_rc = rc_file
        self.backup_file(rc_file)
        if self.state.gemini_api_key:
            self.append_export_if_missing(rc_file, "GEMINI_API_KEY", self.state.gemini_api_key)
        if self.state.gemini_model:
            self.append_export_if_missing(rc_file, "GEMINI_MODEL", self.state.gemini_model)
        if self.state.openai_api_key:
            self.append_export_if_missing(rc_file, "OPENAI_API_KEY", self.state.openai_api_key)
        if self.state.openrouter_api_key:
            self.append_export_if_missing(rc_file, "OPENROUTER_API_KEY", self.state.openrouter_api_key)
        if self.state.yolo_mode:
            self.state.logs.append("Applying YOLO mode configurations...")
            self.append_export_if_missing(rc_file, "AIDER_YES", "1")
            self.append_export_if_missing(rc_file, "INTERPRETER_YOLO", "true")
            self.append_export_if_missing(rc_file, "SGPT_DANGEROUS", "true")
            if rc_file.name != "config.fish":
                line = 'alias interpreter="interpreter --yolo"'
                content = rc_file.read_text(encoding="utf-8") if rc_file.exists() else ""
                if line not in content:
                    if self.state.dry_run: self.state.logs.append(f"[DRY-RUN] Would add alias to {rc_file}")
                    else:
                        with rc_file.open("a", encoding="utf-8") as f: f.write(f"\n# added by {APP_TITLE}\n{line}\n")

    def fetch_available_models(self) -> bool:
        key = self.state.openrouter_api_key
        if not key.strip(): return False
        cmd = ["curl", "-s", "-H", f"Authorization: Bearer {key}", "https://openrouter.ai/api/v1/models"]
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                import json
                data = json.loads(result.stdout)
                self.state.available_models = data.get("data", [])
                return True
        except Exception as e:
            self.state.logs.append(f"Error fetching models: {e}")
        return False

    def test_model_capabilities(self, model_id: str) -> Dict[str, bool]:
        key = self.state.openrouter_api_key
        if not key.strip(): return {"request": False, "tools": False}
        
        results = {"request": False, "tools": False}
        import json
        
        # Test 1: Basic Request
        payload = {
            "model": model_id,
            "messages": [{"role": "user", "content": "Ping"}]
        }
        cmd = ["curl", "-s", "-X", "POST", "-H", f"Authorization: Bearer {key}", "-H", "Content-Type: application/json", "-d", json.dumps(payload), "https://openrouter.ai/api/v1/chat/completions"]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0:
                data = json.loads(res.stdout)
                if "choices" in data: results["request"] = True
        except Exception: pass

        # Test 2: Tool-use (function calling)
        tools = [{
            "type": "function",
            "function": {
                "name": "test",
                "parameters": {"type": "object", "properties": {"val": {"type": "string"}}}
            }
        }]
        payload["tools"] = tools
        payload["messages"] = [{"role": "user", "content": "Call the test function with val='hello'"}]
        # Update cmd with new payload
        cmd[-2] = json.dumps(payload)
        
        try:
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0:
                data = json.loads(res.stdout)
                if "choices" in data:
                    msg = data["choices"][0]["message"]
                    if "tool_calls" in msg: results["tools"] = True
        except Exception: pass
        
        return results

    def generate_opencode_config(self) -> None:
        if not self.state.selected_model or not self.state.openrouter_api_key:
            return

        config_dir = Path.home() / ".config" / "opencode"
        config_file = config_dir / "opencode.json"
        
        # Find the selected model metadata
        model_meta = next((m for m in self.state.available_models if m["id"] == self.state.selected_model), None)
        
        config = {
            "provider": {
                "openrouter": {
                    "name": "OpenRouter",
                    "npm": "@ai-sdk/openai-compatible",
                    "options": {
                        "apiKey": "{env:OPENROUTER_API_KEY}",
                        "baseURL": "https://openrouter.ai/api/v1"
                    },
                    "models": {
                        self.state.selected_model: {
                            "limit": {
                                "context": model_meta.get("context_length", 128000) if model_meta else 128000,
                                "output": 4096
                            },
                            "capabilities": {
                                "tool_call": True,
                                "attachments": True
                            }
                        }
                    }
                }
            },
            "compaction": {
                "auto": True,
                "prune": True,
                "reserved": 20000
            }
        }

        self.state.logs.append(f"Generating OpenCode config in {config_file}...")
        if self.state.dry_run:
            self.state.logs.append(f"[DRY-RUN] Would write config to {config_file}")
            return

        try:
            config_dir.mkdir(parents=True, exist_ok=True)
            import json
            config_file.write_text(json.dumps(config, indent=2), encoding="utf-8")
            self.state.logs.append(f"Successfully generated OpenCode config.")
        except Exception as e:
            self.state.logs.append(f"Failed to generate OpenCode config: {e}")

    def perform_install_and_configure(self) -> None:
        self.state.logs.clear()
        self.state.logs.append("Starting installation and configuration.")
        if self.state.dry_run: self.state.logs.append("!!! DRY-RUN MODE ENABLED - No changes will be made !!!")
        if self.state.openrouter_api_key:
            self.state.logs.append("Validating OpenRouter API key...")
            if self.validate_openrouter_key(self.state.openrouter_api_key): self.state.logs.append("OpenRouter key: VALID")
            else: self.state.logs.append("OpenRouter key: INVALID (Check your key or internet connection)")
        self.install_node()
        for key, tool in self.state.tools.items():
            if tool.should_install and tool.install_cmd:
                self.state.logs.append(f"Installing {tool.name}...")
                result = self.run_command(tool.install_cmd)
                if result.stdout.strip(): self.state.logs.append(result.stdout.strip())
                if result.stderr.strip(): self.state.logs.append(result.stderr.strip())
                if result.returncode != 0: self.state.logs.append(f"Failed to install {tool.name}")
                else: self.state.logs.append(f"Successfully installed {tool.name}")
        self.setup_env_vars()
        self.save_openrouter_config()
        self.generate_opencode_config()
        self.refresh_tool_status()
