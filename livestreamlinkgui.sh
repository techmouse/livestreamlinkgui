#!/bin/bash

########################################
#LiveStreamLinkGUI
#By Mouse
#Last edited: 1-AUG-17
########################################

########################################
#User Preferences
########################################
#You can change the value below to easily switch back and forth between livestreamer, streamlink and any future forks.
export streamercmd="streamlink"

#LiveStreamLinkGUI config directory; If you change this, the old directory will still exist if this script has been executed at least once on your system. If the specified directory doesn't exist, it will be created during setup.
export configdir=$HOME/.livestreamlinkgui

#Preferred quality priority, from most preferred to least preferred. LiveStreamLinkGUI will check for a file named "qualitypriority" in the config directory. If one doesn't exist, LiveStreamLinkGUI will use the priority specified in the below else case. If you have LiveStreamLinkGUI in a cloud storage and synced to multiple machines, the qualitypriority file will allow weaker machines to have separate priorities from stronger machines:
if [ -e $configdir/qualitypriority ]; then
	export lsquality="$(cat $configdir/qualitypriority)"
	echo "Found $configdir/qualitypriority. Prioritizing preferred stream qualities as: $lsquality"
else
	export lsquality="medium,low,360p,worst"
fi

#Opening chat preferences. When opening a stream that has a chat popout window that LiveStreamLinkGUI supports opening, the user can be prompted. The options are "ask", "ignore", and "always". "Always" will always open the chat without asking, "ask" will ask every time, and "ignore" will never ask.
if [ -e $configdir/chatopenpref ]; then
	export chatopenpref="$(cat $configdir/chatopenpref)"
	echo "Found $configdir/chatopenpref. chatopenpref: $chatopenpref"
else
	export chatopenpref="ask"
fi

#Media player command including flags. If you want to change to a different player, or change how VLC works, you can change the variable below.
export playercmd="vlc --network-caching=15000 --no-qt-error-dialogs --no-repeat --no-loop --play-and-exit"

#Extra flags for livestreamer/streamlink. If you want to add some extra flags for livestreamer, streamlink or any future forks, add them to the variable below.
export extralsflags=""

#Youtube preferred resolution. This is for what resolution you prefer when opening Youtube videos and streams.
export youtuberesolution="360p"
#Extra flags for playing Youtube videos in VLC. This is for any extra flags you would like to have when opening Youtube videos.
export extrayoutubeflags="--play-and-exit"

#Add file extensions for media types here. These are the file types LiveStreamLinkGUI will dig for and how it handles direct links to media, including local and saved links. To add support for a new file type, simply add its extension to this array.
export filetypes=(".mp4" ".m3u8" ".flv" ".webm" ".gifv" ".ogg" ".mp3" ".mpg" ".vob" ".avi" ".opus" ".ts" ".wav")

########################################
#End of User Preferences
########################################


########################################
#script variables; don't change these:
########################################
export streamname=0
export loopforever=false
export baseurl=0
export reopentext=""
export shouldreopencheck=true

launchplayer(){
	if [[ ! "$url" == "" ]]; then
		found=false
		for i in ${!filetypes[@]}; do
			if [[ "$url" == *"${filetypes[$i]}"* ]] && [[ $found == false ]]; then
				found=true
				$playercmd $@ "$url"
			fi
		done
		if [[ $found == false ]]; then
			result=$($streamercmd "$url")
			if [[ "$result" == *"No plugin can handle"* ]]; then
				digforurl http
			else
				$streamercmd -p "$playercmd $@" $extralsflags "$url" "$lsquality"
			fi
		fi
	fi
}

gethistorycount(){
	counter=0
	while read line
	do
		$((++counter))
	done < "$configdir/history"
	echo $counter
	counter=0
}

historyfilter(){
	if [[ "$1" ]]; then
		if [[ "$1" == *"Online"* ]]; then
			echo $(echo "$1" | sed 's/(Online!)/LSLGUIping/g')
		else
			if [[ "$1" == *"Offline"* ]]; then
				echo $(echo "$1" | sed 's/(Offline)/LSLGUIping/g')
			else
				echo "$1"
			fi
		fi
	fi
}

