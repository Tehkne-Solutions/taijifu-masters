# Mestres, treinamento e variantes técnicas

## Objetivo

Transformar domínio de arma em acesso a aprendizado especializado, sem conceder bônus automáticos de dano ou atributos.

O ciclo implementado é:

```text
Usar a arma
→ alcançar domínio mínimo
→ procurar um mestre
→ aceitar uma prova
→ cumprir ações reais em combate
→ desbloquear uma variação técnica
```

## Controles

- `T`: abrir ou fechar o painel dos mestres;
- `Y`: alternar entre o perfil P1 e P2;
- `U`: alternar o mestre selecionado;
- `I`: iniciar ou reiniciar a prova exibida.

O painel não pausa a batalha. As provas são concluídas usando as mesmas regras, recursos e adversários do combate normal.

## Mestres iniciais

### Mestre Han — Fu

Arma:

- Bastão Adaptativo.

Requisito:

- domínio Treinada ou superior.

Prova **As Três Correntes**:

- usar três técnicas do bastão;
- acertar duas técnicas;
- realizar um acerto adaptativo após trocar para o bastão.

Recompensa:

- **Círculo das Três Correntes**, variação do Círculo de Retorno.

Características:

- alcance horizontal maior;
- janela ativa ampliada;
- mudança de direção durante a preparação;
- maior custo de fôlego;
- startup e recuperação maiores;
- dano direto ligeiramente menor.

### Mestra Orra — Ji

Armas:

- Manoplas Sísmicas;
- Manoplas Quebra-Fundação.

Requisito:

- domínio Treinada ou superior.

Prova **Fundação Invertida**:

- usar três técnicas das manoplas;
- acertar duas técnicas;
- realizar um aparo com as manoplas equipadas.

Recompensa:

- **Fundação Invertida**, variação do Giro de Fundação.

Características:

- maior dano de postura;
- maior pressão de desarmamento;
- janela ativa ampliada;
- deslocamento menor;
- dano direto reduzido;
- maior custo e recuperação.

### Mestra Lyenne — Tai

Arma:

- Faixas do Vento.

Requisito:

- domínio Treinada ou superior.

Prova **Asa Cruzada**:

- usar três técnicas das faixas;
- acertar duas técnicas;
- trocar para as faixas durante a luta.

Recompensa:

- **Asa Cruzada**, variação do Arco Ascendente.

Características:

- preparação mais rápida;
- maior deslocamento horizontal e vertical;
- capacidade de ajustar a direção;
- dano direto menor;
- maior custo e recuperação.

## Regras de desbloqueio

- o estágio de domínio é lido de `user://weapon_mastery.json`;
- a prova só começa quando existe uma arma compatível no estágio exigido;
- ações com outra arma não contam;
- magias, agarrões genéricos e ecos não contam como uso da arma;
- repetir a prova reinicia somente seus contadores atuais;
- a variante liberada fica vinculada ao perfil;
- desbloqueios são salvos em `user://master_training.json`.

## Aplicação das variantes

As variantes são associadas à combinação:

```text
arma + técnica-base
```

Isso impede que uma variação aprendida com Faixas do Vento seja aplicada ao mesmo golpe quando o personagem estiver desarmado.

A técnica-base permanece registrada na Observação Marcial, no domínio e na telemetria. A variação modifica a execução daquela técnica no momento do uso e comunica seu nome próprio no HUD.

## Filosofia de progressão

Domínio não aumenta atributos passivamente.

Ele demonstra experiência suficiente para acessar desafios mais complexos. A recompensa amplia decisões e especialização, mas preserva contrapartidas claras.

O jogador evolui por:

- prática;
- consistência;
- adaptação;
- execução sob risco;
- orientação de mestres.

## Persistência

```text
user://weapon_mastery.json
user://master_training.json
```

Os arquivos são separados para permitir recalibrar XP, provas ou recompensas sem perder todo o histórico do jogador.

## Validação no Godot 4.3+

1. abrir o painel com `T`;
2. alternar perfil e mestre;
3. bloquear prova sem domínio suficiente;
4. iniciar prova ao alcançar Treinada;
5. confirmar que arma incompatível não conta;
6. confirmar atualização dos contadores;
7. concluir cada uma das três provas;
8. reiniciar o jogo e preservar desbloqueios;
9. executar a variação somente com a arma correta;
10. validar custo, startup, atividade e recuperação;
11. confirmar que a técnica-base continua na telemetria;
12. confirmar ausência de bônus ocultos de atributos.

---

**Tehkné Solutions**
