#!/bin/bash

USERNAME=$1

# Koneksi database
DB_USER="radius"
DB_PASS="radius"
DB_NAME="radius"

# Ambil total input dan output octets dari radacct
QUERY="SELECT IFNULL(SUM(AcctInputOctets) + SUM(AcctOutputOctets), 0) FROM radacct WHERE UserName='$USERNAME';"
TOTAL_OCTETS=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -se "$QUERY")

# Ambil batas maksimum dari radgroupreply
QUERY_MAX="SELECT IFNULL(value, 0) FROM radgroupreply WHERE attribute='ChilliSpot-Max-Total-Octets' AND groupname=(SELECT groupname FROM radusergroup WHERE username='$USERNAME');"
MAX_OCTETS=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -se "$QUERY_MAX")

# Periksa apakah total octets melebihi batas
if [ "$TOTAL_OCTETS" -gt "$MAX_OCTETS" ]; then
    echo "Reply-Message := 'Kuota Anda Telah Habis'"
    exit 1
fi

exit 0
