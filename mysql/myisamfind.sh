#!/bin/bash
###############################################################################
# Copyright (c) 2011, Gary Gogick/Workhabit, Inc.
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

# A simple script to check for MyISAM tables.   Requires read access to the
# MySQL data directory.  Ability to skip databases or tables (eg, certain
# Drupal tables *should* be MyISAM.   Optional ability to send an e-mail
# notification if MyISAM tables are found, should you wish to run the
# script via cron.

## Configuration
# Location of MySQL data directory, usually /var/lib/mysql
MYSQL_DATA_DIR="/var/lib/mysql"
# Space separated list of databases to skip
IGNORE_DB=(mysql test)
# Space separated list of tables to skip; for Drupal, you generally want to
# skip menu_router, sempahore and watchdog at minimum
IGNORE_TABLE=(menu_router semaphore watchdog)
# To receive an e-mail notification if MyISAM tables are found (for example, if
# you're running this via cron instead of manually), set EMAIL_ALERT="TRUE"
# and EMAIL_ADDRESS to the address you wish to notify.
EMAIL_ALERT="FALSE"
EMAIL_ADDRESS=""


## Scriptage
MYISAM_TABLES=''
cd ${MYSQL_DATA_DIR}
for file in $( ls */*.MYI );
do
	SKIP="FALSE";

	# Determine database we're looking at
	DATABASE=$(expr "$file" : '\(.*\)\/')
	# Check to see if we should skip this DB
	for i in "${IGNORE_DB[@]}"
	do
		if [ "$i" == "$DATABASE" ]; then
			SKIP="TRUE"
			break
		fi
	done
	if [ "$SKIP" == "TRUE" ]; then
		continue;
	fi

	# Determine table we're looking at
	TABLE=$(expr "$file" : '.*\/\(.*\)\.MYI')
	# Check to see if we should skip this table
	for i in "${IGNORE_TABLE[@]}"
	do
		if [ "$i" == "$TABLE" ]; then
			SKIP="TRUE"
			break;
		fi
	done
	if [ "$SKIP" == "TRUE" ]; then
		continue;
	fi

	MYISAM_TABLES="${MYISAM_TABLES}${DATABASE}/${TABLE}\n";
done

if [ ! -n "$MYISAMTABLES" ]; then
	echo "The following MyISAM tables were found:"
	echo ""
	echo "Database/Table"
	echo "--------------"
	echo -e "${MYISAM_TABLES}"

	if [ "$EMAIL_ALERT" == "TRUE" ]; then
		SUBJECT="MyISAM tables found on $(hostname)"
		EMAIL="${EMAIL_ADDRESS}"
		echo -e "The following MyISAM tables were found:\n\nDatabase/Table\n--------------\n${MYISAM_TABLES}" | /bin/mail -s "$SUBJECT" "$EMAIL"
	fi
fi

exit 0
