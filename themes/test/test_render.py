"""Tests for themes/render.py: theme parsing, derived values, placeholders, validation, rendering.
Run from the repo root:  python3 -B -m unittest discover -s themes/test
Nothing here touches the live session: themes, templates and output go to a temp dir."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('render', REPO / 'themes' / 'render.py')
render = importlib.util.module_from_spec(spec)
spec.loader.exec_module(render)


def theme_text(name='t', **over):
    """A complete, valid theme file body; keyword arguments replace keys, None drops one."""
    keys = {'name': name, 'mode': 'dark', 'wallpaper': 'w.jpg', 'cursor': 'C'}
    keys.update({k: '102030' for k in render.COLOURS})
    keys.update(over)
    return ''.join(f'{k}={v}\n' for k, v in keys.items() if v is not None)


class Tmp(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)
        self.tpl = self.dir / 'templates'
        self.tpl.mkdir()
        self.wall = self.dir / 'wallpapers'
        self.wall.mkdir()
        (self.wall / 'w.jpg').write_bytes(b'')

    def tearDown(self):
        self._tmp.cleanup()

    def theme(self, name='t', **over):
        p = self.dir / f'{name}.theme'
        p.write_text(theme_text(name, **over))
        return p

    def problems(self, path):
        return render.problems(path, self.tpl, self.wall)


class Parse(Tmp):
    def test_comments_and_spaces_are_stripped(self):
        p = self.dir / 'x.theme'
        p.write_text('# header\n base = 0a0b0c  # trailing\n\nnot a pair\n')
        self.assertEqual(render.load(p), {'base': '0a0b0c'})

    def test_hex_values_get_rgb_and_ansi(self):
        v = render.values({'base': '0a0b0c', 'name': 'x'})
        self.assertEqual(v['base_rgb'], '10, 11, 12')
        self.assertEqual(v['base_ansi'], '38;2;10;11;12')
        self.assertNotIn('name_rgb', v)

    def test_glass_becomes_an_alpha_byte(self):
        self.assertEqual(render.values({'glass': '0.95'})['glass_hex'], 'f2')
        self.assertNotIn('glass_hex', render.values({}))

    def test_mode_sets_its_derived_values(self):
        self.assertEqual(render.values({'mode': 'dark'})['gtk_theme'], 'adw-gtk3-dark')
        light = render.values({'mode': 'light'})
        self.assertEqual((light['gtk_theme'], light['gtk_prefer_dark'], light['icon_theme'], light['color_scheme']),
                         ('adw-gtk3', '0', 'Papirus', 'prefer-light'))

    def test_every_mode_sets_the_same_keys(self):
        self.assertEqual(*[set(m) for m in render.MODES.values()])


class Fill(unittest.TestCase):
    def test_value_fallback_and_missing(self):
        text, missing = render.fill('{{a}} {{b|0.7}} {{c}} {{a|x}}', {'a': '1'})
        self.assertEqual(text, '1 0.7 {{c}} 1')
        self.assertEqual(missing, {'c'})

    def test_empty_fallback_is_a_fallback(self):
        self.assertEqual(render.fill('[{{a|}}]', {}), ('[]', set()))


class Problems(Tmp):
    def test_complete_theme_has_none(self):
        (self.tpl / 'x.conf').write_text('{{base}} {{gtk_theme}} {{base_rgb}} {{glass|0.7}}')
        self.assertEqual(self.problems(self.theme()), [])

    def test_missing_theme_file(self):
        self.assertEqual(self.problems(self.dir / 'nope.theme'), ['no such theme: nope'])

    def test_missing_key_is_reported_once(self):
        (self.tpl / 'x.conf').write_text('{{accent}}')
        self.assertEqual(self.problems(self.theme(accent=None)), ['missing key: accent'])

    def test_bad_hex(self):
        self.assertEqual(self.problems(self.theme(red='ff00')), ['red=ff00 is not six hex digits'])

    def test_name_must_match_file(self):
        p = self.dir / 't.theme'
        p.write_text(theme_text('other'))
        self.assertEqual(self.problems(p),
                         ['name=other does not match the file name t.theme'])

    def test_bad_mode(self):
        self.assertEqual(self.problems(self.theme(mode='dim')), ['mode=dim is not one of dark, light'])

    def test_missing_wallpaper(self):
        self.assertEqual(self.problems(self.theme(wallpaper='gone.jpg')), ['wallpaper gone.jpg is not in wallpapers/'])

    def test_bad_glass(self):
        self.assertEqual(self.problems(self.theme(glass='1.5')), ['glass=1.5 is not a number from 0 to 1'])
        self.assertEqual(self.problems(self.theme(glass='clear')), ['glass=clear is not a number from 0 to 1'])

    def test_template_key_the_theme_lacks(self):
        (self.tpl / 'app').mkdir()
        (self.tpl / 'app' / 'x.css').write_text('{{base}} {{orange}} {{teal|fff}}')
        self.assertEqual(self.problems(self.theme()), ['app/x.css needs orange'])


class RenderAll(Tmp):
    def test_writes_every_destination(self):
        for src in render.TARGETS:
            (self.tpl / src).parent.mkdir(parents=True, exist_ok=True)
            (self.tpl / src).write_text('{{name}}:{{base}}')
        cfg = self.dir / 'cfg'
        self.assertEqual(render.render_all(self.theme(), cfg, self.tpl, self.wall), [])
        for dsts in render.TARGETS.values():
            for d in dsts:
                self.assertEqual((cfg / d).read_text(), 't:102030')

    def test_bad_theme_writes_nothing(self):
        for src in render.TARGETS:
            (self.tpl / src).parent.mkdir(parents=True, exist_ok=True)
            (self.tpl / src).write_text('{{base}}')
        cfg = self.dir / 'cfg'
        self.assertEqual(render.render_all(self.theme(base=None), cfg, self.tpl, self.wall), ['missing key: base'])
        self.assertFalse(cfg.exists())


class RealThemes(unittest.TestCase):
    """The themes and templates in the repo."""

    def test_every_target_template_exists(self):
        for src in render.TARGETS:
            self.assertTrue((render.TEMPLATES / src).is_file(), src)

    def test_every_theme_is_clean(self):
        themes = sorted(render.THEMES.glob('*.theme'))
        self.assertTrue(themes)
        for p in themes:
            with self.subTest(theme=p.stem):
                self.assertEqual(render.problems(p), [])

    def test_render_leaves_no_placeholders(self):
        for p in sorted(render.THEMES.glob('*.theme')):
            v = render.values(render.load(p))
            for tpl in render.templates():
                with self.subTest(theme=p.stem, template=str(tpl.relative_to(render.TEMPLATES))):
                    self.assertNotRegex(render.fill(tpl.read_text(), v)[0], r'\{\{\w+')


if __name__ == '__main__':
    unittest.main()
