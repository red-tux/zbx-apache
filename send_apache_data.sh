#!/bin/bash

# Title:: Apache monitoring library for Zabbix, sender script
# License:: LGPL 2.1   http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
# Copyright:: Copyright (C) 2014 Andrew Nelson nelsonab(at)red-tux(dot)net
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA


DATA_FILE=/var/lib/zabbix/apache-data-out
TMP_FILE=/var/lib/zabbix/sender-tmp
SERVER_NAME=load-server.lab.mclean.red-tux.net
ZABBIX_SERVER=zabbix.mclean.red-tux.net

DATA=$(tail -1 $DATA_FILE)


COUNT=$(echo $DATA | awk '{print $1}')
BYTES_REC=$(echo $DATA | awk '{print $2}')
BYTES_SENT=$(echo $DATA | awk '{print $2}')
TOTAL_TIME=$(echo $DATA | awk '{print $4}')
TOTAL_MS=$(echo $DATA | awk '{print $5}')

echo "$SERVER_NAME apache.count $COUNT" > $TMP_FILE
echo "$SERVER_NAME apache.count_per_sec $COUNT" >> $TMP_FILE
echo "$SERVER_NAME apache.bytes_received $BYTES_REC" >> $TMP_FILE
echo "$SERVER_NAME apache.bytes_sent $BYTES_SENT" >> $TMP_FILE
echo "$SERVER_NAME apache.total_seconds $TOTAL_TIME" >> $TMP_FILE
echo "$SERVER_NAME apache.total_ms $TOTAL_MS" >> $TMP_FILE

if [ -f $TMP_FILE-prev ]; then
  COUNT=$(( COUNT - $(awk '/apache.count / {print $3}' $TMP_FILE-prev) ))

  if (( $COUNT != 0 )); then
    REC_PER_CONN=$(echo "scale=4; ($BYTES_REC - $(awk '/apache.bytes_received/ {print $3}' $TMP_FILE-prev)) / $COUNT"|bc) 
    SENT_PER_CONN=$(echo "scale=4; ($BYTES_SENT - $(awk '/apache.bytes_sent/ {print $3}' $TMP_FILE-prev)) / $COUNT"|bc)
    SEC_PER_CONN=$(echo "scale=4; ($TOTAL_TIME - $(awk '/apache.total_seconds/ {print $3}' $TMP_FILE-prev)) / $COUNT"|bc)
    MS_PER_CONN=$(echo "scale=4; ($TOTAL_MS - $(awk '/apache.total_ms/ {print $3}' $TMP_FILE-prev)) / $COUNT"|bc) 

    COUNT_PER_SEC=$(echo "$COUNT $(date +%s) $(ls -l --time-style=+%s $TMP_FILE-prev|awk '{print $6}')"|awk '{printf "%f", $1/($2-$3)}')
    echo "$SERVER_NAME apache.count_per_second $COUNT_PER_SEC" >> $TMP_FILE

    echo "$SERVER_NAME apache.rec_bytes_per_connection $REC_PER_CONN" >> $TMP_FILE
    echo "$SERVER_NAME apache.sent_bytes_per_connection $SENT_PER_CONN" >> $TMP_FILE
    echo "$SERVER_NAME apache.seconds_per_connection $SEC_PER_CONN" >> $TMP_FILE
    echo "$SERVER_NAME apache.ms_per_connection $MS_PER_CONN" >> $TMP_FILE
  else
    echo "$SERVER_NAME apache.rec_bytes_per_connection 0" >> $TMP_FILE
    echo "$SERVER_NAME apache.sent_bytes_per_connection 0" >> $TMP_FILE
    echo "$SERVER_NAME apache.seconds_per_connection 0" >> $TMP_FILE
    echo "$SERVER_NAME apache.ms_per_connection 0" >> $TMP_FILE
  fi
fi

/usr/bin/zabbix_sender -z $ZABBIX_SERVER -i $TMP_FILE

cp $TMP_FILE $TMP_FILE-prev