getpingstring(){
	if [[ "$1" ]]; then
# Very useful but takes a really long time to load the menu if the saved history is long. Takes about 3-4 minutes with a saved history of 41.
# It also lacks support for sites livestreamer/streamlink doesn't support.
		found=false
		if [[ $(removetheurl "$1") == *"LSLGUIping"* ]]; then
			pingresult=$($streamercmd $(removethename "$1"))
			if [[ "$pingresult" == *"Found matching plugin"* ]]; then
				found=true
				if [[ "$pingresult" == *"No playable streams found on this URL"* ]]; then
					echo $(echo "$1" | sed 's/LSLGUIping/(Offline)/g')
				else
					if [[ "$pingresult" == *"is hosting"* ]]; then
						echo $(echo "$1" | sed 's/LSLGUIping/(Hosting)/g')
					else
						echo $(echo "$1" | sed 's/LSLGUIping/(Online!)/g')
					fi
				fi
			fi
			if [[ $found == false ]]; then
				ping -q -c 1 $(removethename "$1") > /dev/null
				pingresult=$?
				if [[ "$pingresult" == 0 ]]; then
					echo $(echo "$1" | sed 's/LSLGUIping/(Online!)/g')
				else
					found=true
					echo $(echo "$1" | sed 's/LSLGUIping/(Offline)/g')
				fi
			fi
		else
			echo "$1"
		fi
	fi
}

addtohistory(){
	if [[ "$1" ]]; then
		filtered=$(historyfilter "$1")
		urltest=$(removethename "$filtered")
		if [[ $(isinhistory "$urltest") == false ]]; then
			echo "$filtered" >> "$configdir/history"
		fi
		putlinkattopofhistory "$filtered"
	fi
}

removefromhistory(){
	if [[ "$1" ]]; then
		cp "$configdir/history" "$configdir/livestreamlinkgui-deleteme"
		>$configdir/history
		test1=$(removethename "$1")
		while read line
		do
			test2=$(removethename "$line")
			if ! [[ "$test1" == "$test2" ]]; then
				echo "$line" >> "$configdir/history"
			fi
		done < "$configdir/livestreamlinkgui-deleteme"
		>$configdir/livestreamlinkgui-deleteme
	fi
}

removefromhistorydialog(){
	echo "zenity --list \\
	--radiolist \\
	--text \"Which Link To Remove?\" \\
	--width=400 --height=250 \\
	--title=\"LiveStreamLinkGUI: Remove A Link\" \\
	--column=\"?\" --column=\"Available Choices:\" \\" > $configdir/livestreamlinkgui-deleteme
	while read line
	do
		echo "	FALSE \"$line\" \\" >> $configdir/livestreamlinkgui-deleteme
	done < "$configdir/history"
	echo "	FALSE \"Go Back\"" >> $configdir/livestreamlinkgui-deleteme
	choice=$($configdir/livestreamlinkgui-deleteme)
	>$configdir/livestreamlinkgui-deleteme
	if [ $? == 0 ]; then
		if [[ "$choice" == "Go Back" ]]; then
			mainmenu
		else
			removefromhistory "$choice"
			mainmenu
		fi
	else
		mainmenu
	fi
}

putlinkattopofhistory(){
	if [[ "$1" ]]; then
		filtered=$(historyfilter "$1")
		test1=$(removethename "$filtered")
		removefromhistory "$test1"
		cp "$configdir/history" "$configdir/livestreamlinkgui-deleteme"
		echo "$filtered" > "$configdir/history"
		while read line
		do
			test2=$(removethename "$line")
			if ! [[ "$test1" == "$test2" ]]; then
				echo "$line" >> "$configdir/history"
			fi
		done < "$configdir/livestreamlinkgui-deleteme"		
		>$configdir/livestreamlinkgui-deleteme
	fi
}

