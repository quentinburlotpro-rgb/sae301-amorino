#!/usr/bin/env bash
# =====================================================================
#  SAé 3.01 — Déploie toutes les itérations d'affilée sur mmi.unilim.fr,
#  puis commite le journal sur GitHub. Une seule connexion SSH.
#  Usage :  bash prod-all.sh [première-étape]     ex. : bash prod-all.sh it5
# =====================================================================
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
STEPS=(it1 it2 it3 it4 it5 it6 it7 it8 it9 it10 it11 it12 it13 it14 it15 it16 it17 it18 it19 it20 it21 it22 itw itx itz main)
START="${1:-it1}"
source .prod.conf; HOST="$LOGIN@mmi.unilim.fr"; SOCK="$HOME/.ssh/cm-sae301-%r@%h"
(cd site && ddev start >/dev/null)
echo "▶ Connexion SSH (une seule fois)"
ssh -o StrictHostKeyChecking=accept-new -o ControlMaster=auto -o ControlPath="$SOCK" -o ControlPersist=60m -fN "$HOST"
trap 'ssh -o ControlPath="$SOCK" -O exit "$HOST" >/dev/null 2>&1 || true' EXIT
go=0
for s in "${STEPS[@]}"; do
  [[ "$s" == "$START" ]] && go=1
  [[ $go == 1 ]] || continue
  printf "\n\033[1;36m════════ %s ════════\033[0m\n" "$s"
  if ! KEEP_SSH=1 AUTO=1 NOTE="déploiement automatique" bash prod-step.sh "$s"; then
    printf "\n\033[1;31m✖ Arrêt à l'étape %s. Corrige puis reprends avec : bash prod-all.sh %s\033[0m\n" "$s" "$s"
    exit 1
  fi
done
echo; echo "▶ Journal et doc sur GitHub (dépôt sae301-amorino)"
cp JOURNAL.md DEPLOIEMENT.md "$HOME/Desktop/amorino-design-system/"
cd "$HOME/Desktop/amorino-design-system"
git add JOURNAL.md DEPLOIEMENT.md
git diff --cached --quiet || git commit -q -m "Journal de mise en production : IT-1 à IT-Z"
git push -q && echo "✔ Journal poussé"
echo "✔ Terminé : $(grep PROD_URL "$HERE/.prod.conf" | cut -d= -f2)"
