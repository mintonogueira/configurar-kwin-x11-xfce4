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

KEY='3056513887B78AEB'
KEYSERVER='keyserver.ubuntu.com'
KEYRING_URL='https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
MIRRORLIST_URL='https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
PACMAN_CONF='/etc/pacman.conf'

for cmd in pacman pacman-key pacman-conf grep cp; do
    command -v "$cmd" >/dev/null 2>&1 ||
        fail "comando obrigatório ausente: $cmd"
done

if [[ ! -s /etc/pacman.d/gnupg/pubring.gpg ]]; then
    pacman-key --init
fi

if ! pacman-key --list-keys "$KEY" >/dev/null 2>&1; then
    pacman-key --recv-key "$KEY" --keyserver "$KEYSERVER"
fi

# Reassina localmente de forma idempotente.
pacman-key --lsign-key "$KEY"

if ! pacman -Q chaotic-keyring >/dev/null 2>&1 ||
   ! pacman -Q chaotic-mirrorlist >/dev/null 2>&1
then
    pacman -U --noconfirm \
        "$KEYRING_URL" \
        "$MIRRORLIST_URL"
fi

[[ -s /etc/pacman.d/chaotic-mirrorlist ]] ||
    fail 'chaotic-mirrorlist não foi instalado corretamente.'

if pacman-conf --repo-list 2>/dev/null | grep -qx 'chaotic-aur'; then
    info 'repositório [chaotic-aur] já está ativo.'
else
    backup="${PACMAN_CONF}.backup-chaotic-$(date +%Y%m%d_%H%M%S)"
    cp -a -- "$PACMAN_CONF" "$backup"

    cat >> "$PACMAN_CONF" <<'REPO'

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
REPO

    info "bloco [chaotic-aur] adicionado. Backup: $backup"
fi

pacman -Syy --noconfirm

pacman -Sl chaotic-aur >/dev/null 2>&1 ||
    fail 'o repositório chaotic-aur não respondeu após a configuração.'

info 'Chaotic-AUR configurado e funcional.'
