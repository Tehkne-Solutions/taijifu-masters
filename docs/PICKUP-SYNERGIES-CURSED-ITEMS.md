# Sinergias, stacks e itens amaldiçoados

## Objetivo

Transformar os pickups em um sistema de decisões de build durante a batalha, com combinações, riscos, conflitos e evoluções lendárias.

## Stacks seguros

O runtime de pickups passa a manter um valor-base por lutador e atributo. Cada buff ativo contribui com seu próprio modificador e a expiração recalcula o total restante.

Isso evita que a expiração de um efeito sobrescreva outro stack ainda ativo.

## Sinergias

- Dançarino da Tempestade: Passo do Vento + Talismã de Foco;
- Titã de Ferro: Guarda de Ferro + Força Titânica;
- Eco Fluido: Orbe Vital + Pergaminho de Eco;
- Equilíbrio Perfeito: Passo do Vento + Guarda de Ferro + Talismã de Foco.

Cada sinergia concede bônus temporários adicionais, recuperação de fôlego e feedback visual próprio.

## Evoluções lendárias

Pickups lendários podem evoluir para efeitos exclusivos:

- Passo do Tufão;
- Bastião Imóvel;
- Punho do Colosso;
- Mente sem Limite.

A evolução é ativada uma vez por janela de combinação.

## Itens amaldiçoados

- Coroa de Sangue: grande força, defesa reduzida;
- Pluma do Vazio: grande agilidade, resistência reduzida;
- Máscara do Oráculo: grande foco, força reduzida.

A raridade amaldiçoada possui 2% de chance no pool procedural.

## Conflitos

Certas combinações entre maldição e item defensivo provocam um custo imediato:

- Sangue contra Aço;
- Vento Devorado;
- Visão sem Corpo.

Os conflitos drenam vida, postura ou fôlego e geram feedback visual.

## Validação

```text
godot --headless --path . --script res://scripts/ci/pickup_synergy_smoke_test.gd
```
