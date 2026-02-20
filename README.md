# Arch Linux Automated Installation Script

```bash


===========================================================================================================================================================


                    ██╗    ██╗███████╗    ██╗   ██╗███████╗███████╗     █████╗ ██████╗  ██████╗██╗  ██╗
                    ██║    ██║██╔════╝    ██║   ██║██╔════╝██╔════╝    ██╔══██╗██╔══██╗██╔════╝██║  ██║
                    ██║ █╗ ██║█████╗      ██║   ██║███████╗█████╗      ███████║██████╔╝██║     ███████║
                    ██║███╗██║██╔══╝      ██║   ██║╚════██║██╔══╝      ██╔══██║██╔══██╗██║     ██╔══██║
                    ╚███╔███╔╝███████╗    ╚██████╔╝███████║███████╗    ██║  ██║██║  ██║╚██████╗██║  ██║
                     ╚══╝╚══╝ ╚══════╝     ╚═════╝ ╚══════╝╚══════╝    ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝

                                                          BTW

===========================================================================================================================================================


```

Projet de partiel – Administration Linux avancée.  
Script d’installation automatisée d’Arch Linux avec LUKS, LVM et i3.

---

## Objectif

Automatiser l’installation complète d’Arch Linux sur une machine virtuelle disposant de :

- 80G de stockage  
- 8G de RAM  
- UEFI activé  
- Single boot Arch Linux  

Le script prend en charge le partitionnement, le chiffrement, l’installation du système, la configuration des utilisateurs et des services.

---

## Architecture du disque

Structure mise en place :

- Partition EFI  
- Disque chiffré avec LUKS  
- LVM à l’intérieur du conteneur chiffré  

Volumes logiques créés :

- `root`
- `swap`
- `virtualbox`
- `shared` (5G)
- `secure` (10G minimum, chiffré séparément et monté manuellement)

---

## Configuration système

- Création de deux utilisateurs (père et fils)
- Mot de passe temporaire : `azerty123`
- Groupe dédié pour le dossier partagé
- Installation et configuration de i3
- Installation des outils nécessaires :
  - Outils système de base
  - Environnement de développement C (gcc, make, gdb)
  - VirtualBox
  - Navigateur web

---

## Lancement du script

Depuis l’environnement live Arch :

```bash
chmod +x install.sh
./install.sh
```

Le script efface entièrement le disque cible avant installation.

---

## Contenu du rendu

Le projet comprend :

- Le script d’installation
- Les fichiers de configuration modifiés ou créés
- Un fichier regroupant les sorties des commandes suivantes :

```bash
lsblk -f
cat /etc/passwd /etc/group /etc/fstab /etc/mtab
echo $HOSTNAME
grep -i installed /var/log/pacman.log
```

---

Installation automatisée, sécurisée et conforme aux exigences du sujet.
