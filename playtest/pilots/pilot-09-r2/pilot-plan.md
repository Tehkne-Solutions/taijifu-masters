# Taijifu Masters — Plano do piloto externo

- Piloto: `pilot-09-r2`
- Build: `0.2.3-playtest`
- Participantes anônimos: **9**
- Partidas previstas: **54**
- Privacidade: códigos anônimos; não registrar nome, e-mail, telefone ou IP.

## Distribuição

| Código | Plataforma | Ordem das dificuldades | Partidas |
|---|---|---|---:|
| TJFP-001 | Windows | Aprendiz → Discípulo → Mestre | 6 |
| TJFP-002 | Web | Discípulo → Mestre → Aprendiz | 6 |
| TJFP-003 | Windows | Mestre → Aprendiz → Discípulo | 6 |
| TJFP-004 | Windows | Aprendiz → Mestre → Discípulo | 6 |
| TJFP-005 | Web | Mestre → Discípulo → Aprendiz | 6 |
| TJFP-006 | Windows | Discípulo → Aprendiz → Mestre | 6 |
| TJFP-007 | Windows | Aprendiz → Discípulo → Mestre | 6 |
| TJFP-008 | Web | Discípulo → Mestre → Aprendiz | 6 |
| TJFP-009 | Windows | Mestre → Aprendiz → Discípulo | 6 |

## Entrega de cada participante

1. Executar exclusivamente o kit `0.2.3-playtest` na plataforma atribuída.
2. Pressionar `JOGAR CONTRA IA` e informar no diálogo o código anônimo atribuído, por exemplo `TJFP-001`.
3. Confirmar que nenhuma identidade `TJFP-###` é atribuída automaticamente antes da validação.
4. Jogar as 6 partidas; o runtime bloqueia a ordem oficial e avança automaticamente após cada par de partidas da mesma dificuldade.
5. Responder à avaliação de equilíbrio após cada partida.
6. No Web, baixar o relatório JSON; no Windows, localizar o arquivo salvo.
7. Confirmar que o arquivo começa com `TJFP-###__taijifu_`; não renomear quando estiver correto.
8. Confirmar no relatório `pilot_sequence_valid: true` e `arena: "Mountain Dojo Night"`.
9. Registrar bugs sem inserir dados pessoais.

## Gate da rodada

- mínimo de 6 participantes válidos;
- mínimo de 24 partidas concluídas;
- mínimo de 6 partidas por dificuldade;
- cobertura de feedback de 70% ou mais;
- nenhum P0 aberto;
- decisão documentada para todos os P1.

Assinatura: Tehkné Solutions
