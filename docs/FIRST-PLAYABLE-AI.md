# First Playable — combate contra IA

## Objetivo

Transformar o `TacticalBotRuntime` existente em uma experiência clara e testável dentro da vertical slice, sem reescrever o sistema de decisão.

## Dificuldades expostas

```text
[1] APRENDIZ  → apprentice
[2] DISCÍPULO → disciple (padrão)
[3] MESTRE    → master
```

O nível interno `adept` continua disponível no catálogo geral, mas não aparece no primeiro nível para manter a escolha simples.

## Diferenças reais

As dificuldades usam os parâmetros do `BotBehaviorCatalog`:

- tempo de reação;
- intervalo entre decisões;
- chance de defesa;
- chance de erro;
- velocidade de navegação;
- frequência de tentativa de fuga e esquiva.

A ordem é verificável:

```text
Aprendiz → mais lento e mais erros
Discípulo → equilíbrio padrão
Mestre → decisões rápidas e poucos erros
```

## Persistência

A dificuldade selecionada permanece ativa durante:

- contagem regressiva;
- combate;
- resultado;
- revanche iniciada com `Enter`.

O controlador principal pode desabilitar temporariamente a IA fora da luta, mas o `FirstPlayableDifficultyController` reaplica o nível selecionado sem resetar a escolha.

## HUD

A vertical slice exibe:

```text
IA <NÍVEL ATUAL> • [1] APRENDIZ • [2] DISCÍPULO • [3] MESTRE
```

O status principal da partida também é sincronizado com o nível atual. O painel técnico de intenção do `TacticalBotRuntime` permanece oculto para o jogador.

## Validação automatizada

`tests/first_playable_ai_behavior_test.gd` verifica:

1. contrato das três dificuldades;
2. ordem estrita de chance de erro;
3. ordem estrita dos intervalos de decisão;
4. seleção de Mestre;
5. IA habilitada ao iniciar a luta;
6. movimento de navegação em direção a um oponente distante;
7. tentativa ofensiva em curta distância;
8. persistência de Mestre após revanche.

Saída esperada:

```text
FIRST_PLAYABLE_AI_BEHAVIOR_OK
```

## Estado

```text
Navegação: integrada
Combate ofensivo: integrado
Defesa/esquiva: integrado
Três dificuldades: integradas
Persistência na revanche: integrada
Balanceamento final: pendente de playtest humano
```

Assinatura: Tehkné Solutions
