#!/bin/false
# Helpers for tracking dynamic module loading and unloading.
#
# $HeadURL: /caches/xsvn/uxadm/trunk/usr/local/sbin/xworld/functions/module_loader.sh $
# $Author: root(xtreme) $
# $Date: 2006-08-23T03:51:54.910622Z $
# $Revision: 211 $
# Written 2005 by Guenther Brunthaler


# If this variable is changed to a non-null value by the client
# of this function library, additional informational
# messages may be displayed.
OPT_VERBOSE=


# Commands for doing the low-level work.
LOAD_MODULE=/sbin/modprobe
UNLOAD_MODULE="$LOAD_MODULE -r"


# Returns 0 if $LOADED_MODULES contains a module $1.
is_loaded() {
	local lm
	for lm in $LOADED_MODULES; do
		[[ $lm == $1 ]] && return
	done
	return 1
}


# Assume the modules of state in $STATE_FILE are already loaded
# and load any missing modules required for a new state $1.
# If $1 is not specified, $NEW_STATE is used instead of $1.
# If $STATE_FILE does not exist, it is considered to be empty.
# Set up $LOADED_MODULES to contain a list of all currently
# loaded modules for all the states.
# Then append the new state to $STATE_FILE and return.
# The client must provide a function state_modules() which sets
# REPLY to a space-separated string of modules required
# for the state specified as argument (or do nothing
# otherwise - REPLY will have been preset to null).
initialize_state() {
	local new_state loaded_states s m REPLY last_error
	[[ -f $STATE_FILE ]] &&	loaded_states="$(cat $STATE_FILE)"
	LOADED_MODULES=
	for s in $loaded_states; do
		REPLY=
		state_modules $s
		for m in $REPLY; do
			is_loaded $m && m=
			[[ $m && $LOADED_MODULES ]] && m=" $m"
			LOADED_MODULES=$LOADED_MODULES$m
		done
	done
	new_state=${1:-$NEW_STATE}
	last_error=0
	REPLY=
	state_modules $new_state
	for m in $REPLY; do
		is_loaded $m && m=
		if [[ $m ]]; then
			[[ $OPT_VERBOSE ]] && echo "Loading module \"$m\"."
			$LOAD_MODULE $m || {
				last_error=$!
				[[ $OPT_VERBOSE ]] && {
					echo "Failure loading module!" >> /dev/stderr
				} 
				m=
			}
		fi
		[[ $m && $LOADED_MODULES ]] && m=" $m"
		LOADED_MODULES=$LOADED_MODULES$m
	done
	echo $new_state >> $STATE_FILE
	return $last_error
}


# Assume the modules listed in $LOADED_MODULES are already loaded
# and unload those modules not required for state $NEW_STATE.
# Then set $STATE_FILE to contain only $NEW_STATE and return.
# The client must provide a function state_modules() which sets
# REPLY to a space-separated string of modules required
# for the state specified as argument (or do nothing
# otherwise - REPLY will have been preset to null).
complete_state() {
	local REPLY all needed
	REPLY=
	state_modules $NEW_STATE
	for all in $LOADED_MODULES; do
		for needed in $REPLY; do
			if [[ $all == $needed ]]; then
				all=
				break
			fi
		done
		if [[ $all ]]; then
			[[ $OPT_VERBOSE ]] && echo "Unloading module \"$all\"."
			$UNLOAD_MODULE $all
		fi
	done
	echo $NEW_STATE > $STATE_FILE
}
