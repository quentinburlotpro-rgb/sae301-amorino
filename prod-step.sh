#!/usr/bin/env bash
# =====================================================================
#  SAé 3.01 — Mise en Prod itération par itération (mmi.unilim.fr)
#  Usage :  bash prod-step.sh <étape>        (depuis le dossier "sae 3.01")
#  Étapes, dans l'ordre :  it1  it2  it3  it4  it5-22  final
#  Chaque étape : code du thème au commit de l'itération, extensions,
#  contenus de l'itération, vérifications HTTP, ligne dans JOURNAL.md.
# =====================================================================
set -euo pipefail
STEP="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"; SITE="$HERE/site"; CHILD="$SITE/wp-content/themes/storefront-child"
CHILD_REPO="https://github.com/quentinburlotpro-rgb/storefront-child.git"
PREFIX="r3sae01_"
say()  { printf "\n\033[1;35m▶ %s\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m! %s\033[0m\n" "$*"; }
die()  { printf "\033[1;31m✖ %s\033[0m\n" "$*"; exit 1; }

case "$STEP" in
  it1)  LABEL="IT-1 Installation, extensions, thème enfant" ;;
  it2)  LABEL="IT-2 Charte, catalogue, maquette" ;;
  it3)  LABEL="IT-3 Produits variables" ;;
  it4)  LABEL="IT-4 Allergènes, nutrition, composition" ;;
  it5)  LABEL="IT-5 Panier, paiements, expédition" ;;
  it6)  LABEL="IT-6 Checkout, code de retrait" ;;
  it7)  LABEL="IT-7 Compte client" ;;
  it8)  LABEL="IT-8 E-mails transactionnels" ;;
  it9)  LABEL="IT-9 Commandes" ;;
  it10) LABEL="IT-10 Promotions" ;;
  it11) LABEL="IT-11 Équipe" ;;
  it12) LABEL="IT-12 Taxonomie" ;;
  it13) LABEL="IT-13 Ventes croisées" ;;
  it14) LABEL="IT-14 Avis clients" ;;
  it15) LABEL="IT-15 Frais de préparation" ;;
  it16) LABEL="IT-16 Landing page" ;;
  it17) LABEL="IT-17 Factures PDF" ;;
  it18) LABEL="IT-18 Filtres" ;;
  it19) LABEL="IT-19 Tarifs au poids" ;;
  it20) LABEL="IT-20 Créneaux" ;;
  it21) LABEL="IT-21 SEO" ;;
  it22) LABEL="IT-22 Mentions légales et CGV" ;;
  itw)  LABEL="IT-W Produit star" ;;
  itx)  LABEL="IT-X Anti-spam" ;;
  itz)  LABEL="IT-Z Traductions" ;;
  main) LABEL="Dernière version (correctifs)" ;;
  bdd)  LABEL="Base de données et médias Dev → Prod (US-1.4)" ;;
  *) die "Étape inconnue. Usage : bash prod-step.sh it1 … it22 | itw | itx | itz | main | bdd" ;;
