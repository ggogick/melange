#!/bin/bash
###############################################################################
# Copyright (c) 2012, Gary Gogick
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
# Simple script to regularly take MySQL backups via mysqldump and keep them
# pruned to a specific number.  Not terribly resilient; assumes your MySQL
# credentials are valid; your backup storage directory exists and is writable,
# et cetera.  It's also fairly greedy on grabbing backups for pruning; you're 
# going to want to not keep random *.sql.gz files in your backups directory.

## Configuration
# Directory to store backups in; backups will be stored in a subdirectory
# named for the database being backed up
BACKUP_DIR="/backups"

# Space seperated list of databases to backup
DATABASES="sexytimedatabase production_llamas"

# Number of backups to retain after each run; this should be an integer greater 
# than 0
RETAIN="8"

# MySQL username and password; if you need to specify a username, you MUST
# specify a password.  Otherwise, the script assumes your current user
# has proper permissions to simply access databases via mysqldump
MYUSER="root"
MYPASS=""


## Backup
if [ ! -n $MYPASS ]; then
	MYCMD="mysqldump -u$MYUSER -p$MYPASS "
else
	MYCMD="mysqldump -u$MYUSER "
fi

for i in $DATABASES; do
	if [ ! -d "$BACKUP_DIR/$i" ]; then
		mkdir -p $BACKUP_DIR/$i
	fi

	DATE=`date +%Y%m%d-%H%M`
	$MYCMD $i > $BACKUP_DIR/$i/$DATE-$i.sql
	gzip $BACKUP_DIR/$i/$DATE-$i.sql
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

# End
exit 0
