# Suíte XFCE + KWin X11 para Arch Linux

## Escopo atual

Fluxo mestre:

1. `00-validar-ambiente.sh`
2. `05-configurar-chaotic-aur.sh`
3. `10-instalar-pacotes.sh`
4. `20-configurar-servicos.sh`
5. `30-configurar-sessao-xfce-kwin-x11.sh`
6. `40-configurar-kwin-atalhos-workspaces.sh`
7. `50-configurar-integracoes-desktop.sh`
8. `80-validar-instalacao.sh`

Orquestrador:

- `instalar-tudo.sh`

Opcional e fora do mestre:

- `60-preparar-perfil-skel.sh`

## Regras incorporadas

- A suíte pressupõe uma instalação Arch já preparada com `xorg-server` e sessão X11 funcional.
- O instalador não gerencia o grupo `xorg`, `xorg-xinit`, `xorg-xwayland` ou `xf86-input-libinput`.
- `00-validar-ambiente.sh` aborta se `xorg-server` não estiver instalado.
- NetworkManager comum:
  - pacote `networkmanager`
  - serviço `NetworkManager.service`
  - applet `network-manager-applet`
  - executável `nm-applet`
- Chaotic-AUR é configurado antes da instalação dos aplicativos.
- `dockbarx` e `xfce4-dockbarx-plugin` são instalados explicitamente do `chaotic-aur`.
- `xfce4-session`, `xfwm4`, `xfce4-screensaver`, `plasma-desktop`,
  `plasma-workspace` e `xdg-desktop-portal-kde` não pertencem ao escopo.
- A sessão principal é `XFCE + KWin X11`.
- A correção do item "Espaços de trabalho" do XFCE é obrigatória:
  `/usr/local/bin/xfwm4-workspace-settings` redireciona para
  `kcmshell6 kcm_kwin_virtualdesktops_x11`.
- `/etc/skel` é opcional.
- Nenhuma sessão Wayland é criada, configurada ou validada nesta suíte.
