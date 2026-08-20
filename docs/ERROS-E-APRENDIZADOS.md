# Erros e aprendizados

Este documento registra abordagens que foram testadas e **não devem voltar para a implementação final**.

## 1. Confiar apenas em `/etc/xdg/kglobalshortcutsrc`

Não foi confiável para usuários novos. No primeiro login, KWin/KGlobalAccel podia registrar defaults próprios e recolocar `Meta+Tab` no alternador de janelas.

**Solução final:** defaults do usuário em `/etc/skel/.config/kglobalshortcutsrc`, existentes antes do primeiro login.

## 2. Corrigir atalhos depois do KWin subir

Foram testados wrappers e autostarts que paravam/reiniciavam `plasma-kglobalaccel.service` e reescreviam `kglobalshortcutsrc` depois do login.

Isso criou dependência de ordem de inicialização e race conditions.

**Solução final:** não corrigir atalhos pós-login. O wrapper só inicia KGlobalAccel e KWin.

## 3. Fazer XFCE e KGlobalAccel disputarem `Super+Tab`

O XFCE foi configurado temporariamente para capturar `Super+Tab` e executar ações KWin por D-Bus. Ao mesmo tempo, KGlobalAccel também podia registrar a tecla.

Foram observados conflitos de grab e comportamento imprevisível.

**Solução final:** os cinco atalhos são registrados diretamente pelo KGlobalAccel. O XFCE não captura `Super+Tab`.

## 4. `xfsettingsd --replace` como correção permanente

Reiniciar `xfsettingsd` foi útil como diagnóstico, mas não é arquitetura de configuração de atalhos.

**Solução final:** não usar `xfsettingsd --replace` no instalador.

## 5. Autostart de política pós-login

Foi testado um `kwin-xfce-shortcuts-policy.desktop` que aplicava alterações após a sessão iniciar.

Essa abordagem era sujeita a corrida entre XFCE, KWin e kglobalacceld.

**Solução final:** o instalador remove esse artefato se ele existir.

## 6. Regravar `Number=4` em todo login

Este foi um erro importante.

O wrapper chegou a executar:

```sh
kwriteconfig6 --file kwinrc --group Desktops --key Number 4
kwriteconfig6 --file kwinrc --group Desktops --key Rows 1
```

em toda sessão.

O efeito era transformar 4 workspaces em uma política permanente: o usuário tentava criar 5, 6, 7 ou mais e a configuração era restaurada para 4 no login seguinte.

**Solução final:** `Number=4` existe somente em `/etc/skel/.config/kwinrc`. O wrapper jamais altera o número de workspaces.

## 7. Usar um único workspace e concluir que o atalho está quebrado

`Switch to Next Desktop` não produz mudança visível quando só existe um desktop virtual.

Isso mascarou parte do diagnóstico inicial.

**Solução final:** novos usuários começam com 4 desktops virtuais, permitindo validar imediatamente os atalhos de navegação.

## 8. Executar `systemctl --user` como root para a sessão de outro usuário

Isso falhou porque o escopo `--user` pertence ao barramento e à instância systemd do usuário logado.

**Solução final:** o wrapper é executado dentro da própria sessão do usuário e chama:

```sh
systemctl --user start plasma-kglobalaccel.service
```

no contexto correto.

## 9. Confundir `Super` e `Meta`

No KGlobalAccel, a tecla física Super é representada nas combinações como `Meta`.

**Solução final:**

```text
Super+Tab       -> Meta+Tab
Super+Shift+Tab -> Meta+Shift+Tab
```

## 10. Validar com usuário já alterado

Usuários usados durante muitas tentativas carregavam configuração pessoal residual, tornando o teste inconclusivo.

**Solução final:** a validação decisiva é feita com usuário criado **depois** da preparação de `/etc/skel`.

## Regra de manutenção

Uma mudança futura só deve ser incorporada como padrão global depois de ser validada em um HOME novo, sem configurações anteriores, e depois de ser confirmado que não bloqueia a personalização posterior do usuário.
