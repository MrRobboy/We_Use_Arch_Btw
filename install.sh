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

echo " -> Chiffrement de la partition ${DISK}2..."
echo -n "$PASS" | cryptsetup luksFormat --type luks2 ${DISK}2 -
echo -n "$PASS" | cryptsetup open ${DISK}2 cryptlvm

echo " -> Création du Volume Group ($VG) et des Logical Volumes..."
pvcreate /dev/mapper/cryptlvm
vgcreate $VG /dev/mapper/cryptlvm

lvcreate -L 8G -n lv_swap $VG
lvcreate -L 15G -n lv_vbox $VG
lvcreate -L 5G -n lv_shared $VG
lvcreate -L 10G -n lv_vault $VG
lvcreate -l 100%FREE -n lv_root $VG

echo " -> Formatage des partitions (ext4, fat32, swap)..."
mkfs.fat -F32 ${DISK}1
mkfs.ext4 /dev/$VG/lv_root
mkfs.ext4 /dev/$VG/lv_vbox
mkfs.ext4 /dev/$VG/lv_shared
mkswap /dev/$VG/lv_swap

echo " -> Configuration du coffre-fort chiffré (Vault)..."
echo -n "$PASS" | cryptsetup luksFormat /dev/$VG/lv_vault -
echo -n "$PASS" | cryptsetup open /dev/$VG/lv_vault vault_tmp
mkfs.ext4 /dev/mapper/vault_tmp
cryptsetup close vault_tmp

echo -e "\n\033[1;32m>>> Étape 2 terminée : Le stockage est prêt et sécurisé.\033[0m"