# Lotes progressivos de produção — Pack 01

O Pack 01 deve ser concluído em lotes verificáveis. Cada execução lê o repositório atual, identifica os arquivos ausentes e publica um plano sem assumir que assets inexistentes já foram produzidos.

## Ordem oficial

1. `master_and_identity` — fonte mestre, retratos e ícones;
2. `core_movement` — idle, caminhada, corrida, saltos, queda, pouso e dash;
3. `core_combat` — ataques básicos, defesa, parry e dano;
4. `advanced_combat` — skill, knockback, downed, death e victory;
5. `vfx` — water slash e water dragon;
6. `metadata` — metadados das 19 animações;
7. `runtime_and_atlas` — atlas, JSON, SpriteFrames e manifesto de runtime;
8. `validation_and_preview` — cena, script e preview de validação.

## Execução

```bash
python scripts/tgap_pack_promotion_readiness.py --pack pack_01_lian_wu
python scripts/tgap_pack_production_batches.py --pack pack_01_lian_wu
```

## Saídas

```text
artifacts/tgap/promotion-readiness.json
artifacts/tgap/pack-production-batches.json
```

O campo `next_batch` aponta o primeiro lote ainda incompleto. A soma de `missing_total` de todos os lotes deve ser idêntica ao `missing_total` do relatório de prontidão.

## Regra de conclusão

Um lote só é marcado como concluído quando todos os seus arquivos existem e não estão vazios. A conclusão dos oito lotes não substitui os gates visuais, de animação, runtime e aprovação humana; ela apenas zera o inventário físico pendente.

## Correção de CI

O workflow de prontidão deve instalar `requirements-tgap-test.txt` antes de executar pytest. A execução anterior falhou por ausência do módulo `pytest`, não por falha do inventário do Pack 01.
