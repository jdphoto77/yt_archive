#!/bin/bash

#######
# This script can be fed a video ID and channel name (generally taken from the troube_vids table).
# It checks to see what info it can get from the Youtube API and either updates the video as blocked
# or it errors out with a message.  Usually used to check on vids that have been quickly taken down
# by copyright request or similar.  Cleaning up the trouble_vids table is done by hand and this script
# helps automate that work partially.
#######

id=$1
channel_name=$2
code_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${code_dir}/yt_config

chan_id=$(mysql -u $user -p${password} -D youtube -e "select channel_id from channel where channel_name = '"${channel_name}"';" | grep -v channel_id)

curl -sS "https://www.googleapis.com/youtube/v3/videos?key=${key}&part=snippet&id=${id}" -o /tmp/vid_info
if [ $? -ne 0 ]; then
	mysql --user=$user --password=$password --default-character-set=utf8mb4 youtube << EOF
INSERT INTO video (video_id, video_title, channel_name, channel_id, blocked) VALUES ("$id", "NULL", "$channel_name", "$chan_id", 'TRUE');
EOF
        mysql -u ${user} -p${password} -D youtube -e "DELETE FROM trouble_vids where video_id = '"${id}"';"
else
	publish_date=$(cat /tmp/vid_info | grep '"publishedAt":' | cut -d':' -f 2- | cut -d'"' -f 2 | cut -d'T' -f 1)
	vid_title=$(cat /tmp/vid_info | grep '"title":' | head -1 | cut -d':' -f 2- | cut -d'"' -f 2)
	mysql --user=$user --password=$password --default-character-set=utf8mb4 youtube << EOF
INSERT INTO video (video_id, video_title, channel_name, channel_id, publish_date, blocked) VALUES ("$id", '"$vid_title"', "$channel_name", "$chan_id", '"$publish_date"', 'TRUE');
EOF
	if [ $? -ne 0 ]; then
  	      echo "DB Entry Error for blocked Vid: $id, $channel_name"
	else
        	mysql -u ${user} -p${password} -D youtube -e "DELETE FROM trouble_vids where video_id = '"${id}"';"
	fi
fi
rm -rf /tmp/vid_info
