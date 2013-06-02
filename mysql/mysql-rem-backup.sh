#!/bin/bash
###############################################################################
# Copyright (c) 2012, Gary Gogick, Workhabit, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#    * Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
#    * Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
#    * Neither the name of Workhabit, Inc., nor the names of its contributors
# may be used to endorse or promote products derived from this software
# without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
###############################################################################

## Overview
# Simple script for grabbing all but specified MySQL databases from a remote
# server, dumping and compressing them locally, and finally, pruning older
# dumps.  Contains basic error checking and simple e-mail alerting.


## Configuration
# MySQL credentials - you should ideally have a read-only user on the
# remote server for backup purposes.
MYUSER="backup"
MYPASS="1234"
MYHOST="db01.localdomain"

# Alerting, leave EMAIL blank to skip.
EMAIL="foo@localdomain"
SYSNAME="storage.localdomain"

# Databases to skip
DBSKIPLIST="information_schema performance_schema test"
DBSKIP=0

# Location of backups and number to retain; backups will be kept
# in per-database subdirectories under BACKUP_DIR.
BACKUP_DIR="/mysql-backups"
RETAIN=7


## Quick and dirty e-mail function
mail_error() {
	ER_SUBJECT="${SYSNAME}: MySQL backup has failed."
	ER_BODY="/tmp/mysql-rem-backup.txt"
	echo "$1" > $ER_BODY
	mail -s "$ER_SUBJECT" "$EMAIL" < $ER_BODY
}


## Process
# Get our list of databases
DBLIST=$(mysql --batch --skip-pager --skip-column-names --raw -h$MYHOST -u$MYUSER -p$MYPASS --execute='SHOW DATABASES')
RETVAL=$?
if [ $RETVAL -ne 0 ]; then
	mail_error "Failed to get list of databases, error code: $RETVAL"
	exit 0
fi

# Loop through our list of databases; dump/compress/end anything not in DBSKIPLIST
for db in ${DBLIST}; do
        DBSKIP=0
        for i in $DBSKIPLIST; do
                if [ "$db" == "$i" ]; then
                        DBSKIP=1
                        break
                fi
        done
        if [ $DBSKIP == 1 ]; then
                continue
        fi

        # db is valid target; proceed with the backup
	if [ ! -d "$BACKUP_DIR/$db" ]; then
		mkdir -p $BACKUP_DIR/$db
		RETVAL=$?
		if [ $RETVAL -ne 0 ]; then
			mail_error "Failed to create $BACKUP_DIR/$db, error code: $RETVAL"
			exit 0
		fi
	fi
	DATE=`date +%Y%m%d-%H%M`
	mysqldump -h$MYHOST -u$MYUSER -p$MYPASS $db > $BACKUP_DIR/$db/$DATE-$db.sql
	RETVAL=$?
	if [ $RETVAL -ne 0 ]; then
		mail_error "Failed to dump $db, error code: $RETVAL"
		exit 0
	fi
	gzip $BACKUP_DIR/$db/$DATE-$db.sql
	RETVAL=$?
	if [ $RETVAL -ne 0 ]; then
		mail_error "Failed to gzip $db, error code: $RETVAL"
		exit 0
	fi
done


## Pruning
BDIRS=`find $BACKUP_DIR -mindepth 1 -type d -print`
for i in ${BDIRS[@]}; do
	BS=(`ls -1 $i/*.sql.gz`)
	CURRBU=${#BS[@]};
	if [ "$CURRBU" -gt "$RETAIN" ]; then
		for ((z=(CURRBU-RETAIN-1); z>-1; z--))
		do
			rm -f ${BS[$z]}
		done		
	fi
done

exit 0
