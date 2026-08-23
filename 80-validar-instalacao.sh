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
    echo "[PENDENTE] $*" >&2
}

[[ ${EUID} -eq 0 ]] || fail 'execute como root.'
[[ -n ${TARGET_USER:-} ]] || fail 'TARGET_USER não definido.'

RUNTIME=0

if [[ ${1:-} == --runtime ]]; then
    RUNTIME=1
elif [[ $# -gt 0 ]]; then
    fail "argumento desconhecido: $1"
fi

PACOTES_OBRIGATORIOS=(
    kwin
    kwin-x11
    kglobalacceld
    lightdm
    lightdm-slick-greeter
    networkmanager
    network-manager-applet
    bluez
    blueman
    cups
    xfdesktop
    xfce4-panel
    xfce4-settings
    xfconf
    pipewire
    wireplumber
    xorg-xwayland
    dockbarx
    xfce4-dockbarx-plugin
)

for pkg in "${PACOTES_OBRIGATORIOS[@]}"; do
    pacman -Q "$pkg" >/dev/null 2>&1 ||
        fail "pacote obrigatório ausente: $pkg"
done

PROIBIDOS=(
    xfce4-session
    xfwm4
    xfce4-screensaver
    plasma-desktop
    plasma-workspace
    xdg-desktop-portal-kde
)

for pkg in "${PROIBIDOS[@]}"; do
    pacman -Q "$pkg" >/dev/null 2>&1 &&
        fail "pacote proibido instalado: $pkg"
done

for file in \
    /usr/share/xsessions/xfce-kwin.desktop \
    /usr/local/bin/start-xfce-kwin \
    /usr/local/bin/xfwm4-workspace-settings \
    /usr/local/bin/xfce-kwin-next-workspace \
    /usr/local/bin/xfce-kwin-previous-workspace \
    /usr/local/bin/xfce-kwin-user-setup \
    /usr/local/bin/logout \
    /usr/local/bin/reboot \
    /usr/local/bin/poweroff \
    /usr/local/bin/suspend
do
    [[ -e $file ]] ||
        fail "arquivo obrigatório ausente: $file"
done

if grep -Eq \
    '(^|[[:space:]/])xfce4-session([[:space:]]|$)' \
    /usr/local/bin/start-xfce-kwin
then
    fail 'start-xfce-kwin referencia xfce4-session.'
fi

if grep -Eq \
    '(^|[[:space:]/])xfwm4([[:space:]]|$)' \
    /usr/local/bin/start-xfce-kwin
then
    fail 'start-xfce-kwin referencia xfwm4.'
fi

for unit in \
    lightdm.service \
    NetworkManager.service \
    bluetooth.service \
    cups.service
do
    state="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
    [[ $state == enabled ]] ||
        fail "$unit não está habilitado (estado: ${state:-desconhecido})."
done

[[ -f /etc/lightdm/lightdm.conf.d/50-xfce-kwin.conf ]] ||
    fail 'drop-in do LightDM ausente.'

grep -q \
    '^greeter-session=lightdm-slick-greeter$' \
    /etc/lightdm/lightdm.conf.d/50-xfce-kwin.conf ||
    fail 'Slick Greeter não está configurado no drop-in.'

grep -q \
    '^user-session=xfce-kwin$' \
    /etc/lightdm/lightdm.conf.d/50-xfce-kwin.conf ||
    fail 'sessão xfce-kwin não está configurada no drop-in.'

KCM='/usr/lib/qt6/plugins/plasma/kcms/systemsettings/kcm_kwin_virtualdesktops_x11.so'
[[ -f $KCM ]] ||
    fail 'KCM de workspaces do KWin X11 ausente.'

grep -Eq '^Number=4$' /etc/xdg/kwinrc ||
    fail 'default Number=4 não encontrado em /etc/xdg/kwinrc.'

grep -Eq '^Rows=1$' /etc/xdg/kwinrc ||
    fail 'default Rows=1 não encontrado em /etc/xdg/kwinrc.'

info 'validação estática concluída.'

if [[ $RUNTIME -eq 1 ]]; then
    systemd-detect-virt --chroot >/dev/null 2>&1 &&
        fail '--runtime não pode ser usado dentro de chroot.'

    must_run=(
        kwin_x11
        xfsettingsd
        kglobalacceld
        xfdesktop
        xfce4-panel
        nm-applet
        blueman-applet
        thunar
        xscreensaver
        xfce4-power-manager
    )

    for proc in "${must_run[@]}"; do
        pgrep -u "$TARGET_USER" -x "$proc" >/dev/null 2>&1 ||
            fail "processo esperado não está ativo para $TARGET_USER: $proc"
    done

    pgrep -u "$TARGET_USER" -x xfwm4 >/dev/null 2>&1 &&
        fail 'xfwm4 está ativo, mas não deveria.'

    pgrep -u "$TARGET_USER" -x xfce4-session >/dev/null 2>&1 &&
        fail 'xfce4-session está ativo, mas não deveria.'

    info 'processos centrais da sessão estão corretos.'

    cat <<'MANUAL'

Validações manuais finais:

  Alt+Tab
      próxima janela

  Alt+Shift+Tab
      janela anterior

  Alt+F4
      fechar janela

  Super+Tab
      próximo workspace com wrapping

  Super+Shift+Tab
      workspace anterior com wrapping

  Super+L
      bloquear via XScreenSaver

  XFCE Settings > Espaços de trabalho
      deve abrir KWin Virtual Desktops sem erro

  Workspaces
      quantidade inicial = 4
      usuário pode alterar depois

  Área de notificação
      nm-applet
      blueman-applet

  DockBarX
      plugin instalado; inclusão/posição no painel é escolha de layout

  Integrações
      PipeWire
      CUPS
      Thunar
      GVFS

Nenhuma sessão Wayland faz parte desta validação.
Somente depois destes testes faça o snapshot da base.
MANUAL
else
    warn 'validação gráfica não executada. Rode novamente com --runtime depois do login.'
fi
