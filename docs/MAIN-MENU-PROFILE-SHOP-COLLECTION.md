# Menu principal com perfil, loja e coleção

## Sala dos Mestres

O menu principal agora possui três acessos permanentes:

- Perfil e Progressão;
- Loja de Treino;
- Coleção e Personalização.

## Navegação

O `MainMenuHubRuntime` centraliza a abertura e o fechamento das telas, oculta o menu enquanto uma seção está ativa e o restaura ao retornar.

Isso evita sobreposição entre menu, perfil, loja e coleção.

## Seções

```text
profile
shop
collection
```

Perfil e Loja utilizam o painel consolidado de progressão. Coleção abre o seletor de cosméticos equipados.

## API

```text
open_section(section_id)
close_active_section(return_to_menu)
active_section()
is_hub_open()
```

O menu principal também disponibiliza:

```text
hide_for_hub()
restore_from_hub()
```

## Sinais

```text
hub_navigation_requested
hub_opened
hub_closed
navigation_rejected
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/main_menu_hub_smoke_test.gd
```
