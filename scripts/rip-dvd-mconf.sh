#!/bin/sh

# Part of rip-dvd - rips DVDs to h264/vorbis|ac3/mkv
# Copyright (C) 2009 Thomas Spurden
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

function rel2abs {
	if [ "${1:0:1}" = "/" ];then
		echo "$1"
	else
		echo "$(pwd)/$1"
	fi
}


DVDDIR=$(rel2abs $1)
PREFIX=$2
OUTBASE=$3
[ -z "$OUTBASE" ] && OUTBASE=.

OUTBASE=$(rel2abs $OUTBASE)

if [ -z $DVDDIR ];then
	echo "Usage: $0 <dvd-source> [name-prefix] [output-base]"
	exit
fi

nt=$(mplayer -dvd-device "$DVDDIR" dvd:// -identify -quiet -frames 0 2>&1 | sed -nr 's/^ID_DVD_TITLES=([0-9]+)$/\1/p')

if [ -w "$DVDDIR" ] && [ -d "$DVDDIR" ];then
	CFGLOC="$DVDDIR/config"
else
	CFGLOC="$(pwd)/$(basename $DVDDIR).config"
fi

(
awk --assign dvddir=$DVDDIR --assign cfgloc=$CFGLOC --assign outdir=$OUTBASE 'END {
	print "mainmenu \"DVD at " dvddir "\""
	print "menu \"Source options\""
	print "config SOURCE_DVD"
	print "\tstring \"mencoder dvd-device\""
	print "\tdefault \"" dvddir "\""
	print "config SOURCE_CACHE"
	print "\tstring \"mencoder cache size (0 disables)\""
	print "\tdefault 0"
	print "config CFG"
	print "\tstring \"Config file storage location\""
	print "\tdefault \"" cfgloc "\""
	print "endmenu"
	print "config OUTPUT_DIR"
	print "\tstring \"Output directory\""
	print "\tdefault \"" outdir "\""
}' < /dev/null

for t in $(seq 1 $nt);do
	mplayer -dvd-device "$DVDDIR" dvd://$t -identify -quiet -frames 0 2>&1 | awk -F= --assign title=$t --assign prefix="$PREFIX" '
			/ID_AUDIO_ID/ { auds[$2] = $2; }
			/ID_AID_/ { split($1, tmp, "_"); auds[tmp[3]]=$2; }
			/ID_SID_/ { split($1, tmp, "_"); subs[tmp[3]]=$2; }
			/ID_DVD_TITLE_[0-9]+_LENGTH/ { split($1, tmp, "_"); tlen[tmp[4]] = $2; }
			/ID_DVD_TITLE_[0-9]+_CHAPTERS/ { split($1, tmp, "_"); tchap[tmp[4]] = $2; }
			END {
				print "config TITLE_" title
				print "\tbool \"Rip title " title " (" tlen[title] "s / " tchap[title] " chapters)\""
				print "\tdefault n"
				print "config TITLE_" title "_NAME"
				print "\tstring \"Name\""
				print "\tdefault \"" prefix "\""
				print "\tdepends on TITLE_" title
				print "config TITLE_" title "_DEINTERLACE"
				print "\tbool \"Deinterlace the video\""
				print "\tdefault y"
				print "\tdepends on TITLE_" title
				print "menu \"Video options\""
				print "\tdepends on TITLE_" title
				print "config TITLE_" title "_START"
				print "\tstring \"Starting time (must be in a format mencoder can understand)\""
				print "\tdefault 0.1"
				print "config TITLE_" title "_LENGTH"
				print "\tstring \"Amount of input to rip (must be a time that mencoder can understand)\""
				print "\tdefault \"\""
				print "config TITLE_" title "_GET_CHAPTERS"
				print "\tbool \"Get the chapter listing from the dvd info\""
				if(tchap[title] > 1) {
					print "\tdefault y"
				} else {
					print "\tdefault n"
				}
				print "config TITLE_" title "_VIDEO_CRF"
				print "\tint \"CRF for x264enc\""
				print "\trange 1 50"
				print "\tdefault 22"
				print "config TITLE_" title "_VIDEO_THREADS"
				print "\tint \"Number of threads for encoder to use (0 is auto)\""
				print "\trange 0 16"
				print "\tdefault 0"
				print "config TITLE_" title "_VIDEO_CROP"
				print "\tstring \"Crop rectangle for mencoder (w:h:x:y) (leave blank for autodetect)\""
				print "\tdefault \"\""
				print "config TITLE_" title "_VIDEO_ASPECT"
				print "\tstring \"Aspect ratio of the video (default is autodetect)\""
				print "\tdefault \"\""
				print "endmenu"
				for(v in auds) {
					print "config TITLE_" title "_AUDIO_" v
					print "\tbool \"Rip audio stream " v " (" auds[v] ")\""
					if(v == 128) {
						print "\tdefault y"
					} else {
						print "\tdefault n"
					}
					print "\tdepends on TITLE_" title
					print "config TITLE_" title "_AUDIO_" v "_COPY"
					print "\tbool \"Copy audio track (no transcoding)\""
					print "\tdefault no"
					print "\tdepends on TITLE_" title "_AUDIO_" v
					print "config TITLE_" title "_AUDIO_" v "_QUALITY"
					print "\tint \"Vorbis quality for audio stream " v "\""
					print "\trange -1 10"
					print "\tdefault 3"
					print "\tdepends on TITLE_" title "_AUDIO_" v " && !TITLE_" title "_AUDIO_" v "_COPY"
				}
				for(v in subs) {
					print "config TITLE_" title "_SUBTITLE_" v
					print "\tbool \"Rip subtitle stream " v " (" subs[v] ")\""
					print "\tdefault n"
					print "\tdepends on TITLE_" title
				}
			}'
done
) > Config

/usr/src/linux/scripts/kconfig/mconf Config

rm Config

[ ! -e .config ] && exit

TITLES=$(sed -nr 's/^CONFIG_TITLE_([0-9]+)=y$/\1/p' < .config | sort -n | xargs echo)

(
echo "CONFIG_TITLES=$TITLES"
for t in $TITLES;do
	SUBS=$(sed -nr 's/^CONFIG_TITLE_'$t'_SUBTITLE_([0-9]+)=y$/\1/p' < .config | sort -n | xargs echo)
	AUDS=$(sed -nr 's/^CONFIG_TITLE_'$t'_AUDIO_([0-9]+)=y$/\1/p' < .config | sort -n | xargs echo)
	echo "CONFIG_TITLE_${t}_SUBTITLES=$SUBS"
	echo "CONFIG_TITLE_${t}_AUDIOS=$AUDS"
	FNAME=$(sed -nr 's/^CONFIG_TITLE_'$t'_NAME="([^"]+)"$/\1/p' < .config | tr ' ' '_' | tr -d '"'"'").mkv
	echo "CONFIG_TITLE_${t}_OUTPUT="'"'"$FNAME"'"'
	echo 'CONFIG_TITLE_'${t}'_TITLE="'${t}'"'
done
) >> .config

CFG=$(sed -nr 's/^CONFIG_CFG="([^"]+)"$/\1/p' < .config)

tr -d '"' < .config > "$CFG"
rm .config

./scripts/mkdirs.sh "$CFG"
