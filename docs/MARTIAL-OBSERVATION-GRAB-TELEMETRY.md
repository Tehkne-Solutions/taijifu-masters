# Observação Marcial, Disputa de Agarrão e Telemetria

## Objetivo

Esta camada transforma três conceitos centrais do protótipo em sistemas verificáveis:

- aprender técnicas pela experiência real;
- disputar agarrões em vez de aguardar passivamente a projeção;
- registrar como cada jogador utiliza Tai, Ji, Fu e os elementos.

## Observação Marcial

O progresso é separado por perfil local e por técnica.

### Estágios

1. **Vista** — a técnica foi observada a uma distância válida.
2. **Reconhecida** — o jogador já a encontrou mais de uma vez ou foi atingido.
3. **Compreendida** — diferentes respostas já foram experimentadas.
4. **Defendida** — a técnica foi bloqueada ou aparada.
5. **Reproduzida** — um eco foi coletado e executado.
6. **Adaptada** — a técnica reproduzida já fazia parte de uma experiência defensiva anterior.
7. **Dominada** — exige pontuação alta, múltiplas defesas, reproduções e adaptações.

Repetir apenas a observação não libera os estágios superiores.

### Persistência

O arquivo é salvo localmente em:

```text
user://martial_observation.json
```

Estrutura resumida:

```json
{
  "version": 1,
  "profiles": {
    "p1": {
      "ji_body_hook": {
        "score": 18,
        "stage": "defended",
        "events": {
          "seen": 3,
          "recognized": 2,
          "defended": 1
        }
      }
    }
  }
}
```

## Disputa ativa de agarrão

O tempo de controle do **Laço de Centro** foi ampliado para permitir uma decisão real antes da projeção.

### Ações do alvo

- alternar esquerda e direita: maior ganho regular;
- repetir a mesma direção: ganho reduzido;
- esquiva: ganho alto com consumo de fôlego;
- ataque: ganho moderado;
- defesa: ganho pequeno baseado em Controle.

### Ações do agarrador

O agarrador pode pressionar novamente o comando de agarrão para:

- consumir fôlego;
- reduzir o progresso da fuga;
- aplicar uma pequena recarga antes de reforçar novamente.

### Influência da build

- **Fu** reduz a dificuldade da fuga;
- **Agilidade** melhora a tentativa com esquiva;
- **Técnica** melhora a reação ofensiva;
- **Controle** melhora a estabilização defensiva;
- **Ji e Controle do agarrador** elevam o limite necessário.

A fuga concluída separa os personagens e devolve iniciativa limitada ao defensor.

## Telemetria

O runtime registra uma sessão com uma ou mais rodadas.

### Rotas

A posição vertical classifica o uso predominante:

- parte superior: Tai;
- parte inferior: Ji;
- transições centrais: Fu.

### Eventos

São registrados:

- início de técnicas;
- técnicas vistas e enfrentadas;
- bloqueios, aparos e esquivas;
- reprodução de ecos;
- conjurações elementais;
- interações elementais;
- agarrões;
- tentativas e conclusão de fuga;
- derrotas e vencedor.

### Arquivo

```text
user://telemetry/taijifu_<sessão>.json
```

O arquivo é atualizado ao final de cada rodada.

## HUD

A faixa central superior mostra:

- último conhecimento marcial relevante de cada perfil;
- rota predominante na rodada atual;
- avisos temporários de avanço de estágio;
- confirmação de fuga;
- confirmação de salvamento da telemetria.

## Critérios de validação

### Observação

- observar uma técnica atualiza apenas o perfil adversário;
- distância excessiva não conta como observação;
- bloqueio e aparo avançam para Defendida;
- executar eco avança para Reproduzida;
- progressão permanece após reiniciar o jogo;
- repetir apenas Vista não produz Domínio.

### Agarrão

- alvo parado é projetado ao fim da janela;
- alternar direções gera mais progresso que repetir uma direção;
- esquiva consome fôlego;
- agarrador consegue reforçar o controle;
- Fu alto escapa mais facilmente que Fu baixo;
- nenhuma referência permanece presa após fuga, projeção ou reinício.

### Telemetria

- tempo das três rotas é acumulado;
- técnica elemental registra elemento;
- interação elemental registra o tipo;
- fuga e projeção geram eventos diferentes;
- derrota grava arquivo válido;
- nova rodada começa com métricas zeradas sem apagar rodadas anteriores.

## Bloqueadores de merge

- erro de parser em qualquer um dos três novos sistemas;
- arquivo de observação corrompido impedir a abertura do jogo;
- fuga permitir movimento livre enquanto ainda agarrado;
- agarrador perder fôlego continuamente sem novo comando;
- telemetria escrever a cada frame;
- múltiplas conexões do mesmo lutador duplicarem eventos;
- progressão de um perfil ser aplicada ao outro.

---

**Tehkné Solutions**
