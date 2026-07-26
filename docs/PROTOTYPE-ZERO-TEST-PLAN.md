# Plano de Testes — Protótipo Zero

## Ambiente

- Godot 4.3 ou superior.
- Cena: `res://scenes/main.tscn`.
- Resolução de referência: 1280 × 720.
- Testar com teclado completo e teclado sem bloco numérico quando um controle alternativo for adicionado.

## 1. Importação

- Abrir `project.godot`.
- Confirmar ausência de erros de parser.
- Confirmar que `main.tscn` é a cena principal.
- Confirmar que não existem recursos ausentes.
- Confirmar registro global de `TechniqueData`, `TechniqueCatalog`, `HurtboxRegion` e `TemporaryLoot`.

## 2. Preparação de batalha

### P1

- Usar `A/D` para navegar pelas quatro builds.
- Confirmar alteração de nome, resumo e índices.

### P2

- Usar setas esquerda/direita.
- Confirmar alteração independente do P1.

### Início

- Pressionar `Enter`.
- Confirmar que ambos surgem com as builds selecionadas.

## 3. Diferença entre builds

Comparar:

- velocidade máxima;
- altura do salto;
- vitalidade;
- postura;
- resistência ao empurrão;
- técnicas contextuais;
- arma inicial;
- resistência ao desarmamento.

### Resultado esperado

- Fluxo Aéreo é claramente mais móvel e mais vulnerável.
- Rocha Guardiã resiste melhor, mas possui aproximação mais lenta.
- Quebra-Fundação causa alta pressão de postura e exige compromisso.
- Bastão Adaptativo possui melhor transição entre situações.

## 4. Movimento

- Testar salto curto e completo.
- Saltar após sair de uma borda para validar coyote time.
- Pressionar salto antes de tocar o chão para validar buffer.
- Segurar para baixo durante a queda.
- Encostar em parede e validar wall slide.
- Pressionar salto em contato com parede e validar wall jump.
- Utilizar uma esquiva aérea.
- Tentar uma segunda esquiva antes de tocar chão ou parede.

### Resultado esperado

- A segunda recuperação aérea é bloqueada.
- O contato válido com parede ou chão restaura a recuperação.
- Nenhum estado deixa o personagem preso.

## 5. Técnicas Tai, Ji e Fu

### Tai

- Atacar durante corrida.
- Atacar no ar.
- Confirmar maior alcance e deslocamento.

### Ji

- Atacar parado com uma build de Ji elevado.
- Segurar para baixo e atacar para executar varredura.
- Utilizar empurrão.

### Fu

- Atacar parado com Bastão Adaptativo.
- Confirmar Golpe de Transição.
- Observar preparação e recuperação.

### Resultado esperado

- O HUD informa caminho e nome da técnica.
- A hitbox só causa contato na fase ativa.
- Técnicas não podem ser repetidas durante recuperação.

## 6. Defesa e aparo

- Manter defesa contra golpe frontal.
- Receber golpe pelas costas.
- Pressionar defesa imediatamente antes do impacto.

### Resultado esperado

- Defesa frontal reduz dano e impulso.
- Ataques traseiros atravessam a guarda.
- Aparo perfeito anula o golpe e recua o atacante.
- Defesa constante consome postura sob pressão.

## 7. Hurtboxes regionais

Testar golpes que atinjam prioritariamente:

- cabeça;
- tronco;
- pernas.

### Resultado esperado

- Cabeça recebe maior dano de vitalidade.
- Tronco recebe pressão normal e maior pressão de desarmamento.
- Pernas recebem menos dano de vitalidade e maior dano de postura.
- Um único ataque não acerta múltiplas vezes o mesmo personagem.
- O HUD registra a última região atingida apenas para diagnóstico interno quando necessário.

## 8. Agarrão e projeções Ji

### Controles

- P1: `E`.
- P2: `Num 4`.

### Testes

