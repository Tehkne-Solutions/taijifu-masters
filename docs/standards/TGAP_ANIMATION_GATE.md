# TGAP Animation Gate

O gate de animação valida a estrutura temporal e documental de cada animação antes da promoção do pack.

## Validações obrigatórias

- quantidade física igual ao inventário fechado;
- sequência contínua iniciada em `f00`;
- ausência de frames extras ou duplicados;
- nomes no padrão `__fNN.png`;
- metadata por animação;
- `fps` numérico maior que zero e até 60;
- `loop` booleano explícito;
- `frame_count`, quando declarado, igual à quantidade física;
- deriva de pivô dentro do limite técnico;
- cálculo de duração para inspeção.

## Execução

```bash
python scripts/tgap_animation_gate.py assets/tgap/pack_01_lian_wu
```

Limite alternativo de deriva:

```bash
python scripts/tgap_animation_gate.py assets/tgap/pack_01_lian_wu --pivot-drift-limit 8
```

## Saídas

- `validation/animation-gate-report.json`
- `validation/animation-gate-report.md`

O comando retorna código diferente de zero enquanto qualquer animação estiver incompleta ou inválida.
