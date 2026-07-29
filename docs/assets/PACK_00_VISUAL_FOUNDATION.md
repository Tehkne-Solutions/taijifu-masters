# PACK 00 — Visual Foundation

## Objetivo

Estabelecer as regras visuais e técnicas obrigatórias para todos os packs de Taijifu Masters antes da produção em escala. O jogo adota combate lateral em plataforma, identidade comic-mangá, sprites retrô vetoriais com volume 2.5D e cenários vivos compostos por camadas sobrepostas.

## Arena oficial

- Viewport-base: 1920 × 1080, proporção 16:9.
- Mundo de batalha: 4 viewports na horizontal e 3 na vertical.
- Dimensão de referência: 7680 × 3240 unidades.
- Configuração principal: 4 lutadores simultâneos.
- Suporte planejado: 2 a 6 lutadores.
- A câmera deve manter todos os lutadores vivos visíveis.
- A arena usa setores progressivos para impedir dispersão extrema.

## Câmera de grupo

A câmera calcula o retângulo envolvente dos lutadores vivos, adiciona margem segura e ajusta posição e zoom suavemente.

Parâmetros oficiais:

- margem horizontal: 320 px;
- margem vertical: 220 px;
- zoom máximo aproximado: 1.05;
- zoom mínimo normal: 0.56;
- zoom mínimo de emergência: 0.48;
- suavização de posição: 5.5;
- suavização de zoom: 4.5;
- altura mínima projetada do personagem: 72 px;
- quando a legibilidade cair abaixo do limite, a zona de confronto deve fechar em vez de afastar mais a câmera.

## Escala dos personagens

- Altura visual-base do sprite em repouso: 112 px no viewport 1080p.
- Caixa lógica recomendada: 64 × 112 px.
- Ataques podem ultrapassar a caixa lógica, mas não alteram a origem dos pés.
- Pivot obrigatório: centro dos pés.
- Direção principal: lateral, com espelhamento controlado pelo runtime.
- Exportação mestre: PNG transparente em 2× ou 4×.
- Runtime: redução para escala-alvo sem filtro destrutivo.

## Linguagem dos personagens

- proporções estilizadas próximas de chibi heroico, sem infantilizar;
- cabeça e mãos ligeiramente ampliadas para leitura em movimento;
- silhueta forte e reconhecível;
- line art escura consistente;
- blocos de cor vetoriais;
- sombras pintadas em dois ou três níveis;
- highlights direcionais para volume 2.5D;
- armas e acessórios com formas distintas;
- expressões exageradas apenas nos keyframes de impacto.

## Separação entre personagem e cenário

Todos os personagens devem permanecer legíveis em qualquer região da arena.

### Contorno

- contorno estrutural escuro: 3 px na escala-base;
- contorno externo de identificação: 2 px;
- o contorno de jogador nunca deve virar glow neon contínuo;
- reforço temporário permitido em sobreposição, dano crítico ou oclusão.

### Cores de identificação

- P1: azul `#2F8CFF`;
- P2: vermelho `#FF4A3D`;
- P3: amarelo `#FFC83D`;
- P4: verde `#45D47A`;
- P5: violeta `#A76CFF`;
- P6: ciano `#38D9E6`.

### Sombra de contato

- forma elíptica suave;
- largura-base: 72 px;
- altura-base: 20 px;
- opacidade no chão: 38%;
- reduz tamanho e opacidade durante salto;
- permanece ligada ao plano da plataforma, não ao sprite.

### Luz de recorte

- largura visual entre 1 e 3 px;
- cor adaptativa complementar ao fundo;
- intensidade máxima de 22%;
- proibido bloom forte permanente.

### Máscara local de contraste

- cápsula desfocada atrás do personagem;
- raio-base: 84 px;
- opacidade normal: 6%;
- opacidade em sobreposição: até 18%;
- clareia fundos escuros e escurece fundos claros automaticamente.

## Regras do cenário

O cenário deve ter riqueza visual, mas sua leitura é subordinada ao combate.

- camadas distantes: saturação reduzida entre 20% e 35%;
- contraste das camadas distantes: reduzido entre 15% e 30%;
- plataformas jogáveis: bordas claras e leitura imediata;
- objetos interativos: sinal visual próprio;
- props frontais: transparência automática quando ocultarem lutadores;
- detalhes pequenos devem ser evitados atrás da zona principal de combate;
- o plano dos personagens deve possuir maior nitidez que o background.

## Pilha oficial de profundidade

1. céu e atmosfera;
2. montanhas e silhuetas remotas;
3. construções distantes;
4. vegetação intermediária;
5. estruturas jogáveis;
6. terreno e plataformas;
7. objetos interativos e pickups;
8. sombras de contato;
9. personagens;
10. VFX de combate;
11. indicadores de jogador;
12. HUD.

## Parallax

- camada 1: fator 0.05;
- camada 2: fator 0.12;
- camada 3: fator 0.22;
- camada 4: fator 0.38;
- camada 5: fator 0.62;
- camada 6: fator 1.00;
- foreground decorativo: fator 1.12, com fade de oclusão.

## VFX

- efeitos devem priorizar silhueta e direção do golpe;
- o núcleo do impacto pode ser brilhante;
- bordas devem ser transparentes;
- efeitos grandes não podem ocultar lutadores por mais de 6 frames;
- VFX sobre personagens reduzem opacidade automaticamente;
- cada elemento possui forma e ritmo próprios, não apenas troca de cor.

## Critérios de aprovação do Pack 00

O pack é aprovado somente quando:

1. quatro lutadores permanecem visíveis durante todo o teste;
2. nenhum personagem fica menor que o limite visual definido;
3. personagens são distinguíveis em áreas claras, escuras e saturadas;
4. sombras indicam corretamente a plataforma de contato;
5. props frontais não bloqueiam a ação;
6. parallax não provoca enjoo ou deslocamento excessivo;
7. o cenário mantém profundidade sem competir com os sprites;
8. o teste permanece estável em 1080p e escalável para 720p;
9. arquivos seguem nomes, pivôs e pastas definidos;
10. a cena técnica pode ser usada para validar todos os packs futuros.

## Estrutura de arquivos

```text
assets/
  pack_00_foundation/
    palettes/
    silhouettes/
    shadows/
    overlays/
    markers/
    test_patterns/
    manifest.json
scenes/
  validation/
    pack00_visual_validation.tscn
scripts/
  validation/
    pack00_visual_validation.gd
```

## Próxima etapa

Após a validação desta fundação, iniciar o PACK 01 — Terrain Core, produzindo módulos de chão, paredes, bordas, plataformas e conectores sem bordas incompatíveis ou costuras visíveis.