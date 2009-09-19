#!/bin/sh

# Part of dvd-ripper - rips DVDs to h264/vorbis|ac3/mkv
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

MAINMK=$(pwd)/scripts/rip.mk

CFG=$1
if [ -z "$CFG" ] || [ ! -e "$CFG" ];then
	echo "Usage: $0 <config-file>"
	exit
fi

for t in $(sed -nr 's/^CONFIG_TITLES=(.*)$/\1/p' < "$CFG");do
	output=$(sed -nr 's/^CONFIG_TITLE_'$t'_OUTPUT=(.*)$/\1/p' < "$CFG")
	dir=$(mktemp -d -p . "rip.$(basename $output).XXXXXX")
	(
	echo "include $CFG"
	echo "CFG_PREFIX := CONFIG_TITLE_${t}_"
	echo "include $MAINMK"
	) > "$dir/Makefile"
done
