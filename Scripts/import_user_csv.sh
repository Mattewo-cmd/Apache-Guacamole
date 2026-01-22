#!/bin/bash

# --- CONFIGURATION ---
CONTAINER="guacamoledb"
UMB="-uroot -p guacamole_db"
CSV="/opt/guacamole/export_bdd/guac_export_2025-11-24_10-00.csv"

echo "=== IMPORT GUACAMOLE USERS (ANTI-COLLISION) ==="

if [ ! -f "$CSV" ]; then
    echo "❌ Erreur : Fichier $CSV introuvable."
    exit 1
fi

while IFS=',' read -u 3 -r NAME HASH_B64 SALT_B64 || [ -n "$NAME" ]; do

    # Ignorer les lignes vides
    if [ -z "$NAME" ]; then continue; fi

    echo "-------------------------------------------------"
    echo "👤 Traitement de : [$NAME]"

    # 1. Gestion de l'entité
    ENTITY_ID=$(docker exec -i "$CONTAINER" mysql $UMB -N -s -e "SELECT entity_id FROM guacamole_entity WHERE name='$NAME' AND type='USER';")

    if [ -z "$ENTITY_ID" ]; then
        echo "   [+] Création nouvelle entité..."
        docker exec -i "$CONTAINER" mysql $UMB -e "INSERT INTO guacamole_entity (name, type) VALUES ('$NAME', 'USER');"
        ENTITY_ID=$(docker exec -i "$CONTAINER" mysql $UMB -N -s -e "SELECT entity_id FROM guacamole_entity WHERE name='$NAME' AND type='USER';")
    else
        echo "   [=] Entité existante (ID: $ENTITY_ID)"
    fi

    # 2. Mise à jour Hash/Salt
    echo "   [>] Injection Hash/Salt"
    # Docker peut maintenant utiliser l'entrée standard sans voler le CSV
    docker exec -i "$CONTAINER" mysql $UMB <<EOF
SET @h = FROM_BASE64('$HASH_B64');
SET @s = FROM_BASE64('$SALT_B64');

INSERT INTO guacamole_user (entity_id, password_hash, password_salt, password_date)
VALUES ($ENTITY_ID, @h, @s, NOW())
ON DUPLICATE KEY UPDATE
    password_hash=@h,
    password_salt=@s,
    password_date=NOW();
EOF

# C'est ici qu'on redirige le CSV nettoyé vers le canal 3
done 3< <(cat "$CSV" | tr -d '\r' | tail -n +2)

echo "================================================="
echo "✅ IMPORT TERMINÉ"