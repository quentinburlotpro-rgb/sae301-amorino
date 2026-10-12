# Amorino — Click & Collect · Dossier de conception (Semaine 1)

SAé 3.01 — BUT2 MMI, IUT du Limousin. Projet pédagogique, site non officiel.

Contenu du dépôt :
- `index.html` + `style.css` : page **Design System** statique (HTML/CSS natif, sans framework), publiée sur GitHub Pages : https://quentinburlotpro-rgb.github.io/sae301-amorino/
- `README.md` : analyse d'identité, benchmark, conception UX et spécifications Figma.
- `DEPLOIEMENT.md` : procédure de mise à jour Dev → Prod.
- `JOURNAL.md` : journal des mises en production.
- `it1-dev.sh`, `it1-prod.sh` : scripts de l'itération 1 (environnement DDEV, déploiement mmi.unilim.fr).

Le thème enfant WordPress est dans un dépôt séparé, cloné en Prod dans `wp-content/themes/` :
https://github.com/quentinburlotpro-rgb/storefront-child

> Légende de fiabilité : ✅ établi (source) · 🟡 à vérifier · ✏️ choix de conception.

---

## 1. Analyse de l'identité visuelle

| Élément | Constat | Statut |
|---|---|---|
| Promesse | Glace italienne artisanale en forme de rose, choix de parfums illimité (méta-description amorino.com) | ✅ |
| Signature produit | Glace sculptée en pétales à la spatule, servie en pot, cornet ou brioche (« focaccina ») | ✅ |
| Gamme élargie | Boissons chaudes, chocolats, biscuits, gaufres, crêpes | ✅ |
| Univers | Gourmand et lumineux : grandes photos de texture (glace, chocolat coulant), fonds blancs et rosés, titres en capitales serif, accents manuscrits | ✅ observé sur amorino.com |
| Logo | Angelot + logotype « Amorino Gelato al naturale », noir #100B0C. Fichiers `logo.svg` / `logo-light.svg` (fichier officiel fourni) | ✅ |
| Couleurs | Noir #100B0C, blanc #FFFFFF, pêche #E9BC96 (CTA), rosé #FDE8DC, gris #383838, gris clair #F9F9F9 | ✅ relevé (styles calculés) |
| Boutons | Pilule (rayon 30px), capitales, 14px, fond noir ou pêche | ✅ relevé |
| Typographies | Titres **Silver South Serif**, texte **Avenir Next LT Pro** 400/500 (commerciales). Substituts libres : Cormorant Garamond + Nunito Sans | ✅ / ✏️ substituts |
| Ton | Chaleureux, italien, sensoriel (noms de parfums en italien, « Gelato al naturale ») | ✏️ à appliquer aux microcopies |

