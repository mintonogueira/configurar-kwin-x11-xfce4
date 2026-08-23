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

SERVICOS_OBRIGATORIOS=(
    lightdm.service
    NetworkManager.service
    bluetooth.service
    cups.service
)

for unit in "${SERVICOS_OBRIGATORIOS[@]}"; do
    [[ -e "/usr/lib/systemd/system/$unit" ||
       -e "/etc/systemd/system/$unit" ]] ||
        fail "unit obrigatória ausente: $unit"

    systemctl enable "$unit"
    info "$unit habilitado."
done

if [[ -e /usr/lib/systemd/system/cups-browsed.service ||
      -e /etc/systemd/system/cups-browsed.service ]]
then
    state="$(systemctl is-enabled cups-browsed.service 2>/dev/null || true)"

    case "$state" in
        enabled|static|indirect|generated|alias)
            info "cups-browsed.service: $state"
            ;;
        *)
            if systemctl enable cups-browsed.service; then
                info 'cups-browsed.service habilitado.'
            else
                warn 'cups-browsed.service existe, mas não pôde ser habilitado.'
            fi
            ;;
    esac
fi

if systemd-detect-virt --chroot >/dev/null 2>&1; then
    info 'chroot detectado: apenas enable; nenhum serviço foi iniciado.'
else
    info 'serviços habilitados para o próximo boot; nenhum --now foi forçado.'
fi
