set fish_greeting

set -xp PATH (python3 -c "import site; import os; print(os.path.join(site.getuserbase(), 'bin'))")        # scripts installed by pip install --user
set -xp PATH ~/.cargo/bin       # binaries installed by cargo (rust)

set -xg EDITOR nvim             # prefer neovim as default editor
set -xg BROWSER firefox         # prefer firefox as default browser
set -xg CLICOLOR 1              # turn on colors for some BSD tools

if test -n "$DESKTOP_SESSION"
    set -xg GNOME_KEYRING_CONTROL {$XDG_RUNTIME_DIR}/keyring
    set -xg SSH_AUTH_SOCK {$XDG_RUNTIME_DIR}/keyring/ssh
end
