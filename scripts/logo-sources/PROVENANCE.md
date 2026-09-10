# Provenance des logos

Les six logos de `content/media/hyperviseurs-type-1.png`, produits par
`scripts/gen_hypervisor_card.sh`. Relevé le 2026-09-10.

> **`content/media/type-1-hypervisor-examples.png` ne doit pas être supprimée.**
> Elle n'est plus affichée nulle part depuis que la nouvelle carte l'a remplacée,
> donc elle *ressemble* à un orphelin — comme les `images-output5*.png` de #540 —
> mais `gen_hypervisor_card.sh` y découpe trois des six logos. La supprimer casse
> la régénération sans rien casser à la construction, donc en silence.

## Découpés depuis une image déjà présente dans le dépôt

`content/media/type-1-hypervisor-examples.png`, l'illustration d'origine du cours.
Elle vient de `ubackup.com` — provenance non maîtrisée, c'est le reproche que lui
fait l'issue #525. Ces trois logos n'ont pas de source officielle atteignable :

| logo | découpe |
|---|---|
| VMware vSphere | `240x198+229+103` |
| Microsoft Hyper-V | `256x198+592+100` |
| XenServer | `345x172+48+305` |

Les coordonnées ne sont pas devinées : les bornes du contenu ont été relevées ligne
par ligne. La découpe de VMware s'arrête à `y=300` et non `y=295` parce que les cinq
pixels des lignes 296 à 300, à `x=301..305`, sont **la descendante du « p » de
vSphere** et non le logo voisin — vérifié sur l'étalement en x avant de couper.

## Téléchargés depuis le site du projet

| fichier | source | note |
|---|---|---|
| `xcp-ng.png` | `https://xcp-ng.org/assets/img/smalllogo.png` | 180x30, le plus grand disponible. `smalllogo@2x.png`, `@3x` et `.svg` répondent **200 avec une page HTML d'erreur** — vérifié avec `file`, pas avec le code HTTP |
| `kvm.png` | `https://www.linux-kvm.org/kvmless/kvmbanner-logo3.png` | bannière officielle du projet |
| `proxmox.png` | pack média officiel, `https://www.proxmox.com/images/proxmox/logos/proxmox-logo-pack.zip` | `Proxmox_logos_full_lockup_PNG/proxmox-full-lockup-color.png` |

## Marques

Tous ces logos sont des marques de leurs détenteurs respectifs. La charte livrée dans
le pack Proxmox indique : « The Proxmox® name and the Proxmox logo are either
registered trademarks or trademarks of Proxmox Server Solutions GmbH in the EU, the
U.S., and other countries. Third party usage is prohibited without authorized written
consent. »

Le point a été signalé à l'auteur du cours, qui a tranché en connaissance de cause :
usage pédagogique, cours libre et non commercial, illustration éditoriale des produits
nommés. Décision consignée ici pour que la question ne se repose pas à l'aveugle.