Relevé fait le 12/10/2026 sur amorino.com (styles calculés de la page d'accueil). Reste à faire : récupérer 10 photos produits officielles pour les visuels.

---

## 2. Benchmark

Objectif : repérer les patterns éprouvés de commande + personnalisation + retrait. À illustrer par captures (Mobbin, Page Flows) dans Figma.

| Référence | À reprendre | À éviter |
|---|---|---|
| Apps de livraison (Uber Eats, Deliveroo) | Fiche produit en « modale de personnalisation » : groupes d'options obligatoires/facultatifs, prix mis à jour en direct, CTA sticky avec le total | Densité visuelle, upsell agressif |
| Fast-food à borne (McDonald's, Burger King) | Parcours linéaire court, gros visuels, récap final avant paiement | Esthétique « fast-food » incompatible avec le positionnement |
| Coffee shops avec click & collect (Starbucks, Columbus Café) | Choix boutique + créneau de retrait, statut « commande prête » | Obligation de créer un compte pour commander |
| Concurrents glaciers (Häagen-Dazs, Ben & Jerry's) | Mise en scène des parfums, filtres régimes (végan, sans lactose) | Sites vitrines sans commande |

**Positionnement retenu** ✏️ : *l'élégance d'une marque premium avec l'efficacité d'une borne de commande*. Différenciateur : un **composeur de glace** (format → taille → parfums → suppléments) qui reproduit le geste en boutique.

---

## 3. Conception UX

### Personas

**Léa, 21 ans, étudiante** — Commande sur mobile en sortant de cours, veut éviter la file le samedi. Besoins : rapidité, prix visibles, paiement au retrait. Frein : créer un compte.

**Marc, 38 ans, parent** — Commande 4 glaces pour la famille avant d'arriver en centre-ville. Besoins : panier multi-produits clair, allergènes, créneau précis. Frein : se tromper de parfum pour un enfant allergique.

### Parcours clés

1. **Commande retrait (principal)** : Accueil → Carte (filtre catégorie) → Fiche produit (composer) → Ajout panier (alerte succès) → Panier → Retrait en boutique + créneau → Coordonnées + instructions de retrait → Paiement au retrait → Confirmation + e-mail.
2. **Personnalisation** : Format (obligatoire) → Taille (obligatoire) → Parfums (multi, ≥ 1) → Suppléments (facultatif) → Quantité → Ajouter (prix total dans le bouton).
3. **Compte client** : Inscription simple (e-mail + mot de passe) → Historique des commandes → Statut → Facture.

### Catalogue (minimum : 3 × 3 + options)

Prix = 🟡 indicatifs, à aligner sur une carte en boutique.

| Catégorie | Produit | Type WooCommerce | Options |
|---|---|---|---|
| Glaces | Cornet fleur | Variable | Taille (petit/moyen/grand), parfums, macaron |
| Glaces | Pot (coppetta) | Variable | Taille, parfums, chantilly |
| Glaces | Brioche glacée (focaccina) | Variable | Parfums, nappage |
| Gaufres & crêpes | Gaufre | Variable | Nappage, boule de glace en plus |
| Gaufres & crêpes | Crêpe | Variable | Garniture (sucre, chocolat, caramel…) |
| Gaufres & crêpes | Gaufre gelato | Variable | Parfum de la boule, chantilly |
| Boissons | Chocolat chaud | Variable | Taille, lait (vache/avoine), chantilly |
| Boissons | Café / cappuccino | Variable | Taille, lait, sucre |
| Boissons | Smoothie | Variable | Taille, fruits |

Itération 2 : créer d'abord les 9 en **produits simples**, puis les passer en variables à l'itération 3.

---

## 4. Spécifications Figma

### Structure du fichier `SAE312 2026`
Pages : `Changelog` · `Design System` · `Wireframes` · `Maquettes Desktop` · `Maquettes Mobile` · `Prototype`. Dupliquer le fichier à chaque version (v1.0, v1.1…).

### Variables (identiques aux tokens CSS)
- **Couleurs** : `noir` #100B0C, `noir/700`, `gris` #383838, `gris/500`, `peche` #E9BC96, `peche/300`, `rose` #FDE8DC, `gris/50` #F9F9F9, `blanc`, `bordure`, `accent/pistache framboise mangue`, `semantic/success warning danger info`, puis alias de rôle `bg`, `surface`, `text`, `text-muted`, `border`, `primary`.
- **Espacements** : `space/1…8` = 4, 8, 12, 16, 24, 32, 48, 64.
- **Rayons** : `radius/sm 6`, `md 14`, `lg 24`, `pill 30`.
- **Typo (styles)** : H1 64 caps, H2 40 caps, H3 28, H4 20 (Silver South Serif → Cormorant) ; Body 16/400, Small 14/400, Caption 12/500 caps (Avenir Next → Nunito Sans).

### Composants & variants (Auto Layout partout)
| Composant | Variants | Classe CSS |
|---|---|---|
| Button | type = primary/secondary/peche/ghost/icon · size = md/sm · state = default/hover/disabled | `.btn` |
| Badge | new/promo/star/vegan/gf/stock-ok/low/out | `.badge` |
| Chip | selected = true/false | `.chip` |
| Product card | default/promo/out-of-stock | `.product-card` |
| Option tile | default/selected/disabled | `.option-tile` |
| Option row | checked = true/false · extra price on/off | `.option-row` |
| Input | default/focus/error · with hint | `.input` |
| Qty stepper | — | `.qty` |
| Alert | success/info/warning/danger | `.alert` |
| Cart line, Summary, Shipping option, Slot, Pickup box | states selected/disabled | voir DS |
| Header (desktop/mobile), Tab bar, Breadcrumb, Steps, Footer | — | voir DS |

### Écrans à maquetter (desktop 1440 + mobile 390)
Accueil (3 derniers produits, produit star) · Boutique (grille + filtres) · Fiche produit simple · Fiche produit variable (composeur) · Panier · Checkout (retrait + instructions) · Confirmation · Compte (connexion, tableau de bord, commandes) · Équipe (liste + profil) · E-mail transactionnel.

---

## 5. Mise en ligne de la page Design System (GitHub Pages)

Dépôt : https://github.com/quentinburlotpro-rgb/sae301-amorino — Settings › Pages › Branch `main` / `(root)`.
Page publiée : https://quentinburlotpro-rgb.github.io/sae301-amorino/ (lien à reporter dans le PDF de rendu).
