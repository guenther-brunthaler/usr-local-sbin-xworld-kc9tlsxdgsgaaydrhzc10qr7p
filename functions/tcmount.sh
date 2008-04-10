#!/bin/false
# Helper functions for TrueCrypt mount scripts.
#
# $HeadURL: /caches/xsvn/uxadm/trunk/usr/local/sbin/xworld/functions/tcmount.sh $
# $Author: root $
# $Date: 2007-05-30T21:17:40.766801Z $
# $Revision: 758 $


# Override the variables in the next section from within your script:
# *** BEGIN OF TEMPLATE CONFIGURATION SECTION ***
# Set this to any nonempty value in order to enable debug diagnostics.
OPT_DEBUG=
# Default base directory for $VOLUMES, $KEYFILES and $MOUNTPOINTS.
# (Note that ALL paths used by this script will resolved step-by-step,
# expanding symlinks as they are encountered. This allows for
# useful constructions like "/<comp1>/<symlink>/../<comp2>" where
# the ".." refers to the already resolved <symlink>.)
BASE=
# Where TrueCrypt file-based containers (encrypted volumes) can be found.
# Relative to $BASE if not an absolute path.
VOLUMES="volumes"
# Where TrueCrypt file-based containers (encrypted volumes) can be found.
# Relative to $BASE if not an absolute path.
DEVICES="/dev"
# Where mountpoints for mounting the containers can be found.
# Relative to $BASE if not an absolute path.
MOUNTPOINTS="mnt"
# Base directory where key files can be found.
# Relative to $BASE if not an absolute path.
KEYFILES="keyfiles"
# Will be executed if it exists.
# Must be specified relative to toplevel directory of mounted volume.
OPTIONAL_SCRIPT="scripts/init_script"
# Mount options for VFAT.
MOPT_VFAT="utf8=true,umask=117,dmask=007,uid=operator,gid=plugdev"
# Mount options for NTFS.
MOPT_NTFS="nls=utf8,fmask=117,dmask=007,uid=operator,gid=plugdev"
# Set to non-empty if you want to report the script if all went OK.
TELL_OK=
# List of volumes to mount.
# Entries consist of tuples 'tup1:tup2:...:tupN'.
# (Each tuple is terminated by an 'end' option.)
# Each tuple consists of a sub-tuple 'key1=val1:key2=val2:...:keyN=valN'
# where the following keyN are supported:
# 'dev': Device to mount (relative to $DEVICES if not absolute).
# 'vol': Volume to mount (relative to $VOLUMES if not absolute).
# 'dn': Device number to use (integer).
# 'key': Key file name (relative to $KEYFILES if not absolute).
# 'mnt': Mount point to use (relative to $MOUNTPOINTS if not absolute).
# 'opt': Mount options to use. Must be "vfat" or "ntfs".
# 'end': Specifies the end of the current tuple.
TARGETS=
# *** END OF TEMPLATE CONFIGURATION SECTION ***


true > /dev/null << '.'
# *** BEGIN OF TEMPLATE INVOCATION SECTION ***
# Process options and pass through user options.
process "$@" -- "$TARGETS"
# *** END OF TEMPLATE INVOCATION SECTION ***
.


die() {
	echo "ERROR: $*" >& 2
	exit 1
}


dinfo() {
	test -z "$OPT_DEBUG" && return
	echo "DEBUG: $*" >& 2
}


# ARGS: "Description", directory.
chkdir() {
	dinfo "Verifying that directory '$2' exists."
	test -d "$2" || die "$1 directory '$2' does not exist!"
}


. /usr/local/bin/xworld/functions/qin.sh


# ARG: Call options passed as a single string.
check_init_script() {
	local P CMD
	if [ -z "$OPTIONAL_SCRIPT" ]; then
		dinfo "Not searching for initialization script."
		dinfo
		return
	fi
	rebase "$MNT" "$OPTIONAL_SCRIPT"
	dinfo "Searching for initialization script $(qin "$P")..."
	if [ -f "$P" -a -x "$P" ]; then
		dinfo "Script present and appropriate."
		CMD="$(qin "$P")${1:+ }$1"
		dinfo "Will be invoked as: $CMD"
		dinfo "Trying to execute script..."
		eval "$CMD" || die "Initialization script '$P' failed!"
		dinfo "Initialization script execution" \
			"was successful."
	else
		dinfo "No appropriate script found."
	fi
	dinfo
}


