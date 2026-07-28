# Perfis de controle, curva visual e dojo de combos

**Produto:** Taijifu Masters  
**Assinatura:** Tehkné Solutions

## Objetivo

Esta sprint transforma a configuração de controle em uma camada de progressão técnica. Cada modelo de gamepad passa a ter perfil próprio, a curva analógica pode ser desenhada visualmente, L2 e R2 deixam de ser fixos e o jogador recebe métricas reais de execução.

## Arquitetura

O autoload abaixo é carregado depois dos runtimes anteriores:

```text
TaijifuControllerMastery
```

Ordem preservada:

```text
AssetPackRegistry
TaijifuWebBridge
TaijifuGamepadTraining
TaijifuGamepadExperience
TaijifuControllerMastery
```

O PACK 00–06 e seus previews não são alterados.

## Perfis automáticos por controle

Arquivo persistido:

```text
user://controller-mastery-profiles.json
```

A identificação usa:

```gdscript
Input.get_joy_guid(device)
```

Quando o GUID não estiver disponível, o runtime usa o nome do controle. Quando nenhum controle estiver conectado, utiliza um perfil de slot:

```text
slot:1
slot:2
```

Cada perfil armazena:

- nome do modelo;
- cinco pontos da curva;
- ação do gatilho esquerdo;
- ação do gatilho direito;
- limiar dos gatilhos;
- início da janela de cancelamento;
- assistência de cancelamento.

Ao reconectar o mesmo controle em outro índice, o GUID recupera automaticamente o perfil e atualiza o dispositivo associado ao jogador.

## Editor visual de curva

A curva possui cinco pontos:

```text
0%   25%   50%   75%   100%
```

Os extremos são fixos:

```text
entrada 0%   → saída 0%
entrada 100% → saída 100%
```

Os três pontos internos podem ser arrastados no SVG. A sanitização impede inversão e mantém a curva monotônica.

Curva padrão:

```json
[0.0, 0.16, 0.44, 0.76, 1.0]
```

A entrada é processada depois da zona morta e interpolada por segmentos. O teclado e o D-pad permanecem intactos.

## L2 e R2 livres

Os gatilhos podem executar qualquer uma das ações:

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

O runtime remove somente eventos dos eixos L2/R2 e recria os aliases selecionados. Eventos de teclado e botões digitais não são apagados.

O limiar aceito fica entre:

```text
0,20 e 0,92
```

## Janelas técnicas

O overlay na arena mostra:

- tempo restante de aparo;
- fase atual da técnica;
- progresso da recuperação;
- abertura da janela de cancelamento;
- elo atual;
- precisão;
- último evento medido.

Fases lidas do próprio lutador:

```text
LIVRE
STARTUP
ATIVO
RECUPERAÇÃO
```

A janela de aparo usa a constante real do combate:

```text
0,09 s
```

A janela de cancelamento começa em uma porcentagem configurável da recuperação, por padrão:

```text
68%
```

## Assistência de cancelamento

Durante a parte final da recuperação, o runtime pode guardar uma entrada de:

```text
Esquiva
Golpe
Eco
Trocar arma
```

A entrada fica em fila por até 420 ms e é executada assim que o lutador retorna ao estado livre. O resultado só conta como cancelamento confirmado quando o estado do lutador realmente muda.

## Dojo de combos

O dojo possui quatro gates:

1. conectar três técnicas com intervalo máximo de 720 ms;
2. confirmar dois acertos dentro da mesma cadeia;
3. realizar um aparo real;
4. executar um cancelamento confirmado.

A progressão utiliza os sinais reais:

```text
technique_started
technique_experienced
parry_performed
```

O dojo não escreve em ranking, temporadas, histórico competitivo ou inventário.

## Métricas

O painel calcula:

- tentativas;
- acertos;
- precisão;
- elo máximo;
- aparos;
- cancelamentos confirmados;
- intervalo médio entre técnicas;
- desvio padrão dos intervalos;
- latência média de cancelamento.

A consistência é o desvio padrão dos links. Quanto menor, mais regular foi a execução.

## Ponte Web

Funções registradas:

```text
taijifuControllerMasteryCommand
taijifuControllerMasteryState
taijifuControllerMasteryStateJson
taijifuControllerMasteryReady
```

Comandos:

```text
get_state
assign_device
set_curve
set_triggers
set_cancel
set_windows
start_dojo
stop_dojo
reset_device
```

## Build Web

Ordem:

```text
prepare-web-pwa.py
inject-gamepad-web.py
inject-controller-mastery-web.py
validate-web-build.py
```

Artefato adicional:

```text
taijifu-controller-mastery-web.js
```

## Critérios de validação

### Godot

- autoload presente;
- curva monotônica;
- zona morta preservada;
- força máxima alcançada;
- perfil de slot criado sem gamepad;
- L2 e R2 aplicados em ações livres;
- aliases antigos removidos;
- teclado preservado;
- limiar de cancelamento persistido;
- janelas técnicas persistidas;
- sequência completa do dojo;
- restauração do perfil padrão.

### Chromium

- painel visível;
- SVG e três pontos internos presentes;
- arraste de ponto funcional;
- perfil GUID/slot apresentado;
- L2 e R2 persistidos;
- limiares em formato pt-BR;
- oito métricas renderizadas;
- ausência de exceções JavaScript;
- ausência de recursos quebrados.

---

**Tehkné Solutions**
