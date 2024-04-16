
#!/bin/bash

# check whether whiptail or dialog is installed
# (choosing the first command found)
read dialog <<< "$(which whiptail dialog 2> /dev/null)"

# exit if none found
[[ "$dialog" ]] || {
  echo 'neither whiptail nor dialog found' >&2
  exit 1
}

ignore_BKP=yes
SCAN_CACHE_FILE=~/.scan4install.cache
short_names_filter="sed -e \"s/Micro Focus //\""

function beginswith
{ 
	case $2 in 
		"$1"*) true;; 
		*) false;; 
	esac; 
}

function pathremove_startswith () {
	local IFS=':'
	local NEWPATH
	local DIR
	local PATHVARIABLE=${2:-PATH}
	for DIR in ${!PATHVARIABLE}
	do
		if ! beginswith $1 "$DIR";
		then
			NEWPATH=${NEWPATH:+$NEWPATH:}$DIR
		fi
	done
	export $PATHVARIABLE="$NEWPATH"
}

function remove_cobdir
{
	if [ ! ".$COBDIR" == "." ];
	then
		pathremove_startswith $COBDIR PATH
		pathremove_startswith $COBDIR LD_LIBRARY_PATH
		pathremove_startswith $COBDIR CLASSPATH
		pathremove_startswith $COBDIR COBCPY
		pathremove_startswith $COBDIR MFPRODBASE
		pathremove_startswith $COBDIR MFPLI_PRODUCT_DIR
		pathremove_startswith $COBDIR COBDIR
	fi
}

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
					PRODUCT_NAME=$(echo $line | cut -f2- -d= | eval $short_names_filter)
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
	declare FIND_ARG
	if [ -s $SCAN_CACHE_FILE ];
	then
		FIND_ARG="-newer $SCAN_CACHE_FILE"
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

	POSS_COBDIRS="$POSS_COBDIRS $(find ~ -maxdepth 4 $FIND_ARG -ipath '*/etc/cobver' -print)"
	POSS_COBDIRS="$POSS_COBDIRS $(find /opt/microfocus -maxdepth 3 $FIND_ARG -ipath '*/etc/cobver' -print)"

	(
		if [ -s $SCAN_CACHE_FILE ];
		then
			cat $SCAN_CACHE_FILE
		fi

		for i in $POSS_COBDIRS
		do
			POSS_COBDIR=$(cd $(dirname $i)/..; pwd)
			case "${ignore_BKP}_${POSS_COBDIR}" in
				yes*BKP\.*) continue ;;
			esac
			if [ -f $POSS_COBDIR/bin/cobsetenv ];
			then
				grab_mf_info $POSS_COBDIR
			fi
		done
	) | sort -r -t, -k1 | uniq | tee $SCAN_CACHE_FILE
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

	remove_cobdir	

	# exec bash --rcfile <(echo ". ~/.bashrc; . $POSS_COBDIR/bin/cobsetenv $POSS_COBDIR")
	. $POSS_COBDIR/bin/cobsetenv $POSS_COBDIR
}

function dialog_mf_cu
{
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

	scan_lines=$(scan_mf_dirs | grep -Ev "^$")
	if [ "x$scan_lines" == "x" ];
	then
		return
	fi
	readarray mf_lines <<<"$scan_lines"

	WARGS="--title \"Product?\" --menu "Choose" 20 80 ${#mf_lines[@]}"
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
		
		WARGS="$WARGS $ch \"$PRODUCT_NAME\""

		# echo "$ch = $PRODUCT_NAME"
		TS_DATE=$(date -u "+%x" -d @$TS)
		# echo " $TS_DATE -> $POSS_COBDIR"
		ch=$(( $ch + 1 ))

		# echo "$TS,$PROD_STYLE,$POSS_COBDIR,$VER,$PRODUCT_NAME,$BITX64"
	done

	tfile=$$.tmp
	eval $dialog "$(echo -e $WARGS)" 2>$tfile
	ret=$?
	echo ret is $?
	if [ ! "$ret" == "0" ];
	then
		cat $tfile
		echo Leaving..
		return
	fi
	c=$(cat $tfile)
	rm -f $tfile

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

	remove_cobdir	
	tput clear
	. $POSS_COBDIR/bin/cobsetenv $POSS_COBDIR
	# exec bash --rcfile <(echo ". ~/.bashrc; . $POSS_COBDIR/bin/cobsetenv $POSS_COBDIR")
}

ARGS=$*
for i in $ARGS
do
	case "$i" in
		dialog) dialog=dialog ;;
		no_short_names_filter) short_names_filter=cat ;;
		include_bkp_dirs) ignore_BKP= ;;
		nocache) rm -f $SCAN_CACHE_FILE ;;
		choose) dialog_mf ;;
		cu) dialog_mf_cu ;;
		csv) scan_mf_dirs ;;
		remove_cobdir) 	remove_cobdir ;;
		--) ;;
		*) echo $0: invalid argument $i
		   exit 1
	esac
done
