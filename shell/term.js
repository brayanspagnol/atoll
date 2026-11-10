.pragma library
// A command in a new terminal window. Values travel as arguments, never inside the shell text, so nothing in them runs.
// hold: a line shown when the command ends, so its result stays on screen until Enter.
function argv(cmd, hold) {
    const run = hold ? ["sh", "-c", '"$@"; printf "\\n%s " "$0"; read -r _', hold].concat(cmd) : cmd
    return ["sh", "-c", 'if command -v xdg-terminal-exec >/dev/null; then exec xdg-terminal-exec "$@"; else exec kitty "$@"; fi', "sh"].concat(run)
}