esac
COMMIT="IT-$(echo "${STEP#it}" | tr a-z A-Z)"; [[ "$STEP" == main || "$STEP" == bdd ]] && COMMIT=main

# --- Connexion (réglages mémorisés après le 1er lancement) -------------
CONF="$HERE/.prod.conf"
if [[ -f "$CONF" ]]; then source "$CONF"; else
  read -rp "  Identifiant SSH mmi.unilim.fr [burlot4] : " LOGIN; LOGIN=${LOGIN:-burlot4}
  read -rp "  Dossier web distant [public_html/sae301] : " RDIR; RDIR=${RDIR:-public_html/sae301}
  read -rp "  URL publique [https://mmi.unilim.fr/~${LOGIN}/sae301] : " PROD_URL; PROD_URL=${PROD_URL:-https://mmi.unilim.fr/~${LOGIN}/sae301}
  printf 'LOGIN=%q\nRDIR=%q\nPROD_URL=%q\n' "$LOGIN" "$RDIR" "${PROD_URL%/}" > "$CONF"
fi
[[ -n "${LOGIN:-}" ]] || { rm -f "$CONF"; die "Identifiant SSH vide : relance le script."; }
command -v ddev >/dev/null || die "Lance ce script sur ton Mac (Terminal local), pas dans une session SSH sur le serveur."
PROD_URL="${PROD_URL%/}"; HOST="$LOGIN@mmi.unilim.fr"
URL_PATH="/$(printf '%s' "$PROD_URL" | sed -E 's#https?://[^/]+/?##')"; URL_PATH="${URL_PATH%/}/"
SOCK="$HOME/.ssh/cm-sae301-%r@%h"; mkdir -p "$HOME/.ssh"
say "Connexion à $HOST (mot de passe SSH demandé une fois)"
ssh -o StrictHostKeyChecking=accept-new -o ControlMaster=auto -o ControlPath="$SOCK" -o ControlPersist=20m -fN "$HOST" || die "SSH impossible (hors campus : VPN)."
[[ -n "${KEEP_SSH:-}" ]] || trap 'ssh -o ControlPath="$SOCK" -O exit "$HOST" >/dev/null 2>&1 || true' EXIT
R()  { ssh -o ControlPath="$SOCK" "$HOST" "$@"; }
UP() { rsync -az -e "ssh -o ControlPath=$SOCK" "$@"; }
WP=$(R 'command -v wp >/dev/null && echo wp || { [ -f ~/wp-cli.phar ] || curl -fsSL -o ~/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar; echo "php ~/wp-cli.phar"; }')
W()  { R "cd ~/$RDIR && $WP $*"; }
WT() { ssh -t -o ControlPath="$SOCK" "$HOST" "cd ~/$RDIR && $WP $*"; }  # avec terminal : mots de passe masqués
EVAL() { UP "$1" "$HOST:$RDIR/_step.php"; W eval-file _step.php; R "rm -f ~/$RDIR/_step.php"; }
plugins() { for p in "$@"; do W plugin is-installed "$p" 2>/dev/null || W plugin install "$p" --quiet; W plugin activate "$p" --quiet 2>/dev/null || true; done; W language plugin install --all fr_FR --quiet 2>/dev/null || true; }
ok "Connecté — WP-CLI : $WP"

# --- Code du thème au commit de l'étape --------------------------------
theme() {
  local T="$RDIR/wp-content/themes/storefront-child"
  R "test -d ~/$T/.git" || R "rm -rf ~/$T && git clone -q $CHILD_REPO ~/$T"
  R "cd ~/$T && git fetch -q origin && git reset -q --hard origin/main"
  if [[ "$COMMIT" != main ]]; then R "cd ~/$T && git checkout -q \$(git log --format=%h --grep='^\\[$COMMIT\\]' -1)"; fi
  ok "Thème enfant : $(R "cd ~/$T && git log --oneline -1")"
}

setups() { # exécute les scripts setup/*.php présents au commit déployé (relançables)
  for f in $(R "cd ~/$RDIR/wp-content/themes/storefront-child && ls setup/*.php 2>/dev/null"); do
    echo "  $f"; W eval-file "wp-content/themes/storefront-child/$f" || warn "erreur dans $f"
  done
  W rewrite flush >/dev/null
}
say "Étape $STEP — $LABEL"
case "$STEP" in
  it1)
    R "mkdir -p ~/$RDIR"
    R "test -f ~/$RDIR/wp-load.php" || W core download --locale=fr_FR
    for try in 1 2 3; do
      if R "test -f ~/$RDIR/wp-config.php" && W db check >/dev/null 2>&1; then ok "Connexion à la base OK"; break; fi
      if R "test -f ~/$RDIR/wp-config.php"; then
        warn "wp-config.php existe mais la connexion à la base échoue : on le recrée (ancien gardé en wp-config.php.bak)"
        R "mv -f ~/$RDIR/wp-config.php ~/$RDIR/wp-config.php.bak"
      fi
      read -rp "  Nom de la base MySQL [$LOGIN] : " DBN; DBN=${DBN:-$LOGIN}
      read -rp "  Utilisateur MySQL [$LOGIN] : " DBU; DBU=${DBU:-$LOGIN}
      read -rp "  Serveur MySQL [localhost] : " DBH; DBH=${DBH:-localhost}
      echo "  Mot de passe MySQL (tape-le, rien ne s'affiche) :"
      WT config create --dbname="$DBN" --dbuser="$DBU" --prompt=dbpass --dbhost="$DBH" --dbprefix="$PREFIX" --locale=fr_FR --force || true
      if R "test -f ~/$RDIR/wp-config.php" && ! W db check >/dev/null 2>&1; then
        warn "Base « $DBN » introuvable ou inaccessible : tentative de création"
        W db create && ok "Base « $DBN » créée" || warn "Création refusée (droits MySQL) : crée-la dans phpMyAdmin puis relance."
      fi
      [[ $try == 3 ]] && die "Connexion impossible : vérifie le nom de la base, l'utilisateur et le serveur MySQL (mail de l'IUT ou phpMyAdmin)."
    done
    if ! W core is-installed 2>/dev/null; then
      read -rp "  E-mail admin : " AMAIL
      WT core install --url="$PROD_URL" --title="Amorino" --admin_user=quentin --admin_email="$AMAIL" --prompt=admin_password --skip-email
    fi
    W theme install storefront --activate --quiet 2>/dev/null || W theme activate storefront
    plugins woocommerce secure-custom-fields classic-editor
    W option update woocommerce_coming_soon no >/dev/null 2>&1 || true
    theme; W theme activate storefront-child
    W rewrite structure "/%postname%/" --hard >/dev/null 2>&1 || W rewrite structure "/%postname%/"
    R "printf '%s\n' '# BEGIN WordPress' '<IfModule mod_rewrite.c>' 'RewriteEngine On' 'RewriteBase $URL_PATH' 'RewriteRule ^index\.php$ - [L]' 'RewriteCond %{REQUEST_FILENAME} !-f' 'RewriteCond %{REQUEST_FILENAME} !-d' 'RewriteRule . ${URL_PATH}index.php [L]' '</IfModule>' '# END WordPress' > ~/$RDIR/.htaccess"
    ;;
  it2)
    theme
    say "Photos et catalogue"
    UP "$SITE/wp-content/uploads/2026/" "$HOST:$RDIR/wp-content/uploads/2026/"
    (cd "$SITE" && cp "$HERE/prod/seed-export.php" . && ddev wp eval-file seed-export.php > "$HERE/prod/seed.json" && rm seed-export.php)
    UP "$HERE/prod/seed.json" "$HOST:$RDIR/seed.json"
    UP "$HERE/prod/seed-import.php" "$HOST:$RDIR/_step.php"; W eval-file _step.php; R "rm -f ~/$RDIR/_step.php ~/$RDIR/seed.json"
    setups
    ;;
  main)
    theme; setups
    W plugin deactivate custom-post-type-ui --quiet 2>/dev/null || true
    W plugin delete custom-post-type-ui --quiet 2>/dev/null || true
    UP "$HERE/prod/htaccess-cache.txt" "$HOST:$RDIR/_cache.txt"
    R "cd ~/$RDIR && sed -i '/# BEGIN Amorino cache/,/# END Amorino cache/d' .htaccess && cat _cache.txt >> .htaccess && rm -f _cache.txt"
    ;;
  bdd)
    theme
    LOCAL_URL=$(cd "$SITE" && ddev wp option get home 2>/dev/null | tr -d '\r' | grep -Eo 'https?://[^[:space:]]+' | head -1)
    LOCAL_URL="${LOCAL_URL:-https://sae301.ddev.site}"; LOCAL_URL="${LOCAL_URL%/}"
    ok "URL Dev : $LOCAL_URL → URL Prod : $PROD_URL"
    DUMP="$HERE/.dump-dev.sql"
    say "Export de la base Dev ($LOCAL_URL)"
    (cd "$SITE" && ddev export-db --gzip=false --file="$DUMP") || die "Export DDEV impossible"
    say "Extensions, langues et médias Dev → Prod"
    UP "$SITE/wp-content/plugins/" "$HOST:$RDIR/wp-content/plugins/"
    UP "$SITE/wp-content/languages/" "$HOST:$RDIR/wp-content/languages/" 2>/dev/null || true
    UP "$SITE/wp-content/uploads/" "$HOST:$RDIR/wp-content/uploads/"
    say "Sauvegarde Prod puis import"
    W db export ~/sae301-prod-avant-import.sql --quiet && ok "Sauvegarde : ~/sae301-prod-avant-import.sql (sur le serveur)"
    UP "$DUMP" "$HOST:$RDIR/_dump.sql"; rm -f "$DUMP"
    W db import _dump.sql; R "rm -f ~/$RDIR/_dump.sql"
    W search-replace "'$LOCAL_URL'" "'$PROD_URL'" --all-tables-with-prefix --skip-columns=guid --precise --report-changed-only
    W search-replace "'${LOCAL_URL#https:}'" "'${PROD_URL#https:}'" --all-tables-with-prefix --skip-columns=guid --precise --report-changed-only
    [[ "$(W option get home | tr -d '\r')" == "$PROD_URL" ]] || die "home n'est pas $PROD_URL après search-replace" 
    W rewrite structure "/%postname%/" >/dev/null; W rewrite flush >/dev/null
    warn "Les comptes de la Prod sont maintenant ceux de la Dev (même identifiant et mot de passe admin qu'en local)."
    ;;
  it17) theme; plugins woocommerce-pdf-invoices-packing-slips; setups ;;
  itz)  theme; setups; W language core install fr_FR --activate --quiet 2>/dev/null || true; W language plugin install --all fr_FR --quiet 2>/dev/null || true ;;
  *)    theme; setups ;;
