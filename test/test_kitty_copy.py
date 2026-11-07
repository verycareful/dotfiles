"""Tests for scripts/.local/bin/kitty-copy: left-margin removal and the clipboard hand-off.
Run from the repo root:  python3 -B -m unittest discover -s test
wl-copy is replaced by a recorder, so nothing here touches the live clipboard."""
import importlib.machinery
import importlib.util
import io
import unittest
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / ".local" / "bin" / "kitty-copy"
loader = importlib.machinery.SourceFileLoader("kitty_copy", str(SCRIPT))
spec = importlib.util.spec_from_loader("kitty_copy", loader)
kitty_copy = importlib.util.module_from_spec(spec)
loader.exec_module(kitty_copy)


class StripMargin(unittest.TestCase):
    def test_margin_on_every_line(self):
        self.assertEqual(kitty_copy.strip_margin("  a\n  b\n  c"), "a\nb\nc")

    def test_selection_starting_mid_line(self):
        self.assertEqual(kitty_copy.strip_margin("tail of a\n  b\n  c"), "tail of a\nb\nc")

    def test_selection_starting_inside_the_margin(self):
        self.assertEqual(kitty_copy.strip_margin(" a\n  b\n  c"), "a\nb\nc")

    def test_first_line_indented_deeper_than_the_margin(self):
        self.assertEqual(kitty_copy.strip_margin("    a\n  b"), "  a\nb")

    def test_relative_indentation_is_kept(self):
        text = "  def f():\n      return 1\n  x = 2"
        self.assertEqual(kitty_copy.strip_margin(text), "def f():\n    return 1\nx = 2")

    def test_no_margin_is_left_alone(self):
        self.assertEqual(kitty_copy.strip_margin("a\nb\n  c"), "a\nb\n  c")

    def test_single_line_is_left_alone(self):
        self.assertEqual(kitty_copy.strip_margin("    one line"), "    one line")

    def test_blank_lines_do_not_set_the_margin(self):
        self.assertEqual(kitty_copy.strip_margin("  a\n\n  b"), "a\n\nb")

    def test_whitespace_only_lines_come_out_empty(self):
        self.assertEqual(kitty_copy.strip_margin("  a\n    \n  b"), "a\n\nb")

    def test_only_blank_lines_after_the_first(self):
        self.assertEqual(kitty_copy.strip_margin("  a\n\n"), "  a\n\n")

    def test_tab_margin(self):
        self.assertEqual(kitty_copy.strip_margin("\ta\n\tb"), "a\nb")

    def test_trailing_newline_survives(self):
        self.assertEqual(kitty_copy.strip_margin("  a\n  b\n"), "a\nb\n")

    def test_mixed_margin_uses_the_shared_prefix(self):
        self.assertEqual(kitty_copy.strip_margin("x\n  a\n   b"), "x\na\n b")


class Main(unittest.TestCase):
    def run_main(self, stdin):
        with mock.patch("sys.stdin", io.StringIO(stdin)), mock.patch.object(kitty_copy.subprocess, "run") as run:
            run.return_value.returncode = 0
            rc = kitty_copy.main()
        return rc, run

    def test_copies_the_cleaned_text(self):
        rc, run = self.run_main("  a\n  b")
        self.assertEqual(rc, 0)
        run.assert_called_once()
        self.assertEqual(run.call_args.args[0], ["wl-copy"])
        self.assertEqual(run.call_args.kwargs["input"], b"a\nb")

    def test_empty_selection_leaves_the_clipboard_alone(self):
        rc, run = self.run_main("")
        self.assertEqual(rc, 0)
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
