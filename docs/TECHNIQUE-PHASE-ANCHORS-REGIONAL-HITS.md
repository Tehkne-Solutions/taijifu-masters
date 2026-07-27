# Fases técnicas, encaixes de armas e impactos regionais

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta entrega conecta a animação visual ao tempo real das técnicas sem alterar física, dano, prioridade ou duração. Também substitui coordenadas fixas de armas por encaixes por personagem/estado/quadro e representa visualmente a região atingida.

---

## Timeline visual técnica

Arquivo:

```text
scripts/visual/technique_visual_timeline.gd
```

O combate continua sendo controlado por `FighterController` e `TechniqueData`. A timeline apenas lê:

- fase atual;
- tempo restante;
- startup;
- atividade;
- recuperação;
- caminho Tai, Ji ou Fu.

Mapeamento inicial:

| Fase | Quadro de ataque |
|---|---:|
| startup | 0 |
| início da atividade | 1 |
| fim da atividade | 2 |
| recuperação | 3 |

A fase ativa utiliza dois quadros para comunicar o momento de contato. A recuperação nunca repete o quadro ativo.

A timeline também fornece:

- progresso normalizado da fase;
- intensidade visual;
- deslocamento angular da arma;
- rótulo técnico da fase.

Nenhum valor produzido pela timeline entra nos cálculos competitivos.

---

## Encaixes de armas

Arquivo:

```text
scripts/visual/character_attachment_catalog.gd
```

Cada personagem possui:

- mão principal base;
- mão de apoio base;
- ângulo base;
- escala de alcance visual.

Cada estado e quadro aplica offsets próprios:

```text
idle   × 4
move   × 4
attack × 4
guard  × 4
```

O catálogo resolve o encaixe final considerando:

- personagem;
- estado;
- quadro;
- direção horizontal.

Armas integradas:

- Bastão Adaptativo;
- Faixas do Vento;
- Manoplas Sísmicas;
- Manoplas Quebra-Fundação;
- combate desarmado.

O alcance visual não modifica a hitbox. A hitbox continua sendo definida exclusivamente por `TechniqueData`.

---

## Inspetor de encaixes

O Inspetor Visual aberto pela tecla `O` passa a mostrar:

- pivô do lutador;
- mão principal;
- mão de apoio;
- eixo frontal;
- direção angular da arma;
- coordenadas numéricas dos encaixes.

Controle adicional:

```text
A — mostrar ou ocultar guias de encaixe
```

Cores das guias:

- azul: pivô e direção frontal;
- vermelho: mão principal;
- roxo: mão de apoio;
- amarelo: direção inicial da arma.

Isso permite revisar os encaixes quadro a quadro antes da criação de assets finais.

---

## Impactos regionais

Arquivo:

```text
scripts/visual/regional_hit_flash.gd
```

O controlador final emite:

```text
regional_hit_received
```

Dados emitidos:

- lutador atingido;
- região;
- resultado;
- intensidade.

Regiões:

### Cabeça

- anel concêntrico;
- raios de impacto;
- ponto visual em `y = -49`.

### Tronco

- explosão comic angular;
- preenchimento central;
- ponto visual em `y = -17`.

### Pernas

- arco baixo;
- linhas de varredura;
- ponto visual em `y = 20`.

Resultados possuem cores próprias:

| Resultado | Cor |
|---|---|
| acerto | vermelho |
| bloqueio | dourado |
| aparo | ciano |
| esquiva | azul acinzentado |
| quebra de postura | violeta |

O `ImpactDirector` também recebe agora a posição real da região, em vez de um ponto genérico no tronco.

---

## Fluxo visual de uma técnica

1. O jogador inicia uma técnica.
2. `FighterController` define startup e tempo restante.
3. O presenter usa o quadro 0.
4. A fase ativa inicia e habilita a hitbox.
5. O presenter percorre os quadros 1 e 2.
6. A arma acompanha os encaixes desses quadros.
7. O contato resolve a região real.
8. O flash regional representa o resultado.
9. O VFX global nasce na posição da região.
10. A recuperação usa o quadro 3.
11. O personagem volta ao estado livre.

---

## Validação automática

O smoke test agora valida:

- timeline visual importável;
- quatro quadros técnicos dentro da grade;
- encaixes para todos os personagens;
- quatro estados com quatro valores;
- mão principal e mão de apoio válidas;
- flash regional presente em cada lutador;
- ativação programática do flash de cabeça;
- startup no quadro 0;
- início ativo no quadro 1;
- fim ativo no quadro 2;
- recuperação no quadro 3;
- cena principal e runtimes anteriores.

---

## Validação manual

1. Executar uma técnica lenta e observar a preparação.
2. Confirmar mudança para o quadro ativo somente quando a hitbox é ativada.
3. Confirmar segundo quadro durante o contato.
4. Confirmar quadro final durante recuperação.
5. Testar Bastão, Faixas e Manoplas.
6. Abrir o Inspetor com `O`.
7. Ativar e desativar guias com `A`.
8. Percorrer os quatro quadros manualmente.
9. Verificar mãos e direção da arma.
10. Acertar cabeça, tronco e pernas.
11. Testar bloqueio, aparo e esquiva.
12. Confirmar que VFX global aparece na região correta.

---

## Próximas evoluções

- offsets específicos por técnica;
- editor persistente de encaixes;
- sockets para pets e acessórios;
- expressões faciais sincronizadas;
- hit pause com deformação visual;
- animações de queda, vitória e derrota;
- trilhas de arma baseadas na ponta real do equipamento.

---

**Tehkné Solutions**
