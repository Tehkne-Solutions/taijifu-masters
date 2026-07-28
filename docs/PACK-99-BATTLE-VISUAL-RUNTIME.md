# PACK 99 — Aplicação visual na batalha

## Resultado

O `Pack99BattleVisualRuntime` passa a operar como autoload e detecta automaticamente instâncias de `FighterController` na cena ativa.

## Personagens

- aplica uma camada `Sprite2D` do PACK 07 em cada lutador;
- usa os PNGs HD quando estão presentes nos caminhos registrados;
- mantém um fallback gerado em runtime para que o jogo continue funcional sem os binários;
- preserva colisão, física, controles e lógica do lutador original.

## VFX

O runtime observa mudanças reais de vida e postura:

- perda de vida dispara impacto do PACK 09;
- recuperação dispara efeito de cura;
- quebra expressiva de postura dispara impacto dourado;
- todos os efeitos possuem fade e limpeza automática.

## HUD

O PACK 10 passa a orientar uma nova camada HUD com:

- vida;
- postura;
- fôlego;
- personagem;
- elemento;
- arma;
- técnica atual.

A camada é criada sobre a interface existente sem bloquear mouse, teclado ou gamepad.

## Validação

```text
godot --headless --path . --script res://scripts/ci/pack_99_battle_visual_smoke_test.gd
```

## Próxima evolução

Quando os PNGs completos forem copiados para o repositório, o runtime os utiliza automaticamente. A etapa seguinte é mapear cada preset de build para uma classe/direção/variante específica do PACK 07 e ligar cada técnica a um VFX dedicado do PACK 09.
