create table lastfm_play (
       play_title varchar(255),
       play_album varchar(255),
       play_artist varchar(255),
       play_time int(10) NOT NULL DEFAULT 0,
       play_url varchar(255)
) DEFAULT CHARSET=utf8;
create index play_time_index on lastfm_play(play_time);
create table lastfm_stat (
       stat_name varchar(20) NOT NULL,
       stat_val int(10) NOT NULL DEFAULT 0,
       PRIMARY KEY(stat_name)
) DEFAULT CHARSET=utf8;
INSERT INTO lastfm_stat (stat_name) VALUES ('newest');