isinhistory(){
	if [ "$1" ]; then
		found=false
		while read line
		do
			if [[ $(removethename "$1") == $(removethename "$line") ]]; then
				found=true
			fi
		done < "$configdir/history"
		echo $found
	fi
}

inhistorycheck(){
	if [ "$1" ]; then
		found=false
		while read line
		do
			if [[ $(removethename "$1") == $(removethename "$line") ]]; then
				found=true
				baseurl="$line"
			fi
		done < "$configdir/history"
		if [ $found == true ]; then
			putlinkattopofhistory "$baseurl"
		fi
	fi
}

removethename(){
	if [ "$1" ]; then
		if [[ "$1" == *" "* ]]; then
			tmp=${1##*" "}
			echo "$tmp"
		else
			echo "$1"
		fi
	fi
}

removetheurl(){
	if [ "$1" ]; then
		if [[ "$1" == *" "* ]]; then
			tmp=${1%" "*}
			echo "$tmp"
		else
			echo ""
		fi
	fi
}

findurlbyextension(){
	ext="$1"
	if [ $ext ]; then
		#rm is dangerous; make the file empty instead:
		>$configdir/livestreamlinkgui-deleteme
		wget "$baseurl" -O $configdir/livestreamlinkgui-deleteme
		tempfile=$(cat $configdir/livestreamlinkgui-deleteme)
		if [[ "$tempfile" == *"$ext"* ]]; then
			blocktotest=${tempfile%"$ext"*}
			blocktotest="$blocktotest""$ext"
#			blocktotest=${blocktotest##*"\""}
			# Some urls require different protocols (such as hls, http, etc). So we remove the protocol prefix because it's easier/faster to add a prefix, than it is to swap them. It would be difficult to automatically assign the right prefix without a way to test their validity and without getting the user involved.
			blocktotest=$(echo $blocktotest | sed 's/\\//g')
			blocktotest=${blocktotest##*"//"}
			echo "$blocktotest"
		else
			echo ""
		fi
		#rm is dangerous; make the file empty instead:
		>$configdir/livestreamlinkgui-deleteme
	else
		echo "ERROR: findurlbyextention needs an extension passed to it."
	fi
}

digforurl(){
	# This function digs for common video file extensions and then pipes them to a video player.
	if ! [ $protocol ]; then
		local protocol=${url%"//"*}
		local protocol="$protocol//"
	else
		local protocol=$1
	fi
	#rm is dangerous; make the file empty instead:
	>$configdir/livestreamlinkgui-deleteme
	wget "$url" -O $configdir/livestreamlinkgui-deleteme
	tempfile=$(cat $configdir/livestreamlinkgui-deleteme)
	url=""
	found=false
	for i in ${!filetypes[@]}; do
		if [[ "$tempfile" == *"${filetypes[$i]}"* ]] && [[ $found == false ]]; then
			found=true
			blocktotest=${tempfile%"${filetypes[$i]}"*}
			blocktotest=${blocktotest##*"//"}
			url="$protocol://$blocktotest${filetypes[$i]}"
			openstream
		fi
	done
	#rm is dangerous; make the file empty instead:
	>$configdir/livestreamlinkgui-deleteme

	if [[ ! $url == "" ]]; then
		reopentext="$url"
	else
		reopentext="No supported file types found."
	fi

	reopencheck
}

urlwrangler(){
	if ! [[ "$1" ]]; then
		baseurl=$(getuserinputfromtextbox "URL?")
	fi

	if [[ "$baseurl" == *"LSLGUIdig"* ]]; then
		shouldadddigprefix=true
	else
		shouldadddigprefix=false
	fi

	url=$(removethename "$baseurl")

	if [[ $shouldadddigprefix == true ]]; then
		url="LSLGUIdig://$url"
	fi

	shouldreopencheck=true
	if [[ $url ]]; then
		inhistorycheck "$baseurl"
		echo "Opening $url"
		checkforchat &

		streamname=0

		case $url in
			#twitch check
			*"twitch.tv"*)
				streamname=${url##*/}
				#Use livestreamer --twitch-oauth-authenticate to get this token (it's in the url):
#				extralsflags="$extralsflags --twitch-oauth-token="
				openstream
			;;

			#hitbox check
			*"hitbox.tv"*)
				streamname=${url##*/}
				openstream
			;;

			#vaughn check
			*"vaughnlive.tv"*)
				streamname=${url##*/}
				openstream
			;;

			#veetle check
			*"veetle.com"*)
				extralsflags=$extralsflags" --player-continuous-http"
				openstream
			;;

			#special cases (LiveStreamLinkGUI plays and closes when done):
			#Non-stream video inputs are better suited here. Copy and paste blocks to use a template.
			*"roosterteeth.com"*)
				url=$(findurlbyextension .m3u8)
				if [[ "$url" == "" ]]; then
					zenity --error --text="m3u8 link not found. This is usually caused by Rooster Teeth requiring a member subscription. Exiting."
				else
					# findurlbyextension found a url so now we must prefix the proper protocol.
					url="http://$url"
					playercmd=$playercmd" --zoom .5"
					openstream
				fi
			;;

			*"twit.tv"*)
				url=$(findurlbyextension .mp4)
				if [[ "$url" == "" ]]; then
					zenity --error --text="mp4 link not found. Exiting."
				else
					# findurlbyextension found a url so now we must prefix the proper protocol.
					url="http://$url"
					openstream
				fi
			;;

			#youtube cases:
			*"youtube.com"*)
				shouldreopencheck=false
				$playercmd --preferred-resolution $youtuberesolution $url $extrayoutubeflags
			;;
			*"youtu.be"*)
				shouldreopencheck=false
				$playercmd --preferred-resolution $youtuberesolution $url $extrayoutubeflags
			;;

			*"LSLGUIdig"*)
				baseurl=${url#*"//"}
				digforurl "$url"
			;;

			#all others
			*)
				openstream
			;;
		esac
	else
		zenity --error --text="Empty URL detected."
		mainmenu
	fi
}

