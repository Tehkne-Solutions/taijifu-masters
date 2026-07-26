# Dificuldade, personalidade e heatmap

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Adicionar variedade e progressão à inteligência artificial sem conceder vantagens ocultas, além de registrar onde jogadores e bots realmente lutam, circulam e caem nas Ruínas do Caminho Triplo.

## Princípio de justiça

Todos os níveis usam:

- os mesmos atributos da build;
- o mesmo dano;
- os mesmos custos de fôlego;
- as mesmas técnicas;
- as mesmas fases de startup, atividade e recuperação;
- as mesmas regras de colisão, agarrão, elementos e arena.

A dificuldade altera somente:

- atraso de percepção;
- frequência de decisão;
- chance de resposta defensiva;
- frequência de erros intencionais;
- eficiência na disputa de agarrão;
- frequência de revisão de rota.

## Níveis de dificuldade

### Aprendiz

- reações claramente mais lentas;
- hesitação frequente;
- baixa consistência defensiva;
- fuga de agarrão menos eficiente;
- navegação revisada com menor frequência.

Objetivo: ensinar o núcleo sem comportamento passivo completo.

### Discípulo

- comportamento equilibrado;
- erros legíveis;
- defesa e esquiva moderadas;
- navegação funcional.

É o nível padrão do Protótipo Zero.

### Adepto

- melhor leitura;
- menos erros;
- defesa consistente;
- melhor disputa de controle;
- revisão rápida de objetivos.

### Mestre

- reação forte, ainda acima do limite mínimo humano definido;
- baixa frequência de erros;
- boa gestão de defesa, rota e agarrão;
- sem leitura direta de comandos;
- sem recursos ou atributos adicionais.

## Personalidades

### Agressivo

Prioriza:

- aproximação;
- contato Ji;
- agarrões;
- pressão contínua;
- menor distância ideal.

Aceita permanecer mais tempo com postura reduzida antes de recuar.

### Guardião

Prioriza:

- controle territorial;
- defesa;
- recuperação de postura;
- empurrões;
- distância segura.

### Técnico

Prioriza:

- rota Fu;
- transições;
- leitura defensiva;
- manifestações úteis;
- alternância entre kit e elemento.

É a personalidade padrão.

### Caótico

Prioriza:

- elementos;
- manifestações;
- mudança de rota;
- objetivos variados;
- decisões menos previsíveis.

Não significa comportamento aleatório sem propósito: riscos da arena e ameaças imediatas continuam prioritários.

## Controles

- `Tab`: alternar bot e P2 local;
- `F4`: avançar dificuldade;
- `F7`: avançar personalidade;
- `F3`: mostrar ou ocultar heatmap;
- `F2`: mostrar relatório pós-rodada.

A dificuldade e a personalidade podem ser alteradas durante a execução. Toda troca libera comandos simulados e reinicia a decisão atual.

## Heatmap

O runtime divide o mundo em células de 140 pixels.

A cada intervalo controlado, ele registra:

- célula ocupada por P1;
- célula ocupada por P2;
- intensidade acumulada;
- pontos de queda;
- rodada em que cada queda ocorreu;
- perfil atual do bot.

### Visualização

- azul: ocupação de P1;
- laranja: ocupação de P2;
- maior opacidade: maior permanência relativa;
- marca em X: ponto de queda.

O heatmap é uma camada de depuração e não possui colisão.

## Persistência

O arquivo é atualizado ao final de cada rodada e ao fechar a cena:

```text
user://telemetry/heatmap_<sessão>.json
```

O JSON contém:

- versão;
- identificador da sessão;
- quantidade de rodadas;
- tamanho da célula;
- dificuldade e personalidade atuais;
- células de P1 e P2;
- quedas;
- célula mais ocupada por jogador.

## Uso para balanceamento

O heatmap deve ajudar a responder:

- quais plataformas concentram a luta;
- quais rotas são ignoradas;
- onde o bot fica preso;
- onde acontecem mais quedas;
- se uma personalidade realmente altera ocupação;
- se o colapso lateral produz avanço ou apenas dano;
- se manifestações geram disputa territorial;
- se builds Tai, Ji e Fu ocupam regiões diferentes.

## Validação obrigatória no Godot 4.3+

1. alternar os quatro níveis sem comandos presos;
2. alternar as quatro personalidades durante a luta;
3. confirmar que dano, vida e fôlego permanecem inalterados;
4. observar atraso claramente distinto entre Aprendiz e Mestre;
5. confirmar mais recuo do Guardião;
6. confirmar maior contato do Agressivo;
7. confirmar maior uso elemental do Caótico;
8. confirmar maior transição do Técnico;
9. mostrar e ocultar o heatmap por `F3`;
10. validar células separadas para P1 e P2;
11. validar marca única por queda;
12. validar persistência após múltiplas rodadas;
13. comparar JSON e visualização;
14. confirmar ausência de impacto de colisão ou FPS relevante.

## Riscos observados

### Mestre artificialmente perfeito

Mitigação:

- atraso mínimo preservado;
- chance residual de erro;
- resposta baseada em fase visível, não botão pressionado.

### Personalidade anulando sobrevivência

Mitigação:

- borda, agarrão e ataques próximos sempre interrompem objetivos de personalidade.

### Heatmap crescendo indefinidamente

Mitigação:

- grade agregada por célula;
- amostragem intervalada;
- arquivo único por sessão.

### Queda registrada mais de uma vez

Mitigação:

- cada jogador precisa retornar à área segura antes de armar uma nova queda.

## Próxima etapa

- arma secundária e troca manual;
- domínio de arma ligado ao uso real;
- mestres e treinamento alimentados pela Observação Marcial;
- heatmap comparativo entre sessões;
- exportação visual para relatório de playtest.

---

**Tehkné Solutions**
