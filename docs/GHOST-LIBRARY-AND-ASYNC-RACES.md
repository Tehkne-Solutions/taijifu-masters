# Biblioteca local de fantasmas e corridas assíncronas

**Produto:** Taijifu Masters  
**Assinatura:** Tehkné Solutions

## Objetivo

Transformar códigos isolados de replay em uma biblioteca persistente de desafios técnicos.

O jogador pode:

- salvar até 24 fantasmas importados;
- preservar múltiplos desafios no dispositivo;
- selecionar um adversário;
- remover entradas antigas;
- iniciar uma corrida contra o fantasma selecionado;
- manter seu melhor replay pessoal intacto.

## Runtime

Novo autoload:

```text
TaijifuGhostLibrary
```

Arquivo:

```text
scripts/runtime/ghost_library_runtime.gd
```

Persistência:

```text
user://taijifu-ghost-library.json
```

## Segurança competitiva

A biblioteca reutiliza a validação de checksum do runtime de compartilhamento antes de armazenar um código.

A reprodução selecionada usa o runtime visual existente e restaura imediatamente a referência do melhor replay local. Nenhum arquivo de recorde pessoal é sobrescrito.

A biblioteca não importa ou altera:

- inventário;
- ranking;
- recompensas;
- autenticação;
- certificações;
- progressão competitiva.

## Interface Web

Novo painel:

```text
Biblioteca local de fantasmas
```

Ações disponíveis:

```text
Salvar código atual
Selecionar
Correr contra
Remover
```

Arquivos Web:

```text
web/taijifu-ghost-library-web.js
scripts/inject-ghost-library-web.py
```

## Ponte Web

Funções globais:

```text
taijifuGhostLibraryCommand
taijifuGhostLibraryState
taijifuGhostLibraryStateJson
taijifuGhostLibraryReady
```

Comandos:

```json
{"command":"get_state"}
{"command":"import_code","code":"..."}
{"command":"select","id":"ghost-id"}
{"command":"play_selected"}
{"command":"remove","id":"ghost-id"}
```

## Validação

```bash
godot --headless --path . \
  --script res://scripts/ci/ghost_library_smoke_test.gd
```

O smoke test verifica inclusão, persistência lógica das métricas, seleção e remoção.

## Próxima evolução recomendada

- cronômetro e placar ao vivo durante a corrida;
- resultado `venceu/perdeu/empatou` contra o alvo selecionado;
- histórico de tentativas por fantasma;
- filtros por pontuação, precisão, arma e caminho Tai/Ji/Fu;
- QR Code local para transferência entre dispositivos.

---

**Tehkné Solutions**
