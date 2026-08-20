#!/bin/sh

# configurar-kwin-x11-xfce4.sh
# Implanta KWin X11 como gerenciador de janelas e compositor padrão do XFCE
# no Arch Linux, com configuração global para novos usuários.
#
# Shell: POSIX sh
# Projeto: https://github.com/mintonogueira/configurar-kwin-x11-xfce4

set -u

PROGRAM='configurar-kwin-x11-xfce4'
VERSION='1.0.0'
BACKUP_ROOT="/var/backups/$PROGRAM"
LOG_FILE="/var/log/$PROGRAM.log"
WRAPPER='/usr/local/bin/kwin-xfce-session'
SESSION_XML='/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml'
KEYBOARD_XML='/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml'
SKEL_CONFIG='/etc/skel/.config'
GLOBAL_KWINRC='/etc/xdg/kwinrc'
GLOBAL_KSHORTCUTS='/etc/xdg/kglobalshortcutsrc'
OLD_POLICY_DESKTOP='/etc/xdg/autostart/kwin-xfce-shortcuts-policy.desktop'
OLD_POLICY_SCRIPT='/usr/local/bin/kwin-xfce-shortcuts-policy'
BACKUP_DIR=''
TMP_SESSION=''
TMP_KEYBOARD=''

usage() {
    cat <<EOF_USAGE
Uso:
  $0 install
  $0 status
  $0 restore [DIRETORIO_BACKUP]
  $0 --help

Comandos:
  install  Instala e configura KWin X11 globalmente no XFCE.
  status   Exibe o estado da configuração global.
  restore  Restaura a configuração do último backup, ou do backup informado.

Sem argumentos, o comando padrão é: install
EOF_USAGE
}

now() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    line="[$(now)] $*"
    printf '%s\n' "$line"
    printf '%s\n' "$line" >> "$LOG_FILE" 2>/dev/null || true
}

warn() {
    line="[$(now)] [AVISO] $*"
    printf '%s\n' "$line" >&2
    printf '%s\n' "$line" >> "$LOG_FILE" 2>/dev/null || true
}

fail() {
    line="[$(now)] [ERRO] $*"
    printf '%s\n' "$line" >&2
    printf '%s\n' "$line" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
}

cleanup() {
    [ -n "$TMP_SESSION" ] && [ -e "$TMP_SESSION" ] && rm -f "$TMP_SESSION"
    [ -n "$TMP_KEYBOARD" ] && [ -e "$TMP_KEYBOARD" ] && rm -f "$TMP_KEYBOARD"
}

trap 'cleanup' 0 1 2 3 15

require_root() {
    [ "$(id -u)" -eq 0 ] || fail 'Execute este comando como root (sudo ou su -).'
}

require_arch() {
    [ -f /etc/arch-release ] || fail 'Esta versão suporta somente Arch Linux.'
    command -v pacman >/dev/null 2>&1 || fail 'pacman não encontrado.'
}

require_xfce() {
    pacman -Q xfce4-session >/dev/null 2>&1 || fail 'xfce4-session não está instalado.'
    pacman -Q xfce4-settings >/dev/null 2>&1 || fail 'xfce4-settings não está instalado.'
    pacman -Q xfconf >/dev/null 2>&1 || fail 'xfconf não está instalado.'
    [ -f "$SESSION_XML" ] || fail "Arquivo global do XFCE não encontrado: $SESSION_XML"
}

backup_one() {
    src=$1
    dst="$BACKUP_DIR/files$src"
    parent=$(dirname "$dst")
    mkdir -p "$parent" || fail "Falha criando backup: $parent"

    if [ -e "$src" ] || [ -L "$src" ]; then
        cp -p "$src" "$dst" || fail "Falha salvando backup de $src"
    else
        : > "$dst.__MISSING__" || fail "Falha registrando ausência de $src"
    fi
}

restore_one() {
    src=$1
    saved="$BACKUP_DIR/files$src"
    marker="$saved.__MISSING__"

    if [ -f "$marker" ]; then
        rm -f "$src"
        return 0
    fi

    if [ -e "$saved" ] || [ -L "$saved" ]; then
        mkdir -p "$(dirname "$src")" || return 1
        cp -p "$saved" "$src" || return 1
    fi

    return 0
}

