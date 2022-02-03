#! /bin/bash

# The contents of this file are subject to the VTECRM License Agreement
# ("licenza.txt"); You may not use this file except in compliance with the License
# The Original Code is: VTECRM
# The Initial Developer of the Original Code is VTECRM LTD.
# Portions created by VTECRM LTD are Copyright (C) VTECRM LTD.
# All Rights Reserved.

VERSION="1.4"

#
# Installer for VTE
#
# Changelog
#
# Version 1.4
#  . Fix dependencies install in empty host
#
# Version 1.3
#  . Add parameter to install required packages
#
# Version 1.2
#  . Support for vteversion file
#
# Version 1.1
#  . Fixed VTE Url
#
# Version 1.0
#  . First beta release
#

# CONSTANTS

DEBUG_LEVEL_DEBUG=4
DEBUG_LEVEL_INFO=3
DEBUG_LEVEL_WARNING=2
DEBUG_LEVEL_ERROR=1
RETCODE_OK=0
RETCODE_FAIL=1
RETCODE_BREAK=2

CRMVILLAGE_VTE="https://partner.vtecrm.net/"
UPDATE_SERVER="https://autoupdate.vtecrm.net/"


# CONFIG VARIABLES
USECOLORS=1
DEBUG=$DEBUG_LEVEL_INFO
LOGDEBUG=$DEBUG_LEVEL_DEBUG
VTEDIR=""
WORKDIR=~/.vtecrm/
PACKAGESDIR="$WORKDIR"packages/
TEMPDIR="$WORKDIR"temp/


# GLOBAL VARIABLES
STATUS=""
VTEREVISION=0
DESTREVISION=0
PACKAGEFILE=""

USERNAME=""
ACCESSKEY=""
HASHEDKEY=""


# command line flags
WWWUSERS=""
SKIPUPGRADE=0
POSTPONEUPGRADE=0
FORCEUPGRADE=0
INSTALLDEPS=0
DEPSAPACHE=0
DEPSMYSQL=0
DEPSPHP=0
DEPSOTHER=0
USELOCALPKG=""


# FUNCTIONS
write_log () {
	local now=$(date +"%Y-%m-%d %H:%M:%S")
	if [ -n "$LOGFILE" -a -w "$LOGFILE" ]; then
		echo "[$now] $1" >> "$LOGFILE"
	fi
}

write_rec () {
	local now=$(date +"%Y-%m-%d %H:%M:%S")
	if [ -n "$RECFILE" -a -w "$RECFILE" ]; then
		echo "[$now] $1" >> "$RECFILE"
	fi
}

print_text () {
	echo $1
}

debug () {
	[ $DEBUG -ge $DEBUG_LEVEL_DEBUG ] && print_text "${COLOR_WHITE}[DEBUG]${COLOR_NORMAL} $1"
	[ $LOGDEBUG -ge $DEBUG_LEVEL_DEBUG ] && write_log "[DEBUG] $1"
}

info () {
	[ $DEBUG -ge $DEBUG_LEVEL_INFO ] && print_text "${COLOR_CYAN}[INFO]${COLOR_NORMAL} $1"
	[ $LOGDEBUG -ge $DEBUG_LEVEL_INFO ] && write_log "[INFO] $1"
}

warning () {
	[ $DEBUG -ge $DEBUG_LEVEL_WARNING ] && print_text "${COLOR_YELLOW}[WARNING]${COLOR_NORMAL} $1"
	[ $LOGDEBUG -ge $DEBUG_LEVEL_WARNING ] && write_log "[WARNING] $1"
}

error () {
	[ $DEBUG -ge $DEBUG_LEVEL_ERROR ] && print_text "${COLOR_RED}[ERROR]${COLOR_NORMAL} $1"
	[ $LOGDEBUG -ge $DEBUG_LEVEL_ERROR ] && write_log "[ERROR] $1"
}

init_subfolder () {
	mkdir -p "$WORKDIR""vte_installer"
	if [ -w "$WORKDIR""vte_installer" ]; then
		WORKDIR="$WORKDIR""vte_installer/"
		TEMPDIR="$WORKDIR""temp/"
		PACKAGESDIR="$WORKDIR""packages/"
	else 
		error "Unable to create folder ${WORKDIR}vte_installer"
		exit $RETCODE_FAIL
	fi
	mkdir -p "$TEMPDIR"
	mkdir -p "$PACKAGESDIR"
}

init_log () {
	local now=$(date +"%Y%m%d-%H%M%S")
	local LOGNAME="$now""_installer.log"
	local RECNAME="$now""_rec.rec"
	LOGFILE="$WORKDIR"$LOGNAME
	RECFILE="$WORKDIR"$RECNAME
	touch "$LOGFILE"
	if [ ! -w "$LOGFILE" ]; then
		error "Unable to log to file $LOGFILE"
		exit $RETCODE_FAIL
	fi
	debug "Logging to $LOGFILE"
	
	touch "$RECFILE"
}

