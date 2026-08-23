#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    cat <<'USAGE'
Uso:
  ./instalar-tudo.sh --user USUARIO

Exemplo:
  ./instalar-tudo.sh --user ajmn

Observações:
  - Execute como root.
  - O perfil /etc/skel NÃO faz parte do fluxo mestre.
  - Nenhuma sessão Wayland é criada ou configurada.
USAGE
}

[[ ${EUID} -eq 0 ]] || {
    echo 'ERRO: execute como root.' >&2
    exit 1
}

TARGET_USER="${TARGET_USER:-}"

while (($#)); do
    case "$1" in
        --user)
            [[ $# -ge 2 ]] || {
                usage
                exit 2
            }
            TARGET_USER="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERRO: argumento desconhecido: $1" >&2
            usage
            exit 2
            ;;
    esac
done

[[ -n ${TARGET_USER} ]] || {
    echo 'ERRO: informe --user USUARIO.' >&2
    exit 2
}

export TARGET_USER

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

ETAPAS=(
    00-validar-ambiente.sh
    05-configurar-chaotic-aur.sh
    10-instalar-pacotes.sh
    20-configurar-servicos.sh
    30-configurar-sessao-xfce-kwin-x11.sh
    40-configurar-kwin-atalhos-workspaces.sh
    50-configurar-integracoes-desktop.sh
    80-validar-instalacao.sh
)

for etapa in "${ETAPAS[@]}"; do
    script="${BASE_DIR}/${etapa}"

    [[ -x ${script} ]] || {
        echo "ERRO: script ausente ou não executável: ${script}" >&2
        exit 1
    }

    printf '\n========== %s ==========\n' "${etapa}"
    "${script}"
done

cat <<'MSG'

Fluxo mestre concluído.

IMPORTANTE:
- 60-preparar-perfil-skel.sh é opcional e NÃO foi executado.
- Nenhuma sessão Wayland foi criada/configurada.
- Se a execução ocorreu em chroot, reinicie antes da validação gráfica.
- Depois do primeiro login em "XFCE + KWin X11", execute:

    TARGET_USER=<usuario> ./80-validar-instalacao.sh --runtime

Somente depois da validação runtime a base deve ser considerada pronta
para snapshot/backup.
MSG
