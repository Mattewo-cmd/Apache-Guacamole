#!/bin/bash
CONTAINER="guacamoledb"
UMB="-uroot -p guacamole_db" # On groupe les infos de connexion
DATE=$(date +"%d-%m-%Y_%H-%M")
EXPORT_FILE="/opt/guacamole/export_bdd/user_export_${DATE}.sql"

echo "Génération du fichier SQL : $EXPORT_FILE"

# 1. Entête (Mode strict désactivé)
echo "SET SESSION sql_mode = '';" > "$EXPORT_FILE"

# 2. Pipeline direct : MySQL -> Boucle Bash -> Fichier
docker exec -i "$CONTAINER" mysql $UMB -N -s -e \
"SELECT HEX(e.name), HEX(u.password_hash), HEX(u.password_salt)
 FROM guacamole_entity e JOIN guacamole_user u ON e.entity_id = u.user_id WHERE e.type = 'USER';" \
| while read HEX_NAME HEX_HASH HEX_SALT; do

    # Sécurité ligne vide
    [ -z "$HEX_NAME" ] && continue

    # Écriture du bloc SQL (Compacté)
    cat <<EOF >> "$EXPORT_FILE"
SET @n=CAST(UNHEX('$HEX_NAME') AS CHAR); SET @h=UNHEX('$HEX_HASH'); SET @s=UNHEX('$HEX_SALT');
INSERT INTO guacamole_entity (entity_id,name,type) VALUES (NULL,@n,'USER') ON DUPLICATE KEY UPDATE name=name;
INSERT INTO guacamole_user (user_id,password_hash,password_salt,password_date)
VALUES ((SELECT entity_id FROM guacamole_entity WHERE name=@n AND type='USER'), @h, @s, NOW())
ON DUPLICATE KEY UPDATE password_hash=VALUES(password_hash), password_salt=VALUES(password_salt), password_date=NOW();
EOF

done

echo "Export fini dans : $EXPORT_FILE"