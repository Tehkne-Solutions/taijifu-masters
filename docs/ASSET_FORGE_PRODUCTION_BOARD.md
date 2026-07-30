# Taijifu Production Board

O Production Board transforma evidências reais do Asset Forge em um estado único e auditável por personagem.

## Objetivo

Evitar status reconstruídos manualmente a partir de mensagens, logs ou suposições. Cada etapa só avança quando existe evidência física no repositório ou nos artifacts.

## Etapas

1. Character DNA
2. contratos materializados
3. fontes físicas recebidas
4. processamento
5. validação técnica
6. revisão visual
7. gate perceptual
8. aprovação assinada
9. integração Godot/TGAP
10. release oficial

## Uso

```bash
python tools/asset_forge/production_board.py \
  asset-forge/characters/lian_wu.json
```

Modo estrito:

```bash
python tools/asset_forge/production_board.py \
  asset-forge/characters/lian_wu.json \
  --strict
```

Saídas padrão:

```text
artifacts/asset-forge/boards/lian_wu/
├── board.json
└── index.html
```

## Códigos de saída

- `0`: quadro gerado; no modo estrito, nenhum blocker ativo;
- `14`: Character DNA ausente ou inválido;
- `15`: quadro gerado, mas há blockers no modo estrito.

## Regra de confiança

O painel não considera uma etapa concluída por descrição textual. Ele procura contratos, imagens-fonte, relatórios, aprovação, manifest TGAP e estado de release. Arquivos ausentes permanecem explicitamente bloqueados.

## GitHub Actions

O workflow `asset-forge-production-board.yml` executa os testes, gera o painel de Lian Wu e publica um artifact com:

- `board.json`;
- `index.html`;
- revisão visual, quando existir;
- relatórios perceptuais, quando existirem;
- relatório de release, quando existir.

Isso cria um pacote único para diagnóstico e revisão sem depender do ambiente local.
