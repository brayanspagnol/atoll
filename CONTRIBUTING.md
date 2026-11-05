# Contributing to Atoll

Thanks for helping. Issues and pull requests can be written in English or Portuguese.

## Layout

| Path | What it holds |
|---|---|
| `shell/` | The Quickshell interface (QML), pure logic in `cal.js` and `parse.js`, and translations in `i18n/` |
| `hypr/` | Hyprland configuration in Lua |
| `scripts/` | Session helpers installed to `~/.local/share/atoll/scripts` |
| `config/` | Lock screen and default idle configuration |
| `tests/` | Automated tests for the pure logic |
| `tools/` | Maintainer tools, such as the wallpaper generator |

## Test your change

```sh
node tests/test.mjs                                   # logic tests
luac -p hypr/*.lua                                    # Lua syntax
shellcheck -s bash scripts/* install.sh uninstall.sh  # shell scripts
```

CI runs these on every pull request. New logic in `cal.js` or `parse.js` should come with a test.

### Try the interface without leaving your session

Quickshell reloads a running config when its files change, so don't develop on the copy your session uses.
Run a nested compositor instead:

```sh
HOME="$PWD/.sandbox" ./install.sh
HOME="$PWD/.sandbox" ATOLL_NESTED=1 Hyprland --config "$PWD/.sandbox/.config/atoll/hypr/main.lua"
# then, using that instance's WAYLAND_DISPLAY and HYPRLAND_INSTANCE_SIGNATURE:
HOME="$PWD/.sandbox" qs -c atoll
```

`ATOLL_NESTED` skips the session services, such as the idle daemon and the clipboard watcher.

Quickshell's hot reload keeps the old type when a singleton is added or changed, and doesn't reread
`//@ pragma` lines. After those changes, restart the shell instead of trusting a reload.

## Translations

English is the source language: in the QML files, text is written in English inside `Tr.t("...")`, and that text is
the key. Each other language is a file in `shell/i18n/`, so a missing entry simply shows English.

To add a language, copy an existing file to `shell/i18n/<code>.json`, translate the values and add the language to
`languages` in `shell/Tr.qml`. Keep placeholders such as `%1`. Entries such as `dddd, MMMM d` are
[Qt date formats](https://doc.qt.io/qt-6/qml-qtqml-qt.html#formatDateTime-method) for that language.

`node tests/test.mjs` fails if a file is missing a string or changes a placeholder. Most current translations were
not reviewed by native speakers, so corrections are very welcome.

## Pull requests

- Keep each pull request to one change, and explain why it's needed.
- Include a screenshot for visual changes, with personal data removed.
- Use [Conventional Commits](https://www.conventionalcommits.org) messages, such as `fix: keep the dock open on hover`.
- Add an entry under `[Unreleased]` in `CHANGELOG.md`.

## Releases

Maintainers release by moving `[Unreleased]` to a new version in `CHANGELOG.md`, updating `VERSION`, and pushing a
`vX.Y.Z` tag. The release workflow checks that the tag matches `VERSION` and publishes the changelog section.
