# Ponte Web ↔ Godot, remapeamento e treino prático

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta entrega conecta a camada Web diretamente ao runtime Godot para que menu, pausa e controles deixem de ser apenas elementos visuais.

A implementação cobre:

- pausa real da `SceneTree`;
- retomada real da arena;
- remapeamento de teclado para P1 e P2;
- preservação dos controles de gamepad;
- atualização automática dos botões touch do P1;
- atualização automática do tutorial;
- treino prático sobre a arena;
- persistência local;
- validação Godot e Chromium.

---

## Ponte JavaScript ↔ Godot

O autoload abaixo é iniciado antes da cena principal:

```text
TaijifuWebBridge
```

Arquivo:

```text
scripts/runtime/web_platform_bridge_runtime.gd
```

O runtime Web expõe ao navegador:

```text
taijifuGodotSetPaused
taijifuGodotApplyBindings
taijifuGodotResetBindings
taijifuGodotGetState
taijifuGodotBridgeReady
taijifuGodotPaused
taijifuGodotBindingsJson
```

A interface JavaScript consolidada fica disponível em:

```text
window.taijifuGodotBridge
```

---

## Pausa real

Ao abrir o menu Web durante a arena:

```text
SceneTree.paused = true
```

Ao selecionar `Voltar à arena` ou fechar o menu com `Esc`:

```text
SceneTree.paused = false
```

O autoload usa:

```text
process_mode = PROCESS_MODE_ALWAYS
```

Assim, a ponte continua respondendo mesmo com o restante do jogo pausado.

A pausa interrompe:

- física;
- movimentação;
- ataques;
- cronômetros da arena;
- inteligência dos bots;
- progressão dos rounds.

A camada HTML continua funcional para permitir navegação e retomada.

---

## Remapeamento do teclado

As configurações passam a mostrar um seletor:

```text
Jogador 1
Jogador 2
```

Cada jogador possui doze ações configuráveis:

```text
Mover esquerda
Mover direita
Queda rápida
Pular
Esquiva
Golpe
Empurrão
Agarrão
Eco
Guarda/aparo
Elemento
Trocar arma
```

Fluxo:

1. selecionar uma ação;
2. pressionar uma nova tecla;
3. salvar automaticamente;
4. aplicar ao `InputMap` do Godot;
5. atualizar tutorial e touch.

Quando a tecla já pertence a outra ação, as duas teclas são trocadas. Isso evita duplicidades silenciosas.

Teclas reservadas como `Esc`, `Enter` e funções competitivas não entram no conjunto permitido.

---

## Gamepads preservados

O remapeamento remove e recria somente eventos:

```text
InputEventKey
```

Eventos abaixo permanecem intactos:

```text
InputEventJoypadButton
InputEventJoypadMotion
```

Portanto, personalizar teclado não remove:

- analógico;
- salto;
- esquiva;
- golpe;
- empurrão;
- agarrão;
- guarda;
- elemento;
- eco;
- troca de arma.

---

## Fonte única dos controles

As teclas ficam persistidas no mesmo objeto de preferências Web:

```text
localStorage: taijifu.web.preferences.v1
```

Campo:

```json
{
  "keyboardBindings": {
    "p1_attack": "KeyF",
    "p1_swap": "KeyT",
    "p2_attack": "Numpad1"
  }
}
```

O carregamento aplica os valores a três lugares:

```text
InputMap do Godot
Tutorial adaptativo
Botões touch do P1
```

Foi corrigida uma inconsistência anterior:

```text
Trocar arma P1 = T
```

O botão touch `Arma` enviava `V`, enquanto o Godot registrava `T`. Agora ambos utilizam o mesmo binding.

---

## Treino prático

O menu de configurações recebe:

```text
Treino prático
```

Ao iniciar:

- o menu fecha;
- a arena é retomada;
- um painel compacto aparece sobre o jogo;
- o jogador executa os comandos configurados.

Sequência:

1. mover para esquerda ou direita;
2. pular;
3. executar o golpe principal;
4. ativar a guarda;
5. usar o elemento.

O treino reconhece:

- teclado físico;
- botões touch;
- teclas remapeadas.

Ao concluir:

```text
practiceCompleted = true
```

O treino não altera ranking, histórico, temporada ou atributos.

---

## Arquitetura

```text
project.godot
scripts/runtime/web_platform_bridge_runtime.gd
scripts/ci/web_platform_bridge_smoke_test.gd
web/taijifu-web-shell.js
web/taijifu-web-menu.js
web-tests/web-smoke.spec.cjs
scripts/validate-web-build.py
.github/workflows/godot-ci.yml
```

---

## Validação Godot

O gate dedicado confirma:

- autoload disponível;
- bindings padrão;
- troca de arma em `KeyT`;
- remapeamento para `KeyJ`;
- rejeição de ação desconhecida;
- rejeição de tecla não suportada;
- aplicação em lote;
- preservação de gamepad;
- pausa real;
- retomada real;
- restauração dos padrões.

---

## Validação Chromium

### Desktop

- conclusão do tutorial inicial;
- ponte Godot pronta;
- menu pausa a arena;
- configurações permanecem funcionais durante a pausa;
- golpe remapeado para `J`;
- binding confirmado pelo Godot;
- treino prático reconhece `A`, `W`, `J`, `R` e `C`;
- conclusão persistida;
- retorno à arena retoma a `SceneTree`.

### Mobile

- menu pausa a arena;
- golpe remapeado para `J`;
- botão touch passa a enviar `KeyJ`;
- botão `Arma` passa a enviar `KeyT`;
- eventos `keydown` e `keyup` preservados;
- modo canhoto e escala continuam compatíveis;
- orientação paisagem continua obrigatória.

---

## Limites atuais

- remapeamento de gamepad ainda não está disponível;
- controles touch continuam representando apenas o P1;
- treino prático valida entrada, não acerto real no adversário;
- configurações continuam locais ao navegador;
- não existe sincronização em nuvem.

---

## Próxima evolução recomendada

- calibração e remapeamento de gamepad;
- treino com alvos e confirmação de acerto;
- perfis de controle por jogador;
- paletas para daltonismo;
- sincronização das preferências com a conta;
- telemetria opcional de dificuldades no tutorial.

---

**Tehkné Solutions**
