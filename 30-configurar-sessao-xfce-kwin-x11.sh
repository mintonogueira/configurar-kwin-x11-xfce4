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

for bin in \
    /usr/bin/kwin_x11 \
    /usr/bin/xfsettingsd \
    /usr/lib/kglobalacceld \
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
    /usr/bin/xscreensaver \
    /usr/bin/xfdesktop \
    /usr/bin/xfce4-panel \
    /usr/bin/xfce4-power-manager \
    /usr/bin/nm-applet \
    /usr/bin/blueman-applet \
    /usr/bin/thunar
do
    [[ -x $bin ]] || fail "executável obrigatório ausente: $bin"
done

backup_if_exists() {
    local path="$1"

    [[ -e $path ]] || return 0

    cp -a -- \
        "$path" \
        "${path}.backup-xfce-kwin-$(date +%Y%m%d_%H%M%S)"
}

install -d -m 0755 \
    /usr/share/xsessions \
    /usr/local/bin \
    /etc/lightdm/lightdm.conf.d

backup_if_exists /usr/share/xsessions/xfce-kwin.desktop

cat > /usr/share/xsessions/xfce-kwin.desktop <<'DESKTOP'
[Desktop Entry]
Name=XFCE + KWin X11
Comment=XFCE desktop shell with KWin X11 as the only window manager/compositor
Exec=/usr/local/bin/start-xfce-kwin
TryExec=/usr/local/bin/start-xfce-kwin
Type=Application
DesktopNames=XFCE
DESKTOP

chmod 0644 /usr/share/xsessions/xfce-kwin.desktop

backup_if_exists /usr/local/bin/start-xfce-kwin

cat > /usr/local/bin/start-xfce-kwin <<'STARTUP'
#!/usr/bin/env bash
set -u

export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce-kwin
export DESKTOP_SESSION=xfce-kwin

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/xfce-kwin"
mkdir -p -- "$STATE_DIR"
LOG="$STATE_DIR/session.log"

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG"
}

start_bg() {
    "$@" >> "$LOG" 2>&1 &
}

log 'iniciando sessão XFCE + KWin X11'

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment \
        --systemd \
        DISPLAY \
        XAUTHORITY \
        XDG_CURRENT_DESKTOP \
        XDG_SESSION_DESKTOP \
        DESKTOP_SESSION \
        >> "$LOG" 2>&1 || true
fi

start_bg /usr/bin/xfsettingsd

if [[ -x /usr/local/bin/xfce-kwin-user-setup ]]; then
    /usr/local/bin/xfce-kwin-user-setup \
        >> "$LOG" 2>&1 ||
        log 'AVISO: xfce-kwin-user-setup retornou erro'
fi

start_bg /usr/lib/kglobalacceld
start_bg /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
start_bg /usr/bin/xscreensaver -no-splash
start_bg /usr/bin/xfce4-power-manager
start_bg /usr/bin/xfdesktop
start_bg /usr/bin/xfce4-panel

if [[ -x /usr/local/bin/xfce-kwin-panel-setup ]]; then
    start_bg /usr/local/bin/xfce-kwin-panel-setup
fi

start_bg /usr/bin/nm-applet
start_bg /usr/bin/blueman-applet
start_bg /usr/bin/thunar --daemon

log 'transferindo o processo principal da sessão para kwin_x11'
exec /usr/bin/kwin_x11 >> "$LOG" 2>&1
STARTUP

chmod 0755 /usr/local/bin/start-xfce-kwin

LIGHTDM_DROPIN='/etc/lightdm/lightdm.conf.d/50-xfce-kwin.conf'
backup_if_exists "$LIGHTDM_DROPIN"

cat > "$LIGHTDM_DROPIN" <<'LIGHTDM'
[Seat:*]
greeter-session=lightdm-slick-greeter
user-session=xfce-kwin
LIGHTDM

chmod 0644 "$LIGHTDM_DROPIN"

[[ -f /usr/share/xgreeters/lightdm-slick-greeter.desktop ]] ||
    fail 'desktop do Slick Greeter ausente.'

info 'sessão XFCE + KWin X11 configurada.'
info 'LightDM configurado via /etc/lightdm/lightdm.conf.d/50-xfce-kwin.conf.'
