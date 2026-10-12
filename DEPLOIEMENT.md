# Procédure de mise à jour Dev → Prod

SAé 3.01 — Amorino Click & Collect · Quentin Burlot · BUT2 MMI

| | Dev | Prod |
|---|---|---|
| Où | Mac, conteneur DDEV `sae301` | Serveur mmi.unilim.fr |
| URL | https://sae301.ddev.site | https://mmi.unilim.fr/~[login]/sae301 |
| Dossier | `~/Desktop/sae 3.01/site` | `~/public_html/sae301` |
| Préfixe BDD | `r3sae01_` | `r3sae01_` |
| Thème actif | `storefront-child` (parent : Storefront) | idem |
| Dépôt du thème | https://github.com/quentinburlotpro-rgb/storefront-child | cloné dans `wp-content/themes/storefront-child` |

## Règle d'or

**Le code passe par GitHub, les plugins par rsync, la base par export/import.**
À partir de l'itération 5 (commandes clients en Prod), **ne plus écraser la BDD de Prod** : refaire les réglages directement en Prod, ou n'importer que des tables précises.

## Cas 1 — Modification du thème enfant (le plus fréquent)

En Dev :
```bash
cd ~/Desktop/"sae 3.01"/site/wp-content/themes/storefront-child
git add -A
git commit -m "[IT-X] description de la modification"
git push
```
En Prod :
```bash
ssh [login]@mmi.unilim.fr
cd ~/public_html/sae301/wp-content/themes/storefront-child && git pull --ff-only
```
Vérifier la page modifiée en Prod, puis ajouter une ligne au journal.

## Cas 2 — Nouveau plugin (ou mise à jour d'un plugin)

En Dev : installer et tester (`ddev wp plugin install <slug> --activate`).
Envoi en Prod :
```bash
cd ~/Desktop/"sae 3.01"
rsync -az site/wp-content/plugins/<slug>/ [login]@mmi.unilim.fr:public_html/sae301/wp-content/plugins/<slug>/
ssh [login]@mmi.unilim.fr "cd ~/public_html/sae301 && php ~/wp-cli.phar plugin activate <slug>"
```
(remplacer `php ~/wp-cli.phar` par `wp` si WP-CLI est installé sur le serveur)

## Cas 3 — Contenu ou réglages en base (produits, pages, options WooCommerce)

Avant l'itération 5 uniquement — **écrase la base de Prod** :
```bash
bash it1-prod.sh
```
Le script exporte la BDD de Dev, l'importe en Prod puis remplace les URL avec `wp search-replace` (jamais un rechercher/remplacer dans le fichier SQL : cela casserait les données sérialisées).

Après l'itération 5 : refaire la modification à la main dans l'admin de Prod, ou exporter/importer uniquement les produits (Produits › Exporter / Importer en CSV).

## Médias (images produits)

```bash
rsync -az site/wp-content/uploads/ [login]@mmi.unilim.fr:public_html/sae301/wp-content/uploads/
```

## En cas de problème

| Symptôme | Cause probable | Correction |
|---|---|---|
| Erreur 404 sur toutes les pages sauf l'accueil | `.htaccess` absent ou mauvais `RewriteBase` | relancer l'étape 8 de `it1-prod.sh`, ou Réglages › Permaliens › Enregistrer |
| Liens qui pointent vers `sae301.ddev.site` | search-replace non fait | `wp search-replace 'https://sae301.ddev.site' '<url prod>' --all-tables-with-prefix` |
| « Erreur lors de la connexion à la base de données » | identifiants DB_* | vérifier `wp-config.php` en Prod |
| SSH refusé hors de l'IUT | réseau | activer le VPN FortiClient |
