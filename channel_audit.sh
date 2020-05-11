#!/bin/bash

######
# Key script that gets the id's of videos that need downloading by auditing between the new on Youtube and the local db
######

code_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${code_dir}/yt_config
channel_name=$1

## Get text file list of video id's in database
mysql -u ${user} -p${password} -D youtube -e "select video_id from video where channel_name = '"${channel_name}"';" > tmp_list
tail -n +2 tmp_list > working_list_in_db
rm -rf tmp_list

channel_id=$(mysql -u ${user} -p${password} -D youtube -e "select channel_id from channel where channel_name = '"${channel_name}"';" | grep -v channel_id)

## Get text file list of video id's from youtube
curl -sS "https://www.googleapis.com/youtube/v3/channels?key=${key}&id=${channel_id}&part=contentDetails&maxResults=50" -o /tmp/upload_workfile
upload_id=$(grep uploads upload_workfile | cut -d':' -f 2 | cut -d'"' -f 2)
rm -rf upload_workfile
done=0

curl -sS "https://www.googleapis.com/youtube/v3/playlistItems?key=${key}&part=contentDetails&playlistId=${upload_id}&maxResults=50" -o /tmp/playlist_output
while [ ${done} -lt 1 ]; do
	next_page=$(cat playlist_output | head -10 | grep nextPageToken | cut -d'"' -f 4)
	if [ -z ${next_page} ]; then
		cat playlist_output | grep videoId | cut -d'"' -f 4 >> working_list_from_yt
		done=1
	else
		cat playlist_output | grep videoId | cut -d'"' -f 4 >> working_list_from_yt
		curl -sS "https://www.googleapis.com/youtube/v3/playlistItems?key=${key}&pageToken=${next_page}&part=contentDetails&playlistId=${upload_id}&maxResults=50" -o /tmp/playlist_output
		done=0
	fi
done
rm -rf playlist_output

## Diff the lists to find new id's
cat working_list_from_yt | sort > yt_list_sorted
rm -rf working_list_from_yt

cat working_list_in_db | sort > db_list_sorted
rm -rf working_list_in_db

comm -13 db_list_sorted yt_list_sorted > get_staged
sed -e "s/$/\ ${channel_name}/" -i get_staged
cat get_staged >> get_today_from_yt
rm -rf get_staged


rm -rf db_list_sorted yt_list_sorted 
