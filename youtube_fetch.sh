#!/bin/bash

#######
# The actual downloader, where youtube-dl is called, actual download and db injection happens here
#######


code_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${code_dir}/yt_config
id=$1
chan_id=$2
link="https://www.youtube.com/watch?v="${id}

echo Link: $link

## Working directory
mkdir ${scratch_dir}
cd ${scratch_dir}
rm -rf *

## Download the Video
/usr/local/bin/youtube-dl --force-ipv4 --limit-rate 2M -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best' $link
return_c=$?
if [ ${return_c} -ne 0 ]; then
	exit 1
fi
if [[ $id == -* ]]; then
	grepid=$(echo $id | cut -c 2-)
else
        grepid=$id
fi
file_name=$(ls | grep ${grepid})

## Get variables for Database Injection
path=$(mysql -u $user -p${password} -D youtube -e "select base_dir from channel where channel_id = '"${chan_id}"';" | grep -v base_dir)
channel_name=$(mysql -u $user -p${password} -D youtube -e "select channel_name from channel where channel_id = '"${chan_id}"';" | grep -v channel_name)

resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${file_name}")
duration=$(ffprobe -i "${file_name}" -show_entries format=duration -v quiet -of csv="p=0")
full_path="${path}/${file_name}"

curl -sS "https://www.googleapis.com/youtube/v3/videos?key=${key}&part=snippet&id=${id}" -o /tmp/vid_info
publish_date=$(cat /tmp/vid_info | grep '"publishedAt":' | cut -d':' -f 2- | cut -d'"' -f 2 | cut -d'T' -f 1)
vid_title=$(cat /tmp/vid_info | grep '"title":' | head -1 | cut -d':' -f 2- | cut -d'"' -f 2)
rm -rf /tmp/vid_info

## Inject Movie Info to Database
mysql --user=$user --password=$password --default-character-set=utf8mb4 youtube << EOF
INSERT INTO video (video_id, video_title, channel_name, channel_id, resolution, duration_seconds, publish_date, file_path) VALUES ("$id", "$vid_title", "$channel_name", "$chan_id", "$resolution", "$duration", "$publish_date", "$full_path");
EOF
return_c=$?
if [ ${return_c} -ne 0 ]; then
	echo "DB Entry Error: $id, $vid_title, $channel_name, $chan_id, $resolution, $duration, $publish_date, $full_path"
fi

## Playlist Detection
dl_count=$(ls | grep ".mp4" | wc -l)
if [ ${dl_count} -gt 1 ]; then
	extra_ids=($(ls | grep ".mp4" | grep -v ${id} | sed 's/.\{4\}$//' | sed 's/.*\(...........\)/\1/' | xargs))
	for i in ${extra_ids[@]};
	do
		## Note: path, channel_name, and channel_id are reused from master
		if [[ $i == -* ]]; then
          		grepid=$(echo $i | cut -c 2-)
        	else
                	grepid=$i
        	fi
		file_name=$(ls | grep ${grepid})
		resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${file_name}")
		duration=$(ffprobe -i "${file_name}" -show_entries format=duration -v quiet -of csv="p=0")
		full_path="${path}/${file_name}"
		curl -sS "https://www.googleapis.com/youtube/v3/videos?key=${key}&part=snippet&id=${i}" -o /tmp/vid_info
		publish_date=$(cat /tmp/vid_info | grep '"publishedAt":' | cut -d':' -f 2- | cut -d'"' -f 2 | cut -d'T' -f 1)
		vid_title=$(cat /tmp/vid_info | grep '"title":' | head -1 | cut -d':' -f 2- | cut -d'"' -f 2)
		child="TRUE"
		rm -rf /tmp/vid_info
		
		mysql --user=$user --password=$password --default-character-set=utf8mb4 youtube << EOF
INSERT INTO video (video_id, video_title, channel_name, channel_id, resolution, duration_seconds, publish_date, is_child, parent_id, file_path) VALUES ("$i", "$vid_title", "$channel_name", "$chan_id", "$resolution", "$duration", "$publish_date", "$child", "$id",  "$full_path");
EOF
	return_c=$?
	if [ ${return_c} -ne 0 ]; then
	        echo "DB Entry Error: $id, $vid_title, $channel_name, $chan_id, $resolution, $duration, $publish_date, $full_path"
	fi
	done
fi

## Move File to Archive
mv *.mp4 ${path}/
cd /
rm -rf ${scratch_dir}
