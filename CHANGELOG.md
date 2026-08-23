# Changelog

## 2026-08-23 — Reconstrução completa do escopo

O repositório foi reorganizado para refletir a arquitetura atual do projeto.

### Alterações estruturais

- substituição do instalador monolítico por uma suíte modular;
- criação de `instalar-tudo.sh` como orquestrador;
- validação de ambiente separada da alteração do sistema;
- configuração do Chaotic-AUR como primeira alteração efetiva;
- instalação de pacotes oficiais e pacotes do repositório `chaotic-aur` em etapas distintas;
- criação de sessão própria `XFCE + KWin X11` para LightDM;
- uso de LightDM Slick Greeter;
- KWin X11 como único window manager/compositor da sessão;
- remoção de `xfce4-session` e `xfwm4` do escopo;
- configuração de quatro workspaces apenas como default inicial;
- integração de atalhos KWin/KGlobalAccel com atalhos XFCE;
- inclusão da ponte `xfwm4-workspace-settings` -> `kcm_kwin_virtualdesktops_x11`;
- criação de ações globais de logout, reboot, poweroff e suspend sem `xfce4-session`;
- configuração de NetworkManager comum com `network-manager-applet`/`nm-applet`;
- inclusão de DockBarX e `xfce4-dockbarx-plugin` diretamente do Chaotic-AUR;
- `/etc/skel` convertido em etapa opcional e removido do fluxo mestre;
- sessão Wayland removida integralmente do escopo atual;
- validação estática e runtime separadas.

### Aplicativos e integrações

A lista atual inclui, entre outros:

- Xorg, `xorg-xinit` e `xorg-xwayland`;
- KWin (`kwin` e `kwin-x11`), KGlobalAccel e System Settings;
- LightDM e Slick Greeter;
- Terminator e Alacritty;
- htop;
- Spectacle;
- NetworkManager e NetworkManager Applet;
- BlueZ e Blueman;
- PipeWire, WirePlumber e PavuControl;
- GStreamer e plugins selecionados;
- VLC e Audacious;
- stack CUPS ampliado;
- Samba, Rclone e FileZilla;
- Thunderbird com tradução `pt-BR`;
- Paru, Octopi, Google Chrome, Brave, DockBarX e plugin XFCE via Chaotic-AUR.

### Estado

A revisão foi validada sintaticamente com `bash -n`. A validação funcional end-to-end permanece necessária antes de declarar a suíte estável.
