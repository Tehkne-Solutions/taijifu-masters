# Gravação de inputs, fantasma e certificações Tai · Ji · Fu

**Produto:** Taijifu Masters  
**Assinatura:** Tehkné Solutions

## Objetivo

Esta sprint transforma o treino técnico em um ciclo mensurável:

```text
executar
→ gravar
→ reproduzir
→ comparar
→ corrigir
→ dominar
→ certificar
```

O sistema registra a tentativa do jogador, reproduz um fantasma visual, compara o resultado com o melhor registro e alimenta progressão por arma, técnica e caminho Tai/Ji/Fu.

Nenhuma gravação altera ranking, histórico competitivo, temporada, inventário ou resultado da partida.

---

## Arquitetura

Novo autoload:

```text
TaijifuInputGhostMastery
```

Ordem preservada:

```text
AssetPackRegistry
TaijifuWebBridge
TaijifuGamepadTraining
TaijifuGamepadExperience
TaijifuControllerMastery
TaijifuInputGhostMastery
```

Arquivos principais:

```text
scripts/runtime/input_ghost_visual.gd
scripts/runtime/input_ghost_mastery_runtime.gd
web/taijifu-input-ghost-mastery-web.js
scripts/inject-input-ghost-mastery-web.py
scripts/ci/input_ghost_mastery_smoke_test.gd
web-tests/input-ghost-mastery-web.spec.cjs
```

Os PACKS 00–06 não são modificados.

---

## Gravação

Atalho:

```text
F6 → iniciar ou encerrar
```

A interface Web também possui:

```text
Gravar tentativa
```

O limite de uma sessão é:

```text
12 segundos
```

Cada frame registra:

- tempo relativo;
- posição;
- velocidade;
- direção;
- fase da técnica;
- última técnica;
- arma equipada;
- intensidade das ações ativas.

Ações observadas:

```text
esquerda
 direita
 queda rápida
 salto
 esquiva
 golpe
 empurrão
 agarrão
 guarda
 elemento
 eco
 troca de arma
```

A gravação não injeta entradas e não controla o P2.

---

## Fantasma

Atalhos:

```text
F7 → reproduzir melhor tentativa
F8 → encerrar reprodução
```

O fantasma é uma silhueta 2D translúcida desenhada pelo Godot. Ele reproduz:

- posição;
- direção;
- fase atual;
- arma;
- ações ativas;
- duração da tentativa.

As cores mudam conforme a fase:

```text
livre
startup
ativo
recuperação
```

A reprodução é visual. Ela não aplica inputs no jogador, não gera golpes e não interfere na física.

Persistência do melhor replay:

```text
user://input-ghost-best.json
```

---

## Pontuação técnica

Cada tentativa recebe pontuação usando:

- precisão;
- elo máximo;
- velocidade média dos links;
- consistência;
- aparos;
- cancelamentos.

Pesos:

```text
Precisão       320 pontos
Elo            220 pontos
Velocidade     180 pontos
Consistência   120 pontos
Aparos          90 pontos máximos
Cancelamentos   90 pontos máximos
```

O melhor replay só é substituído quando a nova pontuação é superior.

---

## Comparação

O painel apresenta:

```text
Tentativa atual
Melhor tentativa
Variação
```

Comparações:

- pontuação;
- precisão;
- elo;
- link médio;
- consistência.

Para link e consistência, valores menores representam execução mais rápida e regular.

---

## Desafios por técnica

Cada técnica ganha um registro próprio:

```text
attempts
hits
best_chain
fastest_link_ms
tier
```

### Fundamento

```text
5 tentativas
2 acertos
```

### Domínio

```text
12 tentativas
6 acertos
elo 3
```

### Mestria

```text
25 tentativas
15 acertos
65% de precisão
link ≤ 550 ms
```

Os desafios são criados automaticamente quando uma técnica é utilizada.

---

## Progressão por arma

A sprint não cria um segundo sistema de arma.

Ela consulta o ledger existente:

```text
user://weapon_mastery.json
```

O painel exibe:

- arma atual;
- XP;
- estágio;
- registros conhecidos do P1.

Estágios preservados:

```text
DESCONHECIDA
FAMILIAR
TREINADA
PROFICIENTE
DOMINADA
LENDÁRIA
```

---

## Progressão Tai, Ji e Fu

Persistência:

```text
user://input-ghost-mastery.json
```

Cada caminho registra:

- XP;
- usos;
- acertos;
- contatos defendidos;
- contatos aparados;
- contatos evitados;
- aparos realizados;
- cancelamentos;
- melhor elo;
- melhor precisão;
- link mais rápido.

XP por evento:

```text
Uso           +1,0
Acerto        +4,0
Defendido     +2,0
Aparado       +0,8
Evitado       +0,4
Aparo feito   +3,0
Cancelamento  +3,0
```

---

## Certificações

Cada caminho possui:

```text
EM FORMAÇÃO
INICIADO
DISCÍPULO
MESTRE
```

### Iniciado

```text
40 XP
8 usos
3 acertos
```

### Discípulo

```text
120 XP
20 usos
10 acertos
elo 3
45% de precisão
```

### Mestre — requisitos comuns

```text
300 XP
45 usos
24 acertos
elo 4
60% de precisão
```

### Mestre Tai

```text
2 cancelamentos
link ≤ 560 ms
```

### Mestre Ji

```text
3 aparos reais
```

### Mestre Fu

```text
68% de precisão
2 desafios no nível Domínio ou superior
```

A certificação é calculada novamente após eventos, desafios e conclusão de tentativas.

---

## Interface Web

Nova seção:

```text
Fantasma, desafios e certificações Tai · Ji · Fu
```

Inclui:

- gravar tentativa;
- reproduzir melhor;
- limpar recorde;
- habilitar overlay;
- resumo técnico;
- comparação;
- maestria de arma;
- cartões Tai/Ji/Fu;
- lista de desafios.

Durante gravação ou reprodução, uma barra fixa permite interromper o processo sem reabrir o menu.

---

## Ponte Web

Funções:

```text
taijifuGhostMasteryCommand
taijifuGhostMasteryState
taijifuGhostMasteryStateJson
taijifuGhostMasteryReady
```

Comandos:

```text
get_state
start_recording
stop_recording
play_best
stop_playback
clear_best
set_overlay
reset_progress
```

---

## Validação

### Godot CI

- autoload presente;
- pontuação calculada;
- precisão correta;
- comparação positiva;
- replay com frames;
- tiers de desafio;
- Mestre Tai;
- Mestre Ji;
- Mestre Fu;
- ponte com maestria de arma.

### Chromium

- painel visível;
- gravação real com mais de dez frames;
- tentativa persistida;
- melhor replay disponível;
- comparação disponível;
- três cartões de certificação;
- desafio criado por técnica;
- reprodução do fantasma;
- screenshot;
- nenhuma exceção JavaScript;
- nenhum recurso quebrado.

---

## Próxima evolução recomendada

- exportar e importar fantasmas;
- compartilhar desafios por código;
- fantasma de amigos;
- corrida contra fantasma em arenas de percurso;
- temporadas de certificação;
- provas específicas por arma;
- certificados visuais em PNG;
- ranking opcional de execução técnica.

---

**Tehkné Solutions**
