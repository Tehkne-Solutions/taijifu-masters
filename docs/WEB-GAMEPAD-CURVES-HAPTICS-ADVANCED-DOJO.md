# Painel Web de gamepads, curvas, gatilhos e dojo avançado

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta sprint amplia o laboratório nativo de gamepad com uma camada Web completa e transforma ajustes de resposta em comportamento efetivo dentro da luta.

A entrega cobre:

- painel de gamepad dentro das Configurações Web;
- associação de dispositivo por jogador;
- remapeamento de botões pelo navegador;
- curvas analógicas reais;
- calibração de zona morta;
- calibração dos gatilhos L2/R2;
- aliases analógicos de técnicas;
- vibração contextual por resultado de combate;
- dojo avançado com agarrão, fuga, troca de arma e eco;
- validação Godot e Chromium.

---

## Arquitetura

Novo autoload:

```text
TaijifuGamepadExperience
```

Arquivo:

```text
scripts/runtime/gamepad_experience_runtime.gd
```

Ele trabalha em conjunto com:

```text
TaijifuGamepadTraining
TaijifuWebBridge
AssetPackRegistry
```

Nenhum dos sistemas anteriores é substituído.

---

## Painel Web

A tela Configurações recebe a seção:

```text
Gamepads, resposta e dojo real
```

Controles disponíveis:

- Jogador 1 ou Jogador 2;
- dispositivo associado;
- zona morta;
- curva analógica;
- limiar dos gatilhos;
- vibração ativada/desativada;
- intensidade da vibração;
- nove ações remapeáveis;
- calibração do analógico;
- calibração dos gatilhos;
- teste de vibração;
- dojo fundamental;
- dojo avançado;
- restauração dos perfis.

Arquivo Web:

```text
web/taijifu-gamepad-web.js
```

A camada é injetada depois da exportação por:

```text
scripts/inject-gamepad-web.py
```

---

## Curvas analógicas

O movimento do analógico esquerdo deixa de depender exclusivamente da curva linear oferecida pelo `InputMap`.

O runtime remove os eventos nativos do eixo esquerdo e injeta forças processadas nas ações:

```text
p1_left
p1_right
p1_down
p2_left
p2_right
p2_down
```

As teclas físicas continuam preservadas.

### Linear

```text
expoente 1,00
```

Resposta proporcional e previsível.

### Precisão

```text
expoente 1,65
```

Reduz movimentos intermediários e favorece controle fino de distância.

### Agressiva

```text
expoente 0,68
```

Aumenta a resposta intermediária e favorece aproximações rápidas.

A transformação respeita a zona morta configurada:

```text
normalizado = (magnitude - zona_morta) / (1 - zona_morta)
```

---

## Calibração do analógico

O sistema mede:

```text
JOY_AXIS_LEFT_X
JOY_AXIS_LEFT_Y
```

A sugestão automática usa:

```text
maior desvio + 0,08
```

com limites compatíveis com o laboratório base:

```text
0,15 a 0,55
```

---

## Gatilhos L2 e R2

Cada jogador recebe dois aliases analógicos:

```text
L2 → Elemento
R2 → Golpe
```

Os botões anteriores permanecem ativos. O jogador pode usar botão ou gatilho para a mesma ação.

O limiar configurável fica entre:

```text
0,25 e 0,90
```

A calibração considera controles com gatilhos:

- unipolares, com repouso em `0`;
- bipolares, com repouso próximo de `-1`.

---

## Vibração contextual

A vibração usa:

```gdscript
Input.start_joy_vibration(device, weak, strong, duration)
```

Cada resultado possui assinatura própria:

```text
hit
blocked
parried
evaded
posture_broken
grab_started
grab_finished
grab_escaped
weapon_swapped
technique_reproduced
```

A vibração é configurada por jogador e respeita:

```text
haptics_enabled
vibration_scale
```

A ausência de suporte do navegador ou do controle não bloqueia a luta.

---

## Dojo avançado

O dojo fundamental continua validando:

```text
hit → blocked/parried → evaded
```

O novo dojo avançado exige quatro eventos reais:

### 1. Agarrão

```text
grab_started
```

O P1 deve agarrar o alvo usando a técnica Ji.

### 2. Fuga

```text
grab_escaped
```

O P2 inicia um agarrão real e mantém a captura por tempo suficiente para o jogador alternar direções e combinar Esquiva, Golpe ou Guarda.

### 3. Troca de arma

```text
weapon_swapped
```

O jogador precisa trocar para outra arma disponível no loadout.

### 4. Eco

```text
technique_reproduced
```

O runtime fornece uma técnica armazenada e a etapa só termina quando o sistema de eco a reproduz.

Ao concluir:

```text
advanced_training_completed = true
```

---

## Persistência

O laboratório base continua em:

```text
user://gamepad-training-profile.json
```

As novas preferências ficam em:

```text
user://gamepad-experience-profile.json
```

Estrutura:

```json
{
  "version": 1,
  "players": {
    "1": {
      "response_curve": "precision",
      "trigger_threshold": 0.55,
      "haptics_enabled": true,
      "vibration_scale": 0.85
    }
  },
  "advanced_training_completed": false
}
```

A separação mantém compatibilidade com os perfis de gamepad já salvos.

---

## Ponte Web

O runtime registra:

```text
taijifuGamepadExperienceCommand
taijifuGamepadExperienceState
taijifuGamepadExperienceStateJson
taijifuGamepadExperienceReady
```

A interface envia comandos em JSON:

```json
{
  "command": "set_tuning",
  "player": 1,
  "curve": "precision",
  "trigger_threshold": 0.60,
  "haptics_enabled": true,
  "vibration_scale": 0.85
}
```

---

## Build Web

O processo agora executa:

```text
prepare-web-pwa.py
→ inject-gamepad-web.py
→ validate-web-build.py
```

O validador exige:

- arquivo do painel Web;
- marcador no `index.html`;
- ponte de comandos;
- curvas;
- calibração de gatilhos;
- acesso aos dois dojos;
- captura de botões por `requestAnimationFrame`.

---

## Validação Godot

O gate dedicado confirma:

- autoload presente;
- curva linear padrão;
- diferença matemática entre curvas;
- atuação da zona morta;
- persistência de ajuste;
- rejeição de jogador e curva inválidos;
- associação de dispositivo;
- zona morta do perfil base;
- R2 como Golpe;
- L2 como Elemento;
- preservação do teclado;
- sequência avançada completa;
- restauração dos padrões.

---

## Validação Chromium

O navegador confirma:

- ponte pronta;
- painel visível nas Configurações;
- bindings renderizados;
- alteração de dispositivo;
- zona morta em formato pt-BR;
- curva de precisão;
- limiar dos gatilhos;
- desativação da vibração;
- intensidade personalizada;
- persistência confirmada pelo Godot;
- ausência de exceções e recursos quebrados.

---

## Limites atuais

- o navegador não consegue gerar eventos físicos de gamepad sem hardware real;
- a captura Web depende da API `navigator.getGamepads()`;
- alguns controles não oferecem vibração;
- controles podem apresentar índices de botão diferentes do padrão;
- L2 e R2 são aliases fixos nesta versão;
- o dojo avançado usa o P1 como aprendiz e o P2 como alvo controlado.

---

## Próxima evolução recomendada

- editor de curva por pontos;
- perfis por modelo/GUID do controle;
- remapeamento dos gatilhos;
- suporte a giroscópio;
- indicadores visuais de janela de aparo;
- dojo de combos e cancelamentos;
- sincronização dos perfis com a conta.

---

**Tehkné Solutions**
