# Changelog

## 2026-08-20 — Dependências opcionais do Tumbler

Durante a investigação do tempo de inicialização da sessão XFCE, o `tumblerd.service` apresentou aproximadamente 20,5 segundos de inicialização e o journal registrou falhas de carregamento dos plugins:

```text
tumbler-gepub-thumbnailer.so -> libgepub-0.7.so.0 ausente
tumbler-odf-thumbnailer.so   -> libgsf-1.so.114 ausente
tumbler-raw-thumbnailer.so   -> libopenrawgnome.so.9 ausente
```

No sistema Arch Linux usado nos testes, a instalação de `libgepub`, `libgsf` e `libopenraw` foi concluída com sucesso. Após reiniciar `tumblerd.service`, o serviço voltou ativo e os erros acima não reapareceram na verificação executada.

### Script complementar adicionado

```text
instalar-dependencias-tumbler-xfce.sh
```

O script:

- usa Shell POSIX `/bin/sh`;
- valida Arch Linux e a presença do pacote `tumbler`;
- instala apenas `libgepub`, `libgsf` e `libopenraw` com `pacman -S --needed --noconfirm`;
- não executa `pacman -Syyu` e não força atualização completa do sistema;
- valida que os três pacotes estejam instalados após a transação;
- quando executado via `sudo`, tenta encerrar somente o `tumblerd` do usuário chamador para que a sessão o recarregue com as bibliotecas disponíveis;
- fornece modos `install`, `status`, `--help` e `--version`;
- registra log em `/var/log/instalar-dependencias-tumbler-xfce.log`.

### Estado de validação

O código foi validado sintaticamente com `dash -n` e `sh -n`. A correção de dependências foi também validada funcionalmente no sistema Arch Linux em que os erros foram observados: os três pacotes foram instalados e o `tumblerd.service` reiniciou corretamente.

## 2026-08-20 — Compatibilidade do configurador de workspaces do XFCE

Foi identificado um problema após a remoção completa do `xfwm4`: componentes do XFCE ainda podem tentar executar `xfwm4-workspace-settings` ao abrir as configurações dos espaços de trabalho.

Como o binário deixa de existir quando `xfwm4` é removido, o XFCE exibe erro de processo filho inexistente.

### Correção adicionada

Novo script:

```text
corrigir-xfce-workspace-settings-kwin-x11.sh
```

Ele instala globalmente:

```text
/usr/local/bin/xfwm4-workspace-settings
```

O arquivo funciona como uma camada de compatibilidade e redireciona a chamada antiga do XFCE para o KCM de desktops virtuais do KWin.

No Arch Linux atual é utilizado:

```text
kcmshell6 kcm_kwin_virtualdesktops_x11
```

Há fallback para:

```text
kcmshell6 kcm_kwin_virtualdesktops
```

### Características

- Shell POSIX `/bin/sh`;
- suporte inicial a Arch Linux + XFCE/X11 + KWin X11;
- instalação global para todos os usuários;
- dependências verificadas/instaladas via `pacman` (`kwin-x11` e `kcmutils`);
- backup de um shim anterior antes da substituição;
- escrita temporária seguida de `mv` para reduzir risco de arquivo parcial;
- validação do `PATH`;
- modos `install`, `status` e `remove`;
- logs em `/var/log/corrigir-xfce-workspace-settings-kwin-x11.log`.

### Estado de validação

O código foi validado sintaticamente com `dash -n` e `sh -n` antes da publicação. A validação funcional do update deve ser confirmada em uma sessão Arch Linux + XFCE/X11 após a instalação.

## 2026-08-20 — Workspaces iniciais sem limite permanente

A configuração de quatro workspaces foi corrigida para ser apenas o estado inicial dos novos usuários por meio de `/etc/skel/.config/kwinrc`.

O wrapper `/usr/local/bin/kwin-xfce-session` não deve regravar `Number=4` em cada login. Assim, o usuário pode posteriormente criar 5, 6, 7, 8 ou mais workspaces normalmente.