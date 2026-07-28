# Coleção e personalização cosmética

## Slots

O jogador pode equipar um único item por categoria:

- estandarte;
- aura;
- moldura de perfil.

## Itens suportados

### Estandartes

- Estandarte Tai;
- Estandarte Ji;
- Estandarte Fu;
- nenhum.

### Aura

- Aura do Discípulo;
- nenhuma.

### Moldura

- Moldura dos Mestres;
- nenhuma.

Somente itens já adquiridos na loja aparecem como opções equipáveis.

## Comportamento

A escolha é persistida em:

```text
user://taijifu-cosmetic-loadout.json
```

Ao comprar um cosmético para um slot vazio, o item é equipado automaticamente.

Quando o equipamento muda, os lutadores atuais são atualizados e deixam de exibir simultaneamente todos os cosméticos adquiridos.

## API

```text
open_collection()
close_collection()
equip(slot_id, item_id)
equipped_item(slot_id)
equipped_snapshot()
available_items(slot_id)
```

## Sinais

```text
collection_opened
collection_closed
equipment_changed
equipment_rejected
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/cosmetic_collection_smoke_test.gd
```
