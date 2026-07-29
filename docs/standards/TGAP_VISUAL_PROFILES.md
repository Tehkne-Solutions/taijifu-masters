# Perfis visuais TGAP

O gate visual resolve suas regras a partir de `asset_class` e permite sobrescritas em `validation_profile.visual`.

## Regras suportadas

- `canvas`: dimensão exata `[largura, altura]`; `null` aceita qualquer dimensão.
- `alpha`: `required` exige RGBA e transparência; `allowed` aceita imagens opacas.
- `min_margin`: margem mínima recomendada em pixels.
- `baseline_min_ratio`: altura mínima do conteúdo em relação ao canvas; `null` desativa.
- `pivot`: `bottom_center`, `center` ou `none`.
- `pivot_drift_limit`: deriva máxima entre imagens do mesmo grupo; `null` desativa.

## Padrões

| Classe | Canvas | Alpha | Pivô |
|---|---:|---|---|
| character/unit | 128×128 | obrigatório | base central |
| vfx | 256×256 | obrigatório | centro |
| tile | 128×64 | permitido | centro |
| prop | 128×128 | obrigatório | base central |
| environment/ui | livre | permitido | nenhum |

## Sobrescrita por pack

```json
{
  "asset_class": "prop",
  "validation_profile": {
    "visual": {
      "canvas": [64, 64],
      "alpha": "allowed",
      "pivot": "center"
    }
  }
}
```

As sobrescritas são mescladas ao perfil da classe sem apagar as demais regras padrão.
