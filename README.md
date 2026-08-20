# KWin X11 como Window Manager do XFCE no Arch Linux

Este projeto automatiza a substituição do **xfwm4 + compositor externo** pelo **KWin X11**, mantendo o restante do ambiente XFCE: painel, xfdesktop, Thunar, configurações, plugins e aplicações. O repositório também reúne correções complementares validadas durante a implantação, incluindo compatibilidade do configurador de workspaces e instalação das bibliotecas opcionais necessárias aos plugins do Tumbler.

A implementação inicial é específica para **Arch Linux + XFCE em sessão X11**.

## Estado da solução

**Solução testada.**

A configuração foi validada em Arch Linux com XFCE 4.20, sessão X11 e KWin X11 6.7.4. O teste final foi feito com um usuário novo criado após a implantação de `/etc/skel`, sem configuração pessoal anterior. Foram confirmados:

- KWin X11 como gerenciador de janelas;
- compositor do próprio KWin ativo, sem Picom;
- quatro workspaces iniciais;
- possibilidade de criar workspace 5, 6, 7, 8 e posteriores;
- `Alt+Tab` para próxima janela;
- `Alt+Shift+Tab` para janela anterior;
- `Alt+F4` para fechar janela;
- `Super+Tab` para próximo workspace;
- `Super+Shift+Tab` para workspace anterior.

> Importante: os **4 workspaces são somente o valor inicial de novos usuários**. Eles não são regravados em cada login e não funcionam como limite.

## Update: bibliotecas opcionais do Tumbler

Durante a investigação do tempo de inicialização da sessão XFCE, o `tumblerd` apresentou falhas ao carregar três plugins porque as respectivas bibliotecas opcionais não estavam instaladas:

```text
tumbler-gepub-thumbnailer.so -> libgepub-0.7.so.0
tumbler-odf-thumbnailer.so   -> libgsf-1.so.114
tumbler-raw-thumbnailer.so   -> libopenrawgnome.so.9
```

No sistema Arch Linux usado nos testes, a correção foi validada instalando:

```text
libgepub
libgsf
libopenraw
```

Após a instalação, o `tumblerd.service` foi reiniciado com sucesso e os erros de carregamento observados anteriormente deixaram de aparecer no teste executado.

Foi adicionado o script complementar:

```text
instalar-dependencias-tumbler-xfce.sh
```

Uso:

```sh
chmod +x instalar-dependencias-tumbler-xfce.sh
sudo ./instalar-dependencias-tumbler-xfce.sh install
```

Para consultar o estado:

```sh
./instalar-dependencias-tumbler-xfce.sh status
```

O script usa Shell POSIX `/bin/sh`, verifica Arch Linux e o pacote `tumbler`, instala somente `libgepub`, `libgsf` e `libopenraw` com `pacman -S --needed`, valida os pacotes e tenta encerrar somente a instância `tumblerd` do usuário que chamou `sudo`, permitindo que o serviço seja recarregado pela sessão quando necessário. Ele **não executa `pacman -Syyu` e não força uma atualização completa do sistema**.

## O que o instalador principal faz

O script `configurar-kwin-x11-xfce4.sh`:

1. confirma que está rodando no Arch Linux;
2. confirma a presença do XFCE (`xfce4-session`, `xfce4-settings` e `xfconf`);
3. cria backup completo dos arquivos que serão modificados;
4. instala, pelos repositórios oficiais do Arch, `kwin-x11`, `systemsettings`, `wmctrl` e `xmlstarlet`;
5. instala `/usr/local/bin/kwin-xfce-session`;
6. altera somente a sessão **Failsafe X11** do XFCE para iniciar o wrapper do KWin;
7. remove atalhos XFCE conhecidos que conflitam com `Super+Tab` e mantém apenas o provider `commands`, pois o provider de atalhos do xfwm4 deixa de ser necessário;
8. grava em `/etc/skel/.config/kwinrc` o estado inicial com 4 workspaces;
9. grava em `/etc/skel/.config/kglobalshortcutsrc` os atalhos do KWin/KGlobalAccel;
10. remove artefatos conhecidos das tentativas antigas que causavam race conditions ou bloqueavam a alteração da quantidade de workspaces;
11. remove `xfwm4`, `xfwm4-themes` (se instalado) e `picom` sem usar `--nodeps`;
12. executa validações estáticas no final;
13. registra log em `/var/log/configurar-kwin-x11-xfce4.log`;
14. oferece restauração a partir do backup criado antes da instalação.

## Instalação

Clone o repositório e execute:

```sh
git clone https://github.com/mintonogueira/configurar-kwin-x11-xfce4.git
cd configurar-kwin-x11-xfce4
chmod +x configurar-kwin-x11-xfce4.sh
sudo ./configurar-kwin-x11-xfce4.sh install
```

Depois faça **logout completo** e entre novamente em uma sessão **XFCE/X11**.

Também é possível executar sem argumento:

```sh
sudo ./configurar-kwin-x11-xfce4.sh
```

`install` é o modo padrão.

## Verificação

```sh
sudo ./configurar-kwin-x11-xfce4.sh status
```

