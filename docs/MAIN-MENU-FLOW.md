# Menu principal e fluxo de preparação

## Fluxo

1. O jogo abre o menu principal sobre a cena carregada.
2. A preparação permanece fechada enquanto o jogador escolhe o modo.
3. O jogador seleciona uma das cinco experiências.
4. Modos com configuração própria exibem opções adicionais.
5. Ao continuar, o GameModeRuntime aplica a configuração e a preparação de batalha é aberta.

## Série roguelite

Permite escolher melhor de três ou melhor de cinco antes da preparação.

## Modos

- duelo competitivo;
- arena com loot;
- série roguelite;
- treino Tai · Ji · Fu;
- desafio do campeão.

## API

```text
open_main_menu()
return_to_menu()
selected_mode()
selected_series_format()
is_menu_open()
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/main_menu_flow_smoke_test.gd
```
