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
use LWP::UserAgent;
use Sys::Syslog qw( :DEFAULT setlogsock);
use XML::Simple;
use strict;

## Configuration
my $last_username="";
my $last_apikey="";
my $mysql_server="127.0.0.1";
my $mysql_user="";
my $mysql_pass="";
my $mysql_db="";
my $mysql_stat_table="lastfm_stat";
my $mysql_play_table="lastfm_play";
# Set $debug=1 to see additional info, such as song data to be imported
my $debug=1;


## Assorted variables
my ($dbh, $query, $ua, $response, $xml, $data);
my ($song, $artist, $album, $played, $url);
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


## Initialization/Testing
if($debug != 0) {
	logent('info', "Beginning data pull from Last.fm into $mysql_db/$mysql_play_table");
}
# Test DB connectivity and pull necessary config data/test table existence.
$dbh = DBI->connect('DBI:mysql:'.$mysql_db.':'.$mysql_server, $mysql_user, $mysql_pass) or die 'FATAL: Connection to database failed\n';
$query = $dbh->prepare("SELECT stat_val FROM $mysql_stat_table WHERE stat_name = 'newest' LIMIT 1");
$query->execute;
if($dbh->errstr) {
	fatality(1, "Could not access table $mysql_stat_table: \$dbh->errstr");
}
$query->bind_columns(\$lasttime);
while($query->fetch) {
	$nlasttime = $lasttime;
}
$query->finish;
$query = $dbh->prepare("SELECT count(*) FROM $mysql_play_table");
$query->execute;
if($dbh->errstr) {
	fatality(2, "Could not access table $mysql_play_table: \$dbh->errstr");
}
$query->finish;


## The main event
# Set up LWP and make our call to last.fm API
$ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;
$response = $ua->get('http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=' . $last_username . '&api_key=' . $last_apikey);
if(!($response->is_success)) {
	fatality(3, "Failed to access Last.fm API");
}

# Set up our XML object and parse our response
$xml = new XML::Simple;
$data = $xml->XMLin($response->content);

# Quick status check
if($data->{status} ne "ok") {
	fatality(4, "Status from Last.fm API is not ok: $response->status_line");
}

# Parse our XML and insert it into our database.
for my $k1 (sort keys %{$data->{recenttracks}->{track}}) {
	# Drop data into vars for further parsing.
	$song = $k1;
	$artist = $data->{recenttracks}->{track}->{$k1}->{artist}->{content};
	$album = $data->{recenttracks}->{track}->{$k1}->{album}->{content};
	$played = $data->{recenttracks}->{track}->{$k1}->{date}->{uts};
	$url = $data->{recenttracks}->{track}->{$k1}->{url};

	if($debug != 0) {
		logent('info', "New song: $song - $artist - $album - $played - $url");
	}


	# dbh->quote would be far better here, but the DBD-MySQL package on CentOS/RHEL5 is 
	# too old to support UTF8 properly.  May be wise to check for other potential problem 
	# characters here, but I'm pretty sure Last.fm isn't going to try an injection attack. :p
	$song =~ s/'/\\'/g; $song =~ s/"/\\"/g; $song = "'" . $song . "'";
	$artist =~ s/'/\\'/g; $artist =~ s/"/\\"/g; $artist = "'" . $artist . "'";
	$album =~ s/'/\\'/g; $album =~ s/"/\\"/g; $album = "'" . $album . "'";
	$url =~ s/'/\\'/g; $url =~ s/"/\\"/g; $url = "'" . $url . "'";

	# Time check.  If the incoming song was played later than our last recorded time, we'll add it.
	if($played > $lasttime) {
		if($debug != 0) {
			logent('info', "$played > $lasttime, inserting song");
		}
		# Insert our played song record.
		$query = $dbh->prepare("INSERT INTO $mysql_play_table (play_title, play_album, play_artist, play_time, play_url) VALUES ($song, $album, $artist, $played, $url)");
		$query->execute;
		if($dbh->errstr) {
			fatality(5, "Could not insert into $mysql_play_table: \$dbh->errstr");
		}
		$query->finish;

		# If $played > $nlasttime, we need to update the stored 'newest' record.
		if($played > $nlasttime) {
			if($debug != 0) {
				logent('info', "$played > $nlasttime, updating newest");
			}
			$query = $dbh->prepare("UPDATE $mysql_stat_table SET stat_val = $played WHERE stat_name = 'newest'");
			$query->execute;
			if($dbh->errstr) {
				fatality(6, "Could not update 'newest' record in $mysql_stat_table: \$dbh->errstr");
			}
			$query->finish;
			$nlasttime = $played;
		}
	}
}


## We're good.
if($debug != 0) {
	logent('info', 'Last.fm data import successful.');
}
$dbh->disconnect;
exit 0;
