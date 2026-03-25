(*
ms365sync.scpt — STRICT v3 (robust)
Source: "Kalender"
Dest  : "Guido"
Window: next 730 days
*)

property SOURCE_CALENDAR_NAME : "Kalender"
property DEST_CALENDAR_NAME : "Guido"
property DAYS_AHEAD : 730
property DAYS_BEHIND : 0
property SYNC_PREFIX : "[[ms365sync:"
property SYNC_SUFFIX : "]]"

on isoTimestamp()
	return do shell script "date +%Y-%m-%dT%H:%M:%S%z"
end isoTimestamp

on ensureCalendarReady()
	try
		tell application id "com.apple.iCal" to launch
	end try
	repeat 30
		try
			tell application id "com.apple.iCal" to count calendars
			exit repeat
		on error errMsg number errNum
			if errNum is in {-600, -609} then
				delay 1
			else
				error errMsg number errNum
			end if
		end try
	end repeat
	delay 0.3
end ensureCalendarReady

on run
	try
		set nowDate to (current date)
		set fromDate to nowDate - (DAYS_BEHIND * days)
		set toDate to nowDate + (DAYS_AHEAD * days)

		my ensureCalendarReady()

		tell application id "com.apple.iCal"
			set sourceCal to my resolveCalendarWithPreference(SOURCE_CALENDAR_NAME, false)
			if sourceCal is missing value then error my notFoundMessage(SOURCE_CALENDAR_NAME)

			set destCal to my resolveCalendarWithPreference(DEST_CALENDAR_NAME, true)
			if destCal is missing value then error my notFoundMessage(DEST_CALENDAR_NAME)

			set srcEvents to (every event of sourceCal whose start date ≥ fromDate and start date ≤ toDate)

			set srcUIDs to {}
			repeat with e in srcEvents
				set end of srcUIDs to (uid of e) as text
			end repeat

			repeat with e in srcEvents
				my upsertMirrorStrictV3(e, destCal)
			end repeat

			set destCandidates to (every event of destCal whose description contains SYNC_PREFIX and start date ≥ (fromDate - (90 * days)) and start date ≤ (toDate + (90 * days)))
			repeat with d in destCandidates
				set dDesc to my safeText(description of d)
				set duid to my extractUID(dDesc)
				if duid is not "" then
					if (my listContains(srcUIDs, duid)) is false then
						delete d
					end if
				end if
			end repeat
		end tell

		return my isoTimestamp() & " ms365sync: OK (strict v3)"

	on error errMsg number errNum
		return my isoTimestamp() & " ms365sync: ERROR " & errNum & " — " & errMsg
	end try
end run

on upsertMirrorStrictV3(srcEvent, destCal)
	tell application id "com.apple.iCal"
		set srcUID to (uid of srcEvent) as text
		set marker to (SYNC_PREFIX & srcUID & SYNC_SUFFIX)

		set sTitle to my safeText(summary of srcEvent)
		set sStart to (start date of srcEvent)
		set sEnd to (end date of srcEvent)
		set sDesc to my safeText(description of srcEvent)
		set sLoc to my safeText(location of srcEvent)
		set sAllDay to (allday event of srcEvent)

		set finalDesc to sDesc
		if finalDesc is "" then
			set finalDesc to marker
		else
			set p to my offsetOf(SYNC_PREFIX, finalDesc)
			if p > 0 then
				set finalDesc to text 1 through (p - 1) of finalDesc
				set finalDesc to my rtrim(finalDesc)
			end if
			set finalDesc to finalDesc & return & marker
		end if

		set found to {}
		try
			set found to (every event of destCal whose description contains marker)
		end try

		if (count of found) is 0 and (sAllDay is false) then
			set found to (every event of destCal whose summary is sTitle and start date is sStart and end date is sEnd)
		end if

		if (count of found) is 0 and (sAllDay is true) then
			set found to (every event of destCal whose summary is sTitle and start date is sStart and allday event is true)
		end if

		if (count of found) is 0 then
			set newEvent to make new event at end of destCal with properties {summary:sTitle, start date:sStart, end date:sEnd, description:finalDesc, location:sLoc}
			set allday event of newEvent to sAllDay
		else
			set newEvent to item 1 of found
			set summary of newEvent to sTitle
			set start date of newEvent to sStart
			set end date of newEvent to sEnd
			set allday event of newEvent to sAllDay
			set location of newEvent to sLoc
			set description of newEvent to finalDesc
		end if

		try
			set attendees of newEvent to {}
		end try
	end tell
end upsertMirrorStrictV3

on extractUID(txt)
	set prefixLen to (length of SYNC_PREFIX)
	set p to my offsetOf(SYNC_PREFIX, txt)
	if p = 0 then return ""
	set postText to text (p + prefixLen) through -1 of txt
	set q to my offsetOf(SYNC_SUFFIX, postText)
	if q = 0 then return ""
	return text 1 through (q - 1) of postText
end extractUID

on offsetOf(needle, hay)
	try
		return (offset of needle in hay)
	on error
		return 0
	end try
end offsetOf

on rtrim(t)
	repeat while t ends with return or t ends with linefeed or t ends with " "
		set t to text 1 through -2 of t
	end repeat
	return t
end rtrim

on safeText(x)
	try
		return x as text
	on error
		return ""
	end try
end safeText

on listContains(theList, theItem)
	repeat with x in theList
		if (x as text) is (theItem as text) then return true
	end repeat
	return false
end listContains

on resolveCalendarWithPreference(keyText, preferICloud)
	tell application id "com.apple.iCal"
		set matches to {}
		set iCloudMatches to {}
		set nonICloudMatches to {}
		repeat with c in (every calendar)
			try
				if (name of c as text) is keyText then
					set end of matches to c
					if ((name of account of c as text) is "iCloud") then
						set end of iCloudMatches to c
					else
						set end of nonICloudMatches to c
					end if
				end if
			end try
		end repeat
		if (count of matches) is 0 then return missing value
		if preferICloud and (count of iCloudMatches) > 0 then return item 1 of iCloudMatches
		if (count of nonICloudMatches) > 0 then return item 1 of nonICloudMatches
		return item 1 of matches
	end tell
end resolveCalendarWithPreference

on notFoundMessage(keyText)
	return "Kalender nicht gefunden: " & keyText
end notFoundMessage
