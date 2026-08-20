# Testes e validação

## Ambiente validado

A solução foi testada em:

- Arch Linux;
- XFCE 4.20;
- sessão X11;
- KWin X11 6.7.4;
- KDE Frameworks/Plasma 6 correspondentes aos repositórios do Arch no período do teste.

Data da consolidação da solução: **20 de agosto de 2026**.

## Teste decisivo

O teste que validou a solução não reutilizou um HOME previamente alterado.

Foi criado um usuário novo depois da configuração do `/etc/skel`:

```sh
sudo useradd -m test-kwin3
sudo passwd test-kwin3
```

Antes do primeiro login foram conferidos:

```sh
sudo cat /home/test-kwin3/.config/kwinrc
sudo cat /home/test-kwin3/.config/kglobalshortcutsrc
```

O usuário recebeu 4 workspaces iniciais e os cinco atalhos diretamente pelo KGlobalAccel.

No primeiro login em XFCE/X11 foram validados:

```text
Alt+Tab             -> próxima janela
Alt+Shift+Tab       -> janela anterior
Alt+F4              -> fechar janela
Super+Tab           -> próximo workspace
Super+Shift+Tab     -> workspace anterior
```

Também foi confirmado que os 4 workspaces iniciais não devem ser tratados como limite permanente. A implementação final não regrava `Number=4` no wrapper.

## Verificação pós-instalação

### Tipo da sessão

```sh
printf '%s\n' "$XDG_SESSION_TYPE"
```

Esperado:

```text
x11
```

### Window manager

```sh
wmctrl -m
```

Esperado:

```text
Name: KWin
```

### Processos

```sh
pgrep -a kwin_x11
pgrep -a kglobalacceld
pgrep -a xfwm4
pgrep -a picom
```

Esperado:

- `kwin_x11`: ativo;
- `kglobalacceld`: ativo;
- `xfwm4`: nenhuma saída;
- `picom`: nenhuma saída.

### Quantidade atual de workspaces pelo D-Bus do KWin

```sh
qdbus6 org.kde.KWin \
  /VirtualDesktopManager \
  org.freedesktop.DBus.Properties.Get \
  org.kde.KWin.VirtualDesktopManager \
  count
```

Em usuário novo, inicialmente deve retornar `4`.

Depois de o usuário adicionar um workspace, deve poder retornar `5` ou mais e permanecer assim em logins seguintes.

### Configuração do skeleton

```sh
sudo cat /etc/skel/.config/kwinrc
sudo cat /etc/skel/.config/kglobalshortcutsrc
```

### Sessão global XFCE

```sh
xmlstarlet sel -t -v \
  "/channel/property[@name='sessions']/property[@name='Failsafe']/property[@name='Client0_Command']/value[1]/@value" \
  /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml
```

Esperado:

```text
/usr/local/bin/kwin-xfce-session
```

## Teste de um usuário novo

Depois da instalação:

```sh
sudo useradd -m teste-kwin
sudo passwd teste-kwin
```

Antes de logar:

```sh
sudo grep -A3 '^\[Desktops\]' /home/teste-kwin/.config/kwinrc
sudo grep -E '^(Walk Through Windows|Walk Through Windows \(Reverse\)|Window Close|Switch to Next Desktop|Switch to Previous Desktop)=' \
  /home/teste-kwin/.config/kglobalshortcutsrc
```

Após validar, o usuário de teste pode ser removido com:

```sh
sudo userdel -r teste-kwin
```

O aviso de spool de mail ausente não significa que `userdel` falhou; confirme com:

```sh
getent passwd teste-kwin
```

Sem saída, a conta foi removida.
