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
- técnicas contextuais.

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

## 7. Manifestações do Fluxo

- Aguardar surgimento.
- Coletar Tai, Ji e Fu em rodadas diferentes.
- Aproximar ambos simultaneamente.

### Resultado esperado

- Apenas um jogador recebe o efeito.
- Tai restaura fôlego e gera impulso.
- Ji restaura postura.
- Fu restaura parte de vida e fôlego.
- Nova manifestação não aparece imediatamente.

## 8. Arena

- Percorrer rota superior.
- Percorrer rota inferior.
- Utilizar plataforma central móvel.
- Cair além do limite inferior.

### Resultado esperado

- Rotas permanecem conectadas.
- Paredes permitem navegação vertical.
- Queda elimina e reinicia a rodada.
- A câmera mantém ambos visíveis dentro dos limites previstos.

## 9. Regressão

Após qualquer alteração, repetir:

- início da partida;
- seleção de builds;
- movimento;
- ataque;
- defesa;
- aparo;
- coleta;
- queda;
- reinício.

## Bloqueadores de merge

- erro de parser;
- cena principal não carrega;
- personagem atravessa chão;
- ataque permanece ativo indefinidamente;
- defesa funciona pelas costas;
- wall jump gera subida infinita sem risco;
- rodada não reinicia;
- build selecionada não é aplicada;
- manifestação concede bônus aos dois jogadores;
- perda de controle após aparo.

---

**Tehkné Solutions**
