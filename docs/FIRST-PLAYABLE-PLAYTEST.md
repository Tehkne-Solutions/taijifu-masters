# Taijifu Masters — protocolo de playtest do First Playable

## Objetivo

Validar se o combate entre Lian Wu e o Rival de Treino é compreensível, responsivo, equilibrado e divertido nas dificuldades Aprendiz, Discípulo e Mestre.

A coleta desta sprint é local. Nenhum relatório é enviado automaticamente para servidores externos.

## Preparação

1. Use exclusivamente a build `0.2.3-playtest` no piloto `pilot-09-r2`.
2. Extraia o pacote Windows antes de executar.
3. No Web, use navegador Chromium atualizado e mantenha o jogo em orientação paisagem.
4. Tenha em mãos o código anônimo `TJFP-###` fornecido pelo coordenador.
5. Cada código possui uma sequência oficial de dificuldades; o runtime do piloto aplica essa sequência automaticamente.
6. São obrigatórias duas partidas em cada dificuldade, totalizando seis partidas por participante.

## Roteiro do jogador

1. Entrar pelo menu First Playable.
2. Acionar `JOGAR CONTRA IA`.
3. Informar o código anônimo do piloto, por exemplo `TJFP-003` ou somente `003`, quando solicitado.
4. Confirmar que o código foi aceito e que a dificuldade atribuída ao primeiro bloco foi aplicada automaticamente.
5. Não tentar alterar manualmente a dificuldade durante a sessão oficial; os controles devem permanecer travados.
6. Jogar sem orientação adicional na primeira tentativa.
7. Testar movimento, salto, ataque, defesa, esquiva, impulso e agarrão.
8. Pausar e continuar pelo menos uma vez.
9. Concluir uma partida por KO.
10. Concluir ou simular uma partida por tempo quando possível.
11. Ao terminar cada luta, responder à pergunta de equilíbrio antes de `REVANCHE` ou `MENU`:
   - Fácil demais;
   - Equilibrado;
   - Difícil demais.
12. Confirmar que `REVANCHE` só é liberada depois do feedback e inicia a próxima partida na dificuldade exigida pela sequência oficial.
13. Após duas partidas na mesma dificuldade, confirmar a transição automática para o próximo bloco.
14. Após a sexta partida, confirmar que o resultado mostra `PILOTO CONCLUÍDO` e não permite uma sétima luta.
15. No Web, pressionar `BAIXAR RELATÓRIO JSON` e guardar o arquivo baixado.
16. No Windows, pressionar `LOCALIZAR RELATÓRIO JSON` para abrir a localização do arquivo já salvo.
17. Usar `COPIAR RELATÓRIO DO PLAYTEST` somente como alternativa quando o download ou a localização não estiver disponível.
18. Enviar o arquivo JSON junto do feedback textual.

## Perguntas qualitativas

- Em até dez segundos, ficou claro quem você controlava?
- Os comandos pareceram responder imediatamente?
- Foi possível entender quando um golpe acertou, foi defendido ou evitado?
- A arena ajudou ou atrapalhou a leitura do combate?
- A IA pareceu justa em cada dificuldade atribuída?
- A progressão automática de dificuldade ficou clara?
- Houve momento sem saber o que fazer?
- Houve travamento, soft lock, personagem preso ou interface bloqueando a ação?
- Você jogaria uma revanche espontaneamente?

## Dados registrados localmente

Cada sessão pode conter:

- código anônimo `TJFP-###`;
- identificador do piloto;
- versão da build;
- plataforma e localidade;
- dificuldade usada em cada round;
- validade da sequência oficial do piloto;
- duração e forma de encerramento;
- vitória ou derrota;
- vida, postura, fôlego e posição final dos lutadores;
- pausas, retomadas, tentativas de mudança de dificuldade e revanches;
- percepção de equilíbrio escolhida pelo jogador.

Não incluir nome, e-mail, IP, credenciais ou qualquer dado pessoal no relatório.

## Local, download e nome do arquivo

O jogo grava os arquivos em `user://telemetry` já usando o prefixo esperado pelo intake:

```text
TJFP-003__taijifu_1785450000-1234.json
```

Não é necessário renomear o arquivo quando o código foi informado corretamente no menu.

No Web, o botão de download cria o arquivo inteiramente no navegador usando um `Blob` local. O JSON não é enviado para nenhum servidor. A URL temporária é revogada após o início do download.

No Windows, o botão de localização revela o arquivo já gravado, sem criar uma segunda cópia divergente.

O botão de cópia mantém o conteúdo completo da sessão na área de transferência como fallback.

## Critérios de bloqueio

Bloquear uma nova release se ocorrer qualquer um destes casos:

- código válido não inicia uma sessão oficial do participante correto;
- arquivo JSON não recebe o prefixo do participante;
- `pilot_id` ou `participant_code` divergirem do piloto ativo;
- controles de dificuldade permitirem override manual durante a sessão oficial;
- dificuldade aplicada divergir da sequência atribuída ao `TJFP-###`;
- `pilot_sequence_valid` não for verdadeiro ao concluir a sessão válida;
- partida não inicia;
- IA não executa ações;
- KO ou timeout não abre o resultado;
- pausa causa soft lock;
- `REVANCHE` ou `MENU` forem liberados antes do feedback obrigatório;
- revanche iniciar com dificuldade incorreta;
- uma sétima luta puder iniciar depois de 6/6;
- relatório JSON não é gerado;
- download Web não produz um JSON com o nome esperado;
- localização Windows não encontra o arquivo já salvo;
- feedback altera o resultado ou inicia outra ação indevida;
- build Web não abre no Chromium;
- build Windows não inicia após extração.

## Consolidação recomendada

Agrupar os relatórios por versão, código anônimo e dificuldade. Priorizar:

1. travamentos e bloqueios;
2. violações da sequência oficial ou perda de telemetria;
3. comandos não compreendidos;
4. dificuldade percebida diferente da configurada;
5. duração excessiva ou curta;
6. problemas de leitura visual;
7. sugestões de conteúdo e polimento.

Assinatura: Tehkné Solutions
