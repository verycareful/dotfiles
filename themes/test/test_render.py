"""Tests for themes/render.py: theme parsing, derived values, placeholders, validation, rendering.
Run from the repo root:  python3 -B -m unittest discover -s themes/test
Nothing here touches the live session: themes, templates and output go to a temp dir."""
import importlib.util
import json
import plistlib
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

    def test_shimmer_tints_are_lighter_than_their_colour(self):
        v = render.values({'accent': '0660c6', 'yellow': '825800', 'muted': '5b6067'})
        for k in render.SHIMMER_ROLES:
            self.assertGreater(render.luminance(v[k + '_shimmer']), render.luminance(v[k]), k)
        self.assertEqual(render.mix('000000', 'ffffff', 0.5), '808080')
        self.assertNotIn('accent_shimmer', render.values({}))

    def test_snap256_returns_cube_colours_and_keeps_them(self):
        cube = {'%02x%02x%02x' % c for c in render.CUBE_256}
        self.assertEqual(render.snap256('ffafaf'), 'ffafaf')
        self.assertEqual(render.snap256('f8bbb4'), 'ffafaf')
        self.assertIn(render.snap256('123456'), cube)
        self.assertEqual(render.snap256('f59d93', lambda c: c != (255, 175, 175) and sum(c) < 700), 'd78787')

    def test_accent_wash_is_a_pale_true_colour_of_the_accent_hue(self):
        light = render.values({'mode': 'light', 'accent': '0660c6', 'text': '12151a'})['accent_wash']
        dark = render.values({'mode': 'dark', 'accent': '0660c6', 'text': 'e4e8f0'})['accent_wash']
        self.assertGreater(render.luminance(light), 0.7)
        self.assertLess(render.luminance(dark), 0.05)
        for wash in (light, dark):
            r, g, b = (int(wash[i:i + 2], 16) for i in (0, 2, 4))
            self.assertTrue(b > g > r, wash)
        self.assertNotIn('accent_wash', render.values({'mode': 'light'}))

    def test_solve_alpha_is_the_first_alpha_that_reaches_the_target(self):
        a = render.solve_alpha('000000', 'ffffff', 1.45)
        self.assertGreaterEqual(render.contrast(render.mix('ffffff', '000000', a), 'ffffff'), 1.45)
        self.assertLess(render.contrast(render.mix('ffffff', '000000', a - 0.01), 'ffffff'), 1.45)
        self.assertEqual(render.solve_alpha('ffffff', 'ffffff', 2.0), 0.98)

    def test_dark_themes_use_the_fixed_fill_alphas(self):
        for name in ('dusk', 'harbour', 'mono'):
            v = render.values(render.load(render.THEMES / f'{name}.theme'))
            self.assertEqual((v['select_alpha'], v['hover_alpha'], v['field_alpha'], v['empty_alpha']),
                             ('0.55', '0.90', '0.55', '0.45'), name)

    def test_light_fills_are_distinct_from_the_card_and_keep_text_readable(self):
        for name in ('dusk-light', 'harbour-light', 'mono-light'):
            raw = render.load(render.THEMES / f'{name}.theme')
            v = render.values(raw)
            card = raw['mantle']
            selected = render.mix(card, v['fill_selected'], float(v['select_alpha']))
            hover = render.mix(card, v['fill_hover'], float(v['hover_alpha']))
            with self.subTest(theme=name):
                self.assertGreaterEqual(render.contrast(selected, card), 1.45)
                self.assertGreaterEqual(render.contrast(hover, card), 1.28)
                self.assertGreater(render.contrast(selected, card), render.contrast(hover, card))
                for fill, muted in ((selected, 3.3), (hover, 3.5)):
                    self.assertGreaterEqual(render.contrast(raw['text'], fill), 7)
                    self.assertGreaterEqual(render.contrast(raw['subtext'], fill), 4.5)
                    self.assertGreaterEqual(render.contrast(raw['muted'], fill), muted)
                self.assertGreaterEqual(render.contrast(v['on_selected'], selected), 3.0)
                dot = render.mix(card, raw['muted'], float(v['empty_alpha']))
                self.assertGreaterEqual(render.contrast(dot, card), 3.0)

    def test_selection_fill_is_visible_and_light_themes_keep_every_text_readable(self):
        for p in sorted(render.THEMES.glob('*.theme')):
            raw = render.load(p)
            dark = raw['mode'] == 'dark'
            fill = render.values(raw)['accent_select']
            with self.subTest(theme=p.stem):
                self.assertGreaterEqual(render.contrast(fill, raw['base']), render.SELECT_VISIBLE)
                if not dark:
                    for k, need in render.SELECT_TEXT_CONTRAST.items():
                        self.assertGreaterEqual(render.contrast(raw[k], fill), need, k)
        self.assertNotIn('accent_select', render.values({'mode': 'light', 'accent': '0660c6'}))

    def test_snap256_keeps_a_green_green(self):
        r, g, b = (int(render.snap256('153d25')[i:i + 2], 16) for i in (0, 2, 4))
        self.assertTrue(g > r and g > b)

    def test_tints_are_cube_colours_with_the_right_hue_and_order(self):
        cube = {'%02x%02x%02x' % c for c in render.CUBE_256}
        for p in sorted(render.THEMES.glob('*.theme')):
            raw = render.load(p)
            v = render.values(raw)
            dark = raw['mode'] == 'dark'
            with self.subTest(theme=p.stem):
                for k in render.TINT_ROLES:
                    for name in render.TINTS:
                        self.assertIn(v[f'{k}_{name}'], cube, f'{k}_{name}')
                for name in render.TINTS:
                    r, g, b = (int(v[f'red_{name}'][i:i + 2], 16) for i in (0, 2, 4))
                    self.assertTrue(r > g >= b, f'red_{name}')
                    r, g, b = (int(v[f'green_{name}'][i:i + 2], 16) for i in (0, 2, 4))
                    self.assertTrue(g > r and g > b, f'green_{name}')
                for k in ('green', 'red'):
                    wash, strong = (render.lab(tuple(int(v[f'{k}_{n}'][i:i + 2], 16) for i in (0, 2, 4)))[0]
                                    for n in ('tint', 'tint_strong'))
                    self.assertTrue(strong > wash if dark else strong < wash, k)
        self.assertNotIn('green_tint', render.values({'green': '186e3d'}))

    def test_light_themes_are_more_transparent_and_dim_text_stronger(self):
        dark, light = (render.values({'mode': m}) for m in ('dark', 'light'))
        self.assertLess(float(light['terminal_opacity']), float(dark['terminal_opacity']))
        self.assertLess(float(light['scrim_alpha']), 1)
        self.assertGreater(float(light['scrim_alpha']), float(dark['scrim_alpha']))
        self.assertGreater(float(light['dim_opacity']), float(dark['dim_opacity']))

    def test_mode_sets_its_derived_values(self):
        self.assertEqual(render.values({'mode': 'dark'})['gtk_theme'], 'adw-gtk3-dark')
        light = render.values({'mode': 'light'})
        self.assertEqual((light['gtk_theme'], light['gtk_prefer_dark'], light['icon_theme'], light['color_scheme']),
                         ('adw-gtk3', '0', 'Papirus', 'prefer-light'))

    def test_every_mode_sets_the_same_keys(self):
        self.assertEqual(*[set(m) for m in render.MODES.values()])
        self.assertEqual(*[set(m) for m in render.MODE_ROLES.values()])

    def test_mode_roles_point_at_colours(self):
        for roles in render.MODE_ROLES.values():
            self.assertLessEqual(set(roles.values()), set(render.COLOURS))

    def test_mode_roles_take_the_named_colour(self):
        raw = {'mode': 'light', 'subtext': '444444', 'surface': 'eeeeee', 'base': 'ffffff', 'overlay': 'dddddd'}
        v = render.values(raw)
        self.assertEqual((v['ansi_black'], v['qt_light'], v['ansi_black_rgb']), ('444444', 'ffffff', '68, 68, 68'))

    def test_ansi_blue_is_the_accent_only_on_light_themes(self):
        colours = {'accent': '0660c6', 'primary_bright': '4f5866'}
        self.assertEqual(render.values({'mode': 'light', **colours})['ansi_blue'], '0660c6')
        self.assertEqual(render.values({'mode': 'dark', **colours})['ansi_blue'], '4f5866')

    def test_on_accent_picks_the_higher_contrast(self):
        self.assertEqual(render.values({'accent': 'ff8c32', 'base': '06080e', 'text': 'e4e8f4'})['on_accent'], '06080e')
        self.assertEqual(render.values({'accent': '0660c6', 'base': 'f7f7f8', 'text': '12151a'})['on_accent'], 'f7f7f8')

    def test_theme_on_accent_wins(self):
        v = render.values({'accent': '0660c6', 'base': '000000', 'text': 'e4e8f0', 'on_accent': '000000'})
        self.assertEqual(v['on_accent'], '000000')

    def test_contrast_extremes(self):
        self.assertAlmostEqual(render.contrast('000000', 'ffffff'), 21.0)
        self.assertAlmostEqual(render.contrast('777777', '777777'), 1.0)


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

    def test_bad_on_accent(self):
        self.assertEqual(self.problems(self.theme(on_accent='fff')), ['on_accent=fff is not six hex digits'])

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
        cfg, home = self.dir / 'cfg', self.dir / 'home'
        self.assertEqual(render.render_all(self.theme(), cfg, self.tpl, self.wall, home), [])
        for dsts in render.TARGETS.values():
            for d in dsts:
                self.assertEqual(Path(render.destination(d, cfg, home)).read_text(), 't:102030')

    def test_home_destinations_stay_out_of_the_config_dir(self):
        cfg, home = self.dir / 'cfg', self.dir / 'home'
        self.assertEqual(render.destination('~/.claude/x.json', cfg, home), str(home / '.claude/x.json'))
        self.assertEqual(render.destination('kitty/x.conf', cfg, home), str(cfg / 'kitty/x.conf'))

    def test_bad_theme_writes_nothing(self):
        for src in render.TARGETS:
            (self.tpl / src).parent.mkdir(parents=True, exist_ok=True)
            (self.tpl / src).write_text('{{base}}')
        cfg, home = self.dir / 'cfg', self.dir / 'home'
        self.assertEqual(render.render_all(self.theme(base=None), cfg, self.tpl, self.wall, home), ['missing key: base'])
        self.assertFalse(cfg.exists() or home.exists())


