#!/bin/bash
#script fix upload coova-chilli by @maizil41 <https://t.me/maizil41>

USERNAME=$1
IPADDRES=$2

DB_USER="radius"
DB_PASS="radius"
DB_NAME="radius"

upload=$(mysql -u $DB_USER -p$DB_PASS -D $DB_NAME -N -e "
SELECT 
    CONCAT((g.value / 1048576) * 250, 'kb/s') AS upload
FROM radcheck r
JOIN userbillinfo u ON r.username = u.username
JOIN radgroupreply g ON u.planName = g.groupname
WHERE r.username = '$USERNAME' AND g.attribute = 'WISPr-Bandwidth-Max-Up'
LIMIT 1;
")

IP=$IPADDRES
NEW_SPEED=$upload
RULE_NAME=$USERNAME

while iptables -L FORWARD -v -n --line-numbers | grep -q $IP; do
    line_number=$(iptables -L FORWARD -v -n --line-numbers | grep $IP | awk '{print $1}' | head -n 1)
    iptables -D FORWARD $line_number
done

if [ -n "$NEW_SPEED" ]; then
    iptables -I FORWARD -s $IP -m hashlimit --hashlimit-above $NEW_SPEED --hashlimit-mode srcip --hashlimit-name $RULE_NAME -j DROP
fi

exit 0