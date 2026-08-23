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

TARGET_HOME="$(
    getent passwd "$TARGET_USER" |
        awk -F: '{print $6}'
)"

[[ -n $TARGET_HOME ]] ||
    fail 'não foi possível determinar o HOME do usuário-alvo.'

install -d -m 0755 /etc/skel/.config

cat > /etc/skel/.config/kglobalshortcutsrc <<'KGLOBAL'
[kwin]
Walk Through Windows=Alt+Tab,Alt+Tab,Walk Through Windows
Walk Through Windows (Reverse)=Alt+Shift+Backtab,Alt+Shift+Backtab,Walk Through Windows (Reverse)
Window Close=Alt+F4,Alt+F4,Close Window
_k_friendly_name=KWin
KGLOBAL

chmod 0644 /etc/skel/.config/kglobalshortcutsrc

audit_file="$(mktemp)"
trap 'rm -f -- "$audit_file"' EXIT

if grep \
    -RInF \
    -- "$TARGET_HOME" \
    /etc/skel \
    >"$audit_file" \
    2>/dev/null
then
    echo 'ERRO: /etc/skel contém referência ao HOME do usuário construtor:' >&2
    cat "$audit_file" >&2
    exit 1
fi

chown -R root:root /etc/skel

info '/etc/skel preparado.'
info 'Este script é opcional e não é chamado por instalar-tudo.sh.'
