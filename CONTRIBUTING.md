# Contributing to Atoll

Thanks for helping. Issues and pull requests can be written in English or Portuguese.

## Layout

| Path | What it holds |
|---|---|
| `shell/` | The Quickshell interface (QML), plus pure logic in `cal.js` and `parse.js` |
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

The interface is in Brazilian Portuguese, with strings written directly in the QML files. Translation support is
open work: if you want to take it on, open an issue first so we can agree on the approach.

## Pull requests

- Keep each pull request to one change, and explain why it's needed.
- Include a screenshot for visual changes, with personal data removed.
- Use [Conventional Commits](https://www.conventionalcommits.org) messages, such as `fix: keep the dock open on hover`.
- Add an entry under `[Unreleased]` in `CHANGELOG.md`.

## Releases

Maintainers release by moving `[Unreleased]` to a new version in `CHANGELOG.md`, updating `VERSION`, and pushing a
`vX.Y.Z` tag. The release workflow checks that the tag matches `VERSION` and publishes the changelog section.