init_colors () {
	# first set all colors to 0
	COLOR_BOLD=""
	COLOR_UNDERLINE=""
	COLOR_STANDOUT=""
	COLOR_NORMAL=""
	COLOR_BLACK=""
	COLOR_RED=""
	COLOR_GREEN=""
	COLOR_YELLOW=""
	COLOR_BLUE=""
	COLOR_MAGENTA=""
	COLOR_CYAN=""
	COLOR_WHITE=""
	
	if [ $USECOLORS -eq 0 ]; then
		return
	fi
	
	# then check if we are using a real terminal and get the color codes
	command -v "tput" > /dev/null 2>&1 && [ -t 1 ]; { 
		local NCOL=$(tput colors)
		if [ -n "$NCOL" -a $NCOL -ge 8 ]; then
			COLOR_BOLD="$(tput bold)"
			COLOR_UNDERLINE="$(tput smul)"
			COLOR_STANDOUT="$(tput smso)"
			COLOR_NORMAL="$(tput sgr0)"
			COLOR_BLACK="$(tput setaf 0)"
			COLOR_RED="$(tput setaf 1)"
			COLOR_GREEN="$(tput setaf 2)"
			COLOR_YELLOW="$(tput setaf 3)"
			COLOR_BLUE="$(tput setaf 4)"
			COLOR_MAGENTA="$(tput setaf 5)"
			COLOR_CYAN="$(tput setaf 6)"
			COLOR_WHITE="$(tput setaf 7)"
		fi
	}
}

# reads a password
ask_pwd () {
	# $1 = text
	
	local PWD=""
	
	echo -n "$1: "
	while IFS= read -r -s -n 1 char; do
		if [[ $char == $'\0' ]]; then
			echo ""
			break
		elif [[ $char == $'\177' ]]; then
			if [ -n "$PWD" ]; then
				echo -e -n '\b \b'
				PWD="${PWD%?}"
			fi
		else 
			echo -n "*"
			PWD="${PWD}${char}"
		fi
	done
	write_rec "$1: *****"
	write_log "$1: *****"
	_RET="$PWD"
}

ask () {
	# $1 = question
	# $2 = possible answers
	
	local question="$1 "
	
	if [ -n "$2" ]; then
		question="$question""($2) "
	fi
	question="$question"": "
	echo ""
	echo -n "$question"
	
	ans=""
	
	while [ -z "$ans" ]; do
		# read the answer
		read ans
		if [ -z "$ans" ]; then
			echo -n "Please answer $2 : "
		fi
	done
	
	# transform to lowercase
	ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
	
	write_rec "$question $ans"
	write_log "$question $ans"
	_RET=$ans
}

extract_php_global_var () {
	# $1 = php file
	# $2 = variable name
	if [ ! -r "$1" ]; then
		error "PHP file $1 not found"
		exit $RETCODE_FAIL
	fi
	# escape variable name (so i can search for arrays also)
	local varname=$(echo -n "$2" | sed 's/[][]/\\\0/g')

	local ROW=$(grep -m 1 -o -E "^[[:space:]]*\\\$$varname[[:space:]]*=[[:space:]]*['\"]?.*['\"]?[[:space:]]*;" "$1")
	local VALUE=$(echo -n "$ROW" | sed -r "s/.*\\\$$varname[[:space:]]*=[[:space:]]*['\"]?//" | sed -r "s/['\"]?[[:space:]]*;\$//" )
	_RET=$VALUE
}

extract_php_version_var () {
	# $1 = vtedir
	# $2 = variable name
	if [ -f "$1"vteversion.php -a -r "$1"vteversion.php ]; then
		extract_php_global_var "$1"vteversion.php "$2"
	elif [ -f "$1"vtigerversion.php -a -r "$1"vtigerversion.php ]; then
		extract_php_global_var "$1"vtigerversion.php "$2"
	else
		error "Unable to find vteversion file";
		exit $RETCODE_FAIL
	fi
}

create_workdir () {
	debug "Creating working directory..."
	mkdir -p "$1" >/dev/null 2>&1
	if [ ! -w "$WORKDIR" ]; then
		error "Unable to create working directory $1"
		exit $RETCODE_FAIL
	fi
	touch "$1"testfile
	if [ ! -r "$1"testfile ]; then
		error "Working directory $1 is not writable"
		exit $RETCODE_FAIL
	fi
	rm -f "$1"testfile >/dev/null 2>&1
	mkdir -p "$PACKAGESDIR"
}

is_valid_user () {
	# $1 = username to test
	# return 0=invalid
	_RET=0
	id -u "$1" 1>/dev/null 2>&1 && _RET=1
}

is_valid_group () {
	# $1 = groupname to test
	# return 0=invalid
	_RET=0
	id -g "$1" 1>/dev/null 2>&1 && _RET=1
}

