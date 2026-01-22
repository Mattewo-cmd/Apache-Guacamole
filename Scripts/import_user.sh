#!/bin/bash
CONTAINER="guacamoledb"
USER="root"
PASS="mdproot"
DB="guacamole_db"
IMPORT_DIR="/opt/guacamole/export_bdd"
LATEST_EXPORT=$(ls -t ${IMPORT_DIR}/user_export_*.sql* 2>/dev/null | head -n 1)

if [ ! -f "$LATEST_EXPORT" ]; then echo "❌ Fichier introuvable"; exit 1; fi

echo "Importation dans la base de données"
cat "$LATEST_EXPORT" | docker exec -i "$CONTAINER" mysql -u"$USER" -p"$PASS" "$DB"

if [ $? -eq 0 ]; then
  echo "🎉 Importation dans la base de données terminée."
else
  echo "❌ Importation non faite.."
fi