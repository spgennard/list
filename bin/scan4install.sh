#!/bin/bash

EXIT_OR_RETURN=return
BASHRC_MODE=yes
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
SCRIPT_RC="$SCRIPT_DIR/scan4install.rc"

# Default To 24 hours
UPDATEINTERVAL="$((24 * 60 * 60))"

TMP_FILE=$$.tmp
trap "rm -f $TMP_FILE" EXIT

# If not running interactively, don't do anything
case $- in
*i*) ;;
*)
	IS_RC=$(echo $- | cut -c1)
	if [ "$IS_RC" == "-" ]; then
		return
	else
		EXIT_OR_RETURN=exit
		BASHRC_MODE=no
	fi
	;;
esac

# check whether whiptail or dialog is installed
# (choosing the first command found)
read dialog <<<"$(which dialog whiptail 2>/dev/null)"

# exit if none found
[[ "$dialog" ]] || {
	echo 'neither whiptail nor dialog found' >&2
	$EXIT_OR_RETURN
}

ignore_BKP=yes
SCAN_CACHE_FILE=~/.scan4install.cache
short_names_filter="sed -e \"s/Micro Focus //\""

function beginswith {
	case $2 in
	"$1"*) true ;;
	*) false ;;
	esac
}

function pathremove_startswith() {
	local IFS=':'
	local NEWPATH
	local DIR
	local PATHVARIABLE=${2:-PATH}
	for DIR in ${!PATHVARIABLE}; do
		if ! beginswith $1 "$DIR"; then
			NEWPATH=${NEWPATH:+$NEWPATH:}$DIR
		fi
	done
	export $PATHVARIABLE="$NEWPATH"
}

function remove_cobdir {
	if [ ! ".$COBDIR" == "." ]; then
		pathremove_startswith $COBDIR PATH
		pathremove_startswith $COBDIR LD_LIBRARY_PATH
		pathremove_startswith $COBDIR CLASSPATH
		pathremove_startswith $COBDIR COBCPY
		pathremove_startswith $COBDIR MFPRODBASE
		pathremove_startswith $COBDIR MFPLI_PRODUCT_DIR
		pathremove_startswith $COBDIR COBDIR
	fi
}

function getScanCacheUpdateTime() {
	local aptDate="$(stat -c %Y $SCAN_CACHE_FILE)"
	local nowDate="$(date +'%s')"

	echo $((nowDate - aptDate))
}

function grab_mf_info {
	declare POSS_COBDIR=$1
	declare PRODUCT_NAME=
	declare BITX64=
	declare TS=$(stat -c "%Y" $POSS_COBDIR)
	declare VER=0.0.0

	if [ -f $POSS_COBDIR/etc/cobver ]; then
		declare PROD_STYLE=mf
		while read line; do
			case $line in
			PTI=64*)
				BITX64=64
				;;
			cobol*)
				VER=$(echo $line | cut -f2 -d" ")
				;;
			PTI=*for* | PTI=*Unix* | PTI=*Visual\ COBOL* | PTI=*Enterprise\ Developer* | *Community\ Edition*)
				PRODUCT_NAME=$(echo $line | cut -f2- -d= | eval $short_names_filter)
				;;
			esac
		done <$POSS_COBDIR/etc/cobver
	fi

	if [ ! "x$PRODUCT_NAME" == "x" ]; then
		echo "$TS,$PROD_STYLE,$POSS_COBDIR,$VER,$PRODUCT_NAME,$BITX64"
	fi
}

function grab_acu_info {

	declare POSS_COBDIR=$1
	declare PRODUCT_NAME=AcuCOBOL
	declare BITX64=
	declare TS=$(stat -c "%Y" $POSS_COBDIR)
	declare VER=0.0.0
	declare PROD_STYLE=acu

	if [ ! "x$PRODUCT_NAME" == "x" ]; then
		echo "$TS,$PROD_STYLE,$POSS_COBDIR,$VER,$PRODUCT_NAME,$BITX64"
	fi
}