# ARGS:
#  <container_volume> <mount_opts> <container_device>
#  <device_number> <keyfile> <mount_point>
#  <pass_through_options>.
process1() {
        local VOL OPT DEV DN KEY MNT OPTS
        VOL="$1"; OPT="$2"; DEV="$3"
        DN="$4"; KEY="$5"; MNT="$6"; OPTS="$7"
        dinfo "Trying to mount:"
        dinfo "   Container volume = $(qin "$VOL")."
        dinfo "   Mount options = $(qin "$OPT")."
        dinfo "   Container Device = $(qin "$DEV")."
        dinfo "   Device number = $(qin "$DN")."
        dinfo "   Key file = $(qin "$KEY")."
        dinfo "   Mount point = $(qin "$MNT")."
        dinfo "   Initialization script options = $(qin "$OPTS")."

        local TIMEOUT CMD MSG
        if [ -n "$VOL" ]; then
		chkdir "Volume container '$VOL' mount point" "$MNT"
		test -f "$VOL" || {
			die "TrueCrypt container volume '$VOL' not found!"
		}
	else
		chkdir "Device container '$DEV' mount point" "$MNT"
		test -b "$DEV" || {
			die "TrueCrypt container" \
				"block device '$DEV' not found!"
		}
	fi
	test -n "$DN" || die "Missing device-number specification!"
	if truecrypt --list "$DN" > /dev/null 2>& 1; then
		dinfo "Container is already mounted."
		check_init_script "$OPTS"
		return
	fi
	dinfo "TrueCrypt device number $(qin "$DN")" \
		"seems not to be mounted yet."
	test -x "$MNT" -a "$MNT" != "/tmp" || {
		MSG="Mount point directory '$MNT'"
		die "$MSG must not have the 'x' bit set!"
	}
	while true; do
		CMD="truecrypt --device-number $(qin "$DN")"
		test -n "$OPT" && CMD="$CMD --mount-options $(qin "$OPT")"
		if [ -n "$KEY" ]; then
			# Bug in truecrypt4.2a: --password is not recognized.
			CMD="$CMD -p \"\" --keyfile $(qin "$KEY")"
		fi
		if [ -n "$VOL" ]; then
			CMD="$CMD $(qin "$VOL")"
		else
			CMD="$CMD $(qin "$DEV")"
		fi
		CMD="$CMD $(qin "$MNT")"
		dinfo "Evaluating: $CMD"
		eval "$CMD" || break
		sync
		TIMEOUT=5
		until [ -x "$MNT" ]; do
			test $TIMEOUT = 0 && break
			sleep 1;
			TIMEOUT="`expr $TIMEOUT - 1`"
		done
		dinfo "Mount seems to be successful."
		check_init_script "$OPTS"
		return
	done
	if [ -n "$VOL" ]; then
		echo "Could not mount TrueCrypt volume" \
			"'$VOL' as '$MNT'!" >& 2
	fi
	echo "Could not mount TrueCrypt device '$DEV' as '$MNT'!" >& 2
	die "Failed command was: $CMD"
}


# Sets $OPT to the mount options associated with key $1.
select_mount_options() {
	case "$1" in
		vfat) OPT="$MOPT_VFAT";;
		ntfs) OPT="$MOPT_NTFS";;
		*) die "Unsupported mount type '$1'!";;
	esac
}


# Return true if $1 is not an absolute path.
relative() {
	test "$1" = "${1#/}"
}


# Helper for canonpath().
canonerr() {
	local MSG L
	for L in \
		"Cannot canonicalize path '$FULL'!" \
		"Reason: $*" \
		"Failing path component: '$C'." \
		"Result so far: '$P'" \
		"Absolute symlinks resolved so far: $ABS." \
		"Relative symlinks resolved so far: $REL." \
		"Remaining to be resolved: '$IN'."
	do MSG="$MSG$L"$'\n'
	done
	die "$MSG"
}


# $1 should be an absolute path, but not necessarily canonical.
# Sets $P to the canonicalized path. All symlinks will also
# be resolved.
# If $1 is a relative path, however, it will be returned unchanged.
canonpath() {
	local FULL IN C T L ABS REL
	FULL="$1"
	if relative "$FULL"; then
		P="$FULL"
		return
	fi
	IN="$FULL"; ABS=0; REL=0
	while true; do
		P="/"
		# Loop invariants: $P and $IN must have leading
		# slashes.
		while [ -n "$IN" ]; do
			# Chop off first path component.
			C="${IN%%/*}"
			IN="${IN#$C}"
			# Remove leading slashes from rest.
			IN="${IN##/}"
			# Ignore empty path components or ".".
			test -z "$C" -o "$C" = "." && continue
			if [ "$C" = ".." ]; then
				# Strip off last path component.
				test "$P" != "/" && P="${P%/*}"
				continue
			fi
			T="${P%/}/$C"
			if [ ! -e "$T" ]; then
				test -z "$P" && \
					canonerr "Subpath '$T'" \
						"does not exist!"
			fi
			if [ ! -L "$T" ]; then
				# Normal component.
				P="$T"
				continue
			fi
			# Symlink.
			L="$(readlink "$T")" || {
				canonerr "Target of symlink '$T'" \
					"cannot be read!"
			}
			# Insert symlink target in front of remaining path.
			IN="${L%/}/$IN"
			if ! relative "$L"; then
				# Absolute symlink.
				# Forget what we have resolved so far.
				ABS=`expr $ABS + 1`
				continue 2
			fi
			# Relative symlink.
			REL=`expr $REL + 1`
			# OK, go on.
		done
		break
	done
	test -e "$P" || canonerr "Final path component does not exist!"
}


