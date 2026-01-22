####################################################################################
# Description du script : Job bash qui réinitialise le TOTP d'un utilisateur (suppression de la clé et l'appareil confirmé).
#
#_Ver_|_Modifie_le_|_Par_|_Objet___________________________________________
#     |            |     |
#     |            |     | 
# 1.0 | 12/12/2025 | MLE | Création du script
#     |            |     | 
####################################################################################

#!/bin/bash

U=root
M=
B=guacamole_db
read -s -p "Mot de passe BDD : " M
UMB="-u $U -p$M $B"
read -p "Utilisateur concerné : " USER_TOTP

# 1. Réinitialisation du TOTP
echo "--- Réinitialisation du TOTP pour l'utilisateur $USER_TOTP ---"

docker exec guacamoledb mysql $UMB -t -N -e "UPDATE guacamole_user_attribute JOIN guacamole_user ON guacamole_user_attribute.user_id = guacamole_user.user_id JOIN guacamole_entity ON guacamole_user.entity_id = guacamole_entity.entity_id SET guacamole_user_attribute.attribute_value='' where guacamole_entity.name='$USER_TOTP' ;"

# 3. Affiche le TOTP réinitialisé

echo "--- TOTP réinitialisé pour l'utilisateur $USER_TOTP ---"


TOTP_USER=$(docker exec guacamoledb mysql $UMB -t -e "SELECT guacamole_entity.name, guacamole_user_attribute.attribute_name, guacamole_user_attribute.attribute_value FROM guacamole_user_attribute JOIN guacamole_user ON guacamole_user_attribute.user_id = guacamole_user.user_id JOIN guacamole_entity ON guacamole_user.entity_id = guacamole_entity.entity_id WHERE guacamole_entity.name='$USER_TOTP' AND guacamole_user_attribute.attribute_name IN ('guac-totp-key-confirmed', 'guac-totp-key-secret'); ")

echo "$TOTP_USER"