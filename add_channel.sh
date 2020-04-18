#!/bin/bash

#######
## Adds Channel to Channel Table ##
#######

code_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${code_dir}/yt_config
start_date="1970-01-01"

echo "Enter Channel ID:"

read channel_id

echo "Enter Channel Name:"

read channel_name

echo "Enter Rotation Day (1-3):"

read rotation_day

echo "Is Channel Active (yes/no):"

read active

if [ ${active} == "yes" ]; then
	channel_active=1
else
	channel_active=0
fi

echo "Base storage path of channel (no trailing slash):"

read base_dir

mysql --user=$user --password=$password youtube << EOF
INSERT INTO channel (channel_id, channel_name, last_checked, rotation_day, active, base_dir) VALUES ("$channel_id", "$channel_name", "$start_date", "$rotation_day", "$channel_active", "$base_dir");
EOF
