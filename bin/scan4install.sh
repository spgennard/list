
#!/bin/bash

function grab_mf_info
{
	POSS_COBDIR=$1
	PRODUCT_NAME=
	BITX64=
	TS=$(stat -c "%Y" $POSS_COBDIR)
	declare VER=0.0.0
	if [ -f $POSS_COBDIR/etc/cobver ];
	then
		PROD_STYLE=mf
		while read line
		do
			case $line in
				PTI=64*) 
					BITX64=64 
					;;
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
		echo "$TS,$PROD_STYLE,$POSS_COBDIR,$VER,$PRODUCT_NAME,$BITX64"
	fi
}

function scan_mf_dirs
{
	# MF
	POSS_COBDIRS=
	if [ ! "x$COBDIR" == "x" ];
	then
		POSS_COBDIRS="$COBDIR/etc/cobver"
	fi

	if [ ! "x$MFPRODBASE" == "x" ];
	then
		POSS_COBDIRS="$MFPRODBASE/etc/cobver $POSS_COBDIRS"
	fi

	POSS_COBDIRS="$POSS_COBDIRS $(find ~ -maxdepth 5 -name 'cobver' -print)"
	POSS_COBDIRS="$POSS_COBDIRS $(find /opt/microfocus -maxdepth 3 -name 'cobver' -print)"

	for i in $POSS_COBDIRS
	do
		POSS_COBDIR=$(cd $(dirname $i)/..; pwd)
		case "$POSS_COBDIR" in
			*BKP\.*) continue ;;
		esac
		if [ -f $POSS_COBDIR/bin/cobsetenv ];
		then
			grab_mf_info $POSS_COBDIR
		fi
	done | sort -r -t, -k1 | uniq
}

scan_mf_dirs
