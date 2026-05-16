import unittest
import os
import shutil
import tempfile
import subprocess
from pathlib import Path
from unittest.mock import patch, MagicMock
from installer_core import AppState, InstallerCore, ToolInfo

class TestInstallerCore(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.state = AppState()
        self.state.shell_rc = Path(self.test_dir) / ".bashrc"
        self.core = InstallerCore(self.state)

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def test_run_command_dry_run(self):
        self.state.dry_run = True
        result = self.core.run_command(["ls"])
        self.assertEqual(result.returncode, 0)
        self.assertIn("[DRY-RUN] Would run: ls", self.state.logs)

    @patch("subprocess.run")
    def test_run_command_real(self, mock_run):
        self.state.dry_run = False
        mock_run.return_value = MagicMock(returncode=0, stdout="out", stderr="")
        result = self.core.run_command(["ls"])
        self.assertEqual(result.returncode, 0)
        mock_run.assert_called_once()

    def test_backup_file(self):
        test_file = Path(self.test_dir) / "test.txt"
        test_file.write_text("hello")
        self.core.backup_file(test_file)
        bak_file = Path(self.test_dir) / "test.txt.bak"
        self.assertTrue(bak_file.exists())
        self.assertEqual(bak_file.read_text(), "hello")

    def test_append_export_if_missing(self):
        rc_file = Path(self.test_dir) / ".bashrc"
        self.core.append_export_if_missing(rc_file, "TEST_KEY", "test_value")
        content = rc_file.read_text()
        self.assertIn('export TEST_KEY="test_value"', content)

        # Test duplicate
        self.core.append_export_if_missing(rc_file, "TEST_KEY", "test_value")
        self.assertEqual(content.count('export TEST_KEY="test_value"'), 1)

    @patch("shutil.which")
    @patch("installer_core.InstallerCore.run_command")
    def test_refresh_tool_status_installed(self, mock_run, mock_which):
        mock_which.return_value = "/usr/bin/node"
        mock_run.return_value = MagicMock(stdout="v14.17.0", stderr="")
        self.core.refresh_tool_status()
        self.assertTrue(self.state.tools["node"].installed)
        self.assertEqual(self.state.tools["node"].version, "v14.17.0")

    @patch("shutil.which")
    def test_refresh_tool_status_missing(self, mock_which):
        mock_which.return_value = None
        self.core.refresh_tool_status()
        self.assertFalse(self.state.tools["node"].installed)
        self.assertEqual(self.state.tools["node"].version, "Not Installed")

    def test_mock_detection(self):
        with patch.dict(os.environ, {"MOCK_DETECTION": "1"}):
            self.core.refresh_tool_status()
            for tool in self.state.tools.values():
                self.assertTrue(tool.installed)
                self.assertEqual(tool.version, "Mock Version 1.0.0")

    @patch("shutil.which")
    def test_install_node_already_present(self, mock_which):
        mock_which.side_effect = lambda x: "/usr/bin/" + x
        result = self.core.install_node()
        self.assertTrue(result)
        self.assertIn("Node.js and npm already available.", self.state.logs)

    @patch("subprocess.run")
    def test_validate_openrouter_key(self, mock_run):
        mock_run.return_value = MagicMock(stdout="200")
        result = self.core.validate_openrouter_key("test_key")
        self.assertTrue(result)

    def test_save_openrouter_config(self):
        self.state.openrouter_api_key = "test_key"
        with patch("pathlib.Path.home", return_value=Path(self.test_dir)):
            self.core.save_openrouter_config()
            config_file = Path(self.test_dir) / ".config" / "opencode" / "openrouter.key"
            self.assertTrue(config_file.exists())
            self.assertEqual(config_file.read_text(), "test_key")

    def test_setup_env_vars(self):
        self.state.gemini_api_key = "gemini_key"
        self.state.openai_api_key = "openai_key"
        self.core.setup_env_vars()
        content = self.state.shell_rc.read_text()
        self.assertIn('export GEMINI_API_KEY="gemini_key"', content)
        self.assertIn('export OPENAI_API_KEY="openai_key"', content)

    def test_yolo_mode_env_vars(self):
        self.state.yolo_mode = True
        self.core.setup_env_vars()
        content = self.state.shell_rc.read_text()
        self.assertIn('export AIDER_YES="1"', content)
        self.assertIn('export SGPT_DANGEROUS="true"', content)
        self.assertIn('alias interpreter="interpreter --yolo"', content)

    @patch("subprocess.run")
    def test_fetch_available_models(self, mock_run):
        self.state.openrouter_api_key = "test_key"
        mock_run.return_value = MagicMock(returncode=0, stdout='{"data": [{"id": "model-1", "context_length": 8192}]}')
        result = self.core.fetch_available_models()
        self.assertTrue(result)
        self.assertEqual(len(self.state.available_models), 1)
        self.assertEqual(self.state.available_models[0]["id"], "model-1")

    def test_generate_opencode_config(self):
        self.state.openrouter_api_key = "test_key"
        self.state.selected_model = "model-1"
        self.state.available_models = [{"id": "model-1", "context_length": 8192}]
        
        with patch("pathlib.Path.home", return_value=Path(self.test_dir)):
            self.core.generate_opencode_config()
            config_file = Path(self.test_dir) / ".config" / "opencode" / "opencode.json"
            self.assertTrue(config_file.exists())
            
            import json
            config_data = json.loads(config_file.read_text())
            self.assertIn("provider", config_data)
            self.assertIn("openrouter", config_data["provider"])
            self.assertEqual(config_data["provider"]["openrouter"]["models"]["model-1"]["limit"]["context"], 8192)

    def test_perform_install_and_configure_dry_run(self):
        self.state.dry_run = True
        self.core.perform_install_and_configure()
        self.assertIn("!!! DRY-RUN MODE ENABLED - No changes will be made !!!", self.state.logs)
