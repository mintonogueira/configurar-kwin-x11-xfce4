# Changelog

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
