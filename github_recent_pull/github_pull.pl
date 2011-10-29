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

use Date::Parse;
use DBI;
use LWP::UserAgent;
use Sys::Syslog qw( :DEFAULT setlogsock);
use XML::Simple;
use strict;

## Configuration
my $github_username="";
my $mysql_server="127.0.0.1";
my $mysql_user="";
my $mysql_pass="";
my $mysql_db="";
my $mysql_stat_table="github_stat";
my $mysql_activity_table="github_activity";
# Set $debug=1 to see additional info, such as song data to be imported
my $debug=0;


## Assorted variables
my ($dbh, $query, $ua, $response, $xml, $data);
my ($title, $content, $contbuf, $time);
my ($lasttime, $nlasttime);


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


# Initialization/Testing
if($debug != 0) {
	logent('info', "Beginning data pull from github into $mysql_db/$mysql_activity_table");
}
# Test DB connectivity and pull necessary config data/test table existence.
$dbh = DBI->connect('DBI:mysql:'.$mysql_db.':'.$mysql_server, $mysql_user, $mysql_pass) or die 'FATAL: Connection to database failed\n';
$query = $dbh->prepare("SELECT stat_val FROM $mysql_stat_table WHERE stat_name = 'newest' LIMIT 1");
$query->execute;
if($dbh->errstr) {
	fatality(1, "Could not access table $mysql_stat_table: $dbh->errstr");
}
$query->bind_columns(\$lasttime);
while($query->fetch) {
	$nlasttime = $lasttime;
}
$query->finish;
$query = $dbh->prepare("SELECT count(*) FROM $mysql_activity_table");
$query->execute;
if($dbh->errstr) {
	fatality(2, "Could not access table $mysql_activity_table: $dbh->errstr");
}
$query->finish;


## The main event
# Set up LWP and make our call to our github feed
$ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;
$response = $ua->get('http://github.com/' . $github_username . '.atom');
if(!($response->is_success)) {
	fatality(3, "Failed to access github feed");
}

# Set up our XML object and parse our response
$xml = new XML::Simple;
$data = $xml->XMLin($response->content);

# Parse our XML and insert it into our database
for my $k1 (sort keys %{$data->{entry}}) {
	# Activity time
	$time = $data->{entry}->{$k1}->{published};
	# Translate to str2time-ready string
	$time =~ s/[-:]//g;
	# Convert to unix timestamp
	$time = str2time($time);

	# Title
	$title = $data->{entry}->{$k1}->{title}->{content};

	# See if we have a content message - there's a lot of hax here because the atom feed
	# returns a bunch of crufty and broken-link filled HTML.  I've thus decided to only
	# capture anything within a pair of blockquote tags.  It's a tradeoff that provides
	# detail where needed, while avoiding unnecessary cruft.
	$content = "null";
	$contbuf = $data->{entry}->{$k1}->{content}->{content};
	$contbuf =~ s/\n//g;
	$contbuf =~ s/\r//g;
	if($contbuf =~ m/(<blockquote>.+<\/blockquote>)/) {
		$content = $1;
		$content =~ s/<blockquote>//g;
		$content =~ s/<\/blockquote>//g;
	}

	if($debug != 0) {
		logent('info', "New activity: $time - $title $content");
	}

	# dbh->quote would be far better here, but the DBD-MySQL package on CentOS/RHEL5 is
	# too old to support UTF8 properly.   May be wise to check for other potential problem
	# characters here.
	$title =~ s/'/\\'/; $title =~ s/"/\\"/; $title = "'" . $title . "'";
	if($content ne 'null') {
		$content =~ s/'/\\'/; $content =~ s/"/\\"/; $content = "'" . $content . "'";
	}

	# Time check.  If the incoming activity was later than our last recorded time, we'll add it.
	if($time > $lasttime) {
		if($debug != 0) {
			logent('info', "$time > $lasttime, inserting activity");
		}
		# Insert our activity record
		if($content ne 'null') {
			$query = $dbh->prepare("INSERT INTO $mysql_activity_table (github_title, github_content, github_time) VALUES ($title, $content, $time)");
		} else {
			$query = $dbh->prepare("INSERT INTO $mysql_activity_table (github_title, github_time) VALUES ($title, $time)");
		}
		$query->execute;
		if($dbh->errstr) {
			fatality(5, "Could not insert into $mysql_activity_table: $dbh->errstr");
		}
		$query->finish;

		# If $time > $nlasttime, we need to update the stored 'newest' record.
		if($time > $nlasttime) {
			if($debug != 0) {
				logent('info', "$time > $nlasttime, updating newest");
			}
			$query = $dbh->prepare("UPDATE $mysql_stat_table SET stat_val = $time WHERE stat_name = 'newest'");
			$query->execute;
			if($dbh->errstr) {
				fatality(6, "Could not update 'newest' record in $mysql_stat_table: $dbh->errstr");
			}
			$query->finish;
			$nlasttime = $time;
		}
	}
}


# We're good.
if($debug != 0) {
	logent('info', 'Github activity data import successful.');
}
$dbh->disconnect;
exit 0;
