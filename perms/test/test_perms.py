"""Tests for ~/.local/bin/perms and perms-filed: rule logic, generated configs, parsers.
Run from the repo root:  python3 -B -m unittest discover -s perms/test
Nothing here touches the live session: generated text is compared, files go to a temp dir."""
import importlib.machinery
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]


def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


perms = load("perms", REPO / "scripts/.local/bin/perms")
filed = load("perms_filed", REPO / "perms/stage/usr/local/bin/perms-filed")


def rules(**changes):
    r = perms.default_rules()
    for perm, value in changes.items():
        r[perm].update(value)
    return r


class Rules(unittest.TestCase):
    def test_app_key_is_lowercase_basename(self):
        self.assertEqual(perms.app_key("/opt/discord/Discord"), "discord")
        self.assertEqual(perms.app_key("Signal-Desktop\n"), "signal-desktop")

    def test_default_is_allow(self):
        self.assertEqual(perms.effective(rules(), "mic", "discord"), "allow")

    def test_explicit_block(self):
        r = rules(mic={"apps": {"spotify": "block"}})
        self.assertEqual(perms.effective(r, "mic", "Spotify"), "block")
        self.assertEqual(perms.effective(r, "mic", "discord"), "allow")

    def test_global_off_wins_over_allow(self):
        r = rules(mic={"on": False, "apps": {"discord": "allow"}})
        self.assertEqual(perms.effective(r, "mic", "discord"), "block")

    def test_system_always_allowed(self):
        r = rules(mic={"on": False})
        self.assertEqual(perms.effective(r, "mic", "easyeffects"), "allow")

    def test_load_rules_drops_bad_modes_and_normalises_keys(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "rules.json"
            f.write_text(json.dumps({"mic": {"on": False, "apps": {"Spotify": "block", "x": "maybe"}}}))
            with mock.patch.object(perms, "RULES_FILE", f):
                r = perms.load_rules()
        self.assertEqual(r["mic"], {"on": False, "apps": {"spotify": "block"}})
        self.assertEqual(r["clipboard"], {"on": True, "apps": {}})

    def test_ci_regex(self):
        self.assertEqual(perms.ci_regex("ab-1"), "[aA][bB]-1")
        self.assertEqual(perms.literal_regex("g++.x"), "g[+][+][.]x")
        self.assertNotIn("\\", perms.render_wireplumber(rules(mic={"on": False, "apps": {"a.b": "block"}})))


class WirePlumber(unittest.TestCase):
    def test_nothing_blocked_means_no_file(self):
        self.assertIsNone(perms.render_wireplumber(rules(mic={"apps": {"discord": "allow"}})))

    def test_clipboard_rules_do_not_reach_wireplumber(self):
        self.assertIsNone(perms.render_wireplumber(rules(clipboard={"on": False})))

    def test_one_app_mic_block(self):
        text = perms.render_wireplumber(rules(mic={"apps": {"spotify": "block"}}))
        self.assertIn('name = "perms-block-mic"', text)
        self.assertIn('media.class = "~Audio/Source.*"', text)
        self.assertIn('application.process.binary = "~^[sS][pP][oO][tT][iI][fF][yY]$"', text)
        self.assertIn('permission_manager_name = "perms-block-mic"', text)
        self.assertNotIn("xdph", text)

    def test_app_blocked_for_both_gets_combined_manager(self):
        text = perms.render_wireplumber(rules(mic={"apps": {"discord": "block"}}, screen={"apps": {"discord": "block"}}))
        self.assertIn('name = "perms-block-mic-screen"', text)
        self.assertIn('node.name = "~xdph-streaming-.*"', text)
        self.assertIn('pipewire.access.portal.app_id = "~^[dD][iI][sS][cC][oO][rR][dD]$"', text)

    def test_global_off_catch_all_comes_first(self):
        text = perms.render_wireplumber(rules(mic={"on": False}, screen={"apps": {"obs": "block"}}))
        catch_all = text.index('"!~^(')
        obs = text.index("[oO][bB][sS]")
        self.assertLess(catch_all, obs)
        self.assertIn("wireplumber", text[catch_all:obs])
        # obs: mic is off globally and its screen is blocked, so both
        self.assertIn('permission_manager_name = "perms-block-mic-screen"', text[obs:])


class Hyprland(unittest.TestCase):
    def test_enforcement_and_portal_allowed_by_default(self):
        text = perms.render_hyprland(rules())
        self.assertIn("enforce_permissions = true", text)
        self.assertIn('binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", type = "screencopy", mode = "allow"', text)
        self.assertIn('binary = ".*/[gG][rR][iI][mM]", type = "screencopy", mode = "allow"', text)

    def test_global_off_denies_portal_and_tools_but_not_the_session(self):
        text = perms.render_hyprland(rules(screen={"on": False}))
        self.assertIn('xdg-desktop-portal-hyprland", type = "screencopy", mode = "deny"', text)
        self.assertIn('[gG][rR][iI][mM]", type = "screencopy", mode = "deny"', text)
        for binary in ("/usr/bin/quickshell", "/usr/bin/hyprlock", "/usr/bin/hyprland-share-picker"):
            self.assertIn(f'binary = "{binary}", type = "screencopy", mode = "allow"', text)

    def test_per_app_rule(self):
        text = perms.render_hyprland(rules(screen={"apps": {"obs": "block", "kooha": "allow"}}))
        self.assertIn('[oO][bB][sS]", type = "screencopy", mode = "deny"', text)
        self.assertIn('[kK][oO][oO][hH][aA]", type = "screencopy", mode = "allow"', text)


DESKTOP = """[Desktop Entry]
Name=Discord
Exec=/usr/bin/discord %U
Type=Application

[Desktop Action new]
Exec=env FOO=1 /usr/bin/discord --new
"""


class Desktop(unittest.TestCase):
    def test_exec_app(self):
        self.assertEqual(perms.desktop_exec_app(DESKTOP), "discord")
        self.assertEqual(perms.desktop_exec_app("[Desktop Entry]\nExec=env A=1 B=2 firefox %u\n"), "firefox")
        self.assertIsNone(perms.desktop_exec_app("[Other]\nExec=x\n"))

    def test_wrap_every_exec_and_mark(self):
        text = perms.wrap_desktop(DESKTOP, "discord")
        self.assertIn(f"Exec={perms.SELF} run --app discord /usr/bin/discord %U", text)
        self.assertIn(f"Exec={perms.SELF} run --app discord env FOO=1 /usr/bin/discord --new", text)
        self.assertIn(f"{perms.OVERRIDE_KEY}=true", text)
        self.assertEqual(perms.wrap_desktop(text, "discord").count("perms run"), 2)

    def test_sync_writes_and_removes_only_ours(self):
        with tempfile.TemporaryDirectory() as d:
            system, user = Path(d, "sys"), Path(d, "user")
            system.mkdir()
            user.mkdir()
            (system / "discord.desktop").write_text(DESKTOP)
            (system / "firefox.desktop").write_text("[Desktop Entry]\nExec=firefox %u\n")
            (user / "firefox.desktop").write_text("[Desktop Entry]\nExec=firefox --mine\n")   # the user's own
            with mock.patch.object(perms, "APPS_DIR", user), mock.patch.object(perms, "SYSTEM_APPS_DIRS", (system,)), \
                 mock.patch.object(perms.shutil, "which", return_value=None):
                perms.sync_desktop_overrides(rules(clipboard={"on": False}))
                self.assertTrue(perms.is_our_override(user / "discord.desktop"))
                self.assertIn("--mine", (user / "firefox.desktop").read_text())
                perms.sync_desktop_overrides(rules())
                self.assertFalse((user / "discord.desktop").exists())
                self.assertTrue((user / "firefox.desktop").exists())


class Run(unittest.TestCase):
    def test_program_of(self):
        self.assertEqual(perms.program_of(["env", "A=1", "discord", "--x"]), "discord")
        self.assertEqual(perms.program_of(["A=1", "/usr/bin/firefox"]), "/usr/bin/firefox")
        self.assertIsNone(perms.program_of([]))

    class Exec(Exception):
        """exec never returns: the mocks raise this to stop cmd_run the same way"""

    def run_gate(self, argv, r):
        calls = []

        def fake(kind):
            def call(path, args):
                calls.append((kind, args))
                raise self.Exec()
            return call
        with mock.patch.object(perms, "load_rules", return_value=r), \
             mock.patch.object(perms.os, "execv", side_effect=fake("execv")), \
             mock.patch.object(perms.os, "execvp", side_effect=fake("execvp")), \
             mock.patch.object(perms.os, "access", return_value=True), \
             mock.patch.dict(perms.os.environ, {}, clear=False):
            perms.os.environ.pop("PERMS_SANDBOX", None)
            with self.assertRaises(self.Exec):
                perms.cmd_run(argv)
        return calls[0]

    def test_allowed_app_runs_plain(self):
        self.assertEqual(self.run_gate(["firefox", "%u"], rules()), ("execvp", ["firefox", "%u"]))

    def test_blocked_app_runs_in_sandbox(self):
        kind, argv = self.run_gate(["/usr/bin/discord"], rules(clipboard={"apps": {"discord": "block"}}))
        self.assertEqual((kind, argv[1:]), ("execv", ["discord", "/usr/bin/discord"]))

    def test_app_flag_names_the_rule(self):
        kind, argv = self.run_gate(["--app", "discord", "env", "X=1", "/opt/discord/Discord"], rules(clipboard={"on": False}))
        self.assertEqual(argv[1], "discord")

    def test_nested_perms_passes_through(self):
        kind, argv = self.run_gate([perms.SELF, "run", "--app", "x", "x"], rules(clipboard={"on": False}))
        self.assertEqual((kind, argv[0]), ("execvp", perms.SELF))


def node(id, cls, state="running", **props):
    return {"id": id, "type": "PipeWire:Interface:Node", "info": {"state": state, "props": {"media.class": cls, **props}}}


def client(id, binary, name):
    return {"id": id, "type": "PipeWire:Interface:Client",
            "info": {"props": {"application.process.binary": binary, "application.name": name}}}


def link(out, inp):
    return {"id": 900 + out, "type": "PipeWire:Interface:Link", "info": {"output-node-id": out, "input-node-id": inp}}


class Live(unittest.TestCase):
    def test_mic_streams(self):
        dump = [client(1, "Discord", "Discord"), client(2, "pavucontrol", "pavucontrol"), client(3, "spotify", "Spotify"),
                node(10, "Stream/Input/Audio", **{"client.id": 1}),
                node(11, "Stream/Input/Audio", **{"client.id": 2, "media.name": "Peak detect"}),
                node(12, "Stream/Input/Audio", state="suspended", **{"client.id": 3}),
                node(13, "Stream/Input/Audio", **{"client.id": 4, "application.process.binary": "easyeffects"})]
        use = perms.live_use(perms.pw_graph(dump))
        self.assertEqual(use["mic"], {"discord": "Discord"})

    def test_screen_share_follows_the_link(self):
        dump = [client(1, "Discord", "Discord"),
                node(20, "Video/Source", **{"node.name": "xdph-streaming-1"}),
                node(21, "Stream/Input/Video", **{"client.id": 1}),
                node(30, "Video/Source", **{"node.name": "v4l2_input.cam"}),
                node(31, "Stream/Input/Video", **{"application.process.binary": "obs", "application.name": "OBS"}),
                link(20, 21), link(30, 31)]
        use = perms.live_use(perms.pw_graph(dump))
        self.assertEqual(use["screen"], {"discord": "Discord"})
        self.assertEqual(use["camera"], {"obs": "OBS"})

    def test_unlinked_portal_stream_still_shows(self):
        use = perms.live_use(perms.pw_graph([node(20, "Video/Source", **{"node.name": "xdph-streaming-1"})]))
        self.assertEqual(list(use["screen"]), ["?"])

    def test_record_seen_throttles_and_prunes(self):
        with tempfile.TemporaryDirectory() as d, mock.patch.object(perms, "SEEN_FILE", Path(d, "seen.json")):
            perms.save_json(perms.SEEN_FILE, {"mic": {"old": {"last": 1, "name": "Old"}}})
            seen = perms.record_seen({"mic": {"discord": "Discord"}, "screen": {"?": "x"}}, now=10_000_000)
            self.assertEqual(seen["mic"], {"discord": {"last": 10_000_000, "name": "Discord"}})
            self.assertNotIn("?", seen.get("screen", {}))
            seen = perms.record_seen({"mic": {"discord": "Discord"}}, now=10_000_030)
            self.assertEqual(seen["mic"]["discord"]["last"], 10_000_000)

    def test_parse_ss(self):
        text = ('udp 0 0 [2406::1]:39545 [2600:1901::]:443 users:(("spotify",pid=32316,fd=28))\n'
                'tcp 0 0 192.168.0.111:50138 18.97.36.5:443 users:(("claude-desktop",pid=32769,fd=45))\n'
                'tcp 0 0 192.168.0.111:50139 18.97.36.5:443 users:(("claude-desktop",pid=32769,fd=46))\n'
                'tcp 0 0 192.168.0.111:50140 1.1.1.1:443 users:(("claude-desktop",pid=32769,fd=47))\n'
                'tcp 0 0 127.0.0.1:1 127.0.0.1:2\n')
        self.assertEqual(perms.parse_ss(text), {"spotify": {"connections": 1, "remotes": 1},
                                                "claude-desktop": {"connections": 3, "remotes": 2}})

    def test_bar_line(self):
        self.assertEqual(perms.bar_line({"mic": {}, "screen": {}, "camera": {}})["class"], "idle")
        line = perms.bar_line({"mic": {"discord": "Discord"}, "screen": {"obs": "OBS"}, "camera": {}})
        self.assertEqual(line["class"], ["active", "mic", "screen"])
        self.assertEqual(line["tooltip"], "Microphone: Discord\nScreen sharing: OBS")


FOLDER_CASES = {
    "/h/u/.ssh/id_ed25519": "~/.ssh",
    "/h/u/Documents/a/b.pdf": "~/Documents",
    "/h/u/.config/discord/Local Storage/x": "~/.config/discord",
    "/h/u/.local/share/Steam/a/b": "~/.local/share/Steam",
    "/h/u/.config/user-dirs.dirs": "~/.config",
    "/h/u/notes.txt": "~",
    "/h/other/x": None,
}


class Folders(unittest.TestCase):
    def test_perms_and_filed_agree(self):
        for path, want in FOLDER_CASES.items():
            with self.subTest(path=path):
                self.assertEqual(perms.folder_key(path, "/h/u"), want)
                self.assertEqual(filed.folder_key(path, "/h/u"), want)

    def test_deep_folder_lists_match(self):
        self.assertEqual(perms.DEEP_FOLDERS, filed.DEEP_FOLDERS)


class Tally(unittest.TestCase):
    def test_count_flush_reload_and_prune(self):
        user = mock.Mock(pw_gid=os.getgid())
        with tempfile.TemporaryDirectory() as d, mock.patch.object(filed.os, "chown"):
            path = os.path.join(d, "files-u.json")
            t = filed.Tally(path, user)
            now = 100 * 86400
            t.count("discord", "~/Pictures", now - 40 * 86400)
            t.count("code", "~/.ssh", now)
            t.count("code", "~/.ssh", now + 5)
            t.flush(now + 5)
            data = json.loads(Path(path).read_text())
            self.assertEqual(data["apps"], {"code": {"~/.ssh": [2, now, now + 5]}})
            self.assertEqual(oct(os.stat(path).st_mode & 0o777), "0o640")
            again = filed.Tally(path, user)
            self.assertEqual(again.apps["code"]["~/.ssh"][0], 2)


if __name__ == "__main__":
    unittest.main()