create_backup() {
    stamp=$(date '+%Y%m%d_%H%M%S')
    BACKUP_DIR="$BACKUP_ROOT/$stamp"

    mkdir -p "$BACKUP_DIR" || fail "Não foi possível criar $BACKUP_DIR"

    backup_one "$SESSION_XML"
    backup_one "$KEYBOARD_XML"
    backup_one "$WRAPPER"
    backup_one "$SKEL_CONFIG/kwinrc"
    backup_one "$SKEL_CONFIG/kglobalshortcutsrc"
    backup_one "$GLOBAL_KWINRC"
    backup_one "$GLOBAL_KSHORTCUTS"
    backup_one "$OLD_POLICY_DESKTOP"
    backup_one "$OLD_POLICY_SCRIPT"

    : > "$BACKUP_DIR/packages.before"
    for pkg in xfwm4 xfwm4-themes picom; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            printf '%s\n' "$pkg" >> "$BACKUP_DIR/packages.before"
        fi
    done

    printf '%s\n' "$BACKUP_DIR" > "$BACKUP_ROOT/LAST_BACKUP"
    log "Backup criado em: $BACKUP_DIR"
}

install_dependencies() {
    log 'Instalando dependências oficiais do Arch Linux...'
    pacman -S --needed --noconfirm \
        kwin-x11 \
        systemsettings \
        wmctrl \
        xmlstarlet || fail 'Falha instalando dependências.'

    command -v kwin_x11 >/dev/null 2>&1 || fail 'kwin_x11 não foi instalado corretamente.'
    command -v kwriteconfig6 >/dev/null 2>&1 || fail 'kwriteconfig6 não foi encontrado.'
    command -v kreadconfig6 >/dev/null 2>&1 || fail 'kreadconfig6 não foi encontrado.'
    command -v xmlstarlet >/dev/null 2>&1 || fail 'xmlstarlet não foi encontrado.'
}

write_wrapper() {
    log "Instalando wrapper global: $WRAPPER"

    cat > "$WRAPPER" <<'EOF_WRAPPER'
#!/bin/sh

# Inicializa o daemon de atalhos globais do KDE no escopo do usuário.
systemctl --user start plasma-kglobalaccel.service || exit 1

# KWin X11 assume gerenciamento de janelas e composição da sessão XFCE.
exec /usr/bin/kwin_x11
EOF_WRAPPER

    chown root:root "$WRAPPER" || fail 'Falha ajustando proprietário do wrapper.'
    chmod 755 "$WRAPPER" || fail 'Falha ajustando permissões do wrapper.'
}

patch_xfce_session() {
    log 'Configurando KWin X11 como Window Manager da sessão XFCE/X11...'

    count=$(xmlstarlet sel -t -v \
        "count(/channel/property[@name='sessions']/property[@name='Failsafe']/property[@name='Client0_Command']/value[1]/@value)" \
        "$SESSION_XML" 2>/dev/null) || fail 'Não foi possível analisar xfce4-session.xml.'

    [ "$count" = '1' ] || fail 'Estrutura inesperada em xfce4-session.xml; nenhuma alteração foi feita.'

    TMP_SESSION="$SESSION_XML.tmp.$$"
    umask 022

    xmlstarlet ed \
        -u "/channel/property[@name='sessions']/property[@name='Failsafe']/property[@name='Client0_Command']/value[1]/@value" \
        -v "$WRAPPER" \
        "$SESSION_XML" > "$TMP_SESSION" || fail 'Falha alterando xfce4-session.xml.'

    xmlstarlet val -e "$TMP_SESSION" >/dev/null 2>&1 || fail 'XML de sessão resultante é inválido.'
    cat "$TMP_SESSION" > "$SESSION_XML" || fail 'Falha gravando xfce4-session.xml.'
    rm -f "$TMP_SESSION"
    TMP_SESSION=''

    value=$(xmlstarlet sel -t -v \
        "/channel/property[@name='sessions']/property[@name='Failsafe']/property[@name='Client0_Command']/value[1]/@value" \
        "$SESSION_XML" 2>/dev/null)

    [ "$value" = "$WRAPPER" ] || fail 'Validação do Client0_Command falhou.'
}

