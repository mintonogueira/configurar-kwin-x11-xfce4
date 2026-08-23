#!/usr/bin/env bash
set -Eeuo pipefail

# configurar-atalhos-xfce-local.sh
#
# Correção LOCAL para a sessão XFCE + KWin X11.
# Script opcional, fora do fluxo mestre. NÃO exige root.
#
# Regra:
#   - Alt+Tab continua sob responsabilidade direta do KWin/KGlobalAccel.
#   - Os demais atalhos abaixo são capturados pelo XFCE.
#   - Super+Tab e Super+Shift+Tab chamam ações nativas do KWin via D-Bus
#     e ativam navigationWrappingAround=true antes da troca de workspace.
#
# Atalhos configurados:
#   Alt+Shift+Tab       -> janela anterior via KWin/KGlobalAccel
#   Super+Tab           -> próximo workspace, com ciclo contínuo
#   Super+Shift+Tab     -> workspace anterior, com ciclo contínuo
#   Super+L             -> bloquear com XScreenSaver
#   Super+V             -> Clipman
#   Super (tecla Win)   -> Whisker Menu
#   Ctrl+Shift+Esc      -> htop no Alacritty
#   Ctrl+Alt+Del        -> htop no Alacritty
#

CHANNEL='xfce4-keyboard-shortcuts'
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/xfce-kwin-shortcuts-fix"
XFCE_XML="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml"

CMD_REVERSE_WINDOWS='/usr/bin/qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Walk Through Windows (Reverse)"'

CMD_NEXT_WORKSPACE='sh -c '\''qdbus6 org.kde.KWin /VirtualDesktopManager org.freedesktop.DBus.Properties.Set org.kde.KWin.VirtualDesktopManager navigationWrappingAround true >/dev/null; qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Switch to Next Desktop"'\'''

CMD_PREV_WORKSPACE='sh -c '\''qdbus6 org.kde.KWin /VirtualDesktopManager org.freedesktop.DBus.Properties.Set org.kde.KWin.VirtualDesktopManager navigationWrappingAround true >/dev/null; qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Switch to Previous Desktop"'\'''

CMD_LOCK='/usr/bin/xscreensaver-command -lock'
CMD_CLIPMAN='/usr/bin/xfce4-popup-clipman'
CMD_WHISKER='/usr/bin/xfce4-popup-whiskermenu'
CMD_HTOP='/usr/bin/alacritty -o window.dimensions.columns=120 -o window.dimensions.lines=35 -e /usr/bin/htop'

fail() {
    printf 'ERRO: %s\n' "$*" >&2
    exit 1
}

ok() {
    printf '[OK] %s\n' "$*"
}

warn() {
    printf '[AVISO] %s\n' "$*" >&2
}

if [[ ${EUID} -eq 0 ]]; then
    fail 'execute este script como o usuário da sessão gráfica, sem sudo e sem su.'
fi

[[ -n ${DISPLAY:-} ]] ||
    fail 'DISPLAY não definido. Execute dentro da sessão gráfica XFCE + KWin X11.'

[[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]] ||
    fail 'DBUS_SESSION_BUS_ADDRESS não definido. Execute dentro da sessão gráfica.'

for cmd in \
    xfconf-query \
    qdbus6 \
    alacritty \
    htop \
    xfce4-popup-whiskermenu \
    xfce4-popup-clipman \
    xscreensaver-command
do
    command -v "$cmd" >/dev/null 2>&1 ||
        fail "comando necessário ausente: $cmd"
done

xfconf-query -c "$CHANNEL" -l >/dev/null 2>&1 ||
    fail "não foi possível acessar o canal XFCE: $CHANNEL"

mkdir -p -- "$STATE_DIR"

stamp="$(date +%Y%m%d_%H%M%S)"
backup="$STATE_DIR/xfce4-keyboard-shortcuts.${stamp}.xml"

if [[ -f "$XFCE_XML" ]]; then
    cp -a -- "$XFCE_XML" "$backup"
    ok "backup criado: $backup"
else
    warn "arquivo XML ainda não existe; o XFCE o criará ao gravar os atalhos."
fi

set_shortcut() {
    local key="$1"
    local command="$2"
    local property="/commands/custom/${key}"

    if xfconf-query \
        -c "$CHANNEL" \
        -p "$property" \
        >/dev/null 2>&1
    then
        xfconf-query \
            -c "$CHANNEL" \
            -p "$property" \
            -s "$command"
    else
        xfconf-query \
            -c "$CHANNEL" \
            -p "$property" \
            -n \
            -t string \
            -s "$command"
    fi
}

# Faz o conjunto customizado prevalecer sobre defaults do XFCE.
if xfconf-query \
    -c "$CHANNEL" \
    -p /commands/custom/override \
    >/dev/null 2>&1
then
    xfconf-query \
        -c "$CHANNEL" \
        -p /commands/custom/override \
        -s true
else
    xfconf-query \
        -c "$CHANNEL" \
        -p /commands/custom/override \
        -n \
        -t bool \
        -s true
fi

# Alt+Tab NÃO é alterado.
# Alt+Shift+Tab é capturado pelo XFCE e chama a ação reversa nativa do KWin.
set_shortcut \
    '<Alt><Shift>Tab' \
    "$CMD_REVERSE_WINDOWS"

# Workspaces:
# o XFCE captura as teclas, ativa wrapping no KWin via D-Bus e chama a ação
# nativa de troca de desktop do KWin.
set_shortcut \
    '<Super>Tab' \
    "$CMD_NEXT_WORKSPACE"

set_shortcut \
    '<Super><Shift>Tab' \
    "$CMD_PREV_WORKSPACE"

# Bloqueio.
set_shortcut \
    '<Super>l' \
    "$CMD_LOCK"

# Super+V -> Clipman.
set_shortcut \
    '<Super>v' \
    "$CMD_CLIPMAN"

# Tecla Windows/Super sozinha -> Whisker Menu.
set_shortcut \
    'Super_L' \
    "$CMD_WHISKER"

set_shortcut \
    'Super_R' \
    "$CMD_WHISKER"

# htop no Alacritty.
# Ctrl+Shift+Esc.
set_shortcut \
    '<Primary><Shift>Escape' \
    "$CMD_HTOP"

# Ctrl+Alt+Del.
set_shortcut \
    '<Primary><Alt>Delete' \
    "$CMD_HTOP"

printf '\nAtalhos gravados no XFCE:\n\n'
printf '  %-24s %s\n' 'Alt+Shift+Tab'       'janela anterior via KWin/KGlobalAccel'
printf '  %-24s %s\n' 'Super+Tab'           'próximo workspace com wrapping'
printf '  %-24s %s\n' 'Super+Shift+Tab'     'workspace anterior com wrapping'
printf '  %-24s %s\n' 'Super+L'             'bloquear sessão'
printf '  %-24s %s\n' 'Super+V'             'Clipman'
printf '  %-24s %s\n' 'Super / tecla Win'   'Whisker Menu'
printf '  %-24s %s\n' 'Ctrl+Shift+Esc'       'htop no Alacritty'
printf '  %-24s %s\n' 'Ctrl+Alt+Del'         'htop no Alacritty'
printf '\n'

printf 'Alt+Tab NÃO foi alterado.\n\n'

printf 'Comandos de workspace configurados:\n\n'
printf 'Super+Tab:\n%s\n\n' "$CMD_NEXT_WORKSPACE"
printf 'Super+Shift+Tab:\n%s\n\n' "$CMD_PREV_WORKSPACE"

ok 'configuração concluída.'
