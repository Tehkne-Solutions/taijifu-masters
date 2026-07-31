# Taijifu Masters — protocolo de playtest do First Playable

## Objetivo

Validar se o combate entre Lian Wu e o Rival de Treino é compreensível, responsivo, equilibrado e divertido nas dificuldades Aprendiz, Discípulo e Mestre.

A coleta desta sprint é local. Nenhum relatório é enviado automaticamente para servidores externos.

## Preparação

1. Use uma build identificada como `0.2.1-playtest` ou posterior.
2. Extraia o pacote Windows antes de executar.
3. No Web, use navegador Chromium atualizado e mantenha o jogo em orientação paisagem.
4. Tenha em mãos o código anônimo `TJFP-###` fornecido pelo coordenador.
5. Siga a ordem das dificuldades definida no plano do piloto.
6. Faça pelo menos duas partidas em cada dificuldade.

## Roteiro do jogador

1. Entrar pelo menu First Playable.
2. Informar o código anônimo do piloto, por exemplo `TJFP-003` ou somente `003`.
3. Confirmar que o menu mostra `CÓDIGO VÁLIDO` antes de iniciar.
4. Selecionar a dificuldade.
5. Jogar sem orientação adicional na primeira tentativa.
6. Testar movimento, salto, ataque, defesa, esquiva, impulso e agarrão.
7. Pausar e continuar pelo menos uma vez.
8. Concluir uma partida por KO.
9. Concluir ou simular uma partida por tempo quando possível.
10. Usar revanche e confirmar que a dificuldade e o código permanecem selecionados.
11. Responder à pergunta de equilíbrio após cada partida:
   - Fácil demais;
   - Equilibrado;
   - Difícil demais.
12. Pressionar `COPIAR RELATÓRIO DO PLAYTEST` e enviar o JSON junto do feedback textual.

## Perguntas qualitativas

- Em até dez segundos, ficou claro quem você controlava?
- Os comandos pareceram responder imediatamente?
- Foi possível entender quando um golpe acertou, foi defendido ou evitado?
- A arena ajudou ou atrapalhou a leitura do combate?
- A IA pareceu justa na dificuldade escolhida?
- Houve momento sem saber o que fazer?
- Houve travamento, soft lock, personagem preso ou interface bloqueando a ação?
- Você jogaria uma revanche espontaneamente?

## Dados registrados localmente

Cada sessão pode conter:

- código anônimo `TJFP-###`;
- identificador do piloto;
- versão da build;
- plataforma e localidade;
- dificuldade usada;
- duração e forma de encerramento;
- vitória ou derrota;
- vida, postura, fôlego e posição final dos lutadores;
- pausas, retomadas, mudanças de dificuldade e revanches;
- percepção de equilíbrio escolhida pelo jogador.

Não incluir nome, e-mail, IP, credenciais ou qualquer dado pessoal no relatório.

## Local e nome do arquivo

O jogo grava os arquivos em `user://telemetry` já usando o prefixo esperado pelo intake:

```text
TJFP-003__taijifu_1785450000-1234.json
```

Não é necessário renomear o arquivo quando o código foi informado corretamente no menu. Builds antigas sem o campo de código ainda podem exigir renomeio manual pelo coordenador.

O botão de cópia envia o conteúdo completo da sessão para a área de transferência, facilitando o envio por issue, formulário ou mensagem.

## Critérios de bloqueio

Bloquear uma nova release se ocorrer qualquer um destes casos:

- código válido não libera o início da partida;
- arquivo JSON não recebe o prefixo do participante;
- partida não inicia;
- IA não executa ações;
- KO ou timeout não abre o resultado;
- pausa ou revanche causa soft lock;
- relatório JSON não é gerado;
- feedback altera o resultado ou inicia outra ação;
- build Web não abre no Chromium;
- build Windows não inicia após extração.

## Consolidação recomendada

Agrupar os relatórios por versão, código anônimo e dificuldade. Priorizar:

1. travamentos e bloqueios;
2. comandos não compreendidos;
3. dificuldade percebida diferente da configurada;
4. duração excessiva ou curta;
5. problemas de leitura visual;
6. sugestões de conteúdo e polimento.

Assinatura: Tehkné Solutions
