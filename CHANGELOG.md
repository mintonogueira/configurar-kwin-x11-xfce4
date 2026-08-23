# Changelog

## 2026-08-23 — Xorg convertido em pré-requisito

Após validar que o problema observado na instalação vinha de uma base Arch mínima sem a pilha gráfica preparada, o escopo foi simplificado.

### Alterações

- o instalador deixa de instalar o grupo `xorg`;
- `xorg-xinit` e `xorg-xwayland` saem da lista gerenciada pela suíte;
- `xf86-input-libinput` também sai da lista explícita;
- `xorg-server` passa a ser pré-requisito da instalação base;
- `00-validar-ambiente.sh` verifica `xorg-server` e o executável `Xorg` antes de qualquer alteração;
- `80-validar-instalacao.sh` valida `xorg-server`, mas não exige `xorg-xwayland`;
- documentação atualizada para deixar claro que a suíte começa sobre uma base X11 já funcional.

Essa mudança também elimina a necessidade de expandir o grupo `xorg` após habilitar o Chaotic-AUR, evitando que variantes `*-git` de repositórios de terceiros entrem acidentalmente na transação.

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

A validação funcional end-to-end permanece necessária antes de declarar a suíte estável.
