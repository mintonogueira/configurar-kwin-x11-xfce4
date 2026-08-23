#!/usr/bin/env bash
set -Eeuo pipefail

fail() {
    echo "ERRO: $*" >&2
    exit 1
}

info() {
    echo "[OK] $*"
}

[[ ${EUID} -eq 0 ]] || fail 'execute como root.'

install -d -m 0755 \
    /usr/local/bin \
    /etc/xdg/xfce4/whiskermenu

cat > /usr/local/bin/logout <<'LOGOUT'
#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n ${XDG_SESSION_ID:-} ]] || {
    echo 'XDG_SESSION_ID não definido.' >&2
    exit 1
}

exec /usr/bin/loginctl terminate-session "$XDG_SESSION_ID"
LOGOUT

cat > /usr/local/bin/reboot <<'REBOOT'
#!/usr/bin/env bash
exec /usr/bin/systemctl reboot
REBOOT

cat > /usr/local/bin/poweroff <<'POWEROFF'
#!/usr/bin/env bash
exec /usr/bin/systemctl poweroff
POWEROFF

cat > /usr/local/bin/suspend <<'SUSPEND'
#!/usr/bin/env bash
exec /usr/bin/systemctl suspend
SUSPEND

chmod 0755 \
    /usr/local/bin/logout \
    /usr/local/bin/reboot \
    /usr/local/bin/poweroff \
    /usr/local/bin/suspend

cat > /etc/xdg/xfce4/whiskermenu/defaults.rc <<'WHISKER'
command-settings=xfce4-settings-manager
show-command-settings=true

command-lockscreen=/usr/bin/xscreensaver-command -lock
show-command-lockscreen=true

command-switchuser=/usr/bin/dm-tool switch-to-greeter
show-command-switchuser=true

command-logoutuser=/usr/local/bin/logout
show-command-logoutuser=true

command-restart=/usr/local/bin/reboot
show-command-restart=true

command-shutdown=/usr/local/bin/poweroff
show-command-shutdown=true

command-suspend=/usr/local/bin/suspend
show-command-suspend=true

command-logout=/usr/local/bin/logout
show-command-logout=true
WHISKER

chmod 0644 /etc/xdg/xfce4/whiskermenu/defaults.rc

# Garante Whisker + área de notificação.
# DockBarX é instalado pelo script 10, mas NÃO é inserido
# automaticamente no layout do painel porque isso é escolha de layout.
cat > /usr/local/bin/xfce-kwin-panel-setup <<'PANELSETUP'
#!/usr/bin/env bash
set -u

for _ in {1..40}; do
    pgrep -x xfce4-panel >/dev/null 2>&1 && break
    sleep 0.25
done

pgrep -x xfce4-panel >/dev/null 2>&1 || exit 0

panel_dump="$(
    /usr/bin/xfconf-query \
        -c xfce4-panel \
        -lv \
        2>/dev/null || true
)"

if ! grep -Eq \
    '/plugins/plugin-[0-9]+[[:space:]]+whiskermenu$' \
    <<< "$panel_dump"
then
    /usr/bin/xfce4-panel \
        --add=whiskermenu \
        >/dev/null 2>&1 || true
fi

panel_dump="$(
    /usr/bin/xfconf-query \
        -c xfce4-panel \
        -lv \
        2>/dev/null || true
)"

if ! grep -Eq \
    '/plugins/plugin-[0-9]+[[:space:]]+systray$' \
    <<< "$panel_dump"
then
    /usr/bin/xfce4-panel \
        --add=systray \
        >/dev/null 2>&1 || true
fi
PANELSETUP

chmod 0755 /usr/local/bin/xfce-kwin-panel-setup

info 'ações de sessão independentes do xfce4-session configuradas.'
info 'Whisker e integração básica do painel configurados.'
info 'DockBarX permanece instalado, mas sua posição no painel não é imposta.'
