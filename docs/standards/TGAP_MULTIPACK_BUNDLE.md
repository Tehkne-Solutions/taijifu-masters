# TGAP — Bundle multi-pack

O bundle multi-pack transforma o plano do `tgap-registry.json` em uma distribuição conjunta, reproduzível e segura.

## Fluxo

```text
registry gate
→ integration plan
→ pipeline individual de cada pack
→ confirmação de aprovação
→ bundle determinístico
→ manifesto e checksum
```

## Planejamento

```bash
python scripts/tgap_bundle_packs.py --version 1.0.0 --plan-only
```

O plano lista apenas packs habilitados e respeita `integration_order` e dependências já validadas pelo registry gate.

## Bundle oficial

```bash
python scripts/tgap_bundle_packs.py --version 1.0.0 --run-pipelines
```

O comando executa novamente o pipeline de cada pack. O ZIP só é produzido quando todos os relatórios individuais possuem:

```json
{
  "pipeline_passed": true,
  "promotion_blocked": false
}
```

## Bundle diagnóstico

```bash
python scripts/tgap_bundle_packs.py --version 1.0.0-dev --force
```

O modo `--force` é útil para inspecionar estrutura e integração, mas sempre gera:

```json
{
  "forced": true,
  "publishable": false
}
```

## Saídas

```text
artifacts/tgap/bundles/<project>-tgap-<version>.plan.json
artifacts/tgap/bundles/<project>-tgap-<version>.zip
artifacts/tgap/bundles/<project>-tgap-<version>.manifest.json
artifacts/tgap/bundles/<project>-tgap-<version>.sha256
```

Quando algum pack não está aprovado, é produzido um `bundle-report.json` com o bloqueio e o estado de cada pack.

## Determinismo

O ZIP possui:

- ordem canônica de packs e arquivos;
- timestamp fixo;
- permissões normalizadas;
- compressão padronizada;
- namespace `packs/<pack_id>/...`;
- SHA-256 por pack e para o arquivo final.

Duas execuções com os mesmos arquivos e a mesma versão devem gerar o mesmo hash.

## Segurança

O bundle oficial nunca substitui os gates individuais. Ele depende da aprovação de cada pipeline, da validade do registro global e do schema `tgap/bundle/v1`.