patch_xfce_keyboard() {
    [ -f "$KEYBOARD_XML" ] || return 0

    log 'Removendo atalhos XFCE conflitantes e desativando o provider xfwm4...'

    TMP_KEYBOARD="$KEYBOARD_XML.tmp.$$"
    umask 022

    xmlstarlet ed \
        -d "/channel/property[@name='commands']/property[@name='custom']/property[@name='<Super>Tab']" \
        -d "/channel/property[@name='commands']/property[@name='custom']/property[@name='<Shift><Super>ISO_Left_Tab']" \
        -d "/channel/property[@name='commands']/property[@name='custom']/property[@name='<Super>ISO_Left_Tab']" \
        -d "/channel/property[@name='commands']/property[@name='custom']/property[@name='<Super><Shift>Tab']" \
        "$KEYBOARD_XML" > "$TMP_KEYBOARD" || fail 'Falha limpando atalhos globais do XFCE.'

    cat "$TMP_KEYBOARD" > "$KEYBOARD_XML" || fail 'Falha atualizando atalhos globais do XFCE.'
    rm -f "$TMP_KEYBOARD"
    TMP_KEYBOARD=''

    providers=$(xmlstarlet sel -t -v "count(/channel/property[@name='providers'])" "$KEYBOARD_XML" 2>/dev/null) || fail 'Falha lendo providers do XFCE.'

    TMP_KEYBOARD="$KEYBOARD_XML.tmp.$$"

    if [ "$providers" = '0' ]; then
        xmlstarlet ed \
            -s /channel -t elem -n property -v '' \
            -i '/channel/property[last()]' -t attr -n name -v providers \
            -i '/channel/property[last()]' -t attr -n type -v array \
            -s '/channel/property[last()]' -t elem -n value -v '' \
            -i '/channel/property[last()]/value[last()]' -t attr -n type -v string \
            -i '/channel/property[last()]/value[last()]' -t attr -n value -v commands \
            "$KEYBOARD_XML" > "$TMP_KEYBOARD" || fail 'Falha criando provider commands.'
    else
        xmlstarlet ed \
            -u "/channel/property[@name='providers']/@type" -v array \
            -d "/channel/property[@name='providers']/value" \
            -s "/channel/property[@name='providers']" -t elem -n value -v '' \
            -i "/channel/property[@name='providers']/value[last()]" -t attr -n type -v string \
            -i "/channel/property[@name='providers']/value[last()]" -t attr -n value -v commands \
            "$KEYBOARD_XML" > "$TMP_KEYBOARD" || fail 'Falha atualizando provider commands.'
    fi

    xmlstarlet val -e "$TMP_KEYBOARD" >/dev/null 2>&1 || fail 'XML de atalhos resultante é inválido.'
    cat "$TMP_KEYBOARD" > "$KEYBOARD_XML" || fail 'Falha gravando atalhos globais do XFCE.'
    rm -f "$TMP_KEYBOARD"
    TMP_KEYBOARD=''
}

