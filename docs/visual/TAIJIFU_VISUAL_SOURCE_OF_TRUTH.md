# Taijifu Masters — Visual Source of Truth

Esta é a referência visual canônica para o First Playable. Ela consolida apenas decisões já aprovadas no jogo e nos contratos de assets. Gerações reprovadas, pranchas aleatórias e variações fora desta direção não têm autoridade sobre o runtime.

## Direção principal

- comic-mangá 2,5D com leitura forte de personagem;
- silhueta e legibilidade inspiradas em jogos laterais de luta/artilharia, com leitura rápida à distância;
- cenário em camadas sobrepostas com profundidade/parallax;
- câmera fighter-first: os lutadores têm prioridade sobre o cenário;
- UI martial-fantasy/ink, compacta e direta;
- menus de jogo curtos e acionáveis, sem aparência de dashboard/site;
- sem glow roxo/tech, sem painéis SaaS, sem rodapés permanentes de instruções;
- ferramentas de QA ficam recolhidas e nunca dominam a hierarquia do jogador.

## Lian Wu

Status: `art_required` até os assets reais passarem pelo pipeline canônico.

- roupa clara/branca;
- acentos water-blue e dourado;
- tinta/contorno escuro para leitura;
- uma única katana;
- continuidade rigorosa de arma, bainha, anatomia, pivô, escala e linha-base;
- fallback procedural existe apenas para manter o First Playable testável.

Caminho de runtime esperado:

`res://assets/tgap/pack_01_lian_wu/first_playable_lot_01/lian_wu_first_playable_frames.tres`

## Rival de Treino

Status: `art_required` até os assets reais passarem pelo pipeline canônico.

- silhueta mais curta/pesada;
- armadura escura;
- leitura brasa/metal/latão;
- manoplas como assinatura de combate;
- fallback procedural existe apenas para manter o First Playable testável.

Caminho de runtime esperado:

`res://assets/tgap/training_rival/first_playable_lot_01/training_rival_first_playable_frames.tres`

## Arena

- composição lateral de luta;
- layers de foreground, gameplay e background;
- profundidade por parallax, sombra e sobreposição, não por glow tecnológico;
- plataformas e elementos devem preservar leitura das silhuetas;
- a câmera deve manter ambos os combatentes legíveis sempre que possível.

## UI de combate

Na luta ficam visíveis somente informações essenciais:

- vida;
- postura;
- fôlego;
- cronômetro/estado;
- resultado quando a luta terminar.

Comandos permanentes, dificuldade, relatórios e ferramentas de teste não fazem parte da camada principal.

## Governança

Classificações possíveis para qualquer asset visual:

- `canonical`: aprovado e em uso;
- `approved`: aprovado para integração;
- `provisional`: fallback temporário de runtime;
- `legacy`: preservado, mas fora do First Playable;
- `discarded`: reprovado e proibido para integração;
- `missing`: ainda precisa ser produzido.

Nenhuma imagem gerada em chat passa diretamente para `approved`. Ela precisa entrar no repositório de assets, passar pelos contratos existentes, revisão visual e somente então ser promovida ao jogo.

O `tehkne-assets-forge` valida infraestrutura, checksum, intake e budget. Ele não define identidade visual.

Assinatura: Tehkné Solutions
