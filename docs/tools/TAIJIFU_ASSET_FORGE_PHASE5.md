# Taijifu Asset Forge — Fase 5

A Fase 5 recebe matérias-primas visuais por diretório ou ZIP, promove somente os quatro nomes previstos pelo contrato e gera um pacote de revisão humana antes do processamento.

## Entrada do Pack 01

O diretório ou ZIP deve conter exatamente os arquivos relevantes abaixo, mesmo que estejam dentro de subdiretórios:

```text
char_lian_wu__master_raw.png
turnaround_raw.png
portraits_raw.png
icons_raw.png
```

Arquivos extras são registrados, mas não promovidos. Nomes duplicados ficam ambíguos e bloqueiam a execução. Caminhos absolutos e travessia `../` em ZIP são rejeitados.

## Comando

```bash
python tools/asset_forge/intake.py \
  asset-forge/intake/pack_01_lian_wu_base.json \
  caminho/para/pack-01.zip \
  --clean --strict
```

Também é possível fornecer um diretório:

```bash
python tools/asset_forge/intake.py \
  asset-forge/intake/pack_01_lian_wu_base.json \
  caminho/para/pack-01/
```

## Saídas

```text
asset-forge/intake/pack_01_lian_wu_base/
artifacts/asset-forge/pack_01_lian_wu_base__intake.json
artifacts/asset-forge/review/pack_01_lian_wu_base/intake-report.json
artifacts/asset-forge/review/pack_01_lian_wu_base/CHECKLIST.md
```

O relatório inclui SHA-256 de cada arquivo aceito, ausentes, ambiguidades, rejeitados e extras. `ready_for_processing` só fica verdadeiro quando as quatro entradas reais forem encontradas sem conflito.

## Revisão humana

A checklist exige verificação de identidade, enquadramento, coerência do turnaround, retratos, ícones e adequação do fundo. A aprovação humana não é inferida pelo software e não é substituída por uma imagem de apresentação.

## Próxima execução

Depois do intake aprovado:

```bash
python tools/asset_forge/orchestrator.py \
  asset-forge/orchestration/pack_01_lian_wu_base.json \
  --strict
```
