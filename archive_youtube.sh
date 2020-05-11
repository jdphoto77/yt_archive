#!/bin/bash

#######
# This is the main script, what you put in cron; it orchestrates all the madness
#######

day=$(date +%Y-%m-%d)
code_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${code_dir}/yt_config

mysql -u ${user} -p${password} -D youtube -e "select 1;" >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Aborted Run due to mariadb offline"
	exit 1
fi
cd ${code_dir}

vid_left=$(mysql -u ${user} -p${password} -D youtube -e "select count(video_id) FROM working;" | grep -v video)

if [ ${vid_left} -eq 0 ]; then
	## Get Today's Rotation Number
	last_run=$(mysql -u ${user} -p${password} -D youtube -e "select current_run_day FROM run_stats ORDER BY run_number DESC LIMIT 1;" | grep -v current)
	if [ -z ${last_run} ] || [ ${last_run} == "${rotation_days}" ]; then
		today_run_number=1
	else
		today_run_number=$((last_run+1))
	fi

	## Get Today's Channel IDs
	channels=($(mysql -u ${user} -p${password} -D youtube -e "select channel_name from channel where rotation_day = '"${today_run_number}"' AND active = '1';" | grep -v channel_name | xargs))


	## Get New ID's from channel
	for c in ${channels[@]};
	do
		${code_dir}/channel_audit.sh ${c}
	done

	today_id_count=$(cat /tmp/get_today_from_yt | wc -l)

	vids=($(cat /tmp/get_today_from_yt | awk '{print $1}' | xargs))
	chans=($(cat /tmp/get_today_from_yt | awk '{print $2}' | xargs))
	count=$(echo "${#vids[@]}")

	v=0
	while [ ${v} -lt ${count} ]; do
	mysql --user=$user --password=$password --default-character-set=utf8mb4 youtube << EOF
		INSERT INTO working (video_id, channel_id) VALUES ("${vids[$v]}", "${chans[$v]}");
EOF
		v=$((v+1))
	done
	rm -rf /tmp/get_today_from_yt
	vid_left=${count}
fi

daily_count=${vid_left}
consecutive_errors=0
while [ ${vid_left} -gt 0 ]; do
	if [ ${consecutive_errors} -eq 5 ]; then
		echo "Hit 5 consecutive DL failures; Aborting Run"
		vid_done=$((count-vid_left))
		## Set channels checked
		for c in ${channels[@]};
		do
        		mysql -u $user -p${password} youtube -e "UPDATE channel SET last_checked = '"${day}"' WHERE channel_name ='"${c}"'"
		done

		#Set Download Database
		mysql --user=$user --password=$password youtube << EOF
		INSERT INTO run_stats (run_date, count_downloaded, current_run_day) VALUES ("$day", "$vid_done", "$today_run_number");
EOF

		#Message How Many Downloaded
		curl -X POST -H 'Content-type: application/json' --data '{"text":"'$daily_count' Videos were scraped from Youtube"}' $webhook
		exit 1
	fi
	next=$(mysql -u ${user} -p${password} -D youtube -e "select video_id, channel_id from working limit 1;" | tail -n 1)
	v=$(echo ${next} | awk '{print $1}')
	c=$(echo ${next} | awk '{print $2}')
	${code_dir}/youtube_fetch.sh $v $c
	return=$?
	if [ ${return} -ne 0 ]; then
		mysql --user=$user --password=$password --default-character-set=utf8mb4 youtube << EOF
			INSERT INTO trouble_vids (video_id, channel_id) VALUES ("${v}", "${c}");
EOF
		mysql -u ${user} -p${password} -D youtube -e "DELETE FROM working where video_id = '"${v}"';"
		consecutive_errors=$((consecutive_errors+1))
	else
		mysql -u ${user} -p${password} -D youtube -e "DELETE FROM working where video_id = '"${v}"';"
		consecutive_errors=0
	fi
	vid_left=$(mysql -u ${user} -p${password} -D youtube -e "select count(video_id) from working;" | tail -n 1)
	echo "Sleeping between 2-45 seconds"
	sleep $[ ( $RANDOM % 45 )  + 1 ]
done

## Set channels checked
for c in ${channels[@]};
do
	mysql -u ${user} -p${password} youtube -e "UPDATE channel SET last_checked = '"${day}"' WHERE channel_name ='"${c}"'"
done

#Set Download Database
mysql --user=$user --password=$password youtube << EOF
INSERT INTO run_stats (run_date, count_downloaded, current_run_day) VALUES ("$day", "$daily_count", "$today_run_number");
EOF

#Message How Many Downloaded
curl -X POST -H 'Content-type: application/json' --data '{"text":"'$daily_count' Videos were scraped from Youtube"}' $webhook
