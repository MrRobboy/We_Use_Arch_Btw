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

echo -e "\n\033[1;36m>>> ÉTAPE 3 : MONTAGES ET INSTALLATION DES PAQUETS\033[0m"

mount /dev/$VG/lv_root /mnt
mkdir -p /mnt/{boot,var/lib/virtualbox,home/shared}
mount ${DISK}1 /mnt/boot
mount /dev/$VG/lv_vbox /mnt/var/lib/virtualbox
mount /dev/$VG/lv_shared /mnt/home/shared
swapon /dev/$VG/lv_swap

echo " -> Installation des paquets (Patience...)"
pacstrap /mnt base linux linux-firmware lvm2 networkmanager sudo grub efibootmgr \
    vim gcc make gdb fastfetch ranger htop git wget curl zsh \
    xorg-server xorg-xinit i3-wm i3status dmenu xfce4-terminal \
    virtualbox virtualbox-host-modules-arch

genfstab -U /mnt >> /mnt/etc/fstab

echo -e "\n\033[1;32m>>> Étape 3 terminée.\033[0m"

echo -e "\n\033[1;36m>>> ÉTAPE 4 : CONFIGURATION INTERNE ET RAPPORT\033[0m"

cat <<EOF > /mnt/root/setup.sh
#!/bin/bash

ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
echo "fr_FR.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf
echo "KEYMAP=fr-latin1" > /etc/vconsole.conf
echo "$HOST" > /etc/hostname

systemctl enable NetworkManager

sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P
UUID=\$(blkid -s UUID -o value ${DISK}2)
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=\$UUID:cryptlvm root=/dev/$VG/lv_root\"|" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg

groupadd shared_memes
useradd -m -G wheel,shared_memes,vboxusers -s /bin/zsh collegue
echo "collegue:$PASS" | chpasswd
useradd -m -G shared_memes -s /bin/zsh fils
echo "fils:$PASS" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

chown root:shared_memes /home/shared
chmod 2770 /home/shared

for user in collegue fils; do
    UHOME="/home/\$user"
    mkdir -p "\$UHOME/.config/i3"
    cat <<I3CONF > "\$UHOME/.config/i3/config"
set \\\$mod Mod4
font pango:monospace 10
floating_modifier \\\$mod
bindsym \\\$mod+Return exec xfce4-terminal
bindsym \\\$mod+Shift+q kill
bindsym \\\$mod+d exec dmenu_run
bindsym \\\$mod+Left focus left
bindsym \\\$mod+Down focus down
bindsym \\\$mod+Up focus up
bindsym \\\$mod+Right focus right
bindsym \\\$mod+Shift+e exec i3-msg exit
bar {
    status_command i3status
    colors {
        background #282a36
        statusline #f8f8f2
    }
}
I3CONF
    echo "exec i3" > "\$UHOME/.xinitrc"
    cat <<ZSHCONF >> "\$UHOME/.zshrc"
if [[ -z \\\$DISPLAY && \\\$(tty) == /dev/tty1 ]]; then
    exec startx
fi
fastfetch
ZSHCONF
    chown -R \$user:\$user "\$UHOME"
done

REPORT="/root/rendu_final.txt"
{
  echo "=== 1. LSBLK -F ==="
  lsblk -f
  echo -e "\n=== 2. PASSWD / GROUP / FSTAB / MTAB ==="
  cat /etc/passwd /etc/group /etc/fstab /etc/mtab
  echo -e "\n=== 3. HOSTNAME ==="
  echo \$HOSTNAME
  echo -e "\n=== 4. PACKAGES INSTALLED ==="
  grep -i installed /var/log/pacman.log
} > "\$REPORT"
EOF

chmod +x /mnt/root/setup.sh
arch-chroot /mnt /root/setup.sh
rm /mnt/root/setup.sh

echo -e "\n\033[1;32m>>> INSTALLATION TERMINÉE ! Fichier de rendu créé dans /root/rendu_final.txt\033[0m"