- Agarrar adversário parado.
- Tentar agarrar durante esquiva.
- Tentar agarrar adversário no ar.
- Segurar para frente durante o controle.
- Segurar para trás durante o controle.
- Segurar salto durante o controle.
- Segurar para baixo durante o controle.
- Atingir o agarrador antes da projeção em teste futuro com terceiro agente ou chamada de debug.

### Resultado esperado

- Esquiva válida evita o agarrão.
- Alvo aéreo não é agarrado pelo Laço de Centro.
- Frente gera projeção horizontal.
- Trás lança o alvo para o lado oposto.
- Salto gera projeção vertical.
- Baixo gera maior dano de postura.
- Ambos recuperam o controle após a projeção.
- Reiniciar a rodada durante ou após agarrão não mantém referências presas.

## 9. Desarmamento

- Utilizar repetidamente Empurrão de Fundação contra o tronco.
- Combinar pressão de desarmamento com quebra de postura.
- Observar a barra roxa abaixo do personagem.
- Parar de atacar e confirmar redução gradual da pressão.

### Resultado esperado

- A pressão acumula até 100%.
- Ao atingir o limite, a arma é removida do lutador.
- Um objeto de arma aparece na arena.
- O personagem desarmado causa menos dano e postura.
- A arma não é perdida permanentemente.
- A arma original retorna no início da próxima rodada.

## 10. Espólio temporário

### Arma

- Desarmar um adversário.
- Aguardar menos de 0,75 segundo e tentar recolher com o antigo dono.
- Recolher com o adversário.
- Recolher posteriormente com o antigo dono.

### Eco de técnica

- Fazer um personagem utilizar uma técnica.
- Quebrar sua postura.
- Coletar o eco roxo.
- P1 usa `H`; P2 usa `Num 5`.

### Resultado esperado

- O antigo dono não recolhe imediatamente o próprio loot.
- Qualquer jogador pode recolher após o bloqueio inicial.
- Arma recolhida substitui temporariamente a arma atual.
- Eco permite executar uma vez a técnica capturada.
- O HUD exibe arma, pressão de desarmamento e eco disponível.
- Loot desaparece após o tempo limite ou reinício da rodada.

## 11. Manifestações do Fluxo

- Aguardar surgimento.
- Coletar Tai, Ji e Fu em rodadas diferentes.
- Aproximar ambos simultaneamente.

### Resultado esperado

- Apenas um jogador recebe o efeito.
- Tai restaura fôlego e gera impulso.
- Ji restaura postura.
- Fu restaura parte de vida e fôlego.
- Nova manifestação não aparece imediatamente.

## 12. Arena

- Percorrer rota superior.
- Percorrer rota inferior.
- Utilizar plataforma central móvel.
- Cair além do limite inferior.

### Resultado esperado

- Rotas permanecem conectadas.
- Paredes permitem navegação vertical.
- Queda elimina e reinicia a rodada.
- A câmera mantém ambos visíveis dentro dos limites previstos.

## 13. Regressão

Após qualquer alteração, repetir:

- início da partida;
- seleção de builds;
- movimento;
- ataque;
- defesa;
- aparo;
- agarrão;
- projeção;
- desarmamento;
- coleta de arma;
- coleta e uso de eco;
- manifestação;
- queda;
- reinício.

## Bloqueadores de merge

- erro de parser;
- cena principal não carrega;
- personagem atravessa chão;
- ataque permanece ativo indefinidamente;
- uma hitbox acerta duas regiões no mesmo golpe;
- defesa funciona pelas costas;
- wall jump gera subida infinita sem risco;
- alvo permanece agarrado após projeção ou reinício;
- agarrador consegue atacar livremente durante controle;
- arma some sem gerar loot;
- loot concede item múltiplas vezes;
- eco não é consumido após o uso;
- rodada não reinicia;
- build selecionada não é aplicada;
- manifestação concede bônus aos dois jogadores;
- perda de controle após aparo.

---

**Tehkné Solutions**
