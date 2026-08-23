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
[[ -n ${TARGET_USER:-} ]] || fail 'TARGET_USER não definido.'

for cmd in kwriteconfig6 kcmshell6 qdbus6 xfconf-query; do
    command -v "$cmd" >/dev/null 2>&1 ||
        fail "comando obrigatório ausente: $cmd"
done

KCM='/usr/lib/qt6/plugins/plasma/kcms/systemsettings/kcm_kwin_virtualdesktops_x11.so'

[[ -f $KCM ]] ||
    fail "KCM X11 de desktops virtuais ausente: $KCM"

install -d -m 0755 \
    /etc/xdg \
    /usr/local/bin

if [[ -f /etc/xdg/kwinrc ]]; then
    cp -a \
        /etc/xdg/kwinrc \
        "/etc/xdg/kwinrc.backup-xfce-kwin-$(date +%Y%m%d_%H%M%S)"
fi

# Default global: quatro workspaces.
# Não é reimposto a cada login.
XDG_CONFIG_HOME=/etc/xdg \
    kwriteconfig6 \
        --file kwinrc \
        --group Desktops \
        --key Number \
        4

XDG_CONFIG_HOME=/etc/xdg \
    kwriteconfig6 \
        --file kwinrc \
        --group Desktops \
        --key Rows \
        1

chmod 0644 /etc/xdg/kwinrc

# Ponte obrigatória:
# XFCE Settings -> "Espaços de trabalho"
# tenta chamar xfwm4-workspace-settings.
# Como xfwm4 não existe, esse wrapper abre o KCM do KWin X11.
cat > /usr/local/bin/xfwm4-workspace-settings <<'WRAPPER'
#!/usr/bin/env bash
exec /usr/bin/kcmshell6 kcm_kwin_virtualdesktops_x11 "$@"
WRAPPER

chmod 0755 /usr/local/bin/xfwm4-workspace-settings

cat > /usr/local/bin/xfce-kwin-next-workspace <<'NEXT'
#!/usr/bin/env bash
set -u

/usr/bin/qdbus6 \
    org.kde.KWin \
    /VirtualDesktopManager \
    org.freedesktop.DBus.Properties.Set \
    org.kde.KWin.VirtualDesktopManager \
    navigationWrappingAround \
    true \
    >/dev/null 2>&1 || true

exec /usr/bin/qdbus6 \
    org.kde.kglobalaccel \
    /component/kwin \
    org.kde.kglobalaccel.Component.invokeShortcut \
    'Switch to Next Desktop'
NEXT

chmod 0755 /usr/local/bin/xfce-kwin-next-workspace

cat > /usr/local/bin/xfce-kwin-previous-workspace <<'PREV'
#!/usr/bin/env bash
set -u

/usr/bin/qdbus6 \
    org.kde.KWin \
    /VirtualDesktopManager \
    org.freedesktop.DBus.Properties.Set \
    org.kde.KWin.VirtualDesktopManager \
    navigationWrappingAround \
    true \
    >/dev/null 2>&1 || true

exec /usr/bin/qdbus6 \
    org.kde.kglobalaccel \
    /component/kwin \
    org.kde.kglobalaccel.Component.invokeShortcut \
    'Switch to Previous Desktop'
PREV

chmod 0755 /usr/local/bin/xfce-kwin-previous-workspace

# Configuração inicial por usuário, executada uma única vez.
cat > /usr/local/bin/xfce-kwin-user-setup <<'USERSETUP'
#!/usr/bin/env bash
set -Eeuo pipefail

VERSION=1
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$CONFIG_HOME/xfce-kwin"
MARKER="$STATE_DIR/user-setup-v${VERSION}.done"

[[ -e $MARKER ]] && exit 0

mkdir -p -- "$STATE_DIR"

ready=0
for _ in {1..40}; do
    if /usr/bin/xfconf-query \
        -c xfce4-keyboard-shortcuts \
        -l \
        >/dev/null 2>&1
    then
        ready=1
        break
    fi
    sleep 0.25
done

[[ $ready -eq 1 ]] || {
    echo 'xfconf não ficou disponível a tempo.' >&2
    exit 1
}

set_xfce_shortcut() {
    local prop="$1"
    local value="$2"

    if /usr/bin/xfconf-query \
        -c xfce4-keyboard-shortcuts \
        -p "$prop" \
        >/dev/null 2>&1
    then
        /usr/bin/xfconf-query \
            -c xfce4-keyboard-shortcuts \
            -p "$prop" \
            -s "$value"
    else
        /usr/bin/xfconf-query \
            -c xfce4-keyboard-shortcuts \
            -p "$prop" \
            -n \
            -t string \
            -s "$value"
    fi
}

set_xfce_shortcut \
    '/commands/custom/<Super>Tab' \
    '/usr/local/bin/xfce-kwin-next-workspace'

set_xfce_shortcut \
    '/commands/custom/<Super><Shift>Tab' \
    '/usr/local/bin/xfce-kwin-previous-workspace'

set_xfce_shortcut \
    '/commands/custom/<Super>l' \
    '/usr/bin/xscreensaver-command -lock'

/usr/bin/kwriteconfig6 \
    --file kglobalshortcutsrc \
    --group kwin \
    --key 'Walk Through Windows' \
    'Alt+Tab,Alt+Tab,Walk Through Windows'

/usr/bin/kwriteconfig6 \
    --file kglobalshortcutsrc \
    --group kwin \
    --key 'Walk Through Windows (Reverse)' \
    'Alt+Shift+Backtab,Alt+Shift+Backtab,Walk Through Windows (Reverse)'

/usr/bin/kwriteconfig6 \
    --file kglobalshortcutsrc \
    --group kwin \
    --key 'Window Close' \
    'Alt+F4,Alt+F4,Close Window'

touch -- "$MARKER"
USERSETUP

chmod 0755 /usr/local/bin/xfce-kwin-user-setup

info '4 workspaces padrão configurados sem impor limite permanente.'
info 'ponte XFCE Settings -> KWin Virtual Desktops criada.'
info 'atalhos e navegação circular preparados.'
