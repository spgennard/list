
#!/bin/bash

function grab_mf_info
{
	declare POSS_COBDIR=$1
	declare PRODUCT_NAME=
	declare BITX64=
	declare TS=$(stat -c "%Y" $POSS_COBDIR)
	declare VER=0.0.0

	if [ -f $POSS_COBDIR/etc/cobver ];
	then
		declare PROD_STYLE=mf
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
	declare POSS_COBDIR
	declare POSS_COBDIRS
	declare SCAN_CACHE_FILE=~/.scan4install.cache
	if [ -f  $SCAN_CACHE_FILE ];
	then
		SC_STAT=$(stat -c "%Y" $SCAN_CACHE_FILE)
		SC_STAT_NOW=$(date +%s)
		SC_ELAPTED=$((SC_STAT_NOW - SC_STAT))
		if [ "$SC_ELAPTED" -lt "2628000" ];
		then
			cat $SCAN_CACHE_FILE
			return
		fi
	fi

	# MF
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
	done | sort -r -t, -k1 | uniq | tee $SCAN_CACHE_FILE
}

function dialog_mf
{
	declare TS
	declare PROD_STYLE
	declare POSS_COBDIR
	declare VER
	declare PRODUCT_NAME
	declare BITX64
	declare prodinfo
	
	scan_lines=$(scan_mf_dirs | grep -Ev "^$")
	if [ "x$scan_lines" == "x" ];
	then
		return
	fi
	readarray mf_lines <<<"$scan_lines"

	ch=1
	for mf_line in "${mf_lines[@]}"
	do
		saveIFS=$IFS
		IFS=","
		prodinfo=($mf_line)
		IFS=$saveIFS

		TS=${prodinfo[0]}
		PROD_STYLE=${prodinfo[1]}
		POSS_COBDIR=${prodinfo[2]}
		VER=${prodinfo[3]}
		PRODUCT_NAME=${prodinfo[4]}
		BITX64=${prodinfo[5]}
		
		echo "$ch = $PRODUCT_NAME"
		TS_DATE=$(date -u "+%x" -d @$TS)
		echo " $TS_DATE -> $POSS_COBDIR"
		ch=$(( $ch + 1 ))

		# echo "$TS,$PROD_STYLE,$POSS_COBDIR,$VER,$PRODUCT_NAME,$BITX64"
	done

	read -p 'Which? ' -a c

	c=$(( $c - 1 ))
	saveIFS=$IFS
	IFS=","
	set -- ${mf_lines[c]}
	TS=$1
	PROD_STYLE=$2
	POSS_COBDIR=$3
	VER=$4
	PRODUCT_NAME=$5
	BITX64=$6
	IFS=$saveIFS


	exec bash --rcfile <(echo ". ~/.bashrc; . $POSS_COBDIR/bin/cobsetenv $POSS_COBDIR")
}

dialog_mf
