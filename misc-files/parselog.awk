#!/usr/bin/awk -f

# Parses timestamp and counts seconds
# Only prints commands that took longer than a second.

function date_to_sec(date)
{
	if ( ! ( date ~ /\[[\-0-9]*T[:.0-9]*Z\]/ ) )
	{
		return "FAIL"
	}
	# clear brackets from date
	gsub(/(\[|\])/, "", date)
	date = sprintf("(date +%%s.%%N -d '%s' || echo FAIL) 2>/dev/null", date)
	date | getline secs
	close(date)
	return secs
}

{
	secs = date_to_sec($1)

	if (secs != "FAIL")
	{
		elapsed = secs - last

		last = secs

		if (elapsed > 0)
		{
			if ( ! (last_command ~ /^$/ ))
			{
				# the elapsed time is for the PREVIOUS line of input
				print elapsed last_command
			}
		}
		$1 = ""
		last_command = $0
	}
}
