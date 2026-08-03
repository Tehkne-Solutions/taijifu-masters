Tehkné Solutions — VM02 Gate Runner

Preferred validation workflow after checking out a vm02-cXX-* branch:

powershell -ExecutionPolicy Bypass -File ".\tools\RUN-CURRENT-VM02-GATE.ps1" `
  -RepoRoot "W:\TEHKNE-SOLUTIONS\PROJETOS\JOGO-TAIJIFU-MASTERS\taijifu-masters"

The runner:
- detects CXX from the current branch name;
- resolves exactly one matching RUN-VM02-CXX-*-GATE.ps1;
- fetches and fast-forward pulls the current branch;
- runs the canonical gate;
- stores the complete execution log under artifacts\gate-reports;
- preserves the gate's compact COPY_REPORT clipboard output.

Use -NoPull when the repository was already synchronized and you only want to rerun the gate.
