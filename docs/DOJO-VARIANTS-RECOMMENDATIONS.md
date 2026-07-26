# Dojo, variantes selecionáveis e recomendações

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Adicionar um ambiente de treino controlado, permitir que cada perfil escolha conscientemente uma variante desbloqueada antes da batalha e transformar telemetria, domínio e Observação Marcial em recomendações concretas.

## Seleção de variantes

Cada perfil pode levar uma variante ativa por batalha.

### Controles

- P1: `Z/X`;
- P2: `Num 8/Num 9`.

A ordem inclui `SEM VARIANTE`, permitindo comparar a técnica-base com a versão ensinada pelo mestre.

A seleção é salva em:

```text
user://master_training.json
```

O arquivo passou para a versão 2 e mantém compatibilidade com perfis anteriores.

### Regras

- apenas variantes já desbloqueadas podem ser escolhidas;
- o primeiro desbloqueio é selecionado automaticamente quando o perfil ainda não possui escolha;
- a variante continua vinculada à arma e à técnica-base;
- selecionar uma variante não altera atributos;
- trocar de arma não transfere a variante para um kit incompatível.

## Dojo Técnico

O Dojo é ativado depois que os lutadores foram criados.

### Controles

- `F8`: entrar ou sair;
- `F9`: alternar comportamento do boneco;
- `F10`: alternar perfil de recursos;
- `F11`: reiniciar posições e recursos.

Ao entrar:

- o bot tático normal é desativado;
- o colapso lateral é suspenso;
- manifestações deixam de surgir;
- P1 e P2 são posicionados em uma área central de treino;
- os mesmos controladores, hitboxes, custos e técnicas da batalha continuam ativos.

### Comportamentos do boneco

1. **Passivo** — não responde;
2. **Defesa contínua** — segura bloqueio sem gerar aparos artificiais repetidos;
3. **Tentativa de aparo** — toca defesa ao perceber startup/atividade;
4. **Esquiva reativa** — usa esquiva dentro da distância configurada;
5. **Contra-ataque** — bloqueia a pressão e responde durante a recuperação do P1.

### Perfis de recursos

- **Normal** — nenhuma intervenção;
- **Recuperação** — fôlego e postura são restaurados; vida não cai abaixo de uma margem segura;
- **Treino** — vida, postura, fôlego e pressão de desarmamento são restaurados continuamente.

## Recomendações dos mestres

`F6` abre o painel de recomendações.

O sistema cruza:

- variante desbloqueada e ainda não equipada;
- domínio das armas compatíveis com cada mestre;
- respostas defensivas da última rodada;
- rota Tai, Ji ou Fu menos utilizada;
- técnicas muito observadas e ainda não defendidas;
- provas já concluídas.

### Ordem de prioridade

1. recomendar equipar uma variante desbloqueada;
2. indicar uma prova já liberada pelo domínio;
3. recomendar exercício de defesa no Dojo;
4. apontar a arma mais próxima do estágio exigido;
5. sugerir uma rodada mais variada quando ainda não existem dados suficientes.

### Exemplos

- “Equipe Asa Cruzada na preparação.”
- “Mestra Orra: suas respostas defensivas estão baixas.”
- “Treine contra Estocada do Horizonte com o boneco em aparo ou esquiva.”
- “Use o Bastão Adaptativo até o estágio Treinada para acessar Mestre Han.”

## Arquitetura

```text
MasterTrainingLedger
├── variantes desbloqueadas
├── provas concluídas
└── variante selecionada

VariantLoadoutRuntime
├── controles da preparação
├── persistência
└── aplicação no lutador

DojoTrainingRuntime
├── isolamento da arena
├── boneco configurável
├── perfis de recursos
└── reset controlado

MasterRecommendationRuntime
├── domínio de arma
├── Observação Marcial
├── telemetria da rodada
└── recomendação acionável
```

## Critérios de validação

1. perfis antigos migram sem perder variantes;
2. `Z/X` e `Num 8/Num 9` percorrem apenas opções válidas;
3. `SEM VARIANTE` executa a técnica-base;
4. a variante selecionada persiste após reiniciar;
5. somente a combinação arma + técnica correta recebe modificação;
6. `F8` suspende colapso e bot normal;
7. defesa contínua não cria aparo a cada frame;
8. aparo, esquiva e contra-ataque respeitam cooldowns;
9. `F11` restaura posições sem remover a seleção de variante;
10. `F6` apresenta recomendações diferentes conforme os dados;
11. o Dojo não concede domínio ou variantes sem executar ações reais;
12. sair do Dojo restaura o estado anterior do bot e reinicia o fluxo da arena.

---

**Tehkné Solutions**
