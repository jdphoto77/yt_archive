#!/bin/bash

#######
## This ingest video files on disk into the youtube video database
## NOTE: This script hits the youtube API for every video to get its publish date, it is API intensive
## spread this task over enough time as to not exceed Youtube API limits, watch for 403 Forbidden return codes
#######

path=$1
channel=$2
code_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${code_dir}/yt_config

channel_id=$(mysql -u $user -p${password} -D youtube -e "select channel_id from channel where channel_name = '"${channel}"';" | grep -v channel_id)

ids=($(ls ${path} | sed 's/.\{4\}$//' | sed 's/.*\(...........\)/\1/' | xargs))

for i in ${ids[@]}
do
	if [[ $i == -* ]]; then
		grepid=$(echo $i | cut -c 2-)
	else
		grepid=$i
	fi
	filename=$(ls ${path} | grep "${grepid}" | sed 's/\"/\\\"/g')
	file=$(ls ${path} | grep "${grepid}")
	title=$(echo ${filename} | sed 's/.\{16\}$//' | sed 's/\"//g')
	resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${path}/${file}")
	duration_seconds=$(ffprobe -i "${path}/${file}" -show_entries format=duration -v quiet -of csv="p=0")
	full_path="${path}/${filename}"
	wget "https://www.googleapis.com/youtube/v3/videos?key=${key}&part=snippet&id=${i}" -O /tmp/vid_info
	publish_date=$(cat /tmp/vid_info | grep '"publishedAt":' | cut -d':' -f 2- | cut -d'"' -f 2 | cut -d'T' -f 1)
	rm -rf /tmp/vid_info
	echo Filename: $filename
	echo Title: $title
	mysql --user=$user --password=$password --default-character-set=utf8mb4 youtube << EOF
INSERT INTO video (video_id, video_title, channel_name, channel_id, resolution, duration_seconds, publish_date, file_path) VALUES ("$i", "$title", "$channel", "$channel_id", "$resolution", "$duration_seconds", "$publish_date", "$full_path");
EOF

done
