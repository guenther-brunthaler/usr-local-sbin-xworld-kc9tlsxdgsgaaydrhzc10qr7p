#! /bin/sh
# Display the contents of one or more device mapper table files but replace
# the encryption key of "crypt" targets with '?'-characters.
#
# Also avoid executing commands which have parts of the key as arguments,
# because users of "ps" might see those arguments.
#
# Copyright (c) 2017 Guenther Brunthaler. All rights reserved.
#
# This script is free software.
# Distribution is permitted under the terms of the GPLv3.
set -e
trap 'test 0 = $? || echo "$0 failed!" >& 2' 0

p='[^ ]\{1,\} '; p2=$p$p; p4=$p2$p2; p=${p%" "}
single() {
	sed '
		/^'"$p2"'crypt / {
			h
			s/^'"$p4"'\('"$p"'\) [^ ].*/\1/
			s/[[:xdigit:]]/?/g
			G
			s/^\(.*\)\n\('"$p4"'\)'"$p"'\( [^ ].*\)/\2\1\3/
		}
	'${1+ "$1"}
}

if test 0 = $#
then
	single
else
	if  test 1 = $#
	then
		multiple=false
	else
		multiple=true
	fi
	for tfile
	do
		if $multiple
		then
			echo "*** Table '$tfile' ***"
		fi
		single "$tfile"
	done
	if $multiple
	then
		echo "*** End of table dumps. ***"
	fi
fi
