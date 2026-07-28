# Progressão e recompensas de treino

## Objetivo

Transformar a conclusão dos objetivos de treino em progressão persistente e recompensas úteis no restante do jogo.

## Recompensas por conclusão

- treino livre: 100 XP e 1 ficha de treino;
- Tai: 180 XP e 2 fichas;
- Ji: 180 XP e 2 fichas;
- Fu: 180 XP e 2 fichas;
- fantasma: 250 XP e 3 fichas.

A primeira conclusão de cada foco libera sua medalha.

## Certificações

Os caminhos Tai, Ji, Fu e Fantasma concedem certificação após três conclusões.

As certificações Tai, Ji e Fu também liberam variantes de mestre:

- Tai: Asa Cruzada, de Mestra Lyenne;
- Ji: Fundação Invertida, de Mestra Orra;
- Fu: Círculo das Três Correntes, de Mestre Han.

As variantes são liberadas para os perfis P1 e P2 no `MasterTrainingLedger` e ficam disponíveis na preparação de batalha.

## Persistência

```text
user://taijifu-training-progression.json
```

São persistidos:

- XP total;
- nível;
- fichas de treino;
- conclusões por foco;
- medalhas;
- certificações;
- histórico das últimas 50 recompensas.

## Progressão de nível

Cada 500 XP aumenta o nível de treinamento em uma unidade.

## API

```text
grant_completion(focus_id)
progression_snapshot()
completion_count(focus_id)
has_medal(medal_id)
has_certification(certification_id)
```

## Sinais

```text
training_xp_awarded
medal_unlocked
certification_unlocked
training_reward_granted
variant_reward_unlocked
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/training_progression_smoke_test.gd
```
