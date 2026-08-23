#!/usr/bin/env bash
set -Eeuo pipefail

fail() {
    echo "ERRO: $*" >&2
    exit 1
}

info() {
    echo "[OK] $*"
}

warn() {
    echo "[AVISO] $*" >&2
}

[[ ${EUID} -eq 0 ]] || fail 'execute como root.'
[[ -n ${TARGET_USER:-} ]] || fail 'TARGET_USER não definido.'
[[ -f /etc/arch-release ]] || fail 'este script é exclusivo para Arch Linux.'
[[ $(uname -m) == x86_64 ]] || fail 'arquitetura esperada: x86_64.'

for cmd in \
    pacman \
    pacman-key \
    pacman-conf \
    systemctl \
    systemd-detect-virt \
    getent \
    grep \
    awk \
    sed \
    install
do
    command -v "$cmd" >/dev/null 2>&1 ||
        fail "comando obrigatório ausente: $cmd"
done

getent passwd "$TARGET_USER" >/dev/null ||
    fail "usuário-alvo inexistente: $TARGET_USER"

TARGET_HOME="$(
    getent passwd "$TARGET_USER" |
        awk -F: '{print $6}'
)"

[[ -n ${TARGET_HOME} && -d ${TARGET_HOME} ]] ||
    fail "HOME do usuário não encontrado: ${TARGET_HOME:-<vazio>}"

[[ -r /etc/pacman.conf ]] ||
    fail '/etc/pacman.conf não pode ser lido.'

pacman -Q archlinux-keyring >/dev/null 2>&1 ||
    fail 'pacote archlinux-keyring não está instalado.'

# A suíte não instala o servidor X. Ela pressupõe uma base Arch já preparada
# para sessão gráfica X11.
pacman -Q xorg-server >/dev/null 2>&1 ||
    fail 'pré-requisito ausente: xorg-server. Instale a base gráfica X11 antes de executar esta suíte.'

command -v Xorg >/dev/null 2>&1 ||
    fail 'pré-requisito ausente: executável Xorg não encontrado.'

info 'pré-requisito gráfico validado: xorg-server já instalado.'

if getent ahosts archlinux.org >/dev/null 2>&1; then
    info 'resolução de nomes funcionando.'
else
    warn 'não foi possível resolver archlinux.org; pacman/Chaotic-AUR podem falhar.'
fi

PROIBIDOS=(
    xfce4-session
    xfwm4
    xfce4-screensaver
    plasma-desktop
    plasma-workspace
    xdg-desktop-portal-kde
)

presentes=()

for pkg in "${PROIBIDOS[@]}"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        presentes+=("$pkg")
    fi
done

if ((${#presentes[@]})); then
    printf 'ERRO: pacotes incompatíveis com o escopo já estão instalados:\n' >&2
    printf '  - %s\n' "${presentes[@]}" >&2
    printf 'Nada será removido automaticamente.\n' >&2
    exit 1
fi

if systemd-detect-virt --chroot >/dev/null 2>&1; then
    info 'execução detectada dentro de chroot.'
else
    info 'execução fora de chroot.'
fi

info "ambiente validado para ${TARGET_USER} (${TARGET_HOME})."