esac
W cache flush >/dev/null 2>&1 || true

# --- Vérifications + journal -------------------------------------------
say "Vérifications"
CHECKS=""
for p in / /boutique/ /wp-login.php /product/cornet-fleur/ /panier/ /equipe/; do
  c=$(curl -s -o /dev/null -w '%{http_code}' -L "$PROD_URL$p" || echo 000)
  [[ "$c" == 200 ]] && ok "$p $c" || warn "$p $c"
  CHECKS="$CHECKS $p $c ·"
done
HASH=$(R "cd ~/$RDIR/wp-content/themes/storefront-child && git log --format='%h %s' -1")
[[ -n "${AUTO:-}" ]] || read -rp "  Remarque pour le journal (Entrée = aucune) : " NOTE
grep -q "## Journal Prod — étapes" "$HERE/JOURNAL.md" || printf '\n## Journal Prod — étapes\n\n| Date | Étape | Commit déployé | Code | Extensions actives | BDD | Vérifications | Remarques |\n|---|---|---|---|---|---|---|---|\n' >> "$HERE/JOURNAL.md"
printf '| %s | %s | `%s` | git checkout | %s | contenus de l’itération (script) | %s | %s |\n' \
  "$(date +%d/%m/%Y)" "$(echo "$STEP" | tr a-z A-Z)" "$HASH" "$(W plugin list --status=active --field=name | tr '\n' ' ')" "${CHECKS% ·}" "${NOTE:-RAS}" >> "$HERE/JOURNAL.md"
ok "Ligne ajoutée à JOURNAL.md"
echo "  Site : $PROD_URL"
