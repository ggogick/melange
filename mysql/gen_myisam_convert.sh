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

# A simple script to locate MyISAM tables and generate the SQL necessary to
# alter tables to InnoDB.  Script includes the ability to skip tables (eg,
# certain Drupal tables *should* be MyISAM).  Tables to be skipped can be
# either configured below or passed as an argument (space separated list).
#
# Usage:
#   gen_myisam_convert.sh databasename > output.sql
#   gen_myisam_convert.sh databasename 'tabletoskip tabletoskip' > output.sql


## Configuration
# Location of MySQL data directory, usually /var/lib/mysql
MYSQL_DATA_DIR="/var/lib/mysql"
# Space separated list of tables to skip; for Drupal, you generally want to
# skip menu_router, sempahore and watchdog at minimum
IGNORE_TABLE=(menu_router semaphore watchdog)


## Scriptage
# Ensure we have a valid database name to work with
DATABASE=$1
if [ -z "$DATABASE" ]; then
	echo "Error: An argument of a database name is required."
	exit 1
fi

ADDTABLE=($2)
if [ -n "$ADDTABLE" ]; then
	for i in ${ADDTABLE};
	do
		IGNORE_TABLE=("${IGNORE_TABLE[@]}" "$i")
	done
fi

MYISAM_TABLES=''
cd ${MYSQL_DATA_DIR}/${DATABASE}
for file in $( ls *.MYI );
do
	SKIP="FALSE";
	# Determine table we're looking at
	TABLE=$(expr "$file" : '\(.*\)\.MYI')
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

	MYISAM_TABLES="${MYISAM_TABLES} ${TABLE}";
done

if [ ! -n "$MYISAMTABLES" ]; then
	echo "USE ${DATABASE};"
	for i in ${MYISAM_TABLES};
	do
		echo "ALTER TABLE ${i} ENGINE=InnoDB;"
	done
fi

exit 0