configure_skeleton() {
    log 'Configurando /etc/skel para novos usuários...'

    mkdir -p "$SKEL_CONFIG" || fail 'Falha criando /etc/skel/.config.'

    # Quatro workspaces são APENAS o estado inicial do usuário novo.
    # O wrapper NÃO regrava este valor em logins futuros; o usuário pode
    # criar 5, 6, 7, 8 ou mais workspaces depois.
    XDG_CONFIG_HOME="$SKEL_CONFIG" kwriteconfig6 \
        --file kwinrc --group Desktops --key Number 4 || fail 'Falha definindo Number=4 no skeleton.'

    XDG_CONFIG_HOME="$SKEL_CONFIG" kwriteconfig6 \
        --file kwinrc --group Desktops --key Rows 1 || fail 'Falha definindo Rows=1 no skeleton.'

    XDG_CONFIG_HOME="$SKEL_CONFIG" kwriteconfig6 \
        --file kglobalshortcutsrc --group kwin --key 'Walk Through Windows' \
        'Alt+Tab,Alt+Tab,Walk Through Windows' || fail 'Falha configurando Alt+Tab.'

    XDG_CONFIG_HOME="$SKEL_CONFIG" kwriteconfig6 \
        --file kglobalshortcutsrc --group kwin --key 'Walk Through Windows (Reverse)' \
        'Alt+Shift+Tab,Alt+Shift+Tab,Walk Through Windows (Reverse)' || fail 'Falha configurando Alt+Shift+Tab.'

    XDG_CONFIG_HOME="$SKEL_CONFIG" kwriteconfig6 \
        --file kglobalshortcutsrc --group kwin --key 'Window Close' \
        'Alt+F4,Alt+F4,Close Window' || fail 'Falha configurando Alt+F4.'

    XDG_CONFIG_HOME="$SKEL_CONFIG" kwriteconfig6 \
        --file kglobalshortcutsrc --group kwin --key 'Switch to Next Desktop' \
        'Meta+Tab,Meta+Tab,Switch to Next Desktop' || fail 'Falha configurando Super+Tab.'

    XDG_CONFIG_HOME="$SKEL_CONFIG" kwriteconfig6 \
        --file kglobalshortcutsrc --group kwin --key 'Switch to Previous Desktop' \
        'Meta+Shift+Tab,Meta+Shift+Tab,Switch to Previous Desktop' || fail 'Falha configurando Super+Shift+Tab.'

    chown root:root "$SKEL_CONFIG/kwinrc" "$SKEL_CONFIG/kglobalshortcutsrc" || fail 'Falha ajustando proprietário do skeleton.'
    chmod 644 "$SKEL_CONFIG/kwinrc" "$SKEL_CONFIG/kglobalshortcutsrc" || fail 'Falha ajustando permissões do skeleton.'
}

cleanup_failed_experiments() {
    log 'Limpando somente artefatos conhecidos das abordagens antigas...'

    legacy_workspace_policy=0

    if [ -f "$OLD_POLICY_DESKTOP" ] || [ -f "$OLD_POLICY_SCRIPT" ]; then
        legacy_workspace_policy=1
    fi

    if [ -f "$WRAPPER" ]; then
        if grep -q 'kwriteconfig6' "$WRAPPER" 2>/dev/null && \
           grep -q -- '--key Number' "$WRAPPER" 2>/dev/null; then
            legacy_workspace_policy=1
        fi
    fi

    rm -f "$OLD_POLICY_DESKTOP" "$OLD_POLICY_SCRIPT"

    # Versão antiga errada: Number=4/Rows=1 em /etc/xdg/kwinrc somada ao
    # wrapper que regravava Number=4 transformava o valor inicial em política.
    # Só limpamos essa configuração quando detectamos a implementação antiga.
    if [ "$legacy_workspace_policy" -eq 1 ] && [ -f "$GLOBAL_KWINRC" ]; then
        old_number=$(XDG_CONFIG_HOME=/etc/xdg kreadconfig6 --file kwinrc --group Desktops --key Number 2>/dev/null || true)
        old_rows=$(XDG_CONFIG_HOME=/etc/xdg kreadconfig6 --file kwinrc --group Desktops --key Rows 2>/dev/null || true)

        if [ "$old_number" = '4' ] && [ "$old_rows" = '1' ]; then
            XDG_CONFIG_HOME=/etc/xdg kwriteconfig6 --file kwinrc --group Desktops --key Number --delete >/dev/null 2>&1 || true
            XDG_CONFIG_HOME=/etc/xdg kwriteconfig6 --file kwinrc --group Desktops --key Rows --delete >/dev/null 2>&1 || true
            log 'Removida a antiga imposição global Number=4/Rows=1 de /etc/xdg/kwinrc.'
        fi
    fi

    # Outra abordagem antiga criava um /etc/xdg/kglobalshortcutsrc manual com
    # workspaces desabilitados. Removemos somente quando o fingerprint é exato
    # e o arquivo não pertence a pacote do Arch.
    if [ -f "$GLOBAL_KSHORTCUTS" ]; then
        if ! pacman -Qo "$GLOBAL_KSHORTCUTS" >/dev/null 2>&1; then
            if grep -q '^Switch to Next Desktop=none,none,' "$GLOBAL_KSHORTCUTS" 2>/dev/null && \
               grep -q '^Switch to Previous Desktop=none,none,' "$GLOBAL_KSHORTCUTS" 2>/dev/null; then
                rm -f "$GLOBAL_KSHORTCUTS"
                log 'Removido /etc/xdg/kglobalshortcutsrc da abordagem antiga conflitante.'
            fi
        fi
    fi
}