function scan_mf_dirs {
	declare POSS_COBDIR
	declare POSS_COBDIRS
	declare FIND_ARG

	if [ -s $SCAN_CACHE_FILE ]; then
		lastScanUpdateTime="$(getScanCacheUpdateTime)"
		if [[ "${lastScanUpdateTime}" -lt "${UPDATEINTERVAL}" ]]; then
			cat $SCAN_CACHE_FILE
			return
		fi
		FIND_ARG="-newer $SCAN_CACHE_FILE"
	fi

	# MF
	if [ ! "x$COBDIR" == "x" ]; then
		POSS_COBDIRS="$COBDIR/etc/cobver"
	fi

	if [ ! "x$MFPRODBASE" == "x" ]; then
		POSS_COBDIRS="$MFPRODBASE/etc/cobver $POSS_COBDIRS"
	fi

	POSS_COBDIRS="$POSS_COBDIRS $(find ~ -maxdepth 3 -type f $FIND_ARG -ipath '*/etc/cobver' -print 2>/dev/null)"
	POSS_COBDIRS="$POSS_COBDIRS $(find ~ -maxdepth 3 -type f $FIND_ARG -ipath '*/etc/cblconfig' -print 2>/dev/null)"
	POSS_COBDIRS="$POSS_COBDIRS $(find /opt/microfocus -maxdepth 3 -type f $FIND_ARG -ipath '*/etc/cobver' -print 2>/dev/null)"

	(
		if [ -s $SCAN_CACHE_FILE ]; then
			cat $SCAN_CACHE_FILE
		fi

		for i in $POSS_COBDIRS; do
			POSS_COBDIR=$(
				cd $(dirname $i)/..
				pwd
			)
			case "$i" in
			*cblconfig)
				if [ -f $POSS_COBDIR/etc/cblconfig ]; then
					grab_acu_info $POSS_COBDIR
				fi
				;;
			*cobver)
				case "${ignore_BKP}_${POSS_COBDIR}" in
				yes*BKP\.*) continue ;;
				esac
				if [ -f $POSS_COBDIR/bin/cobsetenv ]; then
					grab_mf_info $POSS_COBDIR
				fi
				;;
			esac
		done
	) | sort -r -t, -k1 | uniq | tee $TMP_FILE

	mv $TMP_FILE $SCAN_CACHE_FILE
}

function start_shell_or_env {
	saveIFS=$IFS
	IFS=","
	set -- $*
	TS=$1
	PROD_STYLE=$2
	POSS_COBDIR=$3
	VER=$4
	PRODUCT_NAME=$5
	BITX64=$6
	IFS=$saveIFS

	remove_cobdir
	case "$PROD_STYLE" in
	mf)
		if [ ! -f $POSS_COBDIR/bin/cobsetenv ]; then
			echo "Selection $actual_c not found"
			return
		fi
		if [ "$BASHRC_MODE" == "no" ]; then
			exec bash --rcfile <(echo ". ~/.bashrc; . $POSS_COBDIR/bin/cobsetenv $POSS_COBDIR")
		else
			. $POSS_COBDIR/bin/cobsetenv $POSS_COBDIR
		fi
		;;
	acu)
		if [ ! -f $POSS_COBDIR/bin/acusetenv.sh ]; then
			echo "Selection $actual_c not found"
			return
		fi
		if [ "$BASHRC_MODE" == "no" ]; then
			exec bash --rcfile <(echo ". ~/.bashrc; . $POSS_COBDIR/bin/acusetenv.sh $POSS_COBDIR")
		else
			. $POSS_COBDIR/bin/acusetenv.sh $POSS_COBDIR
		fi
	;;
	esac

}

