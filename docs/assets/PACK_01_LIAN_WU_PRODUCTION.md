# PACK 01 — Lian Wu Master Character

## Estado real

`specified_assets_missing`

A identidade, escala, animações e convenções estão definidas. Os arquivos visuais finais ainda precisam ser gerados, recortados, validados e integrados.

## Entrega obrigatória

Cada frame deve possuir:

- PNG RGBA individual;
- fundo totalmente transparente;
- canvas de 128 × 128 px;
- personagem com aproximadamente 96 px de altura projetada;
- pivô no centro dos pés;
- contorno estrutural de 3 px;
- faixa azul do kimono sempre reconhecível;
- nome no padrão `char_lian_wu__<animation>__f<frame_2d>.png`;
- ausência de bordas, textos, divisórias ou elementos de prancha;
- alinhamento estável entre frames.

## Estrutura de produção

```text
assets/pack_01_characters/lian_wu/
├── manifest.json
├── frames/
│   ├── idle/
│   ├── walk/
│   ├── run/
│   ├── jump_start/
│   ├── jump_loop/
│   ├── fall/
│   ├── land/
│   ├── attack_light_01/
│   ├── attack_light_02/
│   ├── attack_heavy/
│   ├── dash/
│   ├── block/
│   ├── parry/
│   ├── skill_water_dragon/
│   ├── hurt/
│   ├── knockback/
│   ├── downed/
│   ├── death/
│   └── victory/
├── atlases/
├── portraits/
├── vfx/
├── metadata/
└── source/
```

## Ordem de produção

1. modelo mestre frontal/lateral/costas;
2. idle;
3. walk;
4. run;
5. salto, queda e aterrissagem;
6. ataques básicos;
7. dash, defesa e aparo;
8. habilidade do Dragão de Água;
9. dano, knockback, queda e morte;
10. vitória;
11. retratos;
12. VFX separados;
13. atlas e metadados;
14. SpriteFrames;
15. cena de validação;
16. runtime principal.

## Gate de aprovação

O PACK 01 somente recebe `complete` quando:

- a quantidade de frames corresponde ao manifesto;
- todos os PNGs estão recortados e transparentes;
- nenhuma imagem possui borda de célula;
- o pivô não produz tremor;
- os VFX não cobrem a leitura da silhueta;
- atlas e JSON apontam para todos os frames;
- SpriteFrames importa sem referências quebradas;
- cena de validação executa corretamente;
- o personagem real substitui o placeholder no combate.