Após login no XFCE/X11, também podem ser usados:

```sh
wmctrl -m
pgrep -a kwin_x11
pgrep -a kglobalacceld
pgrep -a xfwm4
pgrep -a picom
```

O esperado é `Name: KWin`, processos `kwin_x11` e `kglobalacceld` ativos e nenhuma instância de `xfwm4` ou `picom`.

## Novos usuários

A parte decisiva da solução é `/etc/skel`.

Quando um usuário é criado com, por exemplo:

```sh
sudo useradd -m usuario
sudo passwd usuario
```

o Arch copia `/etc/skel` para o novo HOME. Assim, **antes do primeiro login**, o usuário já recebe os defaults corretos do KWin e do KGlobalAccel.

### Workspaces iniciais

`/etc/skel/.config/kwinrc`:

```ini
[Desktops]
Number=4
Rows=1
```

O wrapper não grava `Number=4`. Portanto o usuário pode aumentar ou reduzir a quantidade depois.

### Atalhos

`/etc/skel/.config/kglobalshortcutsrc` contém:

```ini
[kwin]
Walk Through Windows=Alt+Tab,Alt+Tab,Walk Through Windows
Walk Through Windows (Reverse)=Alt+Shift+Tab,Alt+Shift+Tab,Walk Through Windows (Reverse)
Window Close=Alt+F4,Alt+F4,Close Window
Switch to Next Desktop=Meta+Tab,Meta+Tab,Switch to Next Desktop
Switch to Previous Desktop=Meta+Shift+Tab,Meta+Shift+Tab,Switch to Previous Desktop
```

No KGlobalAccel, a tecla física **Super** é representada como **Meta**.

## KWin como compositor

O KWin X11 é simultaneamente o gerenciador de janelas e o compositor desta configuração. O Picom é removido para impedir dois compositores tentando operar sobre a mesma sessão X11.

O `systemsettings` é instalado para disponibilizar a interface gráfica de configuração do KWin, incluindo decorações, efeitos e comportamento das janelas.

## Backup e restauração

Antes da alteração é criado um backup em:

```text
/var/backups/configurar-kwin-x11-xfce4/AAAAMMDD_HHMMSS/
```

O último backup fica registrado em:

```text
/var/backups/configurar-kwin-x11-xfce4/LAST_BACKUP
```

Para restaurar o último backup:

```sh
sudo ./configurar-kwin-x11-xfce4.sh restore
```

Para escolher um backup específico:

```sh
sudo ./configurar-kwin-x11-xfce4.sh restore /var/backups/configurar-kwin-x11-xfce4/AAAAMMDD_HHMMSS
```

A restauração devolve os arquivos anteriores e tenta reinstalar `xfwm4`, `xfwm4-themes` e/ou `picom` quando eles estavam instalados antes da implantação e continuam disponíveis nos repositórios configurados.

## Atualizações do Arch

O script modifica arquivos sob `/etc/xdg/xfce4` que são fornecidos por pacotes do XFCE. Uma atualização futura pode produzir arquivos `.pacnew`. Após atualizações grandes do XFCE/KDE, execute `status` e revise eventuais `.pacnew` antes de substituí-los.

## Limites atuais

- suporte inicial: **Arch Linux**;
- sessão suportada: **X11**;
- não é uma solução para XFCE/Wayland;
- os defaults de atalhos via `/etc/skel` são destinados principalmente a **usuários novos**;
- configurações pessoais já existentes continuam podendo sobrepor defaults globais;
- não são utilizadas opções do pacman que ignorem dependências.

## Scripts complementares

- `corrigir-xfce-workspace-settings-kwin-x11.sh` — cria a camada global de compatibilidade para que chamadas a `xfwm4-workspace-settings` abram o KCM de desktops virtuais do KWin;
- `instalar-dependencias-tumbler-xfce.sh` — instala `libgepub`, `libgsf` e `libopenraw` para corrigir plugins opcionais do Tumbler que estavam falhando por bibliotecas ausentes.

## Documentação adicional

- [`docs/IMPLEMENTACAO.md`](docs/IMPLEMENTACAO.md) — arquitetura e fluxo detalhado;
- [`docs/TESTES.md`](docs/TESTES.md) — validação e testes;
- [`docs/ERROS-E-APRENDIZADOS.md`](docs/ERROS-E-APRENDIZADOS.md) — abordagens que falharam e por quê;
- [`CHANGELOG.md`](CHANGELOG.md) — histórico de correções e updates publicados.

## Referências técnicas

- Arch Linux `kwin-x11`: https://archlinux.org/packages/extra/x86_64/kwin-x11/
- Arch Linux `kglobalacceld`: https://archlinux.org/packages/extra/x86_64/kglobalacceld/
- Arch Linux `systemsettings`: https://archlinux.org/packages/extra/x86_64/systemsettings/
- Arch Linux `xfce4-session`: https://archlinux.org/packages/extra/x86_64/xfce4-session/
- Arch Linux `xmlstarlet`: https://archlinux.org/packages/extra/x86_64/xmlstarlet/
- Xfce session manager: https://docs.xfce.org/xfce/xfce4-session/start