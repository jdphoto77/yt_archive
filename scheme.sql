CREATE TABLE `channel` (
  `channel_id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `channel_name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_checked` date DEFAULT NULL,
  `rotation_day` int(11) NOT NULL,
  `active` tinyint(1) NOT NULL,
  `base_dir` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`channel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `run_stats` (
  `run_date` date DEFAULT NULL,
  `count_downloaded` int(11) DEFAULT NULL,
  `run_number` int(11) NOT NULL AUTO_INCREMENT,
  `current_run_day` int(11) DEFAULT NULL,
  PRIMARY KEY (`run_number`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `trouble_vids` (
  `video_id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `channel_id` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`video_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `video` (
  `video_id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Videos ID used as the primary key, unique across Youtube',
  `video_title` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Videos Title per API',
  `channel_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Channels Name without Spaces',
  `channel_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Channel Main Playlist ID',
  `resolution` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Videos Resolution in Pixels',
  `duration_seconds` decimal(12,6) DEFAULT NULL COMMENT 'Videos Duration in Seconds',
  `publish_date` date DEFAULT NULL COMMENT 'Day video was published',
  `blocked` varchar(8) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Video in Playlist but Unvailable',
  `is_child` varchar(8) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Video is Child of Another -- Not in API playlist',
  `parent_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'ID of Parent Video',
  `archive_exclusive` varchar(8) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Video Gone or Private -- Not Found with API',
  `file_path` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Path to Video File on Archive Server',
  PRIMARY KEY (`video_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `working` (
  `video_id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `channel_id` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`video_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


