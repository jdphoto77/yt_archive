#!/bin/bash

######
# Key script that gets the id's of videos that need downloading by auditing between the new on Youtube and the local db
######

code_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${code_dir}/yt_config
channel_id=$1

## Get text file list of video id's in database
mysql -u ${user} -p${password} -D youtube -e "select video_id from video where channel_id = '"${channel_id}"';" > /tmp/tmp_list
tail -n +2 /tmp/tmp_list > /tmp/working_list_in_db
rm -rf /tmp/tmp_list

channel_name=$(mysql -u ${user} -p${password} -D youtube -e "select channel_name from channel where channel_id = '"${channel_id}"';" | grep -v channel_id)

## Get text file list of video id's from youtube
curl -sS "https://www.googleapis.com/youtube/v3/channels?key=${key}&id=${channel_id}&part=contentDetails&maxResults=50" -o /tmp/upload_workfile
upload_id=$(grep uploads /tmp/upload_workfile | cut -d':' -f 2 | cut -d'"' -f 2)
rm -rf /tmp/upload_workfile
done=0

curl -sS "https://www.googleapis.com/youtube/v3/playlistItems?key=${key}&part=contentDetails&playlistId=${upload_id}&maxResults=50" -o /tmp/playlist_output
while [ ${done} -lt 1 ]; do
	next_page=$(cat /tmp/playlist_output | head -10 | grep nextPageToken | cut -d'"' -f 4)
	if [ -z ${next_page} ]; then
		cat /tmp/playlist_output | grep videoId | cut -d'"' -f 4 >> /tmp/working_list_from_yt
		done=1
	else
		cat /tmp/playlist_output | grep videoId | cut -d'"' -f 4 >> /tmp/working_list_from_yt
		curl -sS "https://www.googleapis.com/youtube/v3/playlistItems?key=${key}&pageToken=${next_page}&part=contentDetails&playlistId=${upload_id}&maxResults=50" -o /tmp/playlist_output
		done=0
	fi
done
rm -rf /tmp/playlist_output

## Diff the lists to find new id's
cat /tmp/working_list_from_yt | sort > /tmp/yt_list_sorted
rm -rf /tmp/working_list_from_yt

cat /tmp/working_list_in_db | sort > /tmp/db_list_sorted
rm -rf /tmp/working_list_in_db

comm -13 /tmp/db_list_sorted /tmp/yt_list_sorted > /tmp/get_staged
sed -e "s/$/\ ${channel_name}/" -i /tmp/get_staged
cat /tmp/get_staged >> /tmp/get_today_from_yt
rm -rf /tmp/get_staged


rm -rf /tmp/db_list_sorted /tmp/yt_list_sorted
