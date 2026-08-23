#!/usr/bin/env bash
set -Eeuo pipefail

# Correção LOCAL para a sessão XFCE + KWin X11.
# NÃO altera o GitHub. Execute como usuário da sessão gráfica, sem sudo.
# Alt+Tab continua sob responsabilidade do KWin/KGlobalAccel.

CHANNEL='xfce4-keyboard-shortcuts'
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/xfce-kwin-shortcuts-fix"
XFCE_XML="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml"

# A combinação antiga do htop não ficou registrada na documentação recuperada.
# Default desta correção: Ctrl+Shift+Esc. Pode ser sobrescrita assim:
# HTOP_SHORTCUT='<Primary><Alt>h' ./configurar-atalhos-xfce-local.sh
HTOP_SHORTCUT="${HTOP_SHORTCUT:-<Primary><Shift>Escape}"

CMD_REVERSE_WINDOWS='/usr/bin/qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Walk Through Windows (Reverse)"'
CMD_NEXT_WORKSPACE='/usr/local/bin/xfce-kwin-next-workspace'
CMD_PREV_WORKSPACE='/usr/local/bin/xfce-kwin-previous-workspace'
CMD_LOCK='/usr/bin/xscreensaver-command -lock'
CMD_CLIPMAN='/usr/bin/xfce4-popup-clipman'
CMD_WHISKER='/usr/bin/xfce4-popup-whiskermenu'
CMD_HTOP='/usr/bin/alacritty -o window.dimensions.columns=120 -o window.dimensions.lines=35 -e /usr/bin/htop'

fail() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }
ok()   { printf '[OK] %s\n' "$*"; }
warn() { printf '[AVISO] %s\n' "$*" >&2; }

[[ ${EUID} -ne 0 ]] || fail 'execute como o usuário da sessão gráfica, sem sudo e sem su.'
[[ -n ${DISPLAY:-} ]] || fail 'DISPLAY não definido; execute dentro da sessão gráfica.'
[[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]] || fail 'DBUS_SESSION_BUS_ADDRESS não definido; execute dentro da sessão gráfica.'

for cmd in xfconf-query qdbus6 kwriteconfig6 alacritty htop xfce4-popup-whiskermenu xfce4-popup-clipman xscreensaver-command; do
    command -v "$cmd" >/dev/null 2>&1 || fail "comando necessário ausente: $cmd"
done

[[ -x "$CMD_NEXT_WORKSPACE" ]] || fail "wrapper ausente: $CMD_NEXT_WORKSPACE"
[[ -x "$CMD_PREV_WORKSPACE" ]] || fail "wrapper ausente: $CMD_PREV_WORKSPACE"

xfconf-query -c "$CHANNEL" -l >/dev/null 2>&1 || fail "não foi possível acessar o canal XFCE: $CHANNEL"

mkdir -p -- "$STATE_DIR"
stamp="$(date +%Y%m%d_%H%M%S)"
backup="$STATE_DIR/xfce4-keyboard-shortcuts.${stamp}.xml"
if [[ -f "$XFCE_XML" ]]; then
    cp -a -- "$XFCE_XML" "$backup"
    ok "backup criado: $backup"
fi

set_shortcut() {
    local key="$1" command="$2" property="/commands/custom/$1"
    if xfconf-query -c "$CHANNEL" -p "$property" >/dev/null 2>&1; then
        xfconf-query -c "$CHANNEL" -p "$property" -s "$command"
    else
        xfconf-query -c "$CHANNEL" -p "$property" -n -t string -s "$command"
    fi
}

# Faz o conjunto customizado do XFCE prevalecer.
if xfconf-query -c "$CHANNEL" -p /commands/custom/override >/dev/null 2>&1; then
    xfconf-query -c "$CHANNEL" -p /commands/custom/override -s true
else
    xfconf-query -c "$CHANNEL" -p /commands/custom/override -n -t bool -s true
fi

# Alt+Shift+Tab passa a ser capturado pelo XFCE.
# Alt+Tab NÃO é alterado.
kwriteconfig6 \
    --file kglobalshortcutsrc \
    --group kwin \
    --key 'Walk Through Windows (Reverse)' \
    'none,none,Walk Through Windows (Reverse)'

# Tenta retirar o binding ativo do daemon KGlobalAccel sem reiniciar a sessão.
if command -v gdbus >/dev/null 2>&1; then
    if gdbus call \
        --session \
        --dest org.kde.kglobalaccel \
        --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.setShortcut \
        "['kwin','Walk Through Windows (Reverse)','KWin','Walk Through Windows (Reverse)']" \
        '[]' 4 >/dev/null 2>&1; then
        ok 'binding ativo de Alt+Shift+Tab removido do KGlobalAccel.'
    else
        warn 'não foi possível limpar o binding ativo via D-Bus; pode ser necessário logout/login.'
    fi
fi

set_shortcut '<Alt><Shift>Tab'     "$CMD_REVERSE_WINDOWS"
set_shortcut '<Super>Tab'          "$CMD_NEXT_WORKSPACE"
set_shortcut '<Super><Shift>Tab'   "$CMD_PREV_WORKSPACE"
set_shortcut '<Super>l'            "$CMD_LOCK"
set_shortcut '<Super>v'            "$CMD_CLIPMAN"
set_shortcut 'Super_L'             "$CMD_WHISKER"
set_shortcut 'Super_R'             "$CMD_WHISKER"
set_shortcut "$HTOP_SHORTCUT"     "$CMD_HTOP"

printf '\nAtalhos configurados no XFCE:\n'
printf '  Alt+Shift+Tab      -> janela anterior via KWin\n'
printf '  Super+Tab          -> próximo workspace\n'
printf '  Super+Shift+Tab    -> workspace anterior\n'
printf '  Super+L            -> bloquear sessão\n'
printf '  Super+V            -> Clipman\n'
printf '  Super              -> Whisker Menu\n'
printf '  %s -> htop no Alacritty\n' "$HTOP_SHORTCUT"
printf '\nAlt+Tab foi preservado no KWin/KGlobalAccel.\n\n'

xfconf-query -c "$CHANNEL" -lv | grep -E \
    '/commands/custom/(<Alt><Shift>Tab|<Super>Tab|<Super><Shift>Tab|<Super>l|<Super>v|Super_L|Super_R|<Primary><Shift>Escape)' \
    || true

ok 'configuração concluída.'
printf 'Teste os atalhos. Se Alt+Shift+Tab ainda não responder, faça logout/login uma vez.\n'
