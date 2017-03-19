#! /bin/sh
# Display the contents of one or more device mapper "crypt"-target table files
# but replace the actual key with '?'-characters.
#
# Also avoid executing commands which have parts of the key as arguments,
# because users of "ps" might see those arguments.
set -e
trap 'test 0 = $? || echo "$0 failed!" >& 2' 0
test 0 != $#
multiple=false; test 1 != $# && multiple=true
p='[^ ]\{1,\} '; p=$p$p$p$p
for tfile
do
	if test crypt != "`cut -d ' ' -f 3 -- "$tfile"`"
	then
		echo "WARNING: File '$tfile' is not a crypt target table!" >& 2
	else
		if $multiple
		then
			echo "*** Table '$tfile' ***"
		fi
		sed '
			h
			s/^'"$p"'\([^ ]\{1,\}\) [^ ].*/\1/
			s/[[:xdigit:]]/?/g
			G
			s/^\(.*\)\n\('"$p"'\)[^ ]\{1,\}\( [^ ].*\)/\2\1\3/
		' "$tfile"
	fi
done
if $multiple
then
	echo "*** End of table dumps. ***"
fi
