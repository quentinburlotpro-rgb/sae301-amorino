# Procédure de mise à jour Dev → Prod

SAé 3.01 — Amorino Click & Collect · Quentin Burlot · BUT2 MMI

| | Dev | Prod |
|---|---|---|
| Où | Mac, conteneur DDEV `sae301` | Serveur mmi.unilim.fr |
| URL | https://sae301.ddev.site | https://mmi.unilim.fr/~burlot4/sae301/ |
| Dossier | `~/Desktop/sae 3.01/site` | `~/public_html/sae301` |
| Préfixe BDD | `r3sae01_` | `r3sae01_` |
| Thème actif | `storefront-child` (parent : Storefront) | idem |
| Dépôt du thème | https://github.com/quentinburlotpro-rgb/storefront-child | cloné dans `wp-content/themes/storefront-child` |

Dans les commandes, `wp` désigne WP-CLI sur le serveur (ou `php ~/wp-cli.phar` s'il n'est pas installé). Les mots de passe sont toujours tapés au clavier, jamais écrits dans un fichier.

## Règle

**Le code passe par GitHub, les extensions et les médias par rsync, la base par export / import.**
Chaque commit du thème porte l'étiquette de son itération, `[IT-X]`, ce qui permet de déployer une itération précise.

## 1. Installation initiale (US-1.4)

```bash
ssh burlot4@mmi.unilim.fr
cd ~/public_html && mkdir sae301 && cd sae301
wp core download --locale=fr_FR
wp config create --dbname=burlot4 --dbuser=burlot4 --prompt=dbpass --dbprefix=r3sae01_ --locale=fr_FR
git clone https://github.com/quentinburlotpro-rgb/storefront-child.git wp-content/themes/storefront-child
```
Depuis le Mac, téléversement de Storefront et des extensions de la Dev :
```bash
cd ~/Desktop/"sae 3.01"/site/wp-content
rsync -az themes/storefront/ burlot4@mmi.unilim.fr:public_html/sae301/wp-content/themes/storefront/
rsync -az plugins/ burlot4@mmi.unilim.fr:public_html/sae301/wp-content/plugins/
```
Puis import de la base (section 3) et permaliens `/%postname%/` avec un `.htaccess` dont le `RewriteBase` vaut `/~burlot4/sae301/`.

## 2. Modification du thème enfant (le plus fréquent)

En Dev :
```bash
cd ~/Desktop/"sae 3.01"/site/wp-content/themes/storefront-child
git add -A
git commit -m "[IT-X] description de la modification"
git push
```
En Prod :
```bash
ssh burlot4@mmi.unilim.fr
cd ~/public_html/sae301/wp-content/themes/storefront-child
git fetch origin && git reset --hard origin/main
```
Pour déployer une itération précise plutôt que la dernière version :
```bash
git checkout $(git log --format=%h --grep='^\[IT-12\]' -1)
```
Les réglages et contenus propres à une itération sont dans `setup/` du thème (scripts relançables) :
```bash
cd ~/public_html/sae301 && wp eval-file wp-content/themes/storefront-child/setup/it12-taxonomie.php && wp rewrite flush
```
Vérifier les pages modifiées, puis ajouter une ligne à [JOURNAL.md](JOURNAL.md).

## 3. Base de données et médias

**Écrase la base de Prod** : sauvegarde d'abord.
```bash
# Mac
cd ~/Desktop/"sae 3.01"/site
ddev export-db --gzip=false --file=dump.sql
rsync -az wp-content/uploads/ burlot4@mmi.unilim.fr:public_html/sae301/wp-content/uploads/
scp dump.sql burlot4@mmi.unilim.fr:public_html/sae301/ && rm dump.sql

# Serveur
cd ~/public_html/sae301
wp db export ~/sae301-prod-avant-import.sql
wp db import dump.sql && rm dump.sql
wp search-replace 'https://sae301.ddev.site' 'https://mmi.unilim.fr/~burlot4/sae301' --all-tables-with-prefix --skip-columns=guid --precise
wp search-replace '//sae301.ddev.site' '//mmi.unilim.fr/~burlot4/sae301' --all-tables-with-prefix --skip-columns=guid --precise
wp rewrite flush
```
Le changement d'adresse se fait toujours avec `wp search-replace`, jamais dans le fichier SQL (les données sérialisées seraient cassées). Le fichier SQL ne va jamais dans un dépôt GitHub.

## 4. Extension ajoutée ou mise à jour

```bash
rsync -az site/wp-content/plugins/<slug>/ burlot4@mmi.unilim.fr:public_html/sae301/wp-content/plugins/<slug>/
ssh burlot4@mmi.unilim.fr "cd ~/public_html/sae301 && wp plugin activate <slug> && wp language plugin install --all fr_FR"
```

## 5. Cache (IT-Y)

Le `.htaccess` de la Prod contient, après le bloc WordPress, un bloc « Amorino cache » : durées de cache des images, polices, CSS et JS (`mod_expires` / `mod_headers`) et compression (`mod_deflate`).

## En cas de problème

| Symptôme | Cause probable | Correction |
|---|---|---|
| 404 sur toutes les pages sauf l'accueil | `.htaccess` absent ou mauvais `RewriteBase` | Réglages › Permaliens › Enregistrer, ou recréer le `.htaccess` |
| « Page non trouvée » partout, liens vers `sae301.ddev.site` | search-replace non fait après import | relancer les deux `wp search-replace` |
| « Erreur lors de la connexion à la base de données » | identifiants `DB_*` | vérifier `wp-config.php` en Prod |
| SSH refusé hors de l'IUT | réseau | activer le VPN de l'université |
