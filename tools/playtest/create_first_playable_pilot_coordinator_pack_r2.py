#!/usr/bin/env python3
"""Pilot r2 coordinator pack entrypoint.

Keeps the historical coordinator generator compatible with the 0.2.1 fixture
while replacing only the active pilot defaults and operational README.

Signature: Tehkné Solutions
"""
from __future__ import annotations

from pathlib import Path

import create_first_playable_pilot_coordinator_pack as core

ACTIVE_PILOT_ID = "pilot-09-r2"
SIGNATURE = "Tehkné Solutions"


def write_r2_readme(
    path: Path,
    pilot_id: str,
    version: str,
    participant_count: int,
) -> None:
    path.write_text(
        f"""TAIJIFU MASTERS — PACOTE DO COORDENADOR

PILOTO: {pilot_id}
BUILD: {version}
VAGAS ANÔNIMAS: {participant_count}

USO
1. Confira o SHA-256 deste pacote.
2. Não envie este pacote inteiro aos participantes: ele contém o roster de coordenação.
3. Envie apenas game-kit/ e a atribuição individual TJFP-### correspondente.
4. Mantenha contatos e relatórios reais fora do GitHub.
5. Oriente o participante a informar TJFP-### no menu antes de jogar.
6. Confirme que cada JSON recebido já começa com TJFP-###__taijifu_.
7. Não renomeie arquivos corretamente prefixados; rejeite códigos divergentes no intake.
8. Execute o intake pelo entrypoint endurecido.
9. Consolide e gere o backlog somente após corrigir todas as rejeições.

COMANDOS
python tools/run_first_playable_pilot.py intake <reports> --plan pilot/pilot-plan.json --output-dir results/intake --strict
python tools/aggregate_first_playable_reports.py <reports> --output-dir results/summary --fail-on-invalid
python tools/run_first_playable_pilot.py triage --plan pilot/pilot-plan.json --intake results/intake/pilot-intake-manifest.json --summary results/summary/first-playable-playtest-summary.json --observations pilot/pilot-observations.json --decisions pilot/pilot-decisions.json --output-dir results/triage --strict --fail-on-p0

PRIVACIDADE
- Nenhum dado real está incluído neste pacote.
- Os templates de observações e decisões estão vazios.
- Não versionar relatórios reais.
- Não inserir nome, e-mail, telefone, IP, senha, token ou credencial.

Assinatura: {SIGNATURE}
""",
        encoding="utf-8",
    )


def main() -> int:
    core.DEFAULT_PILOT_ID = ACTIVE_PILOT_ID
    core.write_readme = write_r2_readme
    return core.run()


if __name__ == "__main__":
    raise SystemExit(main())
