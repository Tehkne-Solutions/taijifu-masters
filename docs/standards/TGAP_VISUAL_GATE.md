# TGAP — Gate Visual

O gate visual impede que arquivos fisicamente presentes sejam promovidos sem atender ao contrato técnico de imagem.

## Validações

- arquivo decodificável;
- PNG em modo RGBA;
- canal alpha presente;
- transparência real;
- conteúdo não vazio;
- canvas nas dimensões declaradas;
- conteúdo dentro das margens;
- estimativa de pivô pelo centro inferior do conteúdo;
- deriva de pivô agrupada por animação;
- exclusão de previews e relatórios do runtime.

## Uso

```bash
python scripts/tgap_visual_gate.py assets/tgap/pack_01_lian_wu
```

Para outro canvas:

```bash
python scripts/tgap_visual_gate.py <pack-root> --width 256 --height 256
```

## Saídas

```text
validation/visual-gate-report.json
validation/visual-gate-report.md
```

## Bloqueios

A promoção permanece bloqueada quando:

- nenhuma imagem foi encontrada;
- existe imagem ilegível;
- falta canal alpha;
- falta transparência;
- o frame está vazio;
- a dimensão diverge do contrato.

Alertas de margem e deriva de pivô não promovem automaticamente o asset. Eles exigem revisão da animação antes da aprovação artística.

## Limite do gate

O gate confirma integridade técnica. Ele não substitui aprovação humana de identidade, qualidade do desenho, continuidade de movimento, anatomia ou leitura em gameplay.
