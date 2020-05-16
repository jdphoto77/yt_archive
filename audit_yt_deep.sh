#!/bin/bash

channel_name=$1
code_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${code_dir}/yt_config

## Get in DB
mysql -u ${user} -p"${password}" -D youtube -e "select video_id from video where channel_name = '"${channel_name}"' and archive_exclusive IS NULL;" | tail -n +2 | sort > /tmp/${channel_name}.db.ids
db_id_count=$(wc -l /tmp/${channel_name}.db.ids | awk '{print $1}') 

## Get in Youtube
channel_id=$(mysql -u ${user} -p${password} -D youtube -e "select channel_id from channel where channel_name = '"${channel_name}"';" | grep -v channel_id)

## Get text file list of video id's from youtube
curl -sS "https://www.googleapis.com/youtube/v3/channels?key=${key}&id=${channel_id}&part=contentDetails&maxResults=50" -o upload_workfile
upload_id=$(grep uploads upload_workfile | cut -d':' -f 2 | cut -d'"' -f 2)
rm -rf upload_workfile
done=0

curl -sS "https://www.googleapis.com/youtube/v3/playlistItems?key=${key}&part=contentDetails&playlistId=${upload_id}&maxResults=50" -o playlist_output
while [ ${done} -lt 1 ]; do
	next_page=$(cat playlist_output | head -10 | grep nextPageToken | cut -d'"' -f 4)
	if [ -z ${next_page} ]; then
		cat playlist_output >> /tmp/${channel_name}.playlist.data
		done=1
	else
		cat playlist_output >> /tmp/${channel_name}.playlist.data
		curl -sS "https://www.googleapis.com/youtube/v3/playlistItems?key=${key}&pageToken=${next_page}&part=contentDetails&playlistId=${upload_id}&maxResults=50" -o playlist_output
		done=0
	fi
done
rm -rf playlist_output

cat /tmp/${channel_name}.playlist.data | grep videoId | cut -d':' -f 2 | cut -d'"' -f 2 | sort > /tmp/${channel_name}.yt.ids
yt_id_count=$(wc -l /tmp/${channel_name}.yt.ids | awk '{print $1}')

## Compare
if [ ${yt_id_count} -lt ${db_id_count} ]; then

potential_unlisted=($(comm -13 /tmp/${channel_name}.yt.ids /tmp/${channel_name}.db.ids | tr -d "[:blank:]" | xargs))

for p in ${potential_unlisted[@]};
do
	curl -sS "https://www.googleapis.com/youtube/v3/videos?key=${key}&part=status&id=${p}" -o /tmp/vid_status_check
	state=$(cat /tmp/vid_status_check | grep privacyStatus | cut -d':' -f 2 | cut -d'"' -f 2)
	if [ -z ${state} ]; then
                echo ID: ${p} is Gone
                mysql -u $user -p${password} youtube -e "UPDATE video SET archive_exclusive = 'TRUE' WHERE video_id='"${p}"'"
	elif [ ${state} == "unlisted" ]; then
		echo ID: ${p} is Unlisted
		mysql -u ${user} -p"${password}" -D youtube -e "UPDATE video SET archive_exclusive = 'UNLISTED' where video_id = '"${p}"';"
	else
		echo ID: ${p} is in Unknown State
		mysql --user=$user --password=$password --default-character-set=utf8mb4 youtube << EOF
		INSERT INTO trouble_vids (video_id, channel_id) VALUES ("${p}", "${channel_id}");
EOF
	fi
	rm -rf /tmp/vid_status_check
	sleep 1
done

elif [ ${yt_id_count} -gt ${db_id_count} ]; then
	potential_missing=($(comm -23 /tmp/${channel_name}.yt.ids /tmp/${channel_name}.db.ids | tr -d "[:blank:]" | xargs))
	for p in ${potential_missing[@]};do
		echo "${p} should be downloaded"
	done
else
	echo "Channel ID counts really match"
fi
rm -rf /tmp/${channel_name}.playlist.data /tmp/${channel_name}.yt.ids /tmp/${channel_name}.db.ids
