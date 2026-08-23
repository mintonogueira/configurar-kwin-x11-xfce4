# XFCE + KWin X11 no Arch Linux

Suíte modular para construir uma sessão **XFCE + KWin X11** no Arch Linux sem `xfce4-session`, sem `xfwm4` e sem Plasma Desktop como sessão.

O projeto parte de uma instalação Arch limpa, configura o Chaotic-AUR, instala os componentes selecionados, habilita os serviços necessários, cria uma sessão própria do LightDM com Slick Greeter, integra o XFCE ao KWin e valida o resultado.

## Arquitetura

```text
LightDM + Slick Greeter
        |
        v
/usr/share/xsessions/xfce-kwin.desktop
        |
        v
/usr/local/bin/start-xfce-kwin
        |
        +-- xfsettingsd
        +-- kglobalacceld
        +-- polkit-gnome-authentication-agent-1
        +-- xscreensaver
        +-- xfce4-power-manager
        +-- xfdesktop
        +-- xfce4-panel
        +-- nm-applet
        +-- blueman-applet
        +-- thunar --daemon
        |
        `-- exec kwin_x11
```

O KWin X11 é o único window manager/compositor da sessão. O XFCE permanece responsável pelo desktop, painel, configurações, notificações e integrações do ambiente.

## Escopo atual

O fluxo mestre executa, nesta ordem:

1. `00-validar-ambiente.sh`
2. `05-configurar-chaotic-aur.sh`
3. `10-instalar-pacotes.sh`
4. `20-configurar-servicos.sh`
5. `30-configurar-sessao-xfce-kwin-x11.sh`
6. `40-configurar-kwin-atalhos-workspaces.sh`
7. `50-configurar-integracoes-desktop.sh`
8. `80-validar-instalacao.sh`

O orquestrador é:

```text
instalar-tudo.sh
```

### Script opcional

`60-preparar-perfil-skel.sh` prepara `/etc/skel` para novos usuários, mas **não faz parte do fluxo mestre**. Ele só deve ser executado quando o administrador quiser provisionar um perfil inicial para contas criadas posteriormente.

### Wayland

Nenhuma sessão Wayland é criada, configurada ou validada por esta suíte. Os pacotes `kwin` e `xorg-xwayland` permanecem instalados porque fazem parte da seleção atual, mas qualquer desenho de sessão Wayland será tratado em etapa futura e separada.

## Chaotic-AUR

O Chaotic-AUR é configurado **antes** da instalação da lista principal.

Os seguintes pacotes são instalados diretamente do repositório binário `chaotic-aur` com `pacman`:

```text
paru
octopi
google-chrome
brave-bin
dockbarx
xfce4-dockbarx-plugin
```

O script não usa `paru -S`, `makepkg` ou clone de PKGBUILD para instalar essa lista.

## Rede

A pilha de rede é a padrão do NetworkManager:

```text
pacote do daemon:   networkmanager
serviço systemd:    NetworkManager.service
pacote do applet:   network-manager-applet
executável gráfico: nm-applet
```

`nm-applet` é iniciado pela sessão gráfica e não é tratado como serviço systemd.

## Workspaces e integração XFCE -> KWin

Quatro desktops virtuais são definidos como **padrão inicial**, não como limite permanente:

```ini
[Desktops]
Number=4
Rows=1
```

A configuração não é regravada a cada login, portanto o usuário pode alterar a quantidade posteriormente.

Como `xfwm4` não está instalado, o item **Espaços de trabalho** do XFCE normalmente tentaria executar `xfwm4-workspace-settings` e falharia.

A suíte cria a ponte global:

```text
/usr/local/bin/xfwm4-workspace-settings
```

que executa:

```text
kcmshell6 kcm_kwin_virtualdesktops_x11
```

Assim, o painel de configurações do XFCE abre diretamente o gerenciador de desktops virtuais do KWin X11.

## Atalhos

Responsabilidade do KWin/KGlobalAccel:

```text
Alt+Tab          próxima janela
Alt+Shift+Tab    janela anterior
Alt+F4           fechar janela
```

Responsabilidade dos atalhos XFCE, chamando ações do KWin:

```text
Super+Tab          próximo workspace
Super+Shift+Tab    workspace anterior
Super+L            bloquear sessão
```

A navegação entre workspaces usa wrapping circular.

## Pacotes selecionados

A suíte instala componentes XFCE individualmente, além de Xorg, KWin, LightDM/Slick Greeter, NetworkManager, BlueZ/Blueman, GVFS/FUSE, PipeWire/WirePlumber, GStreamer, VLC, Audacious, CUPS, Samba, Rclone, FileZilla, Flatpak, Thunderbird, Spectacle, htop, Terminator, Alacritty e demais componentes descritos em `10-instalar-pacotes.sh`.

Entre as substituições deliberadas estão:

```text
xfce4-terminal       -> terminator + alacritty
xfce4-taskmanager    -> htop
xfce4-screenshooter  -> spectacle
```

DockBarX é instalado com seu plugin XFCE, mas o script não força a posição do plugin no painel.

## Pacotes fora do escopo

A suíte rejeita a presença dos seguintes pacotes estruturais:

```text
xfce4-session
xfwm4
xfce4-screensaver
plasma-desktop
plasma-workspace
xdg-desktop-portal-kde
```

Nada é removido automaticamente quando uma incompatibilidade é encontrada; a execução aborta para revisão do administrador.

## Serviços

São habilitados:

```text
lightdm.service
NetworkManager.service
bluetooth.service
cups.service
```

`cups-browsed.service` é tratado quando a unit estiver disponível.

## LightDM

A sessão própria é registrada em:

```text
/usr/share/xsessions/xfce-kwin.desktop
```

A configuração do LightDM usa:

```text
/etc/lightdm/lightdm.conf.d/50-xfce-kwin.conf
```

com:

```ini
[Seat:*]
greeter-session=lightdm-slick-greeter
user-session=xfce-kwin
```

## Validação

`80-validar-instalacao.sh` possui duas etapas:

- validação estática da instalação;
- validação runtime após o primeiro login.

Após iniciar a sessão gráfica:

```bash
TARGET_USER=<usuario> ./80-validar-instalacao.sh --runtime
```

Ainda são exigidos testes manuais de atalhos, bloqueio, workspaces, integração XFCE -> KWin, rede, Bluetooth, PipeWire, CUPS, Thunar/GVFS e painel.

## Uso

Execute como root em uma instalação Arch preparada:

```bash
chmod +x *.sh
./instalar-tudo.sh --user USUARIO
```

Em chroot, os serviços são apenas habilitados. Depois do reboot e primeiro login, execute a validação runtime.

O perfil `/etc/skel`, se desejado, é uma etapa separada:

```bash
TARGET_USER=USUARIO ./60-preparar-perfil-skel.sh
```

## Estado de validação

Os scripts desta revisão foram verificados sintaticamente com `bash -n` durante a construção. Isso **não equivale a validação funcional completa em uma instalação Arch real**. A suíte só deve ser declarada operacionalmente validada depois da execução integral e dos testes runtime/manuais.

## Licença

GNU General Public License v3.0. Consulte `LICENSE`.
