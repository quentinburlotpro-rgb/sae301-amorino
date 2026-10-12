#!/usr/bin/env bash
# =====================================================================
#  SAé 3.01 — Itération 1 (US-1.4) — mise en production sur mmi.unilim.fr
#  Usage :  bash it1-prod.sh          (depuis le dossier "sae 3.01")
#  Ton mot de passe SSH n'est demandé qu'une fois (connexion partagée).
# =====================================================================
set -euo pipefail

PREFIX="r3sae01_"
DEV_URL="https://sae301.ddev.site"
HERE="$(cd "$(dirname "$0")" && pwd)"
SITE="$HERE/site"
DUMP="$HERE/deploy-db.sql"
CHILD_REPO="https://github.com/quentinburlotpro-rgb/storefront-child.git"

say()  { printf "\n\033[1;35m▶ %s\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m! %s\033[0m\n" "$*"; }
die()  { printf "\033[1;31m✖ %s\033[0m\n" "$*"; exit 1; }

[[ -d "$SITE/wp-content" ]] || die "Dossier site/ introuvable : lance d'abord it1-dev.sh"

# --- 0. Paramètres ----------------------------------------------------
say "Paramètres du serveur"
read -rp "  Identifiant SSH mmi.unilim.fr : " LOGIN
[[ -n "$LOGIN" ]] || die "Identifiant vide"
read -rp "  Serveur SSH [mmi.unilim.fr] : " SRV;          SRV=${SRV:-mmi.unilim.fr}
read -rp "  Dossier web distant [public_html/sae301] : " RDIR; RDIR=${RDIR:-public_html/sae301}
DEF_URL="https://mmi.unilim.fr/~${LOGIN}/sae301"
read -rp "  URL publique [$DEF_URL] : " PROD_URL;          PROD_URL=${PROD_URL:-$DEF_URL}
PROD_URL="${PROD_URL%/}"
URL_PATH="/$(printf '%s' "$PROD_URL" | sed -E 's#https?://[^/]+/?##')"; URL_PATH="${URL_PATH%/}/"
HOST="${LOGIN}@${SRV}"

# --- 1. Connexion SSH partagée ----------------------------------------
say "Connexion SSH à $HOST (mot de passe demandé une seule fois)"
SOCK="$HOME/.ssh/cm-sae301-%r@%h"
mkdir -p "$HOME/.ssh"
ssh -o StrictHostKeyChecking=accept-new -o ControlMaster=yes -o ControlPath="$SOCK" -o ControlPersist=20m -fN "$HOST" \
  || die "Connexion SSH impossible : vérifie identifiant / mot de passe (hors campus : VPN FortiClient)."
trap 'ssh -o ControlPath="$SOCK" -O exit "$HOST" >/dev/null 2>&1 || true' EXIT
R()     { ssh -o ControlPath="$SOCK" "$HOST" "$@"; }
RSYNC() { rsync -az --delete -e "ssh -o ControlPath=$SOCK" "$@"; }
ok "Connecté"

