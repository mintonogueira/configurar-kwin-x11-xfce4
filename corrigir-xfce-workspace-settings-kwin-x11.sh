#!/bin/sh

# corrigir-xfce-workspace-settings-kwin-x11.sh
# Instala uma camada global de compatibilidade para o XFCE quando xfwm4 foi
# substituido por KWin X11. O XFCE pode tentar executar
# "xfwm4-workspace-settings"; este shim redireciona a chamada ao KCM de
# desktops virtuais do KWin.
#
# Shell: POSIX sh
# Plataforma inicial: Arch Linux + XFCE/X11 + KWin X11

set -u

PROGRAM='corrigir-xfce-workspace-settings-kwin-x11'
VERSION='1.0.0'
TARGET='/usr/local/bin/xfwm4-workspace-settings'
BACKUP_ROOT="/var/backups/$PROGRAM"
LOG_FILE="/var/log/$PROGRAM.log"

usage() {
    cat <<EOF_USAGE
Uso:
  $0 install
  $0 status
  $0 remove
  $0 --help

Comandos:
  install  Instala/atualiza o shim global XFCE -> KWin.
  status   Verifica dependencias e estado do shim.
  remove   Remove apenas o shim instalado por este script.

Sem argumentos, o modo padrao e: install
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

require_root() {
    [ "$(id -u)" -eq 0 ] || fail 'Execute como root (sudo ou su -).'
}

require_arch() {
    [ -f /etc/arch-release ] || fail 'Esta versao suporta somente Arch Linux.'
    command -v pacman >/dev/null 2>&1 || fail 'pacman nao encontrado.'
}

install_dependencies() {
    log 'Garantindo dependencias necessarias...'
    pacman -S --needed --noconfirm kwin-x11 kcmutils || fail 'Falha instalando kwin-x11/kcmutils.'

    command -v kwin_x11 >/dev/null 2>&1 || fail 'kwin_x11 nao encontrado.'
    command -v kcmshell6 >/dev/null 2>&1 || fail 'kcmshell6 nao encontrado.'

    if [ ! -f /usr/share/applications/kcm_kwin_virtualdesktops_x11.desktop ] && \
       [ ! -f /usr/share/applications/kcm_kwin_virtualdesktops.desktop ]; then
        fail 'O modulo de desktops virtuais do KWin nao foi encontrado.'
    fi
}

backup_existing() {
    if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
        stamp=$(date '+%Y%m%d_%H%M%S')
        dir="$BACKUP_ROOT/$stamp"
        mkdir -p "$dir" || fail "Falha criando backup em $dir"
        cp -p "$TARGET" "$dir/xfwm4-workspace-settings" || fail 'Falha salvando o shim anterior.'
        log "Backup do arquivo anterior: $dir/xfwm4-workspace-settings"
    fi
}

write_shim() {
    tmp="$TARGET.tmp.$$"
    umask 022

    cat > "$tmp" <<'EOF_SHIM'
#!/bin/sh

# Compatibilidade global XFCE -> KWin X11.
# Algumas partes do XFCE ainda chamam "xfwm4-workspace-settings" para abrir
# o configurador de areas de trabalho. Como xfwm4 foi removido, redirecionamos
# para o configurador real de desktops virtuais do KWin.

if ! command -v kcmshell6 >/dev/null 2>&1; then
    printf '%s\n' 'Erro: kcmshell6 nao foi encontrado. Instale o pacote kcmutils.' >&2
    exit 1
fi

if [ -n "${XDG_SESSION_TYPE-}" ] && [ "$XDG_SESSION_TYPE" != 'x11' ]; then
    printf '%s\n' 'Erro: esta integracao foi projetada para uma sessao X11.' >&2
    exit 1
fi

# KWin X11 atual no Arch Linux.
if [ -f /usr/share/applications/kcm_kwin_virtualdesktops_x11.desktop ]; then
    exec kcmshell6 kcm_kwin_virtualdesktops_x11
fi

# Fallback para instalacoes/versoes que usam o identificador sem sufixo X11.
if [ -f /usr/share/applications/kcm_kwin_virtualdesktops.desktop ]; then
    exec kcmshell6 kcm_kwin_virtualdesktops
fi

printf '%s\n' 'Erro: modulo de desktops virtuais do KWin nao encontrado.' >&2
exit 1
EOF_SHIM

    chown root:root "$tmp" || {
        rm -f "$tmp"
        fail 'Falha ajustando proprietario do arquivo temporario.'
    }
    chmod 755 "$tmp" || {
        rm -f "$tmp"
        fail 'Falha ajustando permissoes do arquivo temporario.'
    }

    mv -f "$tmp" "$TARGET" || {
        rm -f "$tmp"
        fail "Falha instalando $TARGET"
    }
}

validate_install() {
    [ -x "$TARGET" ] || fail "Shim ausente ou nao executavel: $TARGET"

    if ! grep -q 'kcm_kwin_virtualdesktops_x11' "$TARGET" 2>/dev/null; then
        fail 'O shim instalado nao contem o redirecionamento esperado.'
    fi

    command -v xfwm4-workspace-settings >/dev/null 2>&1 || fail 'O comando xfwm4-workspace-settings nao esta visivel no PATH atual.'

    resolved=$(command -v xfwm4-workspace-settings)
    if [ "$resolved" != "$TARGET" ]; then
        warn "O PATH atual resolve xfwm4-workspace-settings para $resolved, e nao para $TARGET."
        warn 'Confirme que /usr/local/bin aparece antes de /usr/bin no PATH das sessoes XFCE.'
    fi

    log 'Validacao estatica concluida.'
}

install_all() {
    require_root
    require_arch

    mkdir -p "$BACKUP_ROOT" || fail "Falha criando $BACKUP_ROOT"
    : >> "$LOG_FILE" || fail "Falha escrevendo em $LOG_FILE"

    log "Iniciando $PROGRAM $VERSION"
    install_dependencies
    backup_existing
    write_shim
    validate_install

    log 'Correcao instalada globalmente para todos os usuarios.'
    log 'Teste no XFCE: abra novamente Configuracoes dos espacos de trabalho.'
}

show_status() {
    require_arch

    printf '%s\n' "=== $PROGRAM $VERSION ==="

    printf '%s' 'kwin-x11: '
    if pacman -Q kwin-x11 >/dev/null 2>&1; then
        pacman -Q kwin-x11
    else
        printf '%s\n' 'nao instalado'
    fi

    printf '%s' 'kcmutils: '
    if pacman -Q kcmutils >/dev/null 2>&1; then
        pacman -Q kcmutils
    else
        printf '%s\n' 'nao instalado'
    fi

    printf 'kcmshell6: %s\n' "$(command -v kcmshell6 2>/dev/null || printf '%s' 'ausente')"

    if [ -x "$TARGET" ]; then
        printf 'shim: OK (%s)\n' "$TARGET"
    else
        printf 'shim: AUSENTE/INVALIDO (%s)\n' "$TARGET"
    fi

    if command -v xfwm4-workspace-settings >/dev/null 2>&1; then
        printf 'resolucao PATH: %s\n' "$(command -v xfwm4-workspace-settings)"
    else
        printf '%s\n' 'resolucao PATH: comando nao encontrado'
    fi

    if [ -f /usr/share/applications/kcm_kwin_virtualdesktops_x11.desktop ]; then
        printf '%s\n' 'KCM: kcm_kwin_virtualdesktops_x11'
    elif [ -f /usr/share/applications/kcm_kwin_virtualdesktops.desktop ]; then
        printf '%s\n' 'KCM: kcm_kwin_virtualdesktops'
    else
        printf '%s\n' 'KCM: nao encontrado'
    fi
}

remove_shim() {
    require_root
    require_arch

    if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
        rm -f "$TARGET" || fail "Falha removendo $TARGET"
        log "Removido: $TARGET"
    else
        log 'O shim ja estava ausente.'
    fi
}

case ${1-install} in
    install)
        install_all
        ;;
    status)
        show_status
        ;;
    remove)
        remove_shim
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