# retrieves the user and group of the webserver
# this is a very rough way to do things
get_httpd_user () {
	
	local USR=""
	local GRP=""
	
	if [ -n "$WWWUSERS" ]; then
		USR=$(echo -n $WWWUSERS | cut -f 1 -d ":")
		GRP=$(echo -n $WWWUSERS | cut -f 2 -d ":")
		is_valid_user "$USR"
		if [ $_RET -eq 0 ]; then 
			error "The chosen user doesn't exist on this system"
			exit $RETCODE_FAIL
		fi
		is_valid_group "$GRP"
		if [ $_RET -eq 0 ]; then 
			error "The chosen group doesn't exist on this system"
			exit $RETCODE_FAIL
		fi
		HTTPD_USER=$USR
		HTTPD_GROUP=$GRP
		debug "Using $HTTPD_USER:$HTTPD_GROUP as user and group for files"
		return
	fi
	
	debug "Detecting web server user and group..."
	
	# test for apache
	if [ -r "/etc/apache2/envvars" ]; then
		USR=$(bash -c 'source /etc/apache2/envvars && echo $APACHE_RUN_USER')
		GRP=$(bash -c 'source /etc/apache2/envvars && echo $APACHE_RUN_GROUP')
	fi
	# test for apache on CentOS
	if [ -z "$USR" -a -r "/etc/httpd/conf/httpd.conf" ]; then
		USR=$(grep "^User " /etc/httpd/conf/httpd.conf | sed 's/User\s*//')
		GRP=$(grep "^Group " /etc/httpd/conf/httpd.conf | sed 's/Group\s*//')
	fi
	# TODO: other systems, other webservers...
	# fallback test on file
	if [ -z "$USR" ]; then
		USR=$(stat -c '%U' "$VTEDIR"config.inc.php)
		GRP=$(stat -c '%G' "$VTEDIR"config.inc.php)
	fi
	
	if [ -n "$USR" -a -n "$GRP" ]; then
		is_valid_user "$USR"
		if [ $_RET -eq 1 ] ; then HTTPD_USER=$USR; fi
		is_valid_group "$GRP"
		if [ $_RET -eq 1 ] ; then HTTPD_GROUP=$GRP; fi
	fi
		
	ask "The user and group for the web server have been detected as $HTTPD_USER:$HTTPD_GROUP. Is this correct?" "Y/N"
	if [ "$_RET" = 'n' ]; then
		while true; do
			ask "Please type the user" ""
			USR=$_RET
			is_valid_user "$USR"
			if [ $_RET -eq 1 ]; then 
				break
			else
				warning "The chosen user doesn't exist on this system"
			fi
		done
		while true; do
			ask "Please type the group" ""
			GRP=$_RET
			is_valid_group "$GRP"
			if [ $_RET -eq 1 ]; then 
				break
			else
				warning "The chosen group doesn't exist on this system"
			fi
		done
		HTTPD_USER=$USR
		HTTPD_GROUP=$GRP
	fi
	
	debug "Using $HTTPD_USER:$HTTPD_GROUP as user and group for files"
}

check_command () {
	debug "Checking $1..."
	command -v "$1" > /dev/null 2>&1 || { error "Command $1 not found."; exit $RETCODE_FAIL; }
}

