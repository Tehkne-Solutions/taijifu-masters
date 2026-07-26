# Elementos e Arena em Movimento

Este documento registra a terceira camada da Sprint 10.5 do Protótipo Zero.

## Objetivo

Validar se elementos e movimento da arena criam decisões estratégicas compreensíveis sem substituir técnica, posicionamento e leitura do adversário.

## Seleção elemental

Cada jogador escolhe um elemento independentemente da build antes da luta.

- P1: `Q/E` na preparação.
- P2: `Num 4/Num 5` na preparação.
- P1 executa a técnica elemental com `C`.
- P2 executa a técnica elemental com `Num 6`.

## Técnicas elementais

| Elemento | Técnica | Função principal |
| --- | --- | --- |
| Fogo | Pulso de Brasa | pressão, dano contínuo e combustão |
| Água | Onda de Fluxo | empurrão, extinção e perda de aderência |
| Terra | Impacto de Fundação | postura, ancoragem e controle do solo |
| Ar | Rajada de Desvio | interrupção, deslocamento e desequilíbrio |

## Estados

### Queimando

- causa dano gradual;
- reduz lentamente a postura;
- é removido por água;
- dura mais quando combinado com ar.

### Molhado

- reduz aderência durante frenagens;
- aumenta o impulso recebido;
- extingue fogo;
- transforma terra em lama.

### Ancorado

- reduz impulso recebido;
- reduz mobilidade e salto;
- recupera parte da postura ao ser aplicado;
- contém parte da força do ar.

### Lama

- reduz velocidade horizontal;
- reduz salto;
- bloqueia wall jump;
- reduz pressão ofensiva do personagem afetado.

### Desequilibrado

- aumenta o impulso recebido;
- favorece expulsão e perseguição;
- possui baixa duração contra terra ou lama.

### Vapor

- surge quando fogo atinge alvo molhado;
- remove o estado molhado;
- reduz temporariamente eficiência ofensiva;
- causa pequena pressão de postura.

## Interações

| Combinação | Resultado |
| --- | --- |
| Fogo + Água | vapor e extinção |
| Fogo + Ar | combustão ampliada |
| Água + Terra | lama |
| Ar + Terra | rajada parcialmente contida |

As interações geram condições de combate. Não existe bônus elemental universal de dano.

## Arena em fases

### Fase 0 — Arena estável

Os jogadores exploram livremente as rotas Tai, Ji e Fu.

### Fase 1 — Colapso inicial

Após 16 segundos, a borda esquerda começa a avançar e força perseguição lateral.

### Fase 2 — Setor Ji fechado

A rota inferior inicial deixa de ser segura. Os jogadores precisam mudar de altura ou avançar.

### Fase 3 — Ascensão final

A borda avança novamente e concentra a luta nas plataformas verticais do lado direito.

### Fase 4 — Plataforma limite

O confronto final ocorre em área menor, com risco elevado de expulsão.

## Pressão da borda

A borda móvel:

- empurra jogadores para a área segura;
- causa dano leve e pressão de postura em intervalos;
- não elimina instantaneamente;
- move o limite mínimo da câmera;
- reinicia a cada rodada.

## Plataforma vertical

Uma segunda plataforma móvel foi adicionada ao setor final para permitir:

- subida e descida durante o combate;
- mudança entre rotas;
- ataques Tai no espaço aberto;
- controle Ji nos pontos de chegada;
- transições Fu durante o movimento.

## Casos de teste

### Preparação

1. Selecionar cada um dos quatro elementos para os dois jogadores.
2. Confirmar que build e elemento são escolhas independentes.
3. Iniciar e verificar o elemento no HUD e na aura.

### Estados

1. Aplicar fogo e aguardar três ciclos de dano.
2. Aplicar água após fogo e confirmar extinção.
3. Aplicar água e depois fogo para gerar vapor.
4. Aplicar fogo e depois ar para gerar combustão.
5. Aplicar água e depois terra para gerar lama.
6. Aplicar terra e depois ar para confirmar resistência parcial.

### Movimento

1. Comparar frenagem normal e molhada.
2. Comparar salto normal, ancorado e em lama.
3. Tentar wall jump durante lama.
4. Comparar knockback normal, ancorado e desequilibrado.

### Arena

1. Aguardar início do colapso.
2. Permanecer atrás da borda e confirmar pressão intervalada.
3. Confirmar que a câmera não retorna ao setor fechado.
4. Chegar à plataforma vertical.
5. Cair durante a ascensão.
6. Encerrar a rodada e confirmar reinício completo do ciclo.

## Bloqueadores de merge

- técnica elemental não utiliza o elemento selecionado;
- estado permanece após reinício;
- fogo continua após ser extinguido;
- lama permite wall jump;
- ancoragem aumenta, em vez de reduzir, o knockback;
- borda causa dano a cada frame;
- câmera mostra novamente um setor fechado;
- respawn ocorre atrás da borda;
- colapso começa durante a preparação;
- plataforma vertical perde colisão.

---

**Tehkné Solutions**