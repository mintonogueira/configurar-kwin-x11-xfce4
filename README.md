# KWin X11 como Window Manager do XFCE no Arch Linux

Este projeto automatiza a substituição do **xfwm4 + compositor externo** pelo **KWin X11**, mantendo o restante do ambiente XFCE: painel, xfdesktop, Thunar, configurações, plugins e aplicações. O repositório também reúne correções complementares validadas durante a implantação, incluindo a compatibilidade do configurador de workspaces do XFCE com o KWin e a instalação das bibliotecas opcionais necessárias aos plugins do Tumbler.

A implementação inicial é específica para **Arch Linux + XFCE em sessão X11**.

## Estado da solução

**Solução base testada.**

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

## Atualização: compatibilidade do configurador de workspaces do XFCE

Após a remoção do `xfwm4`, foi identificado um comportamento residual do XFCE: ao solicitar a abertura das configurações de espaços de trabalho, alguns componentes ainda tentam executar:

```text
xfwm4-workspace-settings
```

Como esse executável pertence ao `xfwm4`, a chamada passa a falhar após a substituição completa do gerenciador de janelas.

Foi adicionado ao repositório o script:

```text
corrigir-xfce-workspace-settings-kwin-x11.sh
```

Ele instala globalmente um shim em:

```text
/usr/local/bin/xfwm4-workspace-settings
```

Esse shim mantém compatibilidade com a chamada esperada pelo XFCE, mas abre o configurador real de desktops virtuais do KWin por meio de `kcmshell6`.

No Arch Linux atual, o módulo fornecido pelo pacote `kwin-x11` é:

```text
kcm_kwin_virtualdesktops_x11
```

O script também possui fallback para o identificador sem o sufixo `_x11` caso uma versão futura utilize essa forma.

### Aplicar a atualização em uma instalação já configurada

```sh
chmod +x corrigir-xfce-workspace-settings-kwin-x11.sh
sudo ./corrigir-xfce-workspace-settings-kwin-x11.sh install
```

Verificação:

```sh
./corrigir-xfce-workspace-settings-kwin-x11.sh status
```

Depois, no próprio XFCE, abra novamente **Configurações dos espaços de trabalho**.

A correção é global: o adaptador fica em `/usr/local/bin`, portanto não precisa ser repetido usuário por usuário.

O script foi validado sintaticamente como POSIX `sh`; a validação funcional deste update deve ser confirmada no host Arch/XFCE após a instalação.

## Atualização: bibliotecas opcionais do Tumbler

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

Após a instalação, o `tumblerd.service` foi reiniciado com sucesso e os erros de carregamento observados anteriormente deixaram de aparecer na verificação executada.

Foi adicionado ao repositório o script complementar:

```text
instalar-dependencias-tumbler-xfce.sh
```

Aplicação:

```sh
chmod +x instalar-dependencias-tumbler-xfce.sh
sudo ./instalar-dependencias-tumbler-xfce.sh install
```

Verificação:

```sh
./instalar-dependencias-tumbler-xfce.sh status
```

O script usa Shell POSIX `/bin/sh`, verifica Arch Linux e o pacote `tumbler`, instala somente `libgepub`, `libgsf` e `libopenraw` com `pacman -S --needed`, valida os pacotes e tenta encerrar somente a instância `tumblerd` do usuário que chamou `sudo`, permitindo que o serviço seja recarregado pela sessão quando necessário.

Ele **não executa `pacman -Syyu` e não força uma atualização completa do sistema**.

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

## Instalação principal

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

## Script da correção de workspaces

O script `corrigir-xfce-workspace-settings-kwin-x11.sh` foi escrito para ser independente do instalador principal e pode ser usado em máquinas que já receberam a configuração anterior.

Ele:

1. confirma Arch Linux e `pacman`;
2. garante `kwin-x11` e `kcmutils`;
3. confirma a presença de `kwin_x11`, `kcmshell6` e do KCM de desktops virtuais;
4. cria backup de um shim anterior, caso exista;
5. instala atomicamente `/usr/local/bin/xfwm4-workspace-settings`;
6. usa `kcm_kwin_virtualdesktops_x11` no Arch atual;
7. possui fallback para `kcm_kwin_virtualdesktops`;
8. valida se o comando está visível no `PATH`;
9. registra operações em `/var/log/corrigir-xfce-workspace-settings-kwin-x11.log`;
10. oferece `status` e `remove`.

## Script das dependências do Tumbler

O script `instalar-dependencias-tumbler-xfce.sh` é independente do instalador principal e pode ser executado em uma instalação XFCE já existente.

Ele:

1. confirma Arch Linux e `pacman`;
2. confirma que o pacote `tumbler` está instalado;
3. instala `libgepub`, `libgsf` e `libopenraw` com `--needed`;
4. valida os três pacotes após a transação;
5. não usa `-Syyu`;
6. não modifica KWin, KGlobalAccel, workspaces ou atalhos;
7. tenta recarregar o `tumblerd` do usuário que chamou `sudo` sem afetar outros usuários;
8. registra operações em `/var/log/instalar-dependencias-tumbler-xfce.log`;
9. oferece `install`, `status`, `--help` e `--version`.

## Backup e restauração

Antes da alteração principal é criado um backup em:

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

O script de correção de workspaces mantém seus próprios backups em:

```text
/var/backups/corrigir-xfce-workspace-settings-kwin-x11/
```

## Atualizações do Arch

O script principal modifica arquivos sob `/etc/xdg/xfce4` que são fornecidos por pacotes do XFCE. Uma atualização futura pode produzir arquivos `.pacnew`. Após atualizações grandes do XFCE/KDE, execute `status` e revise eventuais `.pacnew` antes de substituí-los.

O shim `/usr/local/bin/xfwm4-workspace-settings` está fora da árvore controlada pelo `pacman`, evitando sobrescrever arquivos pertencentes aos pacotes oficiais.

## Limites atuais

- suporte inicial: **Arch Linux**;
- sessão suportada: **X11**;
- não é uma solução para XFCE/Wayland;
- os defaults de atalhos via `/etc/skel` são destinados principalmente a **usuários novos**;
- configurações pessoais já existentes continuam podendo sobrepor defaults globais;
- não são utilizadas opções do pacman que ignorem dependências.

## Documentação adicional

- [`docs/IMPLEMENTACAO.md`](docs/IMPLEMENTACAO.md) — arquitetura e fluxo detalhado;
- [`docs/TESTES.md`](docs/TESTES.md) — validação e testes;
- [`docs/ERROS-E-APRENDIZADOS.md`](docs/ERROS-E-APRENDIZADOS.md) — abordagens que falharam e por quê;
- [`CHANGELOG.md`](CHANGELOG.md) — histórico das atualizações do repositório.

## Referências técnicas

- Arch Linux `kwin-x11`: https://archlinux.org/packages/extra/x86_64/kwin-x11/
- Arch Linux `kcmutils`: https://archlinux.org/packages/extra/x86_64/kcmutils/
- Arch Linux `kglobalacceld`: https://archlinux.org/packages/extra/x86_64/kglobalacceld/
- Arch Linux `systemsettings`: https://archlinux.org/packages/extra/x86_64/systemsettings/
- Arch Linux `xfce4-session`: https://archlinux.org/packages/extra/x86_64/xfce4-session/
- Arch Linux `xmlstarlet`: https://archlinux.org/packages/extra/x86_64/xmlstarlet/
- Xfce session manager: https://docs.xfce.org/xfce/xfce4-session/start
