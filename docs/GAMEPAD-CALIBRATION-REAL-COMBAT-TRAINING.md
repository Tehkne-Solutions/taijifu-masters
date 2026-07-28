# Laboratório de gamepad e treino real de combate

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta sprint adiciona uma camada nativa do Godot para configurar gamepads e validar fundamentos de combate através dos resultados reais da arena.

A entrega cobre:

- detecção dos controles conectados;
- associação de dispositivo por jogador;
- remapeamento de nove ações por jogador;
- resolução automática de conflitos;
- ajuste manual de zona morta;
- calibração automática baseada no desvio atual do analógico;
- persistência em `user://`;
- treino com um lutador-alvo real;
- confirmação de acerto, defesa e esquiva pelo sistema de hurtbox;
- restauração automática dos controles do P2 após o treino.

---

## Acesso

No jogo, pressione:

```text
F10
```

Também é possível abrir o laboratório pelo botão `Start/Menu` de qualquer gamepad.

Com o painel aberto:

```text
1 / 2       seleciona o jogador
↑ / ↓       seleciona a ação
Enter       inicia captura de botão
← / →       ajusta a zona morta
D           calibração automática
P           inicia treino real
R           restaura o perfil padrão
Esc         fecha ou encerra o treino
```

---

## Ações remapeáveis

Cada jogador possui configuração independente para:

```text
Pular
Esquiva
Golpe
Empurrão
Agarrão
Guarda/aparo
Elemento
Eco
Trocar arma
```

Movimento continua associado ao analógico esquerdo. A zona morta configurada é aplicada a movimento e ações do jogador selecionado.

---

## Associação de dispositivos

Os padrões são:

```text
Jogador 1 → dispositivo 0
Jogador 2 → dispositivo 1
```

Ao iniciar a captura e pressionar um botão em qualquer controle, o dispositivo desse evento passa a ser associado ao jogador selecionado.

Isso permite corrigir situações em que o navegador ou o sistema operacional enumera os controles em ordem diferente.

---

## Resolução de conflitos

Quando um botão já está associado a outra ação, os dois bindings são trocados.

Exemplo:

```text
Golpe = X
Empurrão = Y
```

Ao atribuir `Y` ao Golpe:

```text
Golpe = Y
Empurrão = X
```

Nenhuma ação fica duplicada ou sem comando.

---

## Zona morta

Faixa permitida:

```text
0,15 a 0,55
```

A calibração automática mede o maior valor absoluto dos eixos:

```text
JOY_AXIS_LEFT_X
JOY_AXIS_LEFT_Y
```

A recomendação aplicada é:

```text
desvio atual + 0,08
```

O resultado é limitado à faixa segura.

---

## Persistência

O perfil é salvo em:

```text
user://gamepad-training-profile.json
```

Estrutura principal:

```json
{
  "version": 1,
  "players": {
    "1": {
      "device": 0,
      "deadzone": 0.25,
      "buttons": {
        "attack": 2,
        "block": 10
      }
    }
  },
  "real_training_completed": false
}
```

O remapeamento altera apenas eventos `InputEventJoypadButton`. Teclas configuradas anteriormente permanecem intactas.

---

## Treino real

O treino cria ou reutiliza os dois lutadores reais da cena principal.

O P2 tem seus eventos de entrada temporariamente removidos e passa a atuar como alvo controlado pelo runtime. O sistema não usa contagem de teclas nem simulação visual para aprovar etapas.

### Etapa 1 — Acerto confirmado

O jogador precisa acertar o P2.

A etapa só avança quando o defensor emite:

```text
outcome_id = hit
```

### Etapa 2 — Defesa confirmada

O P2 executa ataques reais em intervalos controlados.

A etapa aceita:

```text
outcome_id = blocked
```

ou:

```text
outcome_id = parried
```

### Etapa 3 — Esquiva confirmada

O P2 continua atacando de forma controlada.

A etapa só termina quando o combate emite:

```text
outcome_id = evaded
```

---

## Isolamento competitivo

Durante o treino:

- o fechamento da arena é interrompido;
- o P2 não recebe comandos humanos;
- vida, postura e stamina são restauradas entre etapas;
- o alvo usa uma técnica real do catálogo;
- o sistema de hitbox e hurtbox permanece ativo;
- ranking, temporada e histórico não são alterados.

Ao encerrar:

- os eventos originais do P2 são restaurados;
- o perfil de gamepad é reaplicado;
- os lutadores são reiniciados;
- o fluxo normal da arena volta a funcionar.

---

## Arquitetura

```text
project.godot
scripts/runtime/gamepad_training_runtime.gd
scripts/ci/web_platform_bridge_smoke_test.gd
docs/GAMEPAD-CALIBRATION-REAL-COMBAT-TRAINING.md
```

Autoload:

```text
TaijifuGamepadTraining
```

O runtime usa `PROCESS_MODE_ALWAYS`, permitindo abrir e fechar o laboratório mesmo quando o menu Web pausou a arena.

---

## Validação automatizada

O gate do Godot confirma:

- presença do autoload;
- perfil padrão;
- Golpe P1 em `JOY_BUTTON_X`;
- remapeamento para outro botão e dispositivo;
- preservação do teclado;
- rejeição de jogador e ação inválidos;
- aplicação da zona morta;
- limite máximo da calibração;
- progressão `hit → blocked → evaded`;
- restauração do perfil padrão.

---

## Próxima evolução recomendada

- interface visual Web para o mesmo perfil nativo;
- calibração dos dois analógicos e gatilhos;
- curvas de resposta linear, suave e agressiva;
- vibração diferenciada para acerto, bloqueio e aparo;
- treino de agarrão e fuga;
- treino de troca de arma e eco;
- telemetria local opcional de precisão e tempo de reação.

---

**Tehkné Solutions**