class Catalogue(Tmp):
    """The real themes, against a temp repo wallpapers dir (self.repo_wall) so this machine's
    wallpapers/local/ does not leak in."""
    def setUp(self):
        super().setUp()
        self.repo_wall = self.dir / 'repo-wallpapers'
        self.repo_wall.mkdir()

    def test_wallpaper_prefers_the_copy_in_wall_dir(self):
        real = render.load(sorted(render.THEMES.glob('*.theme'))[0])
        (self.wall / real['wallpaper']).write_bytes(b'')
        entries = {e['name']: e for e in render.catalogue(self.wall, self.repo_wall)}
        self.assertEqual(entries[real['name']]['wallpaper'], str(self.wall / real['wallpaper']))

    def test_wallpaper_falls_back_to_the_repo(self):
        for e in render.catalogue(self.dir / 'nowhere', self.repo_wall):
            self.assertEqual(Path(e['wallpaper']).parent, self.repo_wall)

    def test_local_override_is_per_theme(self):
        real = render.load(sorted(render.THEMES.glob('*.theme'))[0])
        (self.repo_wall / 'local').mkdir()
        (self.repo_wall / 'local' / f"{real['name']}.jpg").write_bytes(b'')
        entries = {e['name']: e for e in render.catalogue(self.wall, self.repo_wall)}
        self.assertEqual(entries[real['name']]['wallpaper'], str(self.repo_wall / 'local' / f"{real['name']}.jpg"))
        for name, e in entries.items():
            if name != real['name']:
                self.assertNotEqual(Path(e['wallpaper']).parent, self.repo_wall / 'local')

    def test_every_theme_with_its_colours(self):
        entries = render.catalogue(self.wall, self.repo_wall)
        self.assertEqual(sorted(e['name'] for e in entries), sorted(p.stem for p in render.THEMES.glob('*.theme')))
        for e in entries:
            self.assertTrue(set(render.META + render.COLOURS) <= set(e))