remove_conflicts() {
    remove_pkgs=''

    for pkg in xfwm4 xfwm4-themes picom; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            remove_pkgs="$remove_pkgs $pkg"
        fi
    done

    if [ -n "$remove_pkgs" ]; then
        log "Removendo gerenciador/compositor conflitante:$remove_pkgs"
        # Intencionalmente sem -d/--nodeps. Se outro pacote depender de um dos
        # itens, pacman deve bloquear a operação em vez de quebrar dependências.
        # shellcheck disable=SC2086
        pacman -Rns --noconfirm $remove_pkgs || fail 'pacman bloqueou a remoção. Nenhuma dependência será forçada.'
    else
        log 'xfwm4/xfwm4-themes/picom já estão ausentes.'
    fi
}

validate_install() {
    log 'Validando arquivos e configuração...'

    [ -x "$WRAPPER" ] || fail 'Wrapper global não é executável.'

    client0=$(xmlstarlet sel -t -v \
        "/channel/property[@name='sessions']/property[@name='Failsafe']/property[@name='Client0_Command']/value[1]/@value" \
        "$SESSION_XML" 2>/dev/null || true)
    [ "$client0" = "$WRAPPER" ] || fail 'XFCE não aponta para o wrapper do KWin.'

    number=$(XDG_CONFIG_HOME="$SKEL_CONFIG" kreadconfig6 --file kwinrc --group Desktops --key Number 2>/dev/null || true)
    rows=$(XDG_CONFIG_HOME="$SKEL_CONFIG" kreadconfig6 --file kwinrc --group Desktops --key Rows 2>/dev/null || true)
    [ "$number" = '4' ] || fail 'Skeleton não contém Number=4.'
    [ "$rows" = '1' ] || fail 'Skeleton não contém Rows=1.'

    next=$(XDG_CONFIG_HOME="$SKEL_CONFIG" kreadconfig6 --file kglobalshortcutsrc --group kwin --key 'Switch to Next Desktop' 2>/dev/null || true)
    prev=$(XDG_CONFIG_HOME="$SKEL_CONFIG" kreadconfig6 --file kglobalshortcutsrc --group kwin --key 'Switch to Previous Desktop' 2>/dev/null || true)
    [ "$next" = 'Meta+Tab,Meta+Tab,Switch to Next Desktop' ] || fail 'Atalho Super+Tab inválido no skeleton.'
    [ "$prev" = 'Meta+Shift+Tab,Meta+Shift+Tab,Switch to Previous Desktop' ] || fail 'Atalho Super+Shift+Tab inválido no skeleton.'

    log 'Validação estática concluída com sucesso.'
}

show_status() {
    require_root
    require_arch

    printf '%s\n' "=== $PROGRAM $VERSION ==="
    printf '%s\n' '--- Pacotes ---'
    for pkg in kwin-x11 systemsettings kglobalacceld xfwm4 xfwm4-themes picom; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            pacman -Q "$pkg"
        else
            printf '%s: não instalado\n' "$pkg"
        fi
    done

    printf '\n%s\n' '--- Wrapper ---'
    if [ -x "$WRAPPER" ]; then
        printf 'OK: %s\n' "$WRAPPER"
    else
        printf 'AUSENTE/INVÁLIDO: %s\n' "$WRAPPER"
    fi

    printf '\n%s\n' '--- XFCE Client0 ---'
    if command -v xmlstarlet >/dev/null 2>&1 && [ -f "$SESSION_XML" ]; then
        xmlstarlet sel -t -v \
            "/channel/property[@name='sessions']/property[@name='Failsafe']/property[@name='Client0_Command']/value[1]/@value" \
            "$SESSION_XML" 2>/dev/null || true
        printf '\n'
    fi

    printf '\n%s\n' '--- /etc/skel: workspaces ---'
    if command -v kreadconfig6 >/dev/null 2>&1; then
        printf 'Number='
        XDG_CONFIG_HOME="$SKEL_CONFIG" kreadconfig6 --file kwinrc --group Desktops --key Number 2>/dev/null || true
        printf 'Rows='
        XDG_CONFIG_HOME="$SKEL_CONFIG" kreadconfig6 --file kwinrc --group Desktops --key Rows 2>/dev/null || true

        printf '\n%s\n' '--- /etc/skel: atalhos ---'
        for key in 'Walk Through Windows' 'Walk Through Windows (Reverse)' 'Window Close' 'Switch to Next Desktop' 'Switch to Previous Desktop'; do
            printf '%s=' "$key"
            XDG_CONFIG_HOME="$SKEL_CONFIG" kreadconfig6 --file kglobalshortcutsrc --group kwin --key "$key" 2>/dev/null || true
        done
    fi
}

