#!/usr/bin/env bash
# =====================================================================
#  SAé 3.01 — Itération 1 (US-1.1 à 1.3) — environnement de Dev DDEV
#  Usage :  bash "it1-dev.sh"      (depuis le dossier "sae 3.01")
# =====================================================================
set -euo pipefail

PROJECT="sae301"
PREFIX="r3sae01_"
HERE="$(cd "$(dirname "$0")" && pwd)"
SITE="$HERE/site"
URL="https://${PROJECT}.ddev.site"

say()  { printf "\n\033[1;35m▶ %s\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
die()  { printf "\033[1;31m✖ %s\033[0m\n" "$*"; exit 1; }

# --- 0. Prérequis -----------------------------------------------------
say "Vérification des prérequis"
command -v ddev   >/dev/null || die "DDEV introuvable. Installe-le : brew install ddev/ddev/ddev"
command -v docker >/dev/null || die "Docker introuvable. Lance OrbStack (ou Docker Desktop) puis réessaie."
docker info >/dev/null 2>&1  || die "Docker ne répond pas. Ouvre OrbStack et attends qu'il soit démarré."
command -v git    >/dev/null || die "git introuvable. Lance : xcode-select --install"
ok "ddev $(ddev version -j 2>/dev/null | grep -o '"DDEV version":"[^"]*"' | cut -d'"' -f4 || echo '?') · docker OK · git OK"

# --- 1. Identifiants admin (saisis par toi, jamais stockés) ------------
say "Compte administrateur WordPress (US-1.1)"
read -rp "  Identifiant admin (pas 'admin') : " ADMIN_USER
[[ -z "$ADMIN_USER" || "$ADMIN_USER" == "admin" ]] && die "Choisis un identifiant différent de 'admin'."
read -rp "  E-mail admin : " ADMIN_MAIL
while true; do
  read -rsp "  Mot de passe admin (12 caractères min.) : " ADMIN_PASS; echo
  [[ ${#ADMIN_PASS} -ge 12 ]] || { echo "  → trop court"; continue; }
  read -rsp "  Confirme le mot de passe : " ADMIN_PASS2; echo
  [[ "$ADMIN_PASS" == "$ADMIN_PASS2" ]] && break || echo "  → différents, recommence"
done

# --- 2. Projet DDEV + WordPress (US-1.1) -------------------------------
say "Création du projet DDEV « $PROJECT »"
mkdir -p "$SITE"
cd "$SITE"
if [[ ! -f .ddev/config.yaml ]]; then
  ddev config --project-type=wordpress --project-name="$PROJECT" --docroot="" --php-version=8.3
fi
ddev start

if [[ ! -f wp-load.php ]]; then
  say "Téléchargement de WordPress (FR)"
  ddev wp core download --locale=fr_FR
fi

say "Préfixe de tables : $PREFIX"
[[ -f wp-config.php ]] || ddev restart   # DDEV génère wp-config.php s'il manque
sed -i '' -e '/#ddev-generated/d' -e '/ddev manages this file/d' wp-config.php
if grep -q '^\$table_prefix' wp-config.php; then
  sed -i '' "s/^\$table_prefix.*/\$table_prefix = '${PREFIX}';/" wp-config.php
else
  sed -i '' "/That's all, stop editing/i\\
\$table_prefix = '${PREFIX}';\\
" wp-config.php
fi
grep -q "table_prefix = '${PREFIX}'" wp-config.php || die "Préfixe non appliqué dans wp-config.php"
ok "wp-config.php : \$table_prefix = '${PREFIX}'"

if ! ddev wp core is-installed >/dev/null 2>&1; then
  say "Installation de WordPress"
  ddev wp core install --url="$URL" --title="Amorino — Click & Collect" \
    --admin_user="$ADMIN_USER" --admin_password="$ADMIN_PASS" --admin_email="$ADMIN_MAIL" --skip-email
fi
unset ADMIN_PASS ADMIN_PASS2
ddev wp rewrite structure '/%postname%/' >/dev/null 2>&1   # DDEV = nginx : pas de .htaccess en local
ddev wp option update timezone_string 'Europe/Paris' >/dev/null

ALL=$(ddev wp db tables --all-tables --format=csv 2>/dev/null | tr ',' '\n' | tr -d '\r' | sed '/^[[:space:]]*$/d')
BAD=$(printf '%s\n' "$ALL" | grep -v "^${PREFIX}" || true)
if [[ -z "$BAD" ]]; then
  ok "Toutes les tables ($(printf '%s\n' "$ALL" | wc -l | tr -d ' ')) commencent par ${PREFIX}"
else
  die "Tables sans le préfixe ${PREFIX} : $(echo $BAD)"
fi

# --- 3. Plugins + thème (US-1.2) ---------------------------------------
say "Plugins : WooCommerce, Secure Custom Fields, Classic Editor"
ddev wp plugin install woocommerce secure-custom-fields classic-editor --activate
ddev wp plugin delete hello akismet >/dev/null 2>&1 || true

say "Thème Storefront"
ddev wp theme install storefront

say "Traductions françaises"
ddev wp language plugin install --all fr_FR >/dev/null 2>&1 || true
ddev wp language theme  install --all fr_FR >/dev/null 2>&1 || true

say "Réglages WooCommerce de base (France, EUR, pages boutique)"
ddev wp option update woocommerce_default_country 'FR' >/dev/null
ddev wp option update woocommerce_currency 'EUR' >/dev/null
ddev wp option update woocommerce_currency_pos 'right_space' >/dev/null
ddev wp option update woocommerce_price_thousand_sep ' ' >/dev/null
ddev wp option update woocommerce_price_decimal_sep ',' >/dev/null
ddev wp wc tool run install_pages --user="$ADMIN_USER" >/dev/null 2>&1 || true

# --- 4. Thème enfant + Git (US-1.3) ------------------------------------
CHILD="$SITE/wp-content/themes/storefront-child"
say "Thème enfant storefront-child"
mkdir -p "$CHILD"
if [[ ! -f "$CHILD/style.css" ]]; then
cat > "$CHILD/style.css" <<'CSS'
/*
Theme Name:   Storefront Child — Amorino Click & Collect
Theme URI:    https://github.com/
Description:  Thème enfant de Storefront — SAé 3.01, BUT MMI, IUT du Limousin.
Author:       Quentin Burlot
Template:     storefront
Version:      1.0.0
Text Domain:  storefront-child
*/
CSS
fi
if [[ ! -f "$CHILD/functions.php" ]]; then
cat > "$CHILD/functions.php" <<'PHP'
<?php
/**
 * Storefront Child — fonctions du thème.
 * Storefront charge automatiquement le style.css du thème enfant
 * (handle « storefront-child-style ») : aucun enqueue nécessaire ici.
 */

defined( 'ABSPATH' ) || exit;
PHP
fi
cat > "$CHILD/.gitignore" <<'GI'
.DS_Store
node_modules/
*.sql
*.sql.gz
*.log
GI
[[ -f "$CHILD/README.md" ]] || printf "# Storefront Child — Amorino Click & Collect\n\nThème enfant de Storefront (SAé 3.01, BUT MMI).\n" > "$CHILD/README.md"
ddev wp theme activate storefront-child
ok "Thème enfant actif"

say "Dépôt Git du thème enfant"
cd "$CHILD"
[[ -d .git ]] || git init -b main >/dev/null
if [[ -z "$(git config user.name || true)" ]]; then
  read -rp "  Ton nom pour Git : " GN;   git config user.name "$GN"
fi
if [[ -z "$(git config user.email || true)" ]]; then
  read -rp "  Ton e-mail GitHub : " GE;  git config user.email "$GE"
fi
git add -A
if ! git rev-parse HEAD >/dev/null 2>&1; then
  git commit -q -F - <<'MSG'
[IT-1] Création du thème enfant Storefront

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_015oHN3XKJUUzJPxpit4MBYA
MSG
fi
ok "Commit : $(git log --oneline -1)"

if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  if ! git remote get-url origin >/dev/null 2>&1; then
    say "Création du dépôt GitHub storefront-child"
    gh repo create storefront-child --public --source=. --push
  else
    git push -u origin main
  fi
else
  cat <<TXT

  ➜ GitHub : crée un dépôt PUBLIC vide nommé « storefront-child » sur github.com
    (sans README), puis lance dans ce dossier :
      cd "$CHILD"
      git remote add origin https://github.com/<ton-user>/storefront-child.git
      git push -u origin main
TXT
fi

# --- 5. Export pour la Prod (US-1.4) -----------------------------------
say "Export de la base pour la mise en production"
cd "$SITE"
ddev export-db --gzip=false --file="$HERE/deploy-db.sql" >/dev/null
ok "Base exportée : $HERE/deploy-db.sql (ne jamais la mettre sur GitHub)"

say "Terminé"
cat <<TXT
  Site      : $URL
  Admin     : $URL/wp-admin   (identifiant : $ADMIN_USER)
  Thème     : $CHILD
  Prochaine étape : mise en production avec it1-prod.sh
TXT
ddev launch >/dev/null 2>&1 || true
