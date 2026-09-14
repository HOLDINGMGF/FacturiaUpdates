# FacturiaUpdates

Depot public contenant uniquement les manifestes et patchs de mise a jour FACTURIA.

Le code source de FACTURIA reste dans le depot prive `HOLDINGMGF/Facturia`.

## Telechargements

Version disponible : **0.13.4**, canaux Production et Beta.

La 0.13.4 renforce les controles de types SQLite et conserve les decimaux exacts sans arrondi. Elle inclut l'assistant de diagnostic et de reparation des rattachements de societe, avec choix explicites, validation et sauvegarde chiffree. Les identifiants historiques sont conserves. Si Facturia ne demarre pas, fermer l'application puis utiliser l'EXE ci-dessous.

- [Installateur Windows autonome EXE](https://github.com/HOLDINGMGF/FacturiaUpdates/releases/latest/download/Setup-Facturia.exe) : fermer Factur.ia avant installation.
- [Release 0.13.4 et packages Windows/macOS](https://github.com/HOLDINGMGF/FacturiaUpdates/releases/tag/v0.13.4).
- Sur macOS Apple Silicon, utiliser la mise a jour integree. Le ZIP macos-arm64 est un patch destine a l'assistant de mise a jour, pas un DMG d'installation. Le package a ete compile depuis Windows ; l'execution sur un Mac reel reste a valider.

Sauvegarder la base et fermer les autres postes avant la premiere migration. La base migree exige la version 0.13.4 minimum : mettre tous les postes partageant la base a jour en 0.13.4 avant reutilisation. La version lourde reste en SQLite/SQLCipher ; les API et PostgreSQL concernent les editions demi-SaaS/SaaS.

La base conserve desormais la version minimale requise. A partir de 0.13.1, un poste trop ancien affiche une fenetre avec installation de la mise a jour avant chargement. Les anciennes versions 0.12.x/0.13.0 ne possedent pas cette fenetre : leurs ecritures dans une base protegee sont refusees, mais elles peuvent encore lire des donnees. En cas d'erreur `no such function: facturia_compatible`, installer la mise a jour avec l'EXE ci-dessus ou le mecanisme integre. Ne pas supprimer les protections de la base.

Fichiers principaux :

- `update-manifest.production.json`
- `update-manifest.beta.json`
- `update-test/facturia-patch-0.6.1-test.zip`

Les URLs de mise a jour utilisees par FACTURIA pointent vers `raw.githubusercontent.com/HOLDINGMGF/FacturiaUpdates/main/...`.
