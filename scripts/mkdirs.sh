#!/bin/sh

MAINMK=$(pwd)/rip.mk

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
	echo "CURTITLE := ${t}"
	echo "include $MAINMK"
	) > "$dir/Makefile"
done