class WallpaperPath(Tmp):
    def setUp(self):
        super().setUp()
        self.repo_wall = self.dir / 'repo-wallpapers'
        (self.repo_wall / 'local').mkdir(parents=True)

    def test_local_image_for_the_theme_wins(self):
        (self.repo_wall / 'local' / 't.png').write_bytes(b'')
        self.assertEqual(render.wallpaper_path('t', 'w.jpg', self.wall, self.repo_wall),
                         self.repo_wall / 'local' / 't.png')

    def test_local_image_of_another_theme_is_ignored(self):
        (self.repo_wall / 'local' / 'other.jpg').write_bytes(b'')
        self.assertEqual(render.wallpaper_path('t', 'w.jpg', self.wall, self.repo_wall), self.wall / 'w.jpg')

    def test_wall_dir_then_repo(self):
        self.assertEqual(render.wallpaper_path('t', 'w.jpg', self.wall, self.repo_wall), self.wall / 'w.jpg')
        self.assertEqual(render.wallpaper_path('t', 'x.jpg', self.wall, self.repo_wall), self.repo_wall / 'x.jpg')


class RealThemes(unittest.TestCase):
    """The themes and templates in the repo."""

    def test_every_target_template_exists(self):
        for src in render.TARGETS:
            self.assertTrue((render.TEMPLATES / src).is_file(), src)

    def test_discord_theme_goes_to_the_vencord_themes_folder(self):
        self.assertEqual(render.TARGETS['vencord/dotfiles.theme.css'], ['Vencord/themes/dotfiles.theme.css'])

    def test_bat_theme_goes_to_the_bat_themes_folder(self):
        self.assertEqual(render.TARGETS['bat/dotfiles.tmTheme'], ['bat/themes/dotfiles.tmTheme'])

    def bat_theme(self, raw):
        text, _ = render.fill((render.TEMPLATES / 'bat' / 'dotfiles.tmTheme').read_text(), render.values(raw))
        return plistlib.loads(text.encode())

    def test_bat_plain_text_is_the_theme_text_colour(self):
        for p in sorted(render.THEMES.glob('*.theme')):
            raw = render.load(p)
            base = self.bat_theme(raw)['settings'][0]['settings']
            with self.subTest(theme=p.stem):
                self.assertEqual(base['foreground'], '#' + raw['text'])
                self.assertEqual(base['background'], '#' + raw['base'])
                self.assertGreaterEqual(render.contrast(raw['text'], raw['base']), 7)

    def test_bat_scopes_stay_readable_on_the_background(self):
        for p in sorted(render.THEMES.glob('*.theme')):
            raw = render.load(p)
            rules = self.bat_theme(raw)['settings'][1:]
            self.assertGreater(len(rules), 10)
            for rule in rules:
                with self.subTest(theme=p.stem, rule=rule['name']):
                    self.assertGreaterEqual(render.contrast(rule['settings']['foreground'][1:], raw['base']), 3.0)

    def test_claude_theme_goes_to_the_claude_themes_folder(self):
        self.assertEqual(render.TARGETS['claude/theme.json'], ['~/.claude/themes/dotfiles.json'])

    def test_claude_theme_is_valid_json_on_the_matching_ansi_base(self):
        for p in sorted(render.THEMES.glob('*.theme')):
            raw = render.load(p)
            text, _ = render.fill((render.TEMPLATES / 'claude' / 'theme.json').read_text(), render.values(raw))
            with self.subTest(theme=p.stem):
                theme = json.loads(text)
                self.assertEqual(theme['base'], raw['mode'] + '-ansi')
                self.assertGreater(len(theme['overrides']), 50)
                for token, colour in theme['overrides'].items():
                    self.assertRegex(colour, r'^#[0-9a-f]{6}$', token)

    def test_claude_theme_diff_text_stays_readable(self):
        for p in sorted(render.THEMES.glob('*.theme')):
            raw = render.load(p)
            text, _ = render.fill((render.TEMPLATES / 'claude' / 'theme.json').read_text(), render.values(raw))
            o = json.loads(text)['overrides']
            for token in ('diffAdded', 'diffRemoved', 'diffAddedWord', 'diffRemovedWord'):
                with self.subTest(theme=p.stem, token=token):
                    self.assertGreaterEqual(render.contrast(o['text'][1:], o[token][1:]), 3.5)

    def test_every_theme_is_clean(self):
        themes = sorted(render.THEMES.glob('*.theme'))
        self.assertTrue(themes)
        for p in themes:
            with self.subTest(theme=p.stem):
                self.assertEqual(render.problems(p), [])

    def test_every_dark_theme_has_a_light_sibling(self):
        names = {p.stem for p in render.THEMES.glob('*.theme')}
        for p in render.THEMES.glob('*.theme'):
            mode = render.load(p)['mode']
            with self.subTest(theme=p.stem):
                self.assertEqual(mode == 'light', p.stem.endswith('-light'))
                if mode == 'dark':
                    self.assertIn(p.stem + '-light', names)

    def test_text_is_readable(self):
        """WCAG AA for body text (4.5:1) on every background it sits on, and 3:1 for text on an accent fill."""
        for p in sorted(render.THEMES.glob('*.theme')):
            v = render.values(render.load(p))
            for fg, bg, floor in [('text', 'base', 4.5), ('text', 'mantle', 4.5), ('text', 'surface', 4.5),
                                  ('subtext', 'mantle', 4.5), ('text', 'primary', 4.5), ('on_accent', 'accent', 3)]:
                with self.subTest(theme=p.stem, pair=f'{fg} on {bg}'):
                    self.assertGreaterEqual(render.contrast(v[fg], v[bg]), floor)

    def test_light_dim_text_is_readable(self):
        """Muted text and the terminal's bright black (dim text in most CLIs) clear AA on a light base."""
        for p in sorted(render.THEMES.glob('*-light.theme')):
            v = render.values(render.load(p))
            for fg in ('muted', 'ansi_black_bright'):
                with self.subTest(theme=p.stem, colour=fg):
                    self.assertGreaterEqual(render.contrast(v[fg], v['base']), 4.5)

    def test_light_mode_uses_greyscale_antialiasing(self):
        """Subpixel antialiasing fringes dark-on-light text with colour; dark mode keeps it."""
        self.assertEqual(render.MODES['light']['gtk_rgba'], 'none')
        self.assertEqual(render.MODES['dark']['gtk_rgba'], 'rgb')

    def test_qml_properties_are_not_signal_handlers(self):
        """QML reads a property named onX as a handler for signal x and refuses to load the file."""
        text = (render.TEMPLATES / 'quickshell' / 'Theme.qml').read_text()
        self.assertNotRegex(text, r'property\s+\w+\s+on[A-Z]')

    def test_render_leaves_no_placeholders(self):
        for p in sorted(render.THEMES.glob('*.theme')):
            v = render.values(render.load(p))
            for tpl in render.templates():
                with self.subTest(theme=p.stem, template=str(tpl.relative_to(render.TEMPLATES))):
                    self.assertNotRegex(render.fill(tpl.read_text(), v)[0], r'\{\{\w+')


if __name__ == '__main__':
    unittest.main()
