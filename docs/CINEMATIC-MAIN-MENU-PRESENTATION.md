# Apresentação cinematográfica do menu principal

## Arena ao fundo

O menu recebe uma composição procedural inspirada em um salão de combate medieval, com pilares, piso em perspectiva e iluminação quente central. A decoração fica atrás da interface e não bloqueia interações.

## Brasões Tai, Ji e Fu

Três brasões permanentes representam os pilares do jogo:

- Tai — Corpo;
- Ji — Fluxo;
- Fu — Técnica.

Cada brasão usa uma cor própria, mantendo a linguagem medieval de metal, pedra e tecido.

## Cards de modos

Os cards de modos recebem símbolos visuais para facilitar reconhecimento rápido por mouse, teclado ou gamepad. Os símbolos cobrem arena, duelo, treino, campeão e série roguelite.

## Resumo do jogador

A faixa inferior apresenta:

- nível;
- XP total;
- fichas de treino;
- estandarte equipado;
- aura equipada;
- moldura equipada.

Os dados são consultados do perfil e da coleção e atualizados periodicamente enquanto o menu está aberto.

## API

```text
presentation_snapshot()
```

## Sinais

```text
presentation_applied
profile_summary_refreshed
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/cinematic_main_menu_smoke_test.gd
```
