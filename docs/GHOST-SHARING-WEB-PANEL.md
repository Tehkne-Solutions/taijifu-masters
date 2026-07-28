# Painel Web de compartilhamento de fantasmas

**Produto:** Taijifu Masters  
**Assinatura:** Tehkné Solutions

## Entrega

A interface Web agora expõe o runtime `TaijifuGhostSharing` dentro da área de configurações e treinamento.

O jogador pode:

- gerar um código a partir do melhor replay;
- copiar o código para a área de transferência;
- baixar o pacote completo em JSON;
- colar um código recebido;
- importar o fantasma com validação de checksum;
- decidir explicitamente se deseja substituir o recorde local;
- visualizar pontuação, precisão e elo do desafio importado.

## Arquivos

```text
web/taijifu-ghost-sharing-web.js
scripts/inject-ghost-sharing-web.py
```

O script `scripts/build-web.sh` injeta o módulo após o painel de gravação, fantasma e certificações.

## Segurança

A opção de substituição permanece desmarcada por padrão. Um replay inferior é importado para comparação sem apagar o melhor replay local.

O painel não importa:

- ranking;
- inventário;
- recompensas;
- autenticação;
- perfil pessoal;
- progressão competitiva.

## CI

O workflow `Godot CI` executa:

```bash
godot --headless --path . \
  --script res://scripts/ci/ghost_sharing_smoke_test.gd
```

Em caso de falha, o log `godot-ghost-sharing.log` é publicado como artefato.

---

**Tehkné Solutions**
