# Diagnóstico rápido da versão Web

## Build não encontra o Godot

Execute:

```bash
bash scripts/build-web.sh
```

O script baixa o editor e os templates automaticamente.

## `web_release.zip` não encontrado

Remova o cache e repita:

```bash
rm -rf .cache/godot
rm -rf ~/.local/share/godot/export_templates/4.3.stable
bash scripts/build-web.sh
```

## Página branca

Verifique:

- console do navegador;
- resposta de `index.wasm`;
- resposta de `index.pck`;
- WebGL 2.0;
- headers e HTTPS.

## Dados não persistem

- evite modo anônimo;
- permita armazenamento/IndexedDB;
- não execute dentro de iframe de terceiro sem permissões;
- teste diretamente na URL da Vercel ou Render.

## Gamepad não aparece

Pressione um botão do controle depois de abrir a página. Navegadores não expõem gamepads antes da primeira interação.

## Áudio não inicia

Clique, toque ou pressione uma tecla para liberar o contexto de áudio do navegador.

---

**Tehkné Solutions**
