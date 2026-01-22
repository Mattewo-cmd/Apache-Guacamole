#!/bin/bash

# ==============================================================================
# Script d'automatisation : Renommage d'une machine et d'un VG Racine (Mode Chroot)
# Sur Debian 13.3
# ==============================================================================

set -e # Arrête le script en cas d'erreur

if [[ $EUID -ne 0 ]]; then
   echo "Erreur: Ce script doit être exécuté en tant que root (ou via sudo)."
   exit 1
fi

echo  "--- Renommage de la machine ---"
read -p "Entrez le nouveau nom de la machine : " HOST

hostnamectl set-hostname "$HOST"
sed -i "s/127.0.1.1.*/127.0.1.1\t$HOST/" /etc/hosts
echo "Nom de la machine changé en : $HOST"

echo "--- ÉTAPE 1 : Identification ---"
vgs
lvs
echo ""
read -p "Entrez le nom ACTUEL du VG : " ANCIEN_VG
read -p "Entrez le NOUVEAU nom du VG : " NOUVEAU_VG
read -p "Entrez le nom du LV racine (ex: root) : " LV_ROOT

# --- AJOUT GESTION DOUBLES TIRETS ---
ANCIEN_VG_MAPPER=$(echo "$ANCIEN_VG" | sed 's/-/--/g')
NOUVEAU_VG_MAPPER=$(echo "$NOUVEAU_VG" | sed 's/-/--/g')
# -------------------------------------

# Vérification de l'existence du VG
if ! vgs "$ANCIEN_VG" > /dev/null 2>&1; then
    echo "Erreur : Le VG '$ANCIEN_VG' n'existe pas."
    exit 1
fi

echo "--- ÉTAPE 2 : Renommage du Volume Group ---"
vgrename "$ANCIEN_VG" "$NOUVEAU_VG"

# Réactivation pour éviter l'erreur "Can't lookup blockdev"
vgscan
vgchange -ay "$NOUVEAU_VG"
vgmknodes

echo "--- ÉTAPE 3 : Préparation du Chroot ---"
MOUNT_POINT="/mnt/systeme"
mkdir -p $MOUNT_POINT

echo "Montage de la racine..."
# Utilisation du chemin /dev/mapper qui est le plus robuste
mount "/dev/mapper/${NOUVEAU_VG_MAPPER}-${LV_ROOT}" $MOUNT_POINT

# Détection et montage optionnel du /boot (si séparé)
read -p "Avez-vous une partition /boot séparée ? (y/n) : " HAS_BOOT
if [ "$HAS_BOOT" = "y" ]; then
    read -p "Entrez le nom de la partition boot (ex: sda1) : " PART_BOOT
    mount "/dev/$PART_BOOT" "$MOUNT_POINT/boot"
fi

echo "Liaison des systèmes de fichiers virtuels..."
for dir in /dev /proc /sys /run; do
    mount --bind $dir "$MOUNT_POINT$dir"
done

mkdir -p "$MOUNT_POINT/var/tmp"
chmod 1777 "$MOUNT_POINT/var/tmp"

echo "--- ÉTAPE 4 : Mise à jour de la configuration (sed) ---"
# Remplacement des noms simples
chroot $MOUNT_POINT sed -i "s/$ANCIEN_VG/$NOUVEAU_VG/g" /etc/fstab
chroot $MOUNT_POINT sed -i "s/$ANCIEN_VG/$NOUVEAU_VG/g" /etc/initramfs-tools/conf.d/* 2>/dev/null || true

# Remplacement des noms avec DOUBLES TIRETS (format mapper)
chroot $MOUNT_POINT sed -i "s/$ANCIEN_VG_MAPPER/$NOUVEAU_VG_MAPPER/g" /etc/fstab
chroot $MOUNT_POINT sed -i "s/$ANCIEN_VG_MAPPER/$NOUVEAU_VG_MAPPER/g" /etc/initramfs-tools/conf.d/* 2>/dev/null || true

# Pour GRUB, on cible le fichier de config et la commande par défaut
if [ -f "$MOUNT_POINT/etc/default/grub" ]; then
    chroot $MOUNT_POINT sed -i "s/$ANCIEN_VG/$NOUVEAU_VG/g" /etc/default/grub
    chroot $MOUNT_POINT sed -i "s/$ANCIEN_VG_MAPPER/$NOUVEAU_VG_MAPPER/g" /etc/default/grub
fi

echo "--- ÉTAPE 5 : Régénération Initramfs et GRUB ---"
chroot $MOUNT_POINT update-initramfs -u -k all
chroot $MOUNT_POINT update-grub

echo "--- ÉTAPE 6 : Nettoyage et Fin ---"
echo "Démontage des partitions..."
umount -l "$MOUNT_POINT/dev" "$MOUNT_POINT/proc" "$MOUNT_POINT/sys" "$MOUNT_POINT/run"
[ "$HAS_BOOT" = "y" ] && umount "$MOUNT_POINT/boot"
umount $MOUNT_POINT

systemctl daemon-reload
echo "================================================================="
echo " OPÉRATION TERMINÉE AVEC SUCCÈS "
echo " Vous pouvez maintenant redémarrer sur votre système."
echo "================================================================="