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
use JSON qw( decode_json );
use LWP::UserAgent;
use Sys::Syslog qw( :DEFAULT setlogsock);
use strict;

## Configuration
my $twitter_username="";
my $mysql_server="127.0.0.1";
my $mysql_user="";
my $mysql_pass="";
my $mysql_db="";
my $mysql_stat_table="twitter_stat";
my $mysql_tweet_table="twitter_tweet";
# Set $debug=1 to see additional info, such as song data to be imported
my $debug=0;


## Assorted variables
my ($dbh, $query, $ua, $response, $decoded_json);
my ($text, $url_text, $time);
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
	logent('info', "Beginning data pull from Twitter into $mysql_db/$mysql_tweet_table");
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
$query = $dbh->prepare("SELECT count(*) FROM $mysql_tweet_table");
$query->execute;
if($dbh->errstr) {
	fatality(2, "Could not access table $mysql_tweet_table: \$dbh->errstr");
}
$query->finish;


## The main event
# Set up LWP and make our call to our github feed
$ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;
$response = $ua->get('https://api.twitter.com/1/statuses/user_timeline.json?screen_name=' . $twitter_username . '&count=10&trim_user=1');
if(!($response->is_success)) {
	fatality(3, "Failed to access twitter API");
}

# Decode our JSON
$decoded_json = decode_json($response->content);

# Parse the decoded JSON and insert it into our database
foreach (@$decoded_json) {
	# Grab our data
	$text = $_->{text};
	$url_text = $_->{text};
	$time = $_->{created_at};
	# Convert to unix timestamp
        $time = str2time($time);

	# Translate url_text 
	# Presently translates #example, @example into proper URLs
	$url_text =~ s/ #(.+?) / <a href="http:\/\/twitter.com\/#\!\/search?q=%23\1">#\1<\/a> /g;
	$url_text =~ s/ @(.+?) / <a href="http:\/\/twitter.com\/\1">@\1<\/a> /g;

	if($debug != 0) {
		logent('info', "New tweet: $time - $text");
	}

	# dbh->quote would be far better here, but the DBD-MySQL package on CentOS/RHEL5 is
	# too old to support UTF8 properly.  May be wise to check for other potential problem
	# characters here.
	$text =~ s/'/\\'/; $text =~ s/"/\\"/; $text = "'" . $text . "'";
	$url_text =~ s/'/\\'/; $url_text =~ s/"/\\"/; $url_text = "'" . $url_text . "'";

	# Time check.  If the incoming tweet was later than our last recorded time, we'll add it.
	if($time > $lasttime) {
		if($debug != 0) {
			logent('info', "$time > $lasttime, inserting tweet");
		}
		# Insert our tweet
		$query = $dbh->prepare("INSERT INTO $mysql_tweet_table (twitter_text, twitter_url_text, twitter_time) VALUES ($text, $url_text, $time)");
		$query->execute;
		if($dbh->errstr) {
			fatality(5, "Could not insert into $mysql_tweet_table: \$dbh->errstr");
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
				fatality(6, "Could not update 'newest' record in $mysql_stat_table: \$dbh->errstr");
			}
			$query->finish;
			$nlasttime = $time;
		}
	}	
}


# We're good.
if($debug != 0) {
	logent('info', 'Twitter data import successful.');
}
$dbh->disconnect;
exit 0;
