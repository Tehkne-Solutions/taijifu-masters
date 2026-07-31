# Taijifu Masters — Auditoria visual do First Playable

## Resultado verificado

O First Playable está funcional como experiência de combate, porém ainda não utiliza o Pack 01 como fonte visual de produção.

### Personagens

O nó `FirstPlayableCharacterIdentity` é anexado em runtime aos dois lutadores. O script desenha Lian Wu e Rival de Treino com primitivas do Godot por meio de `_draw_lian_wu()` e `_draw_training_rival()`.

Esse recurso é um fallback técnico válido para estabilizar gameplay, mas não representa integração de assets finais.

### Pack 01

O contrato canônico em `assets/tgap/pack_01_lian_wu/production-status.json` declara:

- estado `specified`;
- 163 arquivos esperados;
- 0 arquivos presentes;
- 163 arquivos ausentes;
- promoção bloqueada;
- gates de integridade, imagem, animação, runtime, aprovação e release ainda negativos.

## Gate automatizado

Executar:

```bash
python tools/asset_forge/audit_first_playable_visuals.py
```

Para bloquear uma release visual enquanto houver placeholders ou pack incompleto:

```bash
python tools/asset_forge/audit_first_playable_visuals.py --strict
```

Para gerar evidência JSON:

```bash
python tools/asset_forge/audit_first_playable_visuals.py \
  --output artifacts/first-playable-visual-audit.json
```

## Critério para liberar o piloto externo

O campo `visual_release_ready` somente será verdadeiro quando:

1. todos os 163 arquivos canônicos estiverem presentes;
2. `missing` for zero;
3. a promoção do Pack 01 estiver desbloqueada;
4. todos os gates do pack estiverem verdes;
5. o overlay procedural não estiver mais ativo no First Playable;
6. a cena canônica continuar válida.

## Próxima ação

Produzir e aprovar a correção artística do turnaround v1.0.1, publicar o ZIP binário em GitHub Releases, executar intake pelo Tehkné Assets Forge e promover o conjunto mínimo necessário para idle, movimento, salto, ataque, defesa, esquiva, dano e KO.

---

**Tehkné Solutions**