vtews_call () {
	# $1 = wsname
	# $2...$n = parameters in form $2 = name, $3 = value, $3 = name2, $4 = value ....
	# if VTEWSSESSIONID is defined, append it to the request
	# return 0 on error, the json encoded result otherwise
	
	# prepare data
	local DOPOST=1
	local WSNAME="$1"
	local data=""
	
	shift
	while [ $# -gt 0 ]; do
		
		local PNAME="$1"
		shift
		local PVAL="$1"
		shift
		
		[ -n "$data" ] && data="$data""&"
		data="$data""${PNAME}="$(php -r 'echo urlencode($argv[1]);' "$PVAL")
	done
	
	# append session id
	if [ -n "$VTEWSSESSIONID" ]; then
		[ -n "$data" ] && data="$data""&"
		data="$data""sessionName="$(php -r 'echo urlencode($argv[1]);' "$VTEWSSESSIONID")
	fi
	
	if [ "$WSNAME" = "getchallenge" ]; then
		DOPOST=0
	fi
	
	debug "Calling webservice on ${CRMVILLAGE_VTE}: $WSNAME"

	if [ $DOPOST -eq 1 ]; then
		local OUTPUT=$(wget --quiet --timeout 20 "${CRMVILLAGE_VTE}webservice.php?operation=$WSNAME" --post-data="$data" -O - )
	else
		local OUTPUT=$(wget --quiet --timeout 20 "${CRMVILLAGE_VTE}webservice.php?operation=${WSNAME}&${data}" -O - )
	fi

	local success=$(php -r 'if ($d = json_decode($argv[1], true)) { echo ($d["success"] ? 1 : 0); } else echo 0; ' "$OUTPUT")
	if [ $success -eq 1 ]; then
		local result=$(php -r 'if ($d = json_decode($argv[1], true)) echo json_encode($d["result"]);' "$OUTPUT")
		# now set the sessionid
		if [ "$WSNAME" = "login" ];  then
			VTEWSSESSIONID=$(php -r 'if ($d = json_decode($argv[1], true)) echo $d["sessionName"];' "$result")
		fi
		_RET="$result"
	else
		local message=$(php -r 'if ($d = json_decode($argv[1], true)) { echo $d["error"]["message"]; } else echo "Invalid response"; ' "$OUTPUT")
		warning "Error during request: $message"
		_RET=0
	fi	
}

vtews_dologin () {
	# do the proper ws login to get the session id for other calls
	# $1 = username, $2 = accesskey
	
	debug "Executing webservice doLogin"
	
	# getChallenge
	vtews_call "getchallenge" "username" "$1"
	if [ -z "$_RET" ]; then
		exit $RETCODE_FAIL
	else
		local TOKEN=$(php -r 'if ($d = json_decode($argv[1], true)) echo $d["token"];' "$_RET")
		if [ -z "$TOKEN" ]; then 
			error "The server didn't send a valid token"
			exit $RETCODE_FAIL
		fi
	fi
	
	# doLogin
	local HKEY=$(php -r 'echo md5($argv[1].$argv[2]);' "$TOKEN" "$2")
	
	vtews_call "login" "username" "$1" "accessKey" "$HKEY"
	if [ -z "$_RET" ]; then
		exit $RETCODE_FAIL
	elif [ -z "$VTEWSSESSIONID" ]; then
		error "The server didn't provide a valid session id"
		exit $RETCODE_FAIL
	fi
	
	debug "Webservice session key retrieved"
}

update_ws_call () {
	# $1 = wsname
	# $2...$n = parameters in form $2 = name, $3 = value, $3 = name2, $4 = value ....
	# return 
	
	# prepare data
	local WSNAME="$1"
	local data=""
	
	shift
	while [ $# -gt 0 ]; do
		
		local PNAME="$1"
		shift
		local PVAL="$1"
		shift
		
		[ -n "$data" ] && data="$data""&"
		data="$data""${PNAME}="$(php -r 'echo urlencode($argv[1]);' "$PVAL")
	done
	
	debug "Calling webservice on ${UPDATE_SERVER}: $WSNAME"
	
	local OUTPUT=$(wget --quiet --timeout 20 "${UPDATE_SERVER}ws.php?wsname=$WSNAME" --post-data="$data" -O - )

	local success=$(php -r 'if ($d = json_decode($argv[1], true)) { echo ($d["success"] ? 1 : 0); } else echo 0; ' "$OUTPUT")
	if [ $success -eq 1 ]; then
		local result=$(php -r 'if ($d = json_decode($argv[1], true)) echo json_encode($d["result"]);' "$OUTPUT")
		_RET="$result"
	else
		local message=$(php -r 'if ($d = json_decode($argv[1], true)) { echo $d["error"]; } else echo "Invalid response"; ' "$OUTPUT")
		warning "Error during request: $message"
		debug "Server responded with $OUTPUT"
		_RET=0
	fi	
}

get_user_accesskey () {
	
	if [ -n "$ACCESSKEY" -a -n "$USERNAME" ]; then
		debug "Using provided username $USERNAME and accesskey"
		return
	fi
	
	local COUNTER=1
	while true; do
	
		ask "Please type your username"
		USERNAME=$_RET	
		
		ask_pwd "Password"
		local PASSWORD=$_RET
	
		# validate on server
		info "Validating credentials..."
		vtews_call "login_pwd" "username" "${USERNAME}" "password" "${PASSWORD}"
		if [ -z "$_RET" ]; then
			error "Error validating credentials"
			exit $RETCODE_FAIL
		elif [ "$_RET" = "0" ]; then
			if [ $COUNTER -ge 3 ]; then
				error "Invalid credentials. Too many attempts, exiting."
				exit $RETCODE_FAIL
			fi
			COUNTER=$(($COUNTER+1))
			error "Invalid credentials, try again"
			continue
		fi
		ACCESSKEY=$(php -r 'if ($d = json_decode($argv[1], true)) echo $d[0];' "$_RET")
		break
	done
	
	if [ -z "$ACCESSKEY" ]; then
		error "Invalid accesskey"
		exit $RETCODE_FAIL
	fi
	
	HASHEDKEY=$(echo -n "$ACCESSKEY" | md5sum | cut -f 1 -d " ")

	debug "Accesskey succesfully retrieved"
}

check_use_package () {
	if [ -n "$USELOCALPKG" ]; then
		if [ ! -r "$USELOCALPKG" -o ! -s "$USELOCALPKG" ]; then
			error "The specified install package $USELOCALPKG was not found"
			exit $RETCODE_FAIL
		fi

		# now check for the internal revision
		local TMPFILE="$TEMPDIR"tmp_vteversion.php
		tar --wildcards -Oxf "$USELOCALPKG" "*/vt*version.php" > "$TMPFILE"
		if [ $? -gt 0 -o ! -s "$TMPFILE" ]; then
			error "The provided package is not a valid update package"
			rm -f "$TMPFILE"
			exit $RETCODE_FAIL
		fi
		extract_php_global_var "$TMPFILE" "enterprise_current_build"
		if [ -z "$_RET" ]; then
			error "The provided package is not a valid update package"
			rm -f "$TMPFILE"
			exit $RETCODE_FAIL
		fi
		DESTREVISION=$_RET
		rm -f "$TMPFILE"
		
		PACKAGEFILE="$USELOCALPKG"
		debug "Using provided package file $USELOCALPKG to install VTE revision $DESTREVISION"
	fi
}

get_dest_revision () {

	# check if specified from command line
	if [ -n "$DESTREVISION" -a $DESTREVISION -gt 0 ]; then
		return
	fi
	
	info "Checking for latest available version..."
	
	update_ws_call "get_latest_revision"
	if [ -z "$_RET" -o "$_RET" = "0" ]; then
		error "Unable to communicate with the update server"
		exit $RETCODE_FAIL
	fi
	
	DESTREVISION=$(php -r 'if ($d = json_decode($argv[1], true)) echo $d;' "$_RET")
	debug "Latest version available: $DESTREVISION"
	
	ask "You can install VTE revision $DESTREVISION. Do you want to proceed?" "Y/N"
	if [ $_RET = 'n' ]; then
		info "Installation cancelled by the user"
		exit $RETCODE_OK
	fi
}

fetch_package () {
	
	# check if we have the packages from command line
	if [ -s "$PACKAGEFILE" ]; then
		debug "Using install package from command line"
		return
	fi
	
	# first check if package is already here
	local UPDFILELOC="$PACKAGESDIR""vte${DESTREVISION}.tgz"
	
	if [ -s "$UPDFILELOC" ]; then
		PACKAGEFILE="$UPDFILELOC"
		info "Found needed package in local cache, using it."
		debug "Using package $PACKAGEFILE"
		return
	fi
	
	
	
	# check if the package is ready
	update_ws_call "is_vte_package_available" "revision" "$DESTREVISION"
	if [ -z "$_RET" -o "$_RET" = "0" ]; then
		error "Unable to communicate with the update server"
		exit $RETCODE_FAIL
	fi

	local AVAIL=$(php -r 'if ($d = json_decode($argv[1], true)) echo ($d ? 1 : 0); else echo 0;' "$_RET")
	
	if [ $AVAIL -eq 0 ]; then
		# no package available, request it and exit
		info "The installation package is not available at the moment, but you can submit a request and you'll be informed as soon as it will be ready"
		
		while true; do
			ask "To continue, type the email address you want to be notified"
			local EMAIL="$_RET"
			if [[ "$EMAIL" =~ [a-zA-Z0-9_.+%-]+@[a-zA-Z0-9_.-]+\.[a-zA-Z]{2,5} ]]; then
				break
			else
				error "The address provided is invalid"
			fi
		done
		
		get_user_accesskey
		
		info "Sending request..."
		update_ws_call "request_vte_package" \
			"username" "$USERNAME" "hashedkey" "$HASHEDKEY" \
			"revision" "$DESTREVISION" \
			"email" "$EMAIL"
		
		if [ -z "$_RET" -o "$_RET" = "0" ]; then
			error "Unable to communicate with the update server"
			exit $RETCODE_FAIL
		else
			info "Thank you! The installation package will be generated shortly. You'll receive an email when it will be ready"
		fi
		exit $RETCODE_OK
	else
		# download package
		
		get_user_accesskey
		
		info "Downloading package..."
		
		update_ws_call "request_vte_download" \
			"username" "$USERNAME" "hashedkey" "$HASHEDKEY" \
			"revision" "$DESTREVISION"
		
		if [ -z "$_RET" -o "$_RET" = "0" ]; then
			error "Unable to communicate with the update server"
			exit $RETCODE_FAIL
		fi
		
		local REMOTESRC=$(php -r 'if ($d = json_decode($argv[1], true)) echo $d["url"];' "$_RET")
		
		debug "Remote package is $REMOTESRC"
		
		if [ -z "$REMOTESRC" ]; then
			error "Unable to communicate with the update server"
			exit $RETCODE_FAIL
		fi
		
		
		# TODO use curl if wget is not available

		debug "Packages download started..."
		
		wget --progress=bar:force "$UPDATE_SERVER""$REMOTESRC" -O "$UPDFILELOC" 2>&1 | wget_filterbar
		if [ $? -gt 0 ]; then
			rm -f "$UPDFILELOC" 2>/dev/null
			error "Error during download"
			exit $RETCODE_FAIL
		fi
		
		
		if [ -s "$UPDFILELOC" ]; then
			PACKAGEFILE="$UPDFILELOC"
			info "Package downloaded succesfully"
		else
			error "Package was not downloaded correctly"
			exit $RETCODE_FAIL
		fi
		
	fi
	
}

# credit to Dennis Williamson @ http://stackoverflow.com/questions/4686464/howto-show-wget-progress-bar-only
wget_filterbar () {
    local flag=false c count cr=$'\r' nl=$'\n'
    while IFS='' read -d '' -rn 1 c
    do
        if $flag
        then
            printf '%c' "$c"
        else
            if [[ $c != $cr && $c != $nl ]]
            then
                count=0
            else
                ((count++))
                if ((count > 1))
                then
                    flag=true
                fi
            fi
        fi
    done
}

set_file_ownership () {
	# $1 = dir or file
	debug "Setting ownership to $HTTPD_USER:$HTTPD_GROUP for $1..."
	
	chown -fR "$HTTPD_USER":"$HTTPD_GROUP" "$1" || warning "Unable to set ownership of $1"
}

fix_permissions () {
	# $1 = dir or file
	set_file_ownership "$1"
}

install_vte () {
	
	info "Installing VTE revision $DESTREVISION..."
	
	if [ ! -s "$PACKAGEFILE" ]; then
		error "Installation package nto found"
		exit $RETCODE_FAIL
	fi
	
	get_httpd_user
	
	if [ -z "$VTEDIR" ]; then
		VTEDIR=$(pwd)"/vte${DESTREVISION}/"
		
		while true; do
			ask "VTE will be installed in $VTEDIR, do you confirm this location?" "Y/N"
			if [ "$_RET" = 'y' ]; then
				break
			else 
				# require a full path, if the dir is existing, append the common name and ask confirmation
				while true; do
					ask "Please type the full path where you want to install VTE"
					if [ ${_RET:0:1} != '/' ]; then
						warning "The specified path is not absolute, please include the leading '/'"
					elif [ -f "$_RET" ]; then
						warning "The specified path points to an existing file, please provide a directory"
					else
						# add trailing /
						if [ ${_RET:(-1)} != '/' ]; then
							_RET="$_RET""/"
						fi
						if [ -d "$_RET" ]; then
							_RET="$_RET""vte${DESTREVISION}/"
						fi
						VTEDIR=$_RET
						break
					fi
					
				done
				
			fi
		done
	fi
	
	#check if the directory is empty (or non-existant)
	if [ -d "$VTEDIR" ]; then
		local EMPTY=0
		[ "$(ls -A "$VTEDIR")" ] && EMPTY=0 || EMPTY=1
		if [ $EMPTY -eq 0 ]; then
			error "The specified directory exists and it's not empty. Please provide an empty path"
			exit $RETCODE_FAIL
		fi
	elif [ -e "$VTEDIR" ]; then
		error "The location $VTEDIR already exists, please specify an empty directory"
		exit $RETCODE_FAIL
	fi
	
	debug "Installing VTE in $VTEDIR"
	mkdir -p "$VTEDIR"
	
	if [ ! -d "$VTEDIR" ]; then
		error "The directory $VTEDIR cannot be created, check to heve the correct permissions"
		exit $RETCODE_FAIL
	fi
	
	# unpack the file
	info "Extracting files..."
	tar -xzf "$PACKAGEFILE" -C "$VTEDIR" --strip=1
	
	# now check the extracted files
	if [ ! -s "$VTEDIR"index.php -o ! -s "$VTEDIR"install.php ]; then
		error "Some files were not extracted correctly, please try to download the package again"
		exit $RETCODE_FAIL
	fi
	
	# get the extracted revision
	extract_php_version_var "$VTEDIR" "enterprise_current_build"
	VTEREVISION=$_RET
	if [ -z "$VTEREVISION" ]; then
		error "Unable to retrieve VTE revision"
		exit $RETCODE_FAIL
	elif [ "$VTEREVISION" !=  $DESTREVISION ]; then
		error "The installed VTE is at revision $VTEREVISION, maybe you provided the wrnogn package?"
		exit $RETCODE_FAIL
	fi
	
	# fix permissions
	fix_permissions "$VTEDIR"
	
	info "Installation complete"
	info "Please point your browser to the location of this VTE to proceed with the configuration"
}

install_deps () {
	if [ $INSTALLDEPS -eq 0 ]; then
		# do nothing
		return
	fi
	
	info "Installing dependencies..."
	
	local APTCMD="apt"
	command -v "$APTCMD" > /dev/null 2>&1 || { APTCMD="apt-get"; }
	check_command "$APTCMD"
	
	# ask for non specified options
	if [ $DEPSMYSQL -eq 0 ]; then
		ask "Do you want to install Mysql server?" "Y/N"
		if [ "$_RET" = "y" ]; then
			DEPSMYSQL=1
		fi
	fi
	
	if [ $DEPSAPACHE -eq 0 ]; then
		ask "Do you want to install Apache?" "Y/N"
		if [ "$_RET" = "y" ]; then
			DEPSAPACHE=1
		fi
	fi
	
	if [ $DEPSPHP -eq 0 ]; then
		ask "Do you want to install PHP modules?" "Y/N"
		if [ "$_RET" = "y" ]; then
			DEPSPHP=1
		fi
	fi
	
	if [ $DEPSOTHER -eq 0 ]; then
		ask "Do you want to install other utilities (htop, mytop, zip, unzip)?" "Y/N"
		if [ "$_RET" = "y" ]; then
			DEPSOTHER=1
		fi
	fi
	
	# TODO php5 not supported
	$APTCMD -qq update && {
		# mysql
		if [ $DEPSMYSQL -eq 1 ]; then
			$APTCMD -yqq install mysql-server mysql-client
		fi
		# apache
		if [ $DEPSAPACHE -eq 1 ]; then
			$APTCMD -yqq install apache2 libapache2-mod-php php
		fi
		# php
		if [ $DEPSPHP -eq 1 ]; then
			$APTCMD -yqq install php php-cli php-curl php-imap php-xml php-json php-mysql php-mbstring php-zip php-gd php-bcmath php-apcu php-ldap
		fi
		# extra
		if [ $DEPSOTHER -eq 1 ]; then
			$APTCMD -yqq install wget htop mytop zip unzip
		fi
		
		info "Dependencies installed, remember to configure apache, mysql and php, if installed now"
	} || warning "Unable to complete apt update command"
}

self_update () {

	if [ $SKIPUPGRADE -eq 1 ]; then
		info "Self update skipped as specified on command line"
		return
	fi
	
	local LASTUPDATEFILE="$WORKDIR""last_update_check"
	
	if [ $FORCEUPGRADE -eq 0 -a -s "$LASTUPDATEFILE" ]; then
		# check the content
		local NOW=$(date +%Y%m%d)
		local LASTCHECK=$(cat "$LASTUPDATEFILE")
		if [ -n "$NOW" -a -n "$LASTCHECK" ]; then
			# do the comparison
			if [ "$NOW" = "$LASTCHECK" ]; then
				debug "Last check for updates was today, skipped"
				return
			fi
		fi
	fi
	
	# I need php and wget for this to work, so skip it if they are not installed
	command -v "php" > /dev/null 2>&1 || { 
		if [ $POSTPONEUPGRADE -eq 1 ]; then
			warning "PHP not found again, skipping self update"
		elif [ $INSTALLDEPS -eq 1 ]; then
			# no php, but can be installed later
			POSTPONEUPGRADE=1
			info "PHP not found, postponing self update"
		else
			# no php and not going to be installed
			warning "PHP not found, skipping self update"
		fi
		return
	}
	command -v "wget" > /dev/null 2>&1 || { 
		if [ $POSTPONEUPGRADE -eq 1 ]; then
			warning "wget not found again, skipping self update"
		elif [ $INSTALLDEPS -eq 1 ]; then
			# no php, but can be installed later
			POSTPONEUPGRADE=1
			info "wget not found, postponing self update"
		else
			warning "wget not found, skipping self update"
		fi
		return
	}

	# check for new versions
	info "Checking for upgrades of this script..."
		
	update_ws_call "get_latest_script_version" "name" "vte_installer"
	if [ -z "$_RET" -o "$_RET" = "0" ]; then
		warning "Unable to communicate with the update server, self update skipped"
		return
	fi

	# save last update time to file
	date +%Y%m%d > "$LASTUPDATEFILE"

	local NEWVERSION=$(php -r 'if ($d = json_decode($argv[1], true)) echo $d;' "$_RET")
	local COMP=$(php -r 'echo version_compare($argv[1], $argv[2]);' "$VERSION" "$NEWVERSION")
	
	if [ "$COMP" = "-1" ]; then
		info "Upgrading script..."
		update_ws_call "request_script_download" "name" "vte_installer"
		if [ -z "$_RET" -o "$_RET" = "0" ]; then
			warning "Unable to communicate with the update server, self update skipped"
			return
		fi
		local URL=$(php -r 'if ($d = json_decode($argv[1], true)) echo $d["url"];' "$_RET")
		
		debug "Remote script is $URL"
		if [ -z "$URL" ]; then
			warning "Unable to communicate with the update server, self update skipped"
			return
		fi		
		
		debug "Downloading script..."
		local SCRIPTTMP="$WORKDIR""vteInstaller-${NEWVERSION}_temp.tgz"
		wget -nv -q "$UPDATE_SERVER""$URL" -O "$SCRIPTTMP"

		if [ $? -gt 0 -o ! -s "$SCRIPTTMP" ]; then
			rm -f "$SCRIPTTMP" 2>/dev/null
			warning "Error during download, self update skipped"
			return
		fi
		
		debug "Upgrade downloaded successfully"

		# now decompress it
		local NEWSCRIPT="${WORKDIR}vteInstaller.sh"
		rm -f "$NEWSCRIPT" 2>/dev/null
		tar -xzf "$SCRIPTTMP" -C "$WORKDIR"

		if [ ! -s "$NEWSCRIPT" ]; then
			warning "The downloaded upgrade is invalid, skipped"
			return
		fi
	
		# adjust permissions
		local MYSELF=$(basename $0)
		local FILEMODE=$(stat -c "%a" $MYSELF)
		if ! chmod $FILEMODE "$NEWSCRIPT" ; then
			warning "Unable to set correct permission to the new script, self update skipped"
			return
		fi

		# create script to replace myself
		cat > updVteInstaller.sh << UPDEND
#!/bin/bash
# do a backup copy
BAKCOPY="$WORKDIR""vte_installer-$VERSION.sh.bak"
cp -f "vteInstaller.sh" "\$BAKCOPY" 2>/dev/null
# overwrite
if mv -f "$NEWSCRIPT" "vteInstaller.sh"; then
	echo
	echo "[INFO] The update script has been upgraded to version $NEWVERSION. Please launch it again now."
	rm -f -- \$0
else
	echo "[WARNING] The self update has failed, please run again the update script"
	echo "[WARNING] A backup copy of this script is in \$BAKCOPY"
	rm -f -- \$0
fi
UPDEND
   
		# execute it
		{
			debug "Installing new script version..."
			bash ./updVteInstaller.sh
			exit 0
		}

	else
		debug "Server version is $NEWVERSION, no need to update"
	fi
}

trap_handler () {
	
	echo
	if [ "$STATUS" = "UPDATING" ]; then
		warning "CTRL+C pressed during update"
		ask "Are you really sure to interrupt the update process? This can leave the VTE in a inconsistent state." "Y/N"
		if [ "$_RET" = "n" ]; then
			info "Resuming update..."
			return
		fi
		warning "Update interrupted by user"
	else
		warning "Script interrupted by user. No changes made"
	fi
	# exit
	exit $RETCODE_BREAK
}


print_usage () {
	cat << USAGE
Usage: vteInstaller.sh [OPTIONS...]

Options
    -d N, --dest-revision=N   Install revision N (if not specified, query the update 
                                server for the latest available version)
    -e,   --deps              Install or update apache, mysql and required php packages with apt (Ubuntu 16 and later only)
                                Ask confirmation for what to install
          --deps-apache       Install apache without asking 
          --deps-mysql        Install mysql server without asking
          --deps-php          Install php packages without asking
          --deps-other        Install additional packages without asking
    -a,   --deps-all          Install all dependencies without asking
          --package=PKG       Use the file PKG as the install package
          --skip-upgrade      Do not check for upgrades when starting
          --force-upgrade     Check for upgrades when starting (by default the check is done only once a day)
          --www-user=USR:GRP  Set the user and group for the VTE files to USR and GRP
    -k X, --accesskey=X       Use X as the accesskey for the requests (--username must be used also)
    -u X, --username=X        Use X as the username for the requests (--accesskey must be also specified)
    -v N, --verbosity=N       Set the verbositiy level to N (1=errors only, 4=debug, default=3)
          --version           Show version number
    -h,   --help              Show this help screen
USAGE
	exit $RETCODE_OK
}

parse_cmdline () {
	while getopts ":haev:u:d:k:-:" arg; do
		case $arg in
			# special case for long options
			-)
				# split the value from the name
				local LONGOPT="$OPTARG"
				if [[ "$OPTARG" =~ = ]] ; then
					LONGOPT=${OPTARG%%=*}
					OPTARG=${OPTARG##*=}
				else
					OPTARG=""
				fi
				
				case "$LONGOPT" in
					package)
						if [ -z "$OPTARG" ]; then
							echo "Missing argument for option --$LONGOPT"
							print_usage
						fi
						USELOCALPKG="$OPTARG"
						;;
					username)
						if [ -z "$OPTARG" ]; then
							echo "Missing argument for option --$LONGOPT"
							print_usage
						fi
						USERNAME="$OPTARG"
						;;
					accesskey)
						if [ -z "$OPTARG" ]; then
							echo "Missing argument for option --$LONGOPT"
							print_usage
						fi
						ACCESSKEY="$OPTARG"
						;;
					www-user)
						if [ -z "$OPTARG" ]; then
							echo "Missing argument for option --$LONGOPT"
							print_usage
						fi
						WWWUSERS="$OPTARG"
						;;
					skip-upgrade)
						SKIPUPGRADE=1
						;;
					force-upgrade)
						FORCEUPGRADE=1
						;;
					deps)
						INSTALLDEPS=1
						;;
					deps-apache)
						INSTALLDEPS=1
						DEPSAPACHE=1
						;;
					deps-mysql)
						INSTALLDEPS=1
						DEPSMYSQL=1
						;;
					deps-php)
						INSTALLDEPS=1
						DEPSPHP=1
						;;
					deps-other)
						INSTALLDEPS=1
						DEPSOTHER=1
						;;
					deps-all)
						INSTALLDEPS=1
						DEPSAPACHE=1
						DEPSMYSQL=1
						DEPSPHP=1
						DEPSOTHER=1
						;;
					verbosity)
						if [ -z "$OPTARG" ]; then
							echo "Missing argument for option --$LONGOPT"
							print_usage
						fi
						DEBUG=$OPTARG
						;;
					version)
						echo "VTE Mobile Offline Module Installer -- version $VERSION"
						exit $RETCODE_OK
						;;
					help)
						print_usage
						;;
					*)
						echo "Invalid argument: --$LONGOPT"
						print_usage
						;;
				esac
				;;
			# other options
			# b) reserved for batch
			d)
				if [ -z "$OPTARG" ]; then
					echo "Missing argument for option --$arg"
					print_usage
				fi
				DESTREVISION=$OPTARG
				;;
			e)
				INSTALLDEPS=1
				;;
			a)
				INSTALLDEPS=1
				DEPSAPACHE=1
				DEPSMYSQL=1
				DEPSPHP=1
				DEPSOTHER=1
				;;
			u)
				if [ -z "$OPTARG" ]; then
					echo "Missing argument for option --$arg"
					print_usage
				fi
				USERNAME="$OPTARG"
				;;
			k)
				if [ -z "$OPTARG" ]; then
					echo "Missing argument for option --$arg"
					print_usage
				fi
				ACCESSKEY="$OPTARG"
				;;
			h)
				print_usage
				;;
			v)
				if [ -z "$OPTARG" ]; then
					echo "Missing argument for option --$arg"
					print_usage
				fi
				DEBUG=$OPTARG
				;;
			?)
				echo "Invalid argument: -$OPTARG"
				print_usage
				;;
		esac
    done
}


# ------------------------ START ------------------------

# command line parsing
parse_cmdline $@

# color init and header
init_colors
print_text "${COLOR_BOLD}${COLOR_WHITE}VTE Installer  -- version $VERSION ${COLOR_NORMAL}"

trap trap_handler SIGINT

# INITIAL CHECKS
STATUS="INITIALIZING"
check_command touch
check_command date

create_workdir "$WORKDIR"
check_command stat
check_command head
check_command tr
check_command cut
check_command grep
check_command sed
check_command tar
check_command gzip
check_command md5sum

init_subfolder
init_log

self_update

write_log "Command invoked with arguments: $@"

STATUS="INSTALLDEPS"
install_deps

if [ $POSTPONEUPGRADE -eq 1 ]; then
	self_update
fi

# check later to avoid blocking with the self update
check_command php
check_command wget

STATUS="FETCHPACKAGES"
check_use_package
get_dest_revision
fetch_package


STATUS="INSTALLATION"
install_vte


STATUS=""
exit $RETCODE_OK
