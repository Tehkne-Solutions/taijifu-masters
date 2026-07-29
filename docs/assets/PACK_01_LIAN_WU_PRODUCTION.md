# PACK 01 — Lian Wu Master Character

## Objetivo

Entregar o primeiro personagem definitivo do jogo já pronto para integração, sem depender de recortes manuais posteriores.

## Regra de entrega

Cada asset deve possuir:

- arquivo individual recortado;
- fundo transparente;
- ID estável;
- nome padronizado;
- pivô definido;
- resolução e escala declaradas;
- animação associada;
- hitbox e hurtbox documentadas;
- atlas opcional para otimização;
- manifesto JSON;
- recurso SpriteFrames do Godot;
- preview visual do pack;
- checklist de validação.

## Estrutura

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

## Convenção de nomes

```text
char_lian_wu__idle__f01.png
char_lian_wu__walk__f01.png
char_lian_wu__attack_light_01__f01.png
vfx_lian_wu__water_slash__f01.png
portrait_lian_wu__profile.png
```

## Escala oficial

- canvas por frame: 128 × 128 px;
- altura visual padrão no jogo: aproximadamente 96 px;
- origem: centro dos pés;
- contorno estrutural: 3 px;
- contorno de identificação do jogador: 2 px;
- filtro inicial: nearest;
- geração mestre: 4× para preservar qualidade;
- export final: PNG RGBA.

## Identidade imutável

A faixa azul do kimono é o elemento principal de identidade do Lian Wu e deve permanecer reconhecível em todas as skins futuras.

## Metadados por animação

Cada animação terá um arquivo JSON contendo:

- `animation_id`;
- quantidade de frames;
- FPS;
- loop;
- eventos de gameplay;
- frame de ataque ativo;
- frame de recuperação;
- pivô por frame quando necessário;
- hitboxes;
- hurtboxes;
- sockets de arma;
- sockets de VFX;
- deslocamento da sombra.

## Ordem de produção

1. modelo visual mestre;
2. idle;
3. walk e run;
4. salto, queda e aterrissagem;
5. ataques básicos;
6. defesa, aparo e dash;
7. habilidade especial;
8. dano, queda e morte;
9. vitória;
10. retratos;
11. VFX separados;
12. atlas e SpriteFrames;
13. integração na cena de validação;
14. integração no runtime principal.

## Gate de aprovação

O pack somente avança quando:

- todos os arquivos estão recortados e transparentes;
- nenhum frame possui borda do canvas visível;
- pivôs não causam tremor entre frames;
- escala permanece consistente;
- faixa azul continua legível;
- personagem se destaca em fundos claros, escuros e saturados;
- sombra acompanha os pés;
- VFX não encobrem a silhueta;
- IDs do manifesto correspondem aos arquivos;
- cena do Godot importa sem referências quebradas.
