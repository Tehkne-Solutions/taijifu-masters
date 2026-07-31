# Taijifu Masters — Runtime do First Playable Lot 01

## Objetivo

Preparar o jogo para consumir o lote mínimo de animações de Lian Wu definido no repositório `taijifu-masters-assets`, sem promover o Pack 01 completo e sem remover o fallback antes da chegada dos binários aprovados.

## Caminho canônico

```text
res://assets/tgap/pack_01_lian_wu/first_playable_lot_01/
```

O runtime procura:

```text
lian_wu_first_playable_frames.tres
```

## Animações obrigatórias

- `idle`
- `run`
- `jump_start`
- `airborne`
- `fall`
- `attack_light`
- `guard`
- `dodge`
- `hit`
- `ko`

O presenter só ativa assets reais quando todas as animações existem e possuem ao menos um frame.

## Política de fallback

Enquanto o recurso `.tres` não existir ou estiver incompleto:

- o presenter permanece inativo;
- o First Playable continua usando a identidade procedural existente;
- o gate visual em modo estrito continua falhando;
- nenhuma release pode declarar integração real do Pack 01.

Após a aprovação do lote:

1. importar PNGs e metadados;
2. gerar `lian_wu_first_playable_frames.tres`;
3. anexar `FirstPlayableLot01Presenter` somente ao preset de Lian Wu;
4. ocultar a camada procedural quando `using_real_assets()` retornar `true`;
5. executar smoke, matriz de partidas, Web e Windows;
6. remover definitivamente `_draw_lian_wu()` em PR posterior.

## Mapeamento de gameplay

| Estado | Animação |
| --- | --- |
| vida zerada | `ko` |
| hitstun | `hit` |
| esquiva | `dodge` |
| ataque ativo | `attack_light` |
| guarda | `guard` |
| subindo no ar | `airborne` |
| caindo | `fall` |
| deslocamento no solo | `run` |
| repouso | `idle` |

## Validação

```bash
godot --headless --path . --script tests/first_playable_lot01_presenter_contract.gd
```

Resultado esperado:

```text
FIRST_PLAYABLE_LOT01_PRESENTER_CONTRACT_OK
```

Assinatura: Tehkné Solutions