# ARGS: <base_path>, <path>.
# Sets $P to the resulting path.
# If the resulting $P is an absolute path,
# it will be canonicalized and all symlinks will be resolved.
rebase() {
	if [ -z "$2" ]; then
		P="${1%%/}"
	elif relative "$2"; then
		if relative "$1"; then
			die "Base path must be absolute!"
		fi
		P="${1%%/}/${2%%/}"
	else
		P="${2%%/}"
	fi
	canonpath "$P"
}


# Output a command to override variable $1 with $2.
# Updates helper variable "HAVE_$1" which should
# be initialized to be empty.
override() {
	local E H
	H="\$HAVE_$1"
	E="	if [ -n \"$H\" ]; then"
	E="$E		local $1;"
	E="$E		$1=1;"
	E="$E	fi;"
	E="$E	$1=\"$2\""
	echo $E
}


# Add one or more options to $OPTS.
add_option() {
	OPTS="$OPTS${OPTS:+ }$*"
}


# ARGS: [ options [ -- ] ] <targets>
process() {
	local VOL OPT DEV DN KEY MNT OPTS
	local E K V P OLD_IFS
	local HAVE_OPT_DEBUG HAVE_TELL_OK
	while [ -n "$1" ]; do
		case "$1" in
			--debug|-d)
				add_option "--debug"
				eval "$(override OPT_DEBUG 1)"
				;;
			--quiet|-q)
				add_option "--quiet"
				eval "$(override TELL_OK)"
				;;
			--) shift; break;;
			*)
				test "${1#-}" = "$1" && break
				die "Unknown option '$1'!"
			;;
		esac
		shift
	done
	if [ -n "$BASE" ]; then
		if relative "$BASE"; then
			die "'$BASE' is not an absolute path!"
		fi
		chkdir "Base" "$BASE"
		rebase "$BASE" "$VOLUMES"; VOLUMES="$P"
		rebase "$BASE" "$DEVICES"; DEVICES="$P"
		rebase "$BASE" "$MOUNTPOINTS"; MOUNTPOINTS="$P"
		rebase "$BASE" "$KEYFILES"; KEYFILES="$P"
	fi
	test -n "$DEVICES" && chkdir "Encryption devices base" "$DEVICES"
	test -n "$VOLUMES" && chkdir "Encryption containers" "$VOLUMES"
	test -n "$MOUNTPOINTS" && chkdir "Mount point" "$MOUNTPOINTS"
	test -n "$KEYFILES" && chkdir "Key files" "$KEYFILES"
	OLD_IFS="$IFS"
	dinfo "Processing target specification $(qin "$1")."
	local IFS
	IFS=:
	for E in $1; do
		IFS="$OLD_IFS"
		K="${E%%=*}"
		dinfo "Processing option key $(qin "$K")."
		if [ "$K" = "$E" ]; then
			V=
		else
			V="${E#*=}"
		fi
		dinfo "Associated value is $(qin "$V")."
		case "$K" in
			vol) rebase "$VOLUMES" "$V"; VOL="$P";;
			opt) select_mount_options "$V";;
			dev) rebase "$DEVICES" "$V"; DEV="$P";;
			dn) DN="$V";;
			key) rebase "$KEYFILES" "$V"; KEY="$P";;
			mnt) rebase "$MOUNTPOINTS" "$V"; MNT="$P";;
			end)
				if [ -z "$VOL" -a -z "$DEV" ]; then
					die "Need key 'vol' or 'dev'!"
				fi
				process1 "$VOL" "$OPT" "$DEV" \
					"$DN" "$KEY" "$MNT" "$OPTS"
				VOL=; OPT=; DEV=; DN=; KEY=; MNT=
			;;
			*)
				die "Invalid option key $(qin "$K")" \
					"encountered!"
			;;
		esac
	done
	if [ -n "$VOL$OPT$DEV$DN$KEY$MNT" ]; then
		die "The last option must be an 'end'!"
	fi
	test -z "$TELL_OK" && return
	echo "All requested TrueCrypt volumes have been" \
		"mounted successfully." >& 2
}


export PATH="/bin:/usr/bin:/sbin:/usr/local/sbin:/usr/local/sbin/xworld"