openchat() {
	if [[ $url =~ "twitch.tv" ]]; then
		streamname=${url##*/}
		xdg-open $url/chat
	fi

	if [[ $url =~ "vaughnlive.tv" ]]; then
		streamname=${url##*/}
		xdg-open http://vaughnlive.tv/popout/chat/$streamname
	fi

	if [[ $url =~ "hitbox.tv" ]]; then
		streamname=${url##*/}
		xdg-open http://www.hitbox.tv/embedchat/$streamname?autoconnect=true
	fi

	if [[ $url =~ "arconaitv.me" ]]; then
		#rm is dangerous; make the file empty instead:
		>$configdir/livestreamlinkgui-deleteme
		wget "$url" -O $configdir/livestreamlinkgui-deleteme
		tempfile=$(cat $configdir/livestreamlinkgui-deleteme)
		if [[ "$tempfile" == *"cbox"* ]]; then
			boxid=${tempfile##*"boxid="}
			boxid=${boxid%%"&"*}
			boxtag=${tempfile##*"boxtag="}
			boxtag=${boxtag%%"&"*}
			xdg-open "https://www7.cbox.ws/box/?boxid=$boxid&boxtag=$boxtag&sec="
		fi
		#rm is dangerous; make the file empty instead:
		>$configdir/livestreamlinkgui-deleteme
	fi
}

checkforchat() {
	if [ $chatopenpref == "ask" ]; then
		if [[ $url =~ "twitch.tv" ]]; then
			streamname=${url##*/}
			zenity --question --text="Twitch link detected. Open $streamname's chat?" --title="LiveStreamLinkGUI: $streamname"
			if [[ $? == 0 ]]; then
				openchat
			fi
		fi

		if [[ $url =~ "hitbox.tv" ]]; then
			streamname=${url##*/}
			zenity --question --text="Hitbox link detected. Open $streamname's chat?" --title="LiveStreamLinkGUI: $streamname"
			if [[ $? == 0 ]]; then
				openchat
			fi
		fi

		if [[ $url =~ "vaughnlive.tv" ]]; then
			streamname=${url##*/}
			zenity --question --text="Vaughnlive link detected. Open $streamname's chat?" --title="LiveStreamLinkGUI: $streamname"
			if [[ $? == 0 ]]; then
				openchat
			fi
		fi

		if [[ $url =~ "arconaitv.me" ]]; then
			streamname=${url##*arconaitv.me/}
			streamname=$(echo $streamname | sed 's/\///g')
			zenity --question --text="Arconai link detected. Open $streamname's chat?" --title="LiveStreamLinkGUI: $streamname"
			if [[ $? == 0 ]]; then
				openchat
			fi
		fi
	fi
	if [ $chatopenpref == "always" ]; then
		openchat
	fi
}

openstream() {
#FIXME: when the vaughnlive plugin is fixed, delete this block:
	if [[ "$baseurl" =~ "vaughnlive.tv" ]]; then
		streamercmd="$streamercmd --http-header Referer=http://vaughnlive.tv/$streamname"
		url=""
		$streamercmd -p "$playercmd $@" $extralsflags "hlsvariant://https://hls-ord-4a.vaughnsoft.net/den/live/live_$streamname/playlist.m3u8" "$lsquality"
	fi

	#Non-livestreamer/streamlink supported streams are better suited here. Copy and paste blocks to use a template.
	if [[ "$baseurl" =~ "arconaitv.me" && true == false ]]; then
		url=$(findurlbyextension .m3u8)
		if [[ "$url" == "" ]]; then
			zenity --error --text="m3u8 link not found."
		else
			# findurlbyextension found a url so now we must prefix the proper protocol.
			url="http://$url"
#			playercmd="$playercmd --no-repeat"
		fi
	fi

	if [[ "$baseurl" =~ "ssh101.com" ]]; then
		url=$(findurlbyextension .m3u8)
		if [[ "$url" == "" ]]; then
			zenity --error --text="m3u8 link not found."
		else
			# findurlbyextension found a url so now we must prefix the proper protocol.
			url="hlsvariant://http://$url"
		fi
	fi

	# Now we launch our player.
	if [[ ! "$url" == "" ]]; then
		launchplayer
	fi

	if [ $loopforever == true ]; then
		sleep 1
	fi

	# Exit status 1 might mean streamer closed it or stream not present. Exit status 0 might mean closed by user.
	# Update: Exit status 0 also seems to include when a stream isn't present.
	# Update: Exit status 1 seems to also mean site isn't supported.
	exitstatus=$?
	echo "Exit status: $exitstatus"
	if [ $exitstatus == 1 ]; then
#		reopentext="$(gettitlename)\'s Stream Lost Or Not Found."
		reopentext="$(gettitlename)\'s Stream Closed, Lost Or Not Found."
	fi
	if [ $exitstatus == 0 ]; then
#		reopentext="$(gettitlename)\'s Stream Closed By $USER."
		reopentext="$(gettitlename)\'s Stream Closed, Lost Or Not Found."
	fi

	if [[ $shouldreopencheck == true && $loopforever == false ]]; then
		reopencheck
	else
		if [[ $shouldreopencheck == false && $loopforever == true ]]; then
			openstream
		fi
	fi
}

gettitlename() {
	if [ $streamname != 0 ]; then
		echo $streamname
	else
		echo "$baseurl"
	fi	
}

getuserinputfromtextbox(){
	text="$1"
	if [[ "$text" ]]; then
		echo $(zenity --entry --text="$text" --title="LiveStreamLinkGUI" --width=600)
	else
		echo "ERROR: getuserinputfromtextbox requires a text string to be passed to it."
	fi
}

mainmenu(){
	echo "zenity --list \\
	--radiolist \\
	--text \"Main Menu:\" \\
	--width=500 --height=250 \\
	--title=\"LiveStreamLinkGUI\" \\
	--column=\"?\" --column=\"Available Choices:\" \\
	TRUE \"Open A New Link\" \\
	FALSE \"Save A New Link\" \\" > $configdir/livestreamlinkgui-deleteme
#	FALSE \"(Experimental) Dig for a URL (NEW) (HTTP)\" \\
#	FALSE \"(Experimental) Dig for a URL (NEW) (HLS)\" \\" > $configdir/livestreamlinkgui-deleteme
	while read line
	do

		string=$(getpingstring "$line")
		echo "	FALSE \"$string\" \\" >> $configdir/livestreamlinkgui-deleteme

	done < "$configdir/history"
	echo "	FALSE \"Remove A Saved Link\" \\" >> $configdir/livestreamlinkgui-deleteme
	echo "	FALSE \"Close Program\"" >> $configdir/livestreamlinkgui-deleteme
	baseurl=$($configdir/livestreamlinkgui-deleteme)
	>$configdir/livestreamlinkgui-deleteme
	#Can't use a case statement here because of the save history (without monkeying with arrays). So nested if statements are used instead. It's probably better like this anyways to conserve system resources.
	if [[ "$baseurl" ]]; then
		if [[ "$baseurl" == "Close Program" ]]; then
			exit
		else
			if [[ "$baseurl" == "Save A New Link" ]]; then
				question=$(getuserinputfromtextbox "URL To Save?\nYou can name links by putting the name before the link.\nThis is completely optional.\nEXAMPLE: \"Don't Do Drugs https://www.ispot.tv/ad/7mvR/the-partnership-at-drugfreeorg-awkward-silence\"")
				if [ $? == 0 ]; then
					addtohistory "$question"
					mainmenu
				else
					zenity --error --text="No URL detected."
					mainmenu
				fi
			else
				if [[ "$baseurl" == *"Dig"*"HTTP"* ]]; then
					question=$(getuserinputfromtextbox "URL?")
					if [ $? == 0 ]; then
						baseurl="$question"
						digforurl http
					else
						zenity --error --text="No URL detected."
						mainmenu
					fi
				else
					if [[ "$baseurl" == *"Dig"*"HLS"* ]]; then
						question=$(getuserinputfromtextbox "URL?")
						if [ $? == 0 ]; then
							baseurl="$question"
							digforurl hls
						else
							zenity --error --text="No URL detected."
							mainmenu
						fi
					else
						if [[ "$baseurl" == "Remove A Saved Link" ]]; then
							removefromhistorydialog
						else
							if [[ "$baseurl" == "Open A New Link" ]]; then
								urlwrangler
							else
								putlinkattopofhistory "$baseurl"
								urlwrangler "$baseurl"
							fi
						fi
					fi
				fi
			fi
		fi
	else
		exit
	fi
}

reopencheck() {
	echo "zenity --list \\
	--radiolist \\
	--text \"$reopentext\" \\
	--width=500 --height=250 \\
	--title=\"LiveStreamLinkGUI: $(gettitlename)\" \\
	--column=\"?\" --column=\"What Now?:\" \\
	TRUE \"Attempt to Reopen\" \\
	FALSE \"Reopen Stream And Chat(if possible)\" \\
	FALSE \"Loop Forever\" \\
	FALSE \"Save Link: $baseurl\" \\
	FALSE \"Open Link in Browser: $(removethename "$baseurl")\" \\
	FALSE \"Open A New Link\" \\
	FALSE \"Save A New Link\" \\" > $configdir/livestreamlinkgui-deleteme
#	FALSE \"(Experimental) Dig for a URL (REOPEN) (HTTP)\" \\
#	FALSE \"(Experimental) Dig for a URL (REOPEN) (HLS)\" \\
#	FALSE \"(Experimental) Dig for a URL (NEW) (HTTP)\" \\
#	FALSE \"(Experimental) Dig for a URL (NEW) (HLS)\" \\" > $configdir/livestreamlinkgui-deleteme
	while read line
	do
		string=$(getpingstring "$line")
		echo "	FALSE \"$string\" \\" >> $configdir/livestreamlinkgui-deleteme
	done < "$configdir/history"
	echo "	FALSE \"Remove A Saved Link\" \\" >> $configdir/livestreamlinkgui-deleteme
	echo "	FALSE \"Close Program\"" >> $configdir/livestreamlinkgui-deleteme
	checklist=$($configdir/livestreamlinkgui-deleteme)
	>$configdir/livestreamlinkgui-deleteme
	#Can't use a case statement here because of the save history (without monkeying with arrays). So nested if statements are used instead. It's probably better like this anyways to conserve system resources.
	if [[ $checklist ]]; then
		if [[ $checklist == "Close Program" ]]; then
			exit
		else
			if [[ $checklist == *"Save Link:"* ]]; then
				question=$(getuserinputfromtextbox "Name To Save?\nYou can name links. The name will appear before the link.\nIf you don't care about giving it a name, just click \"OK\".\nEXAMPLE: \"Name $(removethename "$baseurl")\"\nIf this link is already in your history:\n\tSaving a new name will overwrite the previous name.\n\tCanceling or leaving this blank will not change the name.\nNOTE: Don't put a space after the name.")
				if [ $? == 0 ]; then
					if [[ $question == "" ]]; then
						addtohistory "$baseurl"
					else
						addtohistory "$question $(removethename "$baseurl")"
					fi
					mainmenu
				else
					zenity --error --text="No name given. Saving without name."
					addtohistory "$baseurl"
				fi
			else
				if [[ $checklist == *"Open Link in Browser: "* ]]; then
					xdg-open $(removethename "$baseurl") &
					reopencheck
				else
					if [[ $checklist == "Remove A Saved Link" ]]; then
						removefromhistorydialog
					else
						if [[ $checklist == "Open A New Link" ]]; then
							urlwrangler
						else
							if [[ $checklist == "Attempt to Reopen" ]]; then
								openstream
							else
								if [[ $checklist == "Reopen Stream And Chat"* ]]; then
									openchat &
									openstream
								else
									if [[ $checklist == "Loop Forever" ]]; then
										loopforever=true
										playercmd=$playercmd" --fullscreen"
										shouldreopencheck=false
										openstream
									else
										if [[ $checklist == "Save A New Link" ]]; then
											question=$(getuserinputfromtextbox "URL To Save?")
											if [ $? == 0 ]; then
												addtohistory "$question"
												mainmenu
											else
												zenity --error --text="No URL detected."
												mainmenu
											fi
										else
											if [[ $checklist == *"Dig"*"REOPEN"*"HTTP"* ]]; then
												digforurl http
											else
												if [[ $checklist == *"Dig"*"REOPEN"*"HLS"* ]]; then
													digforurl hls
												else
													if [[ $checklist == *"Dig"*"NEW"*"HTTP"* ]]; then
														question=$(getuserinputfromtextbox "URL?")
														if [ $? == 0 ]; then
															baseurl="$question"
															digforurl http
															reopencheck
														else
															zenity --error --text="No URL detected."
															mainmenu
														fi
													else
														if [[ $checklist == *"Dig"*"NEW"*"HLS"* ]]; then
															question=$(getuserinputfromtextbox "URL?")
															if [ $? == 0 ]; then
																baseurl="$question"
																digforurl hls
																reopencheck
															else
																zenity --error --text="No URL detected."
																mainmenu
															fi
														else
															baseurl=$checklist
															putlinkattopofhistory "$baseurl"
															urlwrangler "$baseurl"
														fi
													fi
												fi
											fi
										fi
									fi
								fi
							fi
						fi
					fi
				fi
			fi
		fi
	else
		exit
	fi
}

#First time setup.
if [ -d "$configdir" ]; then
	>$configdir/livestreamlinkgui-deleteme
	chmod u+x $configdir/livestreamlinkgui-deleteme
	mainmenu
else
	#Ask about configdir.
	question=$(zenity --question --text="It appears this is the first time this script has run on\nthis system. LiveStreamLinkGUI needs a directory to\ntemporarily write data and save some configuration\nfiles to.\n\nThis directory will be $configdir\n\nIs this acceptable?" --title="LiveStreamLinkGUI")

	if [[ $? == 0 ]]; then
		#Yes, configdir is okay.
		mkdir -p $configdir
		>$configdir/livestreamlinkgui-deleteme
		chmod u+x $configdir/livestreamlinkgui-deleteme

		#Ask about stream quality priority.
		question=$(zenity --entry --text="Stream quality priority?\nUse commas to separate different qualities.\nThese values are saved at $configdir/qualitypriority.\nDefault priority: $lsquality" --entry-text="$lsquality" --title="LiveStreamLinkGUI")
		if [[ $? == 1 ]]; then
			#Canceled.
			zenity --warning --text="Canceled. No configuration was written. Setup has been halted. If you want to run the setup again, delete $configdir and run this script again. Otherwise all user specific configurations will have to be created manually." --title="LiveStreamLinkGUI"
		else
			#Write config for quality priority.
			echo "$question" > $configdir/qualitypriority

			#Ask about chat prompt.
			question=$(zenity --list --radiolist --text="Some streams have popout chat windows for your webbrowser\n(such as Twitch and Vaughnlive) and LiveStreamLinkGUI supports\nopening chat windows for some of these websites.\nIf LiveStreamLinkGUI can open a stream's chat in your browser,\nit will ask you if you want to open it every time.\n\nDo you want to enable this?\n\nThis value is saved at $configdir/chatopenpref" --title="LiveStreamLinkGUI" --width=600 --height=400 --column="?" --column="Options:" TRUE "Always Ask" FALSE "Always Open Without Asking" FALSE "Never Ask Or Open")

			if [[ $? == 1 ]]; then
				#Canceled.
				zenity --warning --text="Canceled. No configuration was written. Setup has been halted. If you want to run the setup again, delete $configdir and run this script again. Otherwise all user specific configurations will have to be created manually." --title="LiveStreamLinkGUI"
			else
				#Choice Made.
				if [[ "$question" == "Always Ask" ]]; then
					echo "ask" > $configdir/chatopenpref
				fi
				if [[ "$question" == "Always Open Without Asking" ]]; then
					echo "always" > $configdir/chatopenpref
				fi
				if [[ "$question" == "Never Ask Or Open" ]]; then
					echo "ignore" > $configdir/chatopenpref
				fi

				printf "Setup is complete!\nHere is your configuration:\nConfiguration Directory: $configdir\nStream Quality Priority: $(cat $configdir/qualitypriority)\nOpen Chat Configuration: $(cat $configdir/chatopenpref)\n\nThe LiveStreamLinkGUI Main Menu will display when this window is closed." | zenity --text-info --title="LiveStreamLinkGUI" --width=600 --height=400
				mainmenu
			fi
		fi
	else
		#No, configdir is not okay.
		zenity --warning --text="If you are not satisfied with the default directory, then please open the LiveStreamLinkGUI script with a text editor and change the value for \"configdir\" near the top." --title="LiveStreamLinkGUI"
	fi
fi

#this was used for very early testing from command line. Pretty much meaningless now:
if [ $1 ]; then
	if [[ $1 =~ "twitch.tv" ]]; then
		echo "Twitch link detected. Open chat? y/n"
		read input
		if [ ${input:0:1} == "y" ] || [ ${input:0:1} == "Y" ]; then
			echo "Yes detected. Opening chat..."
			xdg-open $1/chat
		else
			echo "No detected. Skipping..."
		fi
	fi
	launchplayer
#else
#	mainmenu
fi
