# Aplicação de itens comprados e estatísticas automáticas

## Cosméticos

Os Estandartes Tai, Ji e Fu passam a ser exibidos atrás dos lutadores como peças visuais coloridas.

A Aura do Discípulo é aplicada aos lutadores quando o item está adquirido.

A Moldura dos Mestres adiciona uma borda dourada ao painel de perfil.

## Utilidade

O Espaço Extra de Preset publica `extra_preset_slots = 1` no perfil e pode ser consumido pela interface de presets.

## Estatísticas automáticas

Ao receber o evento `defeated` de um lutador, o runtime identifica o vencedor e registra o resultado no perfil.

Ao concluir um objetivo de treino, uma sessão é registrada automaticamente.

## API

```text
active_items()
extra_preset_slots()
```

## Sinais

```text
cosmetics_applied
battle_stat_recorded
training_session_recorded
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/purchased_items_application_smoke_test.gd
```
