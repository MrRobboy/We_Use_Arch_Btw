#!/bin/bash

print_banner() {
cat <<'EOF'
==============================================================================
 
██╗    ██╗███████╗    ██╗   ██╗███████╗███████╗     █████╗ ██████╗  ██████╗██╗  ██╗
██║    ██║██╔════╝    ██║   ██║██╔════╝██╔════╝    ██╔══██╗██╔══██╗██╔════╝██║  ██║
██║ █╗ ██║█████╗      ██║   ██║███████╗█████╗      ███████║██████╔╝██║     ███████║
██║███╗██║██╔══╝      ██║   ██║╚════██║██╔══╝      ██╔══██║██╔══██╗██║     ██╔══██║
╚███╔███╔╝███████╗    ╚██████╔╝███████║███████╗    ██║  ██║██║  ██║╚██████╗██║  ██║
 ╚══╝╚══╝ ╚══════╝     ╚═════╝ ╚══════╝╚══════╝    ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝

                                 BTW

==============================================================================
EOF
}

print_banner

DISK="/dev/sda"
VG="vg_arch"
PASS="azerty123"
HOST="arch-workstation"

echo -e "\n\033[1;33m>>> ÉTAPE 0 : NETTOYAGE DU DISQUE\033[0m"
set +e 

umount -R /mnt 2>/dev/null
swapoff -a 2>/dev/null
cryptsetup close cryptlvm 2>/dev/null
vgchange -an $VG 2>/dev/null
dmsetup remove_all --force 2>/dev/null

echo " -> Effacement de la table de partition..."
wipefs --all --force $DISK 2>/dev/null
dd if=/dev/zero of=$DISK bs=1M count=100 status=none
partprobe $DISK 2>/dev/null
sleep 2

echo -e "\n\033[1;36m>>> ÉTAPE 1 : PARTITIONNEMENT (EFI & LVM)\033[0m"
set -e
sgdisk -Z $DISK
sgdisk -n 1:0:+512M -t 1:ef00 $DISK
sgdisk -n 2:0:0 -t 2:8309 $DISK
partprobe $DISK
sleep 2

echo -e "\n\033[1;32m>>> Partitionnement terminé avec succès.\033[0m"