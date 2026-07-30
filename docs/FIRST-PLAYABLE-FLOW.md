# First Playable — fluxo completo do primeiro nível

## Entrada padrão

O projeto passa a abrir em:

```text
scenes/vertical_slice/first_playable_menu.tscn
```

Versão do projeto:

```text
0.2.0-first-playable
```

## Menu

A ação principal é `JOGAR CONTRA IA`.

O menu também oferece:

- dificuldade Aprendiz, Discípulo ou Mestre;
- resumo de Lian Wu e do Rival de Treino;
- acesso secundário ao protótipo completo;
- saída do jogo;
- navegação por teclado, mouse e foco de gamepad.

Atalhos:

```text
Enter  iniciar combate
1      Aprendiz
2      Discípulo
3      Mestre
Esc    sair
```

## Persistência da sessão

`FirstPlayableSession` preserva a dificuldade selecionada entre:

```text
menu → combate → resultado → revanche
```

## HUD de combate

Cada lutador possui barras independentes de:

- vida;
- postura;
- fôlego.

O HUD mantém também:

- nomes;
- elemento;
- arma;
- dificuldade da IA;
- tempo restante;
- comandos principais.

## Pausa

Durante countdown ou combate:

```text
Esc → pausa
```

A tela de pausa oferece:

- continuar;
- voltar ao menu.

Os timers da contagem regressiva respeitam a pausa.

## Resultado

Após KO ou timeout, a tela de resultado informa:

- vitória ou derrota;
- vencedor;
- motivo;
- dificuldade usada.

Ações disponíveis:

- revanche;
- voltar ao menu.

`Enter` inicia revanche apenas no estado de resultado, evitando reinícios acidentais durante a luta.

## Protótipo completo

A cena histórica permanece disponível em:

```text
scenes/main.tscn
```

Ela pode ser aberta pelo botão `ABRIR PROTÓTIPO COMPLETO` no menu do First Playable.

## Validação

`tests/first_playable_flow_test.gd` verifica:

1. menu como entrada padrão;
2. botões obrigatórios;
3. seleção Mestre;
4. persistência até o combate;
5. seis barras inicializadas;
6. pausa e retomada;
7. resultado de vitória;
8. revanche pelo botão;
9. dificuldade preservada após revanche.

Saída esperada:

```text
FIRST_PLAYABLE_FLOW_OK
```

Assinatura: Tehkné Solutions
