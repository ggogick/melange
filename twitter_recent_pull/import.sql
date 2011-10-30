create table twitter_tweet (
	twitter_text varchar(255),
	twitter_url_text varchar(2048),
	twitter_time int(10) NOT NULL DEFAULT 0
) DEFAULT CHARSET=utf8;
create index twitter_time_index on twitter_tweet(twitter_time);
create table twitter_stat (
	stat_name varchar(20) NOT NULL,
	stat_val int(10) NOT NULL DEFAULT 0,
	PRIMARY KEY(stat_name)
) DEFAULT CHARSET=utf8;
INSERT INTO twitter_stat (stat_name) VALUES ('newest');
