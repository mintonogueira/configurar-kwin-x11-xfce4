# Implementação técnica

## Objetivo

Substituir o xfwm4 pelo KWin X11 em uma sessão XFCE tradicional, deixando o KWin responsável por:

- gerenciamento de janelas;
- decorações de janelas;
- composição X11;
- atalhos globais relacionados a janelas e workspaces.

O XFCE continua responsável pelo restante do desktop.

## Arquitetura final

```text
XFCE/X11
   |
   +-- xfce4-session
   |      |
   |      +-- Client0_Command
   |              |
   |              +-- /usr/local/bin/kwin-xfce-session
   |                         |
   |                         +-- plasma-kglobalaccel.service
   |                         +-- /usr/bin/kwin_x11
   |
   +-- xfsettingsd
   +-- xfce4-panel
   +-- xfdesktop
   +-- demais componentes XFCE
```

## Wrapper global

O wrapper é propositalmente pequeno:

```sh
#!/bin/sh
systemctl --user start plasma-kglobalaccel.service || exit 1
exec /usr/bin/kwin_x11
```

Ele não regrava atalhos e **não regrava o número de workspaces**. Isso evita race conditions com o registro do KGlobalAccel e evita transformar `Number=4` em política permanente.

## Alteração da sessão XFCE

A configuração global é alterada em:

```text
/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml
```

Apenas o caminho X11 é alterado:

```text
sessions/Failsafe/Client0_Command
```

O script não altera `FailsafeWayland`.

A edição é feita com XMLStarlet e validada antes da gravação definitiva.

## Por que `/etc/skel`

O problema observado durante os testes foi que o KWin/KGlobalAccel pode criar seus próprios defaults no primeiro login. Tentar alterar os atalhos depois disso criou comportamento inconsistente.

A solução validada foi fazer a configuração existir **antes do primeiro login**.

No Arch, `useradd -m` usa `/etc/skel` como esqueleto do HOME. Assim os arquivos abaixo já existem quando KWin e KGlobalAccel são inicializados pela primeira vez:

```text
/etc/skel/.config/kwinrc
/etc/skel/.config/kglobalshortcutsrc
```

## Workspaces

O novo usuário começa com:

```ini
[Desktops]
Number=4
Rows=1
```

Esse valor só existe no skeleton. Não é gravado em `/usr/local/bin/kwin-xfce-session` e a implementação final não depende de `/etc/xdg/kwinrc` para forçar quantidade.

Consequência:

```text
primeiro login -> 4 workspaces
usuário altera -> 5, 6, 7, 8, ...
login seguinte -> valor escolhido pelo usuário permanece
```

## Atalhos e KGlobalAccel

Os atalhos usados são:

| Tecla física | Representação KGlobalAccel | Ação |
|---|---|---|
| Alt+Tab | `Alt+Tab` | próxima janela |
| Alt+Shift+Tab | `Alt+Shift+Tab` | janela anterior |
| Alt+F4 | `Alt+F4` | fechar janela |
| Super+Tab | `Meta+Tab` | próximo workspace |
| Super+Shift+Tab | `Meta+Shift+Tab` | workspace anterior |

O KGlobalAccel usa `Meta` para a tecla Super.

## Atalhos do XFCE

A implementação final não usa o provider do XFCE para capturar `Super+Tab`. Isso eliminou a disputa de grabs entre XFCE e KGlobalAccel.

O script remove do bloco `commands/custom` apenas as formas conhecidas que foram usadas durante os testes:

```text
<Super>Tab
<Shift><Super>ISO_Left_Tab
<Super>ISO_Left_Tab
<Super><Shift>Tab
```

Depois configura `providers` para conter somente `commands`. O bloco estático `xfwm4/default` pode continuar no XML do pacote, mas deixa de ser provider ativo.

## Compositor

`kwin_x11` fornece o compositor da sessão. `picom` é removido para impedir composição duplicada.

## Remoção do xfwm4

O script tenta remover simultaneamente os pacotes conflitantes instalados:

```text
xfwm4
xfwm4-themes
picom
```

A remoção usa `pacman -Rns` **sem `--nodeps`**. Se outra dependência impedir a transação, o script aborta e não força a quebra do sistema.

## Limpeza das abordagens antigas

O instalador reconhece e remove somente artefatos específicos conhecidos do processo de desenvolvimento:

```text
/etc/xdg/autostart/kwin-xfce-shortcuts-policy.desktop
/usr/local/bin/kwin-xfce-shortcuts-policy
```

Também remove um `/etc/xdg/kglobalshortcutsrc` não pertencente a pacote quando encontra o fingerprint exato da configuração antiga que desabilitava `Switch to Next/Previous Desktop`.

A antiga configuração `/etc/xdg/kwinrc` com `Number=4` e `Rows=1` só é limpa quando o script detecta sinais da implementação antiga que regravava workspaces no wrapper.

## Backup

São preservados antes das alterações:

```text
/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml
/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
/usr/local/bin/kwin-xfce-session
/etc/skel/.config/kwinrc
/etc/skel/.config/kglobalshortcutsrc
/etc/xdg/kwinrc
/etc/xdg/kglobalshortcutsrc
/etc/xdg/autostart/kwin-xfce-shortcuts-policy.desktop
/usr/local/bin/kwin-xfce-shortcuts-policy
```

Também é registrado quais pacotes conflitantes estavam instalados antes da implantação.

## POSIX shell

O instalador foi escrito para `/bin/sh` e não utiliza arrays Bash, `[[ ... ]]`, `local`, `source`, process substitution ou outras extensões específicas do Bash.

A sintaxe foi validada com:

```sh
dash -n configurar-kwin-x11-xfce4.sh
sh -n configurar-kwin-x11-xfce4.sh
```
