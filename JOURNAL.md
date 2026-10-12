# Journal des mises en production

SAé 3.01 — Amorino Click & Collect · Prod : https://mmi.unilim.fr/~[login]/sae301

| Date | Itération | Commit déployé | Code | Plugins | BDD | Vérifications | Anomalies / remarques |
|---|---|---|---|---|---|---|---|
| 12/10/2026 | IT-1 | `[hash]` [IT-1] Création du thème enfant Storefront | thème enfant (git clone) | WooCommerce, Secure Custom Fields, Classic Editor + Storefront | import complet + search-replace | accueil [code HTTP], wp-login [code], /boutique/ [code], connexion admin OK | [à compléter] |
| | | | | | | | |

**Légende**
- Code : comment le thème enfant a été mis à jour (git pull / clone).
- BDD : « import complet » (écrase la Prod), « aucune », ou « manuel en Prod ».
- Vérifications : pages ouvertes et codes HTTP renvoyés (200 attendu), connexion admin.
