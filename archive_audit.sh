#!/bin/bash

#####
# Audits between the local mariadb and the mounted file system or between the mariadb and youtube itself
# To take care of your API limit, may be best not to run as often as archive_youtube.sh
#####

code_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${code_dir}/yt_config
mode=$1
rotation_day=$2

if [ "${mode}" == "youtube" ]; then
	chan_list=($(mysql -u ${user} -p${password} -D youtube -e "select channel_name from channel where active = '1' and rotation_day='"${rotation_day}"';" | grep -v "channel_name" | xargs))
elif [ "${mode}" == "fs" ]; then
	chan_list=($(mysql -u ${user} -p${password} -D youtube -e "select channel_name from channel;" | grep -v "channel_name" | xargs))
else
	echo "Invalid Mode"
fi

for c in ${chan_list[@]};
do

	if [ ${mode} == "youtube" ]; then
        	db_count=$(mysql -u ${user} -p${password} -D youtube -e "select count(video_id) from video where channel_name = '"${c}"' and is_child IS NULL and archive_exclusive is NULL;" | grep -v count)

		channel_id=$(mysql -u ${user} -p${password} -D youtube -e "select channel_id from channel where channel_name = '"${c}"';" | grep -v channel_id)
		curl -sS "https://www.googleapis.com/youtube/v3/channels?key=${key}&id=${channel_id}&part=contentDetails&maxResults=50" -o upload_workfile
		upload_id=$(grep uploads upload_workfile | cut -d':' -f 2 | cut -d'"' -f 2)
		rm -rf upload_workfile

		curl -sS "https://www.googleapis.com/youtube/v3/playlistItems?key=${key}&part=contentDetails&playlistId=${upload_id}&maxResults=50" -o playlist_output
		yt_count=$(cat playlist_output | grep totalResults | cut -d':' -f 2 | cut -d',' -f 1 | sed "s/ //g")
		rm -rf playlist_output

		if [ ${db_count} -ne ${yt_count} ]; then	
			echo "Channel: ${c}    In Database: ${db_count}   Youtube: ${yt_count}"
			${code_dir}/audit_yt_deep.sh ${c}
		fi

	elif [ ${mode} == "fs" ]; then
		db_count=$(mysql -u ${user} -p${password} -D youtube -e "select count(video_id) from video where channel_name = '"${c}"' and blocked IS NULL;" | grep -v count)
		basedir=$(mysql -u ${user} -p${password} -D youtube -e "select base_dir from channel where channel_name = '"${c}"';" | grep -v "base_dir")
		fs_count=$(find /${basedir} -type f | grep mp4 | wc -l)
		if [ ${db_count} -ne ${fs_count} ]; then
			echo "Channel: ${c}    In Database: ${db_count}   File System: ${fs_count}"
			mysql -u ${user} -p${password} -D youtube -e "select video_id from video where channel_name = '"${c}"' and blocked IS NULL;" | grep -v video_id | sort > /tmp/db_ids.${c}
			find /${basedir} -type f | sed 's/.\{4\}$//' | sed 's/.*\(...........\)/\1/' | sort > /tmp/fs_ids.${c}
			if [ ${db_count} -gt ${fs_count} ]; then
				echo "ID's in DB not in FS"
				comm -13 /tmp/fs_ids.${c} /tmp/db_ids.${c}
			else
				echo "ID's in FS not in DB"
				comm -13 /tmp/db_ids.${c} /tmp/fs_ids.${c}
			fi
		fi
		rm -rf /tmp/fs_ids.*
		rm -rf /tmp/db_ids.*
	else
		echo "Bad Mode, choose youtube or fs"	
	fi
	
done
