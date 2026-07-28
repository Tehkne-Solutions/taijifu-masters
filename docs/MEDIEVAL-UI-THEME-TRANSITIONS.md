# Tema medieval e transições de interface

## Direção visual

A interface passa a usar uma linguagem de fantasia medieval inspirada em salões de mestres, pedra, madeira escura, pergaminho e detalhes metálicos.

Paleta principal:

- ouro;
- pergaminho;
- madeira;
- pedra.

## Botões

Todos os botões encontrados nas camadas de interface recebem estados consistentes:

- normal;
- hover;
- foco;
- pressionado;
- desabilitado.

O foco é visível para teclado e gamepad e utiliza borda dourada reforçada, texto luminoso e leve ampliação.

## Cards e painéis

`Panel` e `PanelContainer` recebem:

- fundo de pedra escura;
- borda dourada;
- cantos discretamente arredondados;
- sombra profunda;
- margens internas mais confortáveis.

## Tipografia

Títulos grandes usam ouro claro com sombra. Textos secundários utilizam tom de pergaminho para manter legibilidade sem aparência tecnológica neon.

## Transições

Menu principal, perfil e coleção recebem entrada por fade curto de 0,22 segundo. As animações continuam funcionando quando a árvore está pausada.

## Aplicação automática

O runtime procura novas `CanvasLayer` periodicamente. Isso permite aplicar o tema também a interfaces criadas dinamicamente depois do início do jogo.

## API

```text
theme_snapshot()
```

## Sinais

```text
theme_applied
transition_started
transition_finished
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/medieval_ui_theme_smoke_test.gd
```
