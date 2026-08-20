#!/bin/sh

# instalar-dependencias-tumbler-xfce.sh
# Instala bibliotecas opcionais do Tumbler ausentes no Arch Linux para evitar
# falhas de carregamento dos plugins EPUB, ODF e RAW no XFCE.
#
# Shell: POSIX sh
# Plataforma inicial: Arch Linux + XFCE
# Projeto: https://github.com/mintonogueira/configurar-kwin-x11-xfce4

set -u

PROGRAM='instalar-dependencias-tumbler-xfce'
VERSION='1.0.0'
LOG_FILE="/var/log/$PROGRAM.log"
PACKAGES='libgepub libgsf libopenraw'

usage() {
    cat <<EOF_USAGE
Uso:
  $0 install
  $0 status
  $0 --help

Comandos:
  install  Instala as bibliotecas opcionais do Tumbler que estavam ausentes.
  status   Mostra o estado dos pacotes e do serviço Tumbler do usuário atual.

Sem argumentos, o modo padrão é: install
EOF_USAGE
}

now() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    line="[$(now)] $*"
    printf '%s\n' "$line"
    if [ "$(id -u)" -eq 0 ]; then
        printf '%s\n' "$line" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

fail() {
    line="[$(now)] [ERRO] $*"
    printf '%s\n' "$line" >&2
    if [ "$(id -u)" -eq 0 ]; then
        printf '%s\n' "$line" >> "$LOG_FILE" 2>/dev/null || true
    fi
    exit 1
}

require_arch() {
    [ -f /etc/arch-release ] || fail 'Esta versão suporta somente Arch Linux.'
    command -v pacman >/dev/null 2>&1 || fail 'pacman não encontrado.'
}

require_root() {
    [ "$(id -u)" -eq 0 ] || fail 'Execute o modo install como root (sudo ou su -).'
}

check_tumbler() {
    if pacman -Q tumbler >/dev/null 2>&1; then
        pacman -Q tumbler
    else
        fail 'O pacote tumbler não está instalado.'
    fi
}

install_packages() {
    log 'Instalando bibliotecas opcionais usadas pelos plugins do Tumbler...'

    # Sem -Syyu: este script complementar não força atualização completa do
    # sistema. Apenas instala, se necessário, os três pacotes validados.
    # shellcheck disable=SC2086
    pacman -S --needed --noconfirm $PACKAGES || fail 'Falha instalando dependências do Tumbler.'
}

validate_packages() {
    missing=0

    for pkg in $PACKAGES; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            log "OK: $(pacman -Q "$pkg")"
        else
            printf '%s\n' "[ERRO] pacote ausente após instalação: $pkg" >&2
            missing=1
        fi
    done

    [ "$missing" -eq 0 ] || fail 'A validação dos pacotes falhou.'
}

restart_tumbler_for_invoking_user() {
    # Ao executar via sudo, SUDO_UID identifica o usuário da sessão gráfica.
    # Encerramos somente a instância tumblerd desse usuário; o serviço é
    # reativado automaticamente pelo D-Bus/systemd --user quando necessário.
    if [ -n "${SUDO_UID-}" ] && [ "$SUDO_UID" != '0' ] && command -v pkill >/dev/null 2>&1; then
        if pkill -TERM -u "$SUDO_UID" -x tumblerd 2>/dev/null; then
            log 'Instância tumblerd do usuário que chamou sudo foi encerrada para recarregar as bibliotecas.'
            log 'O Tumbler será iniciado novamente automaticamente quando solicitado pela sessão.'
        else
            log 'Nenhuma instância tumblerd do usuário chamador precisava ser reiniciada.'
        fi
    else
        log 'Reinício automático do tumblerd não foi aplicado.'
        log 'Se estiver em uma sessão XFCE, execute como usuário normal: systemctl --user restart tumblerd.service'
    fi
}

show_status() {
    require_arch

    printf '%s\n' "=== $PROGRAM $VERSION ==="
    printf '%s\n' '--- Tumbler ---'

    if pacman -Q tumbler >/dev/null 2>&1; then
        pacman -Q tumbler
    else
        printf '%s\n' 'tumbler: não instalado'
    fi

    printf '\n%s\n' '--- Bibliotecas opcionais ---'
    for pkg in $PACKAGES; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            pacman -Q "$pkg"
        else
            printf '%s: não instalado\n' "$pkg"
        fi
    done

    printf '\n%s\n' '--- Serviço da sessão atual ---'
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user --no-pager status tumblerd.service 2>/dev/null || true
    else
        printf '%s\n' 'systemctl não encontrado.'
    fi
}

install_all() {
    require_root
    require_arch
    : >> "$LOG_FILE" || fail "Não foi possível escrever em $LOG_FILE"

    log "Iniciando $PROGRAM $VERSION"
    check_tumbler
    install_packages
    validate_packages
    restart_tumbler_for_invoking_user

    log 'Correção concluída.'
    log 'Bibliotecas instaladas: libgepub, libgsf e libopenraw.'
}

case ${1-install} in
    install)
        install_all
        ;;
    status)
        show_status
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