# --- 2. WP-CLI côté serveur -------------------------------------------
say "WP-CLI sur le serveur"
WP=$(R 'if command -v wp >/dev/null; then echo wp;
        elif [ -f ~/wp-cli.phar ]; then echo "php ~/wp-cli.phar";
        else curl -fsSL -o ~/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar 2>/dev/null && echo "php ~/wp-cli.phar" || echo NONE; fi')
[[ "$WP" == "NONE" ]] && die "WP-CLI indisponible sur le serveur (pas d'accès Internet ?). Dis-le à Claude : on passera par phpMyAdmin."
R "$WP --version" >/dev/null || die "WP-CLI ne démarre pas sur le serveur"
ok "WP-CLI : $(R "$WP --version")"
W() { R "cd ~/$RDIR && $WP $*"; }

# --- 3. Fichiers WordPress --------------------------------------------
say "Installation des fichiers WordPress dans ~/$RDIR"
R "mkdir -p ~/$RDIR"
if ! R "test -f ~/$RDIR/wp-load.php"; then
  W core download --locale=fr_FR
fi
ok "WordPress présent"

# --- 4. wp-config.php (configuration MANUELLE, exigée par le sujet) ---
if ! R "test -f ~/$RDIR/wp-config.php"; then
  say "Préparation de wp-config.php"
  R "cd ~/$RDIR && cp wp-config-sample.php wp-config.php \
     && sed -i \"s/^\\\$table_prefix.*/\\\$table_prefix = '${PREFIX}';/\" wp-config.php \
     && chmod 640 wp-config.php"
  W config shuffle-salts >/dev/null 2>&1 || warn "Salts : génère-les sur https://api.wordpress.org/secret-key/1.1/salt/"
fi
TRY=0
until W db check >/dev/null 2>&1; do
  TRY=$((TRY+1)); [[ $TRY -gt 3 ]] && die "Connexion BDD toujours refusée : vérifie tes identifiants BDD auprès de l'IUT."
  cat <<TXT

  ➜ À TOI : dans wp-config.php, remplace les valeurs d'exemple
    ('votre_nom_de_bdd', 'votre_utilisateur_de_bdd', 'votre_mdp_de_bdd', 'localhost')
    par tes identifiants de base de données mmi : DB_NAME, DB_USER, DB_PASSWORD, DB_HOST.
    Enregistrer : Ctrl+O puis Entrée · Quitter : Ctrl+X
TXT
  read -rp "  Entrée pour ouvrir l'éditeur (essai $TRY/3)… " _
  ssh -t -o ControlPath="$SOCK" "$HOST" "nano ~/$RDIR/wp-config.php"
done
R "grep -q \"table_prefix = '${PREFIX}'\" ~/$RDIR/wp-config.php" || die "Préfixe ${PREFIX} absent de wp-config.php distant"
ok "wp-config.php configuré et BDD accessible"

# --- 5. Thème parent, plugins, langues --------------------------------
say "Envoi de Storefront, des plugins et des traductions"
R "mkdir -p ~/$RDIR/wp-content/themes ~/$RDIR/wp-content/plugins ~/$RDIR/wp-content/languages"
RSYNC "$SITE/wp-content/themes/storefront/" "$HOST:$RDIR/wp-content/themes/storefront/"
for p in woocommerce secure-custom-fields classic-editor; do
  RSYNC "$SITE/wp-content/plugins/$p/" "$HOST:$RDIR/wp-content/plugins/$p/"
done
[[ -d "$SITE/wp-content/languages" ]] && RSYNC "$SITE/wp-content/languages/" "$HOST:$RDIR/wp-content/languages/"
ok "Fichiers synchronisés"

# --- 6. Thème enfant depuis GitHub ------------------------------------
say "Thème enfant depuis GitHub"
if R "test -d ~/$RDIR/wp-content/themes/storefront-child/.git"; then
  R "cd ~/$RDIR/wp-content/themes/storefront-child && git pull --ff-only"
elif R "command -v git >/dev/null"; then
  R "cd ~/$RDIR/wp-content/themes && rm -rf storefront-child && git clone $CHILD_REPO storefront-child"
else
  warn "git absent du serveur : envoi du thème enfant par rsync"
  RSYNC --exclude .git "$SITE/wp-content/themes/storefront-child/" "$HOST:$RDIR/wp-content/themes/storefront-child/"
fi
ok "Thème enfant : $(R "cd ~/$RDIR/wp-content/themes/storefront-child && git log --oneline -1 2>/dev/null || echo 'copie rsync'")"

# --- 7. Base de données -----------------------------------------------
say "Export de la BDD de Dev"
( cd "$SITE" && ddev export-db --gzip=false --file="$DUMP" >/dev/null )
say "Import en Prod (écrase les tables ${PREFIX}* distantes)"
read -rp "  Confirmer l'import ? [o/N] " C; [[ "$C" =~ ^[oOyY]$ ]] || die "Import annulé"
rsync -az -e "ssh -o ControlPath=$SOCK" "$DUMP" "$HOST:sae301-deploy.sql"
W db import ~/sae301-deploy.sql
R "rm -f ~/sae301-deploy.sql"
ok "BDD importée"

say "Remplacement des URL : $DEV_URL → $PROD_URL"
W search-replace "'$DEV_URL'" "'$PROD_URL'" --all-tables-with-prefix --skip-columns=guid --report-changed-only
W search-replace "'http://sae301.ddev.site'" "'$PROD_URL'" --all-tables-with-prefix --skip-columns=guid --report-changed-only
W option get home

# --- 8. Permaliens + .htaccess ----------------------------------------
say "Permaliens et .htaccess (RewriteBase $URL_PATH)"
R "cat > ~/$RDIR/.htaccess" <<HT
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase $URL_PATH
RewriteRule ^index\.php\$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . ${URL_PATH}index.php [L]
</IfModule>
# END WordPress
HT
W rewrite structure "'/%postname%/'" >/dev/null 2>&1 || true
W cache flush >/dev/null 2>&1 || true
W theme list --status=active --fields=name --format=csv
W plugin list --status=active --fields=name --format=csv

# --- 9. Vérification (US-1.5) -----------------------------------------
say "Vérification HTTP"
for path in "" "/wp-login.php" "/boutique/"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -L "$PROD_URL$path" || echo 000)
  printf "  %-14s %s\n" "${path:-/}" "$code"
done

say "Mise en production terminée"
echo "  Site  : $PROD_URL"
echo "  Admin : $PROD_URL/wp-admin  (mêmes identifiants qu'en Dev)"
echo "  Commit déployé : $(cd "$SITE/wp-content/themes/storefront-child" && git log --oneline -1)"
echo "  Date  : $(date '+%d/%m/%Y %H:%M')"
