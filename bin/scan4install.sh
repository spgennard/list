#!/bin/bash

function grab_info
{
	POSS_COBDIR=$1
	PRODUCT_NAME=
	TS=$(stat -c "%Y" $POSS_COBDIR)
	declare VER=0.0.0
	if [ -f $POSS_COBDIR/etc/cobver ];
	then
		while read line
		do
			case $line in
				cobol*)
					VER=$(echo $line | cut -f2 -d" ")
					;;
				PTI=*for*|PTI=*Unix*|PTI=*Visual\ COBOL*|PTI=*Enterprise\ Developer*|*Community\ Edition*)
					PRODUCT_NAME=$(echo $line | cut -f2- -d=)
					;;
			esac
		done < $POSS_COBDIR/etc/cobver
	fi

	if [ ! "x$PRODUCT_NAME" == "x" ];
	then
		echo "$TS,$POSS_COBDIR,$VER,$PRODUCT_NAME"
	fi
}

POSS_COBDIRS="$(find ~ -maxdepth 5 -name 'cobver' -print)"
POSS_COBDIRS="$POSS_COBDIRS $(find /opt/microfocus -maxdepth 3 -name 'cobver' -print)"

for i in $POSS_COBDIRS
do
	POSS_COBDIR=$(cd $(dirname $i)/..; pwd)
	case "$POSS_COBDIR" in
		*BKP\.*) continue ;;
	esac
	if [ -f $POSS_COBDIR/bin/cobsetenv ];
	then
		grab_info $POSS_COBDIR
	fi
done | sort -r -t, -k1
