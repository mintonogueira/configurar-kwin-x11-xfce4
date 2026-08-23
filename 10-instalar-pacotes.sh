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

command -v pacman >/dev/null 2>&1 ||
    fail 'pacman ausente.'

# O grupo "xorg" pode receber membros adicionais de repositórios de terceiros.
# Como o Chaotic-AUR é configurado antes desta etapa, não podemos usar diretamente
# todo o resultado de "pacman -Sgq xorg": pacotes *-git do Chaotic-AUR podem
# declarar o mesmo grupo e conflitar com os pacotes oficiais do Arch.
#
# Portanto:
#   1. lemos todos os nomes declarados no grupo xorg;
#   2. mantemos somente os que existem em repositórios oficiais do Arch;
#   3. guardamos o alvo qualificado (repo/pacote), impedindo o pacman de escolher
#      uma variante de outro repositório durante a instalação.

OFFICIAL_REPOS=(
    core
    extra
    multilib
)

XORG_GROUP=()

while IFS= read -r pkg; do
    [[ -n ${pkg} ]] || continue

    for repo in "${OFFICIAL_REPOS[@]}"; do
        if pacman -Si "${repo}/${pkg}" >/dev/null 2>&1; then
            XORG_GROUP+=("${repo}/${pkg}")
            break
        fi
    done
done < <(
    pacman -Sgq xorg |
        sort -u
)

((${#XORG_GROUP[@]})) ||
    fail 'nenhum membro oficial do grupo xorg foi encontrado.'

info "grupo xorg filtrado: ${#XORG_GROUP[@]} pacote(s) oficial(is)."

PACOTES_REPOS_OFICIAIS=(
    "${XORG_GROUP[@]}"
    xorg-xinit
    xorg-xwayland

    # Entrada / dispositivos apontadores.
    # Mantidos explicitamente mesmo que possam vir por dependência do Xorg.
    libinput
    xf86-input-libinput

    # Núcleo XFCE selecionado; sem xfce4-session e sem xfwm4.
    exo
    garcon
    thunar
    thunar-volman
    tumbler
    xfce4-appfinder
    xfce4-panel
    xfce4-power-manager
    xfce4-settings
    xfconf
    xfdesktop
    xfce4-notifyd
    xfce4-whiskermenu-plugin
    xfce4-clipman-plugin
    xfce4-pulseaudio-plugin
    thunar-archive-plugin
    thunar-media-tags-plugin

    # Aplicativos escolhidos.
    terminator
    alacritty
    htop
    spectacle
    mousepad
    atril
    catfish

    # KWin X11 + pacote kwin solicitado.
    # Nenhuma sessão Wayland é criada/configurada por esta suíte.
    kwin
    kwin-x11
    kglobalacceld
    systemsettings
    breeze

    # Login / autenticação / bloqueio.
    lightdm
    lightdm-slick-greeter
    polkit-gnome
    xscreensaver

    # Rede.
    networkmanager
    network-manager-applet

    # Bluetooth.
    bluez
    bluez-utils
    blueman

    # Integração de arquivos.
    gvfs
    gvfs-mtp
    gvfs-gphoto2
    gvfs-smb
    fuse2
    fuse3

    # Áudio.
    pipewire
    pipewire-alsa
    pipewire-pulse
    pipewire-jack
    wireplumber
    pavucontrol
    alsa-utils

    # GStreamer.
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
    gst-plugin-pipewire
    gst-plugin-gtk
    gst-plugin-qml6

    # Multimídia.
    vlc
    vlc-plugins-all
    vlc-gui-ncurses
    vlc-gui-skins2
    audacious

    # Impressão.
    cups
    cups-filters
    cups-pk-helper
    cups-browsed
    ghostscript
    ipp-usb
    system-config-printer

    # Rede / arquivos.
    samba
    rclone
    filezilla
    flatpak

    # E-mail.
    thunderbird
    thunderbird-i18n-pt-br
)

PACOTES_CHAOTIC=(
    paru
    octopi
    google-chrome
    brave-bin
    dockbarx
    xfce4-dockbarx-plugin
)

missing=()

for pkg in "${PACOTES_REPOS_OFICIAIS[@]}"; do
    if ! pacman -Si "$pkg" >/dev/null 2>&1; then
        missing+=("$pkg")
    fi
done

for pkg in "${PACOTES_CHAOTIC[@]}"; do
    if ! pacman -Si "chaotic-aur/$pkg" >/dev/null 2>&1; then
        missing+=("chaotic-aur/$pkg")
    fi
done

if ((${#missing[@]})); then
    printf 'ERRO: pacote(s) não localizado(s) nos repositórios previstos:\n' >&2
    printf '  - %s\n' "${missing[@]}" >&2
    exit 1
fi

pacman -S \
    --needed \
    --noconfirm \
    "${PACOTES_REPOS_OFICIAIS[@]}"

CHAOTIC_TARGETS=()
for pkg in "${PACOTES_CHAOTIC[@]}"; do
    CHAOTIC_TARGETS+=("chaotic-aur/$pkg")
done

pacman -S \
    --needed \
    --noconfirm \
    "${CHAOTIC_TARGETS[@]}"

PROIBIDOS=(
    xfce4-session
    xfwm4
    xfce4-screensaver
    plasma-desktop
    plasma-workspace
    xdg-desktop-portal-kde
)

violacoes=()

for pkg in "${PROIBIDOS[@]}"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        violacoes+=("$pkg")
    fi
done

if ((${#violacoes[@]})); then
    printf 'ERRO: a transação introduziu pacote(s) proibido(s):\n' >&2
    printf '  - %s\n' "${violacoes[@]}" >&2
    printf 'Nada será removido automaticamente; revise dependências.\n' >&2
    exit 1
fi

info 'pacotes oficiais e Chaotic-AUR instalados.'
info 'DockBarX + xfce4-dockbarx-plugin foram instalados via Chaotic-AUR.'
