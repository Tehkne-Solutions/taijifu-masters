# Integração de atributos estratégicos ao combate

Os atributos consolidados da preparação agora alteram o comportamento real dos lutadores.

## FOR

Aumenta força, técnica, dano direto, pressão ofensiva e duração útil da fase ativa. O ganho é limitado para preservar a leitura técnica do combate.

## DEF

Aumenta defesa, resistência, controle, vida, postura, redução de dano, resistência a impacto e recuperação de postura.

## AGI

Aumenta agilidade, percepção, foco, velocidade de movimento, salto, duração da esquiva, redução do cooldown de esquiva, recuperação de técnicas e regeneração de fôlego.

## Balanceamento

Os modificadores trabalham em uma faixa segura de 0,82× a 1,22×. A build original é preservada em metadados e os valores são sempre recalculados a partir dela, impedindo multiplicação acumulativa.

A arma principal, arma secundária e elemento já são incorporados aos valores FOR, DEF e AGI pelo `PreparationBuildComparisonRuntime`.

## Aplicação dinâmica

O runtime localiza os lutadores pelo `player_index`, consulta os loadouts do Conselho de Guerra e atualiza:

- dano;
- dano de postura;
- defesa;
- vida e postura máximas;
- velocidade e salto;
- janela e cooldown de esquiva;
- startup, fase ativa e recuperação de técnicas;
- regeneração de fôlego e postura.

## API

```text
integration_snapshot()
```

## Sinais

```text
combat_attributes_applied
combat_balance_refreshed
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/combat_attribute_integration_smoke_test.gd
```