restore_backup() {
    require_root
    require_arch

    requested=${1-}

    if [ -n "$requested" ]; then
        BACKUP_DIR=$requested
    else
        [ -f "$BACKUP_ROOT/LAST_BACKUP" ] || fail 'Nenhum LAST_BACKUP encontrado.'
        IFS= read -r BACKUP_DIR < "$BACKUP_ROOT/LAST_BACKUP" || fail 'Falha lendo LAST_BACKUP.'
    fi

    [ -d "$BACKUP_DIR" ] || fail "Backup inexistente: $BACKUP_DIR"

    log "Restaurando backup: $BACKUP_DIR"

    restore_one "$SESSION_XML" || fail "Falha restaurando $SESSION_XML"
    restore_one "$KEYBOARD_XML" || fail "Falha restaurando $KEYBOARD_XML"
    restore_one "$WRAPPER" || fail "Falha restaurando $WRAPPER"
    restore_one "$SKEL_CONFIG/kwinrc" || fail 'Falha restaurando kwinrc do skel.'
    restore_one "$SKEL_CONFIG/kglobalshortcutsrc" || fail 'Falha restaurando atalhos do skel.'
    restore_one "$GLOBAL_KWINRC" || fail "Falha restaurando $GLOBAL_KWINRC"
    restore_one "$GLOBAL_KSHORTCUTS" || fail "Falha restaurando $GLOBAL_KSHORTCUTS"
    restore_one "$OLD_POLICY_DESKTOP" || fail "Falha restaurando $OLD_POLICY_DESKTOP"
    restore_one "$OLD_POLICY_SCRIPT" || fail "Falha restaurando $OLD_POLICY_SCRIPT"

    if [ -s "$BACKUP_DIR/packages.before" ]; then
        packages=$(tr '\n' ' ' < "$BACKUP_DIR/packages.before")
        if [ -n "$packages" ]; then
            log "Reinstalando pacotes que existiam antes:$packages"
            # shellcheck disable=SC2086
            pacman -S --needed --noconfirm $packages || fail 'Falha reinstalando pacotes do estado anterior.'
        fi
    fi

    log 'Restauração concluída. Faça logout/login antes de avaliar a sessão.'
}

install_all() {
    require_root
    require_arch
    require_xfce

    mkdir -p "$BACKUP_ROOT" || fail "Falha criando $BACKUP_ROOT"
    : >> "$LOG_FILE" || fail "Não foi possível escrever em $LOG_FILE"

    log "Iniciando instalação $PROGRAM $VERSION"
    create_backup
    install_dependencies
    cleanup_failed_experiments
    write_wrapper
    patch_xfce_session
    patch_xfce_keyboard
    configure_skeleton
    remove_conflicts
    validate_install

    log 'Instalação concluída.'
    log 'IMPORTANTE: faça logout completo e entre novamente em uma sessão XFCE/X11.'
    log 'Novos usuários começam com 4 workspaces, mas podem criar quantos quiserem depois.'
}

case ${1-install} in
    install)
        install_all
        ;;
    status)
        show_status
        ;;
    restore)
        shift
        restore_backup "${1-}"
        ;;
    --help|-h|help)
        usage
        ;;
    --version|-V)
        printf '%s %s\n' "$PROGRAM" "$VERSION"
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