function dialog_mf {
	declare TS
	declare PROD_STYLE
	declare POSS_COBDIR
	declare VER
	declare PRODUCT_NAME
	declare BITX64
	declare prodinfo

	scan_lines=$(scan_mf_dirs | grep -Ev "^$")
	if [ "x$scan_lines" == "x" ]; then
		$EXIT_OR_RETURN
	fi
	readarray mf_lines <<<"$scan_lines"

	ch=1
	for mf_line in "${mf_lines[@]}"; do
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
		# echo " $TS_DATE -> $POSS_COBDIR"
		ch=$(($ch + 1))

		# echo "$TS,$PROD_STYLE,$POSS_COBDIR,$VER,$PRODUCT_NAME,$BITX64"
	done

	if [ ! "${#mf_lines[@]}" == "1" ]; then
		read -p 'Which? ' -a c
	else
		c=1
	fi

	actual_c=$c
	c=$(($c - 1))
	if [ "x${mf_lines[c]}" == "x" ]; then
		return
	fi

	start_shell_or_env ${mf_lines[c]}
}

function dialog_mf_cu {
	declare TS
	declare PROD_STYLE
	declare POSS_COBDIR
	declare VER
	declare PRODUCT_NAME
	declare BITX64
	declare prodinfo
	declare scan_lines
	declare WARGS
	declare ch
	declare BOX_MLIMIT
	declare BOX_LINES

	scan_lines=$(scan_mf_dirs | grep -Ev "^$")
	if [ "x$scan_lines" == "x" ]; then
		$EXIT_OR_RETURN
	fi
	readarray mf_lines <<<"$scan_lines"

	BOX_MLIMIT=$((${#mf_lines[@]}))

	BOX_LINES=$((BOX_MLIMIT + 6))

	if [[ $BOX_LINES -gt $LINES ]]; then
		read dialog <<<"$(which dialog 2>/dev/null)"

		# exit if none found
		[[ "$dialog" ]] || {
			dialog_mf $*
			return
		}
	fi
	# WARGS="--title \"Product?\" --menu "Choose" 20 80 ${#mf_lines[@]}"
	WARGS="--menu \"Select Product\" $BOX_LINES 80 ${#mf_lines[@]}"
	ch=1
	for mf_line in "${mf_lines[@]}"; do
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

		WARGS="$WARGS $ch \"$PRODUCT_NAME\""

		# echo "$ch = $PRODUCT_NAME"
		TS_DATE=$(date -u "+%x" -d @$TS)
		# echo " $TS_DATE -> $POSS_COBDIR"
		ch=$(($ch + 1))

		# echo "$TS,$PROD_STYLE,$POSS_COBDIR,$VER,$PRODUCT_NAME,$BITX64"
	done

	if [ ! "${#mf_lines[@]}" == "1" ]; then
		tput smcup
		tfile=$$.tmp
		eval $dialog "$(echo -e $WARGS)" 2>$tfile
		ret=$?
		if [ ! "$ret" == "0" ]; then
			tput rmcup
			cat $tfile
			return
		fi
		c=$(cat $tfile)
		rm -f $tfile
		tput rmcup
	else
		c=1
	fi

	c=$(($c - 1))

	start_shell_or_env ${mf_lines[c]}
	if [ "x${mf_lines[c]}" == "x" ]; then
		return
	fi
}

ARGS=$*
if [ "x$ARGS" == "x" ]; then
	dialog_mf_cu
	$EXIT_OR_RETURN
fi

for i in $ARGS; do
	case "$i" in
	dialog) dialog=dialog ;;
	no_short_names_filter) short_names_filter=cat ;;
	include_bkp_dirs) ignore_BKP= ;;
	nocache) rm -f $SCAN_CACHE_FILE ;;
	choose) dialog_mf ;;
	cu) dialog_mf_cu ;;
	csv) scan_mf_dirs ;;
	remove_cobdir) remove_cobdir ;;
	--) ;;
	*)
		echo $0: invalid argument $i
		$EXIT_OR_RETURN
		;;
	esac
done
