create table github_activity (
	github_title varchar(255),
	github_content varchar(255),
	github_time int(10) NOT NULL DEFAULT 0
) DEFAULT CHARSET=utf8;
create index github_time_index on github_activity(github_time);
create table github_stat (
	stat_name varchar(20) NOT NULL,
	stat_val int(10) NOT NULL DEFAULT 0,
	PRIMARY KEY(stat_name)
) DEFAULT CHARSET=utf8;
INSERT INTO github_stat (stat_name) VALUES ('newest');
