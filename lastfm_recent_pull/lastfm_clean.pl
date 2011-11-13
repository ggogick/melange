#!/usr/bin/perl -CS
##############################################################################
# Copyright (c) 2011, Gary Gogick
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of the copyright holder nor the names of its 
#      contributors may be used to endorse or promote products derived from 
#      this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
##############################################################################

use DBI;
use Sys::Syslog qw( :DEFAULT setlogsock);
use strict;

## Configuration
my $mysql_server="127.0.0.1";
my $mysql_user="";
my $mysql_pass="";
my $mysql_db="";
my $mysql_stat_table="lastfm_stat";
my $mysql_play_table="lastfm_play";

# Trim time - the number of seconds prior to the 'newest' play to start
# trimming.  That is, if your newest play was right now, selecting
# $SDAY would trim everything *prior* to (now - 86400 seconds) - that
# is, everything older than one day.   Note that $SMONTH is fuzzy, and
# by default set to 30 days, regardless of calendar month.
my $SDAY = 86400;
my $SWEEK = ($SDAY * 7);
my $SMONTH = ($SDAY * 30);
my $SYEAR = ($SDAY * 365);
# Set $trim=$SDAY, $SWEEK, $SMONTH or $SYEAR
my $trim=$SWEEK;

# Set $debug=1 to see additional info, such as song data to be imported
my $debug=1;


## Assorted variables
my ($dbh, $query, $lt, $lasttime, $wolftime);


## Supporting Functions
sub logent {
	my ($priority, $msg) = @_;
	return 0 unless ($priority =~ /info|err|debug/);
 	setlogsock('unix');
	openlog($0, '', 'user');
	syslog($priority, $msg);
	closelog();
	return 0;
}

sub fatality {
	my ($exit, $msg) = @_;
	logent('err', $msg);
	$dbh->disconnect;
	exit $exit;
}


## Initialization/Testing
if($debug != 0) {
	logent('info', "Beginning housekeeping for Last.fm data in $mysql_db/$mysql_play_table");
}
# Test DB connectivity and pull necessary config data/test table existence.
$dbh = DBI->connect('DBI:mysql:'.$mysql_db.':'.$mysql_server, $mysql_user, $mysql_pass) or die 'FATAL: Connection to database failed\n';
$query = $dbh->prepare("SELECT stat_val FROM $mysql_stat_table WHERE stat_name = 'newest' LIMIT 1");
$query->execute;
if($dbh->errstr) {
	fatality(1, "Could not access table $mysql_stat_table: \$dbh->errstr");
}
$query->bind_columns(\$lt);
while($query->fetch) {
	$lasttime = $lt;
}
$query->finish;
$query = $dbh->prepare("SELECT count(*) FROM $mysql_play_table");
$query->execute;
if($dbh->errstr) {
	fatality(2, "Could not access table $mysql_play_table: \$dbh->errstr");
}
$query->finish;


## The main event
# Gratuitous WH40K reference
$wolftime = $lasttime - $trim;
$query = $dbh->prepare("DELETE FROM $mysql_play_table WHERE play_time < $wolftime");
$query->execute;
if($dbh->errstr) {
	fatality(3, "Could not delete from $mysql_play_table: \$dbh->errstr");
}
if($debug != 0) {
	logent('info', "Purged " . $query->rows . " records from $mysql_play_table");
}
$query->finish;


## We're good.
if($debug != 0) {
	logent('info', 'Last.fm data successful purged.');
}
$dbh->disconnect;
exit 0;
