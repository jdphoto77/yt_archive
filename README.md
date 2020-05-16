# Description

This repo contains scripts written in bash that leverage the Youtube API to archive video's to local storage (local disk, network mounted, etc.)  It is provided without support, at this time I have no interest or cycles to handle pull requsets, etc. use at your own risk and tweak to meet your needs.  That said, I will update this repo when necessary for my work and when time permits.  There are a bunch of ways to tackle this task, this is just one way.  

The general structure and basic functionality relies on three main scripts: archive_youtube.sh, channel_audit.sh, and youtube_fetch.sh; other scripts are supporting scripts, neccessary in some ways, more of a convenience in others.  The archive_youtube.sh script quarterbacks the operation, calling out to the channel_audit.sh script and the youtube_fetch.sh script when needed. 

Which channels are checked on a given day, is controlled by the rotation_days column in the channel database as well as the rotation_days variable in the config.  My default is to assign channels to a rotation_day value of 1-3 such that channels are checked once every three days (or instances of the run, if you run it more than once per day) eg channels in rotation_day 1 are downloaded on the first instance, etc..  This spreads out the work, but keeps things pretty up to date.  This can be adjusted via the variable, and by putting the correct values in the channel database.  There are a lot of knobs to be turned here that can be handled in the code (youtube video quality, download speed throttle, time between youtube-dl invocations, etc.) most should be easy to find and some echoing occurs in the script to let the user know where things are.

The archive_audit.sh script runs in two modes (taking the argument of fs or youtube) which performs an audit between the database and your archive or the database and youtube depending on the mode.

All scripts have brief descirptions of their function in their top comment block.

# Install/Use Instructions

## Prerequisites

- At least basic knowledge of bash scripting, helpful when tweaking anything necessary for this to fit in your environment
- Current installation of youtube-dl
- MariaDB Installed and at least listening on localhost ( create a database called: youtube )
- An API key from Youtube, this can be obtained for free
- A read/write mount of the Youtube archive area, can be local or network mounted
- Patience :)

## Installation Steps

- Take care of above prerequisites
- Fill in the yt_config file with relevant information
- Create database tables per commands below, note the encoding...people use emojis in video titles...
 -- `mysql youtube < ./scheme.sql`
- Populate Channel table via the add_channel.sh script
	-- A channel's ID can be found by going to: https://socialnewsify.com/get-channel-id-by-username-youtube/
- Pre-load database with already ingested videos via the ingest_vids.sh script; read it's requirements in the comment section at the top
- Most likely useful to run an audit of the db against your archive before going against youtube
- Let'er rip, fire off the archive_youtube.sh script (probably by hand the first few times)
	-- There is a good amount of error catching in this code, but there are edge cases and some things I assume will just work

## FreeBSD (and FreeNAS)

- Create symlink `ln -s /usr/local/bin/bash /bin/bash` to run scripts unmodified

## Creating the tables

Database schema located in `scheme.sql file`. Create tables using the following command:

```bash
mysql youtube < ./scheme.sql
```

