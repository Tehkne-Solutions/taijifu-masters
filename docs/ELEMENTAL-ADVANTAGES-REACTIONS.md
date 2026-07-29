# Vantagens e reações elementais

O combate passa a considerar uma relação circular entre os quatro elementos:

```text
Fogo > Ar > Terra > Água > Fogo
```

## Multiplicadores

- vantagem elemental: `1,18×`;
- desvantagem elemental: `0,86×`;
- mesmo elemento: `0,78×`;
- combinação neutra: `1,00×`.

Os multiplicadores atuam em uma janela curta durante técnicas elementais. A força e a técnica do atacante são ajustadas, enquanto defesa e resistência do alvo respondem à relação entre os elementos.

## Resistência natural

Um lutador recebe duração reduzida quando sofre um estado associado ao próprio elemento. Estados contra os quais o elemento possui vantagem também duram menos. Quando o estado possui vantagem sobre o elemento do alvo, sua duração é ampliada de forma controlada.

## Estados preservados

O runtime complementa, sem substituir, os estados existentes:

- queimadura;
- molhado;
- ancoragem;
- lama;
- instabilidade aérea;
- vapor.

## Reações preservadas

Continuam ativas:

- Fogo + Água → vapor ou extinção;
- Água + Terra → lama;
- Fogo + Ar → combustão;
- Ar contra Terra ou lama → resistência ao deslocamento.

## Feedback visual

O lutador recebe um brilho temporário na cor do elemento sempre que:

- inicia uma técnica elemental;
- recebe um estado;
- ativa uma reação elemental.

## Proteção de balanceamento

Os atributos originais são armazenados antes da janela elemental e restaurados ao final. Isso impede acúmulo de bônus entre técnicas consecutivas.

## API

```text
matchup_multiplier(attacking_element, defending_element)
system_snapshot()
```

## Sinais

```text
elemental_matchup_applied
elemental_status_scaled
elemental_reaction_presented
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/elemental_advantage_smoke_test.gd
```
