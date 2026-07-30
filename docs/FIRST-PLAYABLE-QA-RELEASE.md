# Taijifu Masters — Matriz de QA e Liberação do First Playable

**Versão-alvo:** `0.2.0-first-playable`  
**Entrada padrão:** `res://scenes/vertical_slice/first_playable_menu.tscn`  
**Batalha:** `res://scenes/vertical_slice/first_playable.tscn`

## Escopo liberável

O First Playable entrega um ciclo completo e isolado:

1. menu inicial;
2. escolha de dificuldade da IA;
3. Lian Wu contra Rival de Treino;
4. arena Ruínas do Caminho Triplo;
5. combate, KO ou timeout;
6. pausa;
7. resultado;
8. revanche ou retorno ao menu.

O protótipo completo histórico permanece acessível como opção secundária e não é requisito para aprovar esta versão.

## Matriz automatizada

| Gate | Cobertura | Critério de aprovação |
| --- | --- | --- |
| First Playable character contract | IDs, nomes, elementos, armas e renderização procedural | Lian Wu e Rival não podem herdar atlas de outro personagem |
| First Playable scene smoke | cena, arena, camadas, HUD e contratos estruturais | todos os nós obrigatórios presentes e colisão preservada |
| First Playable flow | menu, dificuldade, HUD, pausa, resultado e revanche | fluxo completo sem soft lock |
| First Playable AI behavior | Aprendiz, Discípulo e Mestre | IA navega, pressiona e mantém dificuldade na revanche |
| First Playable match cycle | KO, timeout e reinicialização | três ciclos consecutivos válidos |
| First Playable QA matrix | dez partidas nas três dificuldades | dez partidas concluídas sem vazamento de estado |
| Godot CI | importação e regressões do projeto | workflow concluído com sucesso |
| Web Release | exportação, manifesto e Chromium | manifesto válido e smoke Web do produto atual aprovado |
| Windows Build | exportação x86_64, manifesto, ZIP e checksum | executável PE válido, pacote publicado e hash portátil |

## Matriz manual mínima

Executar no Windows e no navegador:

| Caso | Ação | Resultado esperado |
| --- | --- | --- |
| M01 | abrir o jogo | menu First Playable aparece sem tela técnica sobreposta |
| M02 | selecionar Aprendiz e iniciar | HUD indica IA Aprendiz |
| M03 | selecionar Discípulo e iniciar | HUD indica IA Discípulo |
| M04 | selecionar Mestre e iniciar | HUD indica IA Mestre |
| M05 | mover, saltar, atacar, esquivar e defender | Lian Wu responde sem travar física ou colisão |
| M06 | pressionar Esc durante countdown | jogo pausa e permite continuar ou voltar ao menu |
| M07 | pressionar Esc durante combate | timers, IA e lutadores permanecem pausados |
| M08 | vencer por KO | resultado exibe vitória, vencedor e motivo |
| M09 | perder por KO | resultado exibe derrota, vencedor e motivo |
| M10 | aguardar timeout | partida termina por tempo e escolhe vencedor por pontuação |
| M11 | escolher revanche | nova partida inicia mantendo a dificuldade selecionada |
| M12 | voltar ao menu | menu é restaurado sem duplicar lutadores ou overlays |
| M13 | redimensionar navegador | canvas mantém proporção e permanece utilizável |
| M14 | testar teclado e gamepad | foco e comandos principais permanecem acessíveis |

## Contrato dos artifacts

Todo pacote oficial deve conter `build-info.json` com:

- schema `tehkne/taijifu-first-playable-build/v1`;
- assinatura `Tehkné Solutions`;
- versão e canal;
- commit de origem;
- plataforma;
- cena inicial e cena de batalha;
- lista de arquivos, tamanhos e SHA-256.

### Windows

O artifact deve publicar:

- `Taijifu-Masters-First-Playable-Windows-x86_64.zip`;
- `Taijifu-Masters-First-Playable-Windows-x86_64.zip.sha256`;
- `build-info.json`.

Após extrair o artifact, o checksum deve ser validável fora do GitHub Actions:

```bash
sha256sum -c Taijifu-Masters-First-Playable-Windows-x86_64.zip.sha256
```

A referência dentro do arquivo `.sha256` não pode conter caminho absoluto.

### Web

O artifact deve conter, no mínimo:

- `index.html`;
- arquivos JavaScript e WebAssembly do Godot;
- PCK do jogo;
- `build-info.json`;
- recursos de PWA e integração Web gerados pela esteira.

## Bloqueadores de liberação

A versão não pode ser marcada como liberada quando ocorrer qualquer um dos itens abaixo:

- falha no First Playable Smoke;
- falha no Godot CI;
- falha na matriz de dez partidas;
- ausência de artifact Web ou Windows;
- manifesto ausente ou com cena inicial incorreta;
- checksum Windows inválido ou não portátil;
- menu, pausa, resultado ou revanche com soft lock;
- personagem usando identidade visual de outro lutador.

## Dívida conhecida fora do escopo

Os gates TGAP legados continuam registrando incompatibilidades históricas de catálogo e runtime. Essa dívida está separada na issue `#138` e não altera os critérios funcionais do First Playable, mas deve ser resolvida antes da consolidação completa dos packs legados no produto principal.

---

**Tehkné Solutions**
