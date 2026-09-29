#!/usr/bin/env python3
"""Test generated hooks and their presence in real IPK control archives."""
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("hooks", REPO / "scripts/write-desktop-cache-hooks.py")
HOOKS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HOOKS)


class DesktopHooks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tdvp-desktop-hooks-")
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.payload = self.work / "payload"
        self.control = self.work / "control"
        self.payload.mkdir()
        self.control.mkdir()

    def resources(self):
        for relative in ("icons/hicolor/index.theme", "icons/hicolor/48x48/apps/test.png",
                         "applications/test.desktop", "mime/packages/test.xml"):
            path = self.payload / "usr/share" / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture\n")

    def run_hook(self, name, action, offline=None, fail=False):
        # Map only the immutable absolute resource prefix into a sandbox; the
        # generated action/offline guards and tool calls are executed unchanged.
        hook = self.work / "run-hook"
        hook.write_text((self.control / name).read_text().replace("/usr/share/", str(self.payload / "usr/share") + "/"))
        tools = self.work / "tools"
        tools.mkdir(exist_ok=True)
        log = self.work / "calls"
        for tool in ("gtk-update-icon-cache", "update-desktop-database", "update-mime-database"):
            path = tools / tool
            path.write_text('#!/bin/sh\nprintf "%s\\n" "$0 $*" >> "$TEST_LOG"\nexit ' + ("7" if fail else "0") + "\n")
            path.chmod(0o755)
        env = dict(os.environ, PATH=str(tools) + ":/usr/bin:/bin", TEST_LOG=str(log), PKG_ROOT=offline or "/")
        env.pop("IPKG_INSTROOT", None)
        result = subprocess.run(["sh", str(hook), action], env=env, capture_output=True, text=True)
        return result, log.read_text() if log.exists() else ""

    def test_cli_only_package_has_no_hooks(self):
        HOOKS.write_hooks(self.payload, self.control)
        self.assertEqual(list(self.control.iterdir()), [])

    def test_install_remove_refresh_all_declared_resources(self):
        self.resources()
        HOOKS.write_hooks(self.payload, self.control)
        for name, action in (("postinst", "configure"), ("postrm", "remove")):
            result, calls = self.run_hook(name, action)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("gtk-update-icon-cache -f -t", calls)
            self.assertIn("update-desktop-database", calls)
            self.assertIn("update-mime-database", calls)
            self.assertEqual((self.control / name).stat().st_mode & 0o777, 0o755)

    def test_offline_and_unrelated_actions_do_not_touch_host(self):
        self.resources()
        HOOKS.write_hooks(self.payload, self.control)
        for name, action, offline in (("postinst", "configure", "/offline"),
                                      ("postinst", "abort-upgrade", None),
                                      ("postrm", "upgrade", None)):
            result, calls = self.run_hook(name, action, offline)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(calls, "")

    def test_tool_failure_is_visible_for_retry(self):
        self.resources()
        HOOKS.write_hooks(self.payload, self.control)
        result, _ = self.run_hook("postinst", "configure", fail=True)
        self.assertEqual(result.returncode, 7)

    def test_existing_scripts_are_not_silently_overwritten(self):
        self.resources()
        (self.control / "postinst").write_text("existing\n")
        with self.assertRaises(ValueError):
            HOOKS.write_hooks(self.payload, self.control)
        self.assertEqual((self.control / "postinst").read_text(), "existing\n")

    def test_real_ipk_contains_executable_hooks(self):
        self.resources()
        recipe = self.work / "recipe"
        recipe.mkdir()
        self.payload.rename(recipe / "root")
        (recipe / "package.env").write_text(
            "PACKAGE='desktop-fixture'\nVERSION='1-1'\nPACKAGE_ARCH='riscv64'\n"
            "MAINTAINER='TDVP Test'\nDESCRIPTION='Desktop fixture'\nSUPPORTED_PLATFORMS='tdvp-k230-r1'\n")
        output = self.work / "feed"
        env = {key: value for key, value in os.environ.items() if not key.startswith("TDVP_")}
        result = subprocess.run(["bash", str(REPO / "scripts/build-ipk.sh"), "--platform", "tdvp-k230-r1",
                                 str(recipe), str(output)], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        data = subprocess.check_output(["ar", "p", str(next(output.glob("*.ipk"))), "control.tar.gz"])
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
            for name in ("./postinst", "./postrm"):
                self.assertEqual(archive.getmember(name).mode, 0o755)
                self.assertIn(b"gtk-update-icon-cache", archive.extractfile(name).read())


if __name__ == "__main__":
    unittest.main(verbosity=2)
