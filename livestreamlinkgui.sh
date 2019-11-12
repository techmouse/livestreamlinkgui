#!/bin/bash

########################################
#LiveStreamLinkGUI
#By Mouse
#Last edited: 12-NOV-19
########################################

########################################
#User Preferences
########################################
#You can change the value below to easily switch back and forth between livestreamer, streamlink and any future forks.
export streamercmd="streamlink --http-no-ssl-verify"

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

#Some websites like being a pain and frequently stop working with Livestreamer/Streamlink. And if you were to find a fix for that site's plugin (and wanted to change the plugin manually, instead of waiting for it to be updated in the repositories), you would have to elevate yourself to superuser status, edit the file, and then save it. Then you would have to do this with every system that uses Livestreamer/Streamlink, which involves memorizing, writing down, emailing, or somehow keeping track of the changes you need to make. It can be very annoying when all you want to do is turn on a show while you work. But now, you can save plugins you edit yourself to <your LiveStreamLinkGUI config directory>/plugins without needing an admin password, set a cloud service to sync the directory across all of your systems, and they will automatically update when you edit a plugin! So when a fix is found for a website, you only need to make one change on one system and the rest will update, too! Plugins in this secondary directory take priority over the default plugins, and you only need to add the plugins you want to overwrite the default plugins.
if [ -d "$configdir/plugins" ]; then
	export extralsflags="--plugin-dirs $configdir/plugins"
else
	export extralsflags=""
fi


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
export streamname=""
export loopforever=false
export baseurl=""
export reopentext=""
export shouldreopencheck=true
export playlistmode=false
export playlistnum=2

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
			result=$($streamercmd $@ $extralsflags $url)
			if [[ "$result" == *"No plugin can handle"* ]]; then
				digforurl http
			else
				$streamercmd -p "$playercmd $@" $extralsflags $url $lsquality
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
		tmp=$(removethename "$filtered")
		if [[ $(isinhistory "$tmp") == false ]]; then
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
	--text \"Which Link To Remove?\" \\
	--width=500 --height=350 \\
	--title=\"LiveStreamLinkGUI: Remove A Link\" \\
	--column=\"Available Choices:\" \\" > $configdir/livestreamlinkgui-deleteme
	while read line
	do
		echo "	\"$line\" \\" >> $configdir/livestreamlinkgui-deleteme
	done < "$configdir/history"
	echo "	\"Go Back\"" >> $configdir/livestreamlinkgui-deleteme
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
		if [[ $(isinhistory "$1") == true ]]; then
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
	fi
}

isinhistory(){
	if [[ "$1" ]]; then
		found=false
		tmp=$(removethename "$1")
		while read line
		do
			if [[ "$tmp" == $(removethename "$line") ]]; then
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
		tmp="$1"
#		if [[ "$tmp" == *" "* ]] && [[ $(isinhistory "$tmp") == true ]]; then
		if [[ "$tmp" == *" "* ]]; then
			if [[ $(isalinktoafile "$tmp") == true ]]; then
				if [[ "$tmp" == *"/"* ]]; then
					tmp=${tmp#*"/"}
					tmp="/$tmp"
				fi
			else
				tmp=${tmp##*" "}
			fi
		fi
		echo "$tmp"
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

isalinktoafile(){
	found=false
	if [ "$1" ]; then
		for i in ${!filetypes[@]}; do
			if [[ $found == false ]]; then
				if [[ "$1" == *"${filetypes[$i]}"* ]]; then
					found=true
				fi
			fi
		done
	fi
	echo $found
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

#Why did I clear url?
#	url=""

	#There are two different dig "modes". Many links tack ID crap on to the end of a file path (example: http://site.com/dir/path/file.mp4?id=123456790), and just linking directly to the file without the ID crap (example: http://site.com/dir/path/file.mp4) does nothing.
	#"Mode A" works better for this because it preserves the ID crap.
	#However, usually there are a lot of media thumbnails in mp4, flv, webm, etc format so when the user hovers over the thumbnail, a short preview video will play. Ads are also sometimes in these media formats. But all of these are usually at the beginning of the page.
	#"Mode B"/false works better in these situations because it searches through the file backwards.
	#I can't think of any way to set this up so LSLGUI will automatically differentiate between the two situations, so I kind of just have to pick one and go with it. It's not bulletproof, but overall it works better.
	digmodea=true
	found=false
	if [[ $digmodea == true ]]; then
		while read line; do
			if [[ $found == false ]]; then
				for i in ${!filetypes[@]}; do
					if [[ "$line" == *"${filetypes[$i]}"* ]] && [[ $found == false ]]; then
						found=true
						blocktotest=${line##*"//"}
						if [[ "$line" == *"\'"* ]]; then
							blocktotest=${blocktotest%"\'"*}
							url="$protocol://$blocktotest"
						else
							if [[ "$line" == *"\""* ]]; then
								blocktotest=${blocktotest%"\""*}
								url="$protocol://$blocktotest"
							else
								blocktotest=${blocktotest%"${filetypes[$i]}"*}
								url="$protocol://$blocktotest${filetypes[$i]}"
							fi
						fi
						openstream
					fi
				done
			fi
		done < "$configdir/livestreamlinkgui-deleteme"
	
	else
		#old version:
		tempfile=$(cat $configdir/livestreamlinkgui-deleteme)
		for i in ${!filetypes[@]}; do
			if [[ "$tempfile" == *"${filetypes[$i]}"* ]] && [[ $found == false ]]; then
				found=true
				blocktotest=${tempfile%"${filetypes[$i]}"*}
				blocktotest=${blocktotest##*"//"}
				url="$protocol://$blocktotest${filetypes[$i]}"
				openstream
			fi
		done
	fi

	#rm is dangerous; make the file empty instead:
	>$configdir/livestreamlinkgui-deleteme

	if [[ ! "$url" == "" ]]; then
		reopentext="$url"
	else
		reopentext="No supported file types found."
	fi

	mainmenu
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

	if [[ $playlistmode == false ]]; then
		#non playlists
		url=$(removethename "$baseurl")
	fi

	if [[ $shouldadddigprefix == true ]]; then
		url="LSLGUIdig://$url"
	fi

	if [[ "$url" ]]; then
		if [[ $playlistmode == false ]]; then
			inhistorycheck "$baseurl"
		fi
		echo "Opening $url"
		checkforchat &

		streamname=""

		case "$url" in
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
				extralsflags="$extralsflags --player-continuous-http"
				openstream
			;;

			#special cases (LiveStreamLinkGUI plays and closes when done):
			#Non-stream video inputs are better suited here. Copy and paste blocks to use a template.
			*"roosterteeth.com"*)
				url=$(findurlbyextension .m3u8)
				if [[ "$url" == "" ]]; then
					zenity --error --title="LiveStreamLinkGUI" --text="m3u8 link not found.\n\nThis is usually caused by Rooster Teeth requiring a member subscription.\n\nExiting."
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
					zenity --error --title="LiveStreamLinkGUI" --text="mp4 link not found.\n\nExiting."
				else
					# findurlbyextension found a url so now we must prefix the proper protocol.
					url="http://$url"
					openstream
				fi
			;;

			#youtube cases:
			*"youtube.com"*)
				shouldreopencheck=false
				if [[ "$url" == *"https:"* ]]; then
					url=${url/https/http}
				fi
				$playercmd --preferred-resolution $youtuberesolution $url $extrayoutubeflags
			;;
			*"youtu.be"*)
				shouldreopencheck=false
				if [[ "$url" == *"https:"* ]]; then
					url=${url/https/http}
				fi
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
		zenity --error --title="LiveStreamLinkGUI" --text="Empty URL detected."
		mainmenu
	fi
}

openchat() {
	if [[ "$url" =~ "twitch.tv" ]]; then
		streamname=${url##*/}
		xdg-open "$url"/chat
	fi

	if [[ "$url" =~ "vaughnlive.tv" ]]; then
		streamname=${url##*/}
		xdg-open http://vaughnlive.tv/popout/chat/$streamname
	fi

	if [[ "$url" =~ "hitbox.tv" ]]; then
		streamname=${url##*/}
		xdg-open http://www.hitbox.tv/embedchat/$streamname?autoconnect=true
	fi

	if [[ "$url" =~ "arconai.tv" ]]; then
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
	if [[ $chatopenpref == "ask" ]]; then
		if [[ "$url" =~ "twitch.tv" ]]; then
			streamname=${url##*/}
			zenity --question --text="Twitch link detected. Open $streamname's chat?" --title="LiveStreamLinkGUI: $streamname"
			if [[ $? == 0 ]]; then
				openchat
			fi
		fi

		if [[ "$url" =~ "hitbox.tv" ]]; then
			streamname=${url##*/}
			zenity --question --text="Hitbox link detected. Open $streamname's chat?" --title="LiveStreamLinkGUI: $streamname"
			if [[ $? == 0 ]]; then
				openchat
			fi
		fi

		if [[ "$url" =~ "vaughnlive.tv" ]]; then
			streamname=${url##*/}
			zenity --question --text="Vaughnlive link detected. Open $streamname's chat?" --title="LiveStreamLinkGUI: $streamname"
			if [[ $? == 0 ]]; then
				openchat
			fi
		fi

		if [[ "$url" =~ "arconai.tv" ]]; then
			streamname=${url##*arconai.tv/}
			streamname=$(echo $streamname | sed 's/\///g')
			zenity --question --text="Arconai link detected. Open $streamname's chat?" --title="LiveStreamLinkGUI: $streamname"
			if [[ $? == 0 ]]; then
				openchat
			fi
		fi
	fi
	if [[ $chatopenpref == "always" ]]; then
		openchat
	fi
}

openstream() {
#FIXME: when the vaughnlive plugin is fixed, delete this block:
	if [[ "$baseurl" =~ "vaughnlive.tv" ]] && [[ true == false ]]; then
		streamercmd="$streamercmd --http-header Referer=http://vaughnlive.tv/$streamname"
		url=""
#Server locations:
#den = denver server
#ord = orlando server
#nyc = newyork server
#ams = amsterdam, nl
#Known working alts:
#4a. 1a. 2a.
		$streamercmd -p "$playercmd $@ $extralsflags" "hlsvariant://https://hls-ord-4a.vaughnsoft.net/den/live/live_$streamname/playlist.m3u8" "$lsquality"
	fi

	#Non-livestreamer/streamlink supported streams are better suited here. Copy and paste blocks to use a template.
	if [[ "$baseurl" =~ "arconai.tv" ]] && [[ true == false ]]; then
		url=$(findurlbyextension .m3u8)
		if [[ "$url" == "" ]]; then
			zenity --error --title="LiveStreamLinkGUI" --text="m3u8 link not found."
		else
			# findurlbyextension found a url so now we must prefix the proper protocol.
			url="http://$url"
#			playercmd="$playercmd --no-repeat"
		fi
	fi

	if [[ "$baseurl" =~ "ssh101.com" ]]; then
		url=$(findurlbyextension .m3u8)
		if [[ "$url" == "" ]]; then
			zenity --error --title="LiveStreamLinkGUI" --text="m3u8 link not found."
		else
			# findurlbyextension found a url so now we must prefix the proper protocol.
			url="hlsvariant://http://$url"
		fi
	fi

	# Now we launch our player.
	if [[ ! "$url" == "" ]]; then
		launchplayer
	fi

	if [[ $loopforever == true ]]; then
		sleep 1
	fi

	if [[ $playlistmode == true ]]; then
		playlistnum=$(($playlistnum+1))
		tmp=$(sed $playlistnum'q;d' "$configdir/playlists/$baseurl")
		url=$(removethename "$tmp")
		if [[ "$url" == "" ]]; then
			if [[ $loopforever == true ]]; then
				playlistnum=2
				tmp=$(sed '2q;d' "$configdir/playlists/$baseurl")
				url=$(removethename "$tmp")
			else
				zenity --error --title="LiveStreamLinkGUI" --text="The end of the playlist has been reached.\n\nExiting."
				exit
			fi
		fi
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
		mainmenu
	else
		if [[ $shouldreopencheck == false ]]; then
			if [[ $loopforever == true || $playlistmode == true ]]; then
				openstream
			fi
		fi
	fi
}

gettitlename() {
	if [[ ! "$streamname" == "" ]]; then
		echo "$streamname"
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

createaplaylist(){
	mkdir -p $configdir/playlists
	tmp=$(getuserinputfromtextbox "What do you want to name the new playlist?\n\nNOTES:\n-The playlist name will also be the filename so use appropriate characters.\n-Deleting playlists is outside the scope of LSLGUI, as rm is dangerous, so\n you can either rename and repurpose unused playlists, or manually delete\n any you create.\n\nYour playlists will be saved at $configdir/playlists/")
	if [[ ! "$tmp" == "" ]]; then
		>"$configdir/playlists/$tmp"
		editplaylistoptions "$tmp"
		editaplaylist "$tmp"
	else
		zenity --error --title="LiveStreamLinkGUI" --text="Playlist creation canceled."
	fi
}

editplaylistoptions(){
	if ! [[ "$1" ]]; then
		echo "zenity --list \\
		--text \"Which Playlist?\" \\
		--width=500 --height=350 \\
		--title=\"LiveStreamLinkGUI\" \\
		--column=\"Available Choices:\" \\" > $configdir/livestreamlinkgui-deleteme

		for i in $configdir/playlists/*; do
			if [ -f "$i" ]; then
				i=${i##*"/"}
				echo "	\"$i\" \\" >> $configdir/livestreamlinkgui-deleteme
			fi
		done

		tmp=$($configdir/livestreamlinkgui-deleteme)
		>$configdir/livestreamlinkgui-deleteme
	else
		tmp="$1"
	fi

	if [[ "$tmp" ]] && ! [[ "$tmp" == "" ]]; then
		if ! [[ -f "$configdir/playlists/$tmp" ]]; then
			#File doesn't exist. Create it.
			>"$configdir/playlists/$tmp"
		fi

		#Create list of menus
		echo "zenity --list \\
		--checklist \\
		--text \"What options do you want the playlist to have?\" \\
		--width=500 --height=350 \\
		--title=\"LiveStreamLinkGUI\" \\
		--column=\"?\" --column=\"Available Options:\" \\
			FALSE \"Ask To Open Chat For Each Link\" \\
			FALSE \"Open Each Link In Fullscreen\" \\
			TRUE \"Loop The Playlist Forever (Must be killed manually)\"" > $configdir/livestreamlinkgui-deleteme

		#Get user's response
		tmp2="$($configdir/livestreamlinkgui-deleteme)"

		#Copy entire playlist, options and all.
		cp "$configdir/playlists/$tmp" "$configdir/livestreamlinkgui-deleteme"

		#Clear old list and write new options to the top.
		echo "$tmp2" > "$configdir/playlists/$tmp"

		#Done with tmp2, use it to ignore first line when copying the old list to the new list.
		tmp2=false
		while read line
		do
			if [[ $tmp2 == false ]]; then
				tmp2=true
			else
				if ! [[ "$line" == "" ]]; then
					echo "$line" >> "$configdir/playlists/$tmp"
				fi
			fi
		done < "$configdir/livestreamlinkgui-deleteme"

		>$configdir/livestreamlinkgui-deleteme
	else
		zenity --error --title="LiveStreamLinkGUI" --text="Canceled."
	fi
}

editaplaylist(){
	tmp="$1"
	if ! [ "$tmp" ]; then
		# A playlist wasn't passed so we ask user to pick one.
		echo "zenity --list \\
		--text \"Which Playlist?\" \\
		--width=500 --height=350 \\
		--title=\"LiveStreamLinkGUI\" \\
		--column=\"Available Choices:\" \\" > $configdir/livestreamlinkgui-deleteme

		for i in $configdir/playlists/*; do
			if [ -f "$i" ]; then
				i=${i##*"/"}
				echo "	\"$i\" \\" >> $configdir/livestreamlinkgui-deleteme
			fi
		done

		tmp=$($configdir/livestreamlinkgui-deleteme)
		>$configdir/livestreamlinkgui-deleteme
	fi

	echo "zenity --list \\
	--checklist \\
	--text \"What links do you want to the playlist to have?\" \\
	--width=500 --height=350 \\
	--title=\"LiveStreamLinkGUI\" \\
	--column=\"?\" --column=\"Available Choices:\" \\" > $configdir/livestreamlinkgui-deleteme

	tmp2=false
	while read line
	do
		if [[ $tmp2 == false ]]; then
			tmp2=true
		else
			if ! [[ "$line" == "" ]]; then
				echo "	TRUE \"$line\" \\" >> $configdir/livestreamlinkgui-deleteme
			fi
		fi
	done < "$configdir/playlists/$tmp"

	while read line
	do
		if ! [[ $(cat "$configdir/livestreamlinkgui-deleteme") == *"$line"* ]]; then
			echo "	FALSE \"$line\" \\" >> $configdir/livestreamlinkgui-deleteme
		fi
	done < "$configdir/history"


	tmp2=$($configdir/livestreamlinkgui-deleteme)

	if ! [[ $tmp2 == "" ]]; then
		#preserve playlist options:
		echo $(sed "1q;d" "$configdir/playlists/$tmp") > "$configdir/playlists/$tmp"
		#change '|'s to newlines:
		echo "${tmp2//\|/$'\n'}" >> "$configdir/playlists/$tmp"
	else
		zenity --error --title="LiveStreamLinkGUI" --text="Either nothing was selected or the edit was canceled.\n\nPlaylist not saved."
	fi

	>$configdir/livestreamlinkgui-deleteme

}

editplaylistsmenu(){
	echo "zenity --list \\
	--text \"Which Playlist To Edit?\" \\
	--width=500 --height=350 \\
	--title=\"LiveStreamLinkGUI\" \\
	--column=\"Options:\" \\
		\"Create A New Playlist\" \\
		\"Rename A Playlist\" \\
		\"Edit A Playlist's Options\" \\" >> $configdir/livestreamlinkgui-deleteme

	for i in $configdir/playlists/*; do
		if [ -f "$i" ]; then
			i=${i##*"/"}
			echo "	\"$i\" \\" >> $configdir/livestreamlinkgui-deleteme
		fi
	done
	echo "	\"Go Back\"" >> $configdir/livestreamlinkgui-deleteme

	tmp=$($configdir/livestreamlinkgui-deleteme)
	if [[ $? == 0 ]] && [[ "$tmp" == "" ]]; then
		tmp="Create A New Playlist"
	fi
	>$configdir/livestreamlinkgui-deleteme

	if ! [[ "$tmp" == "" ]]; then
		if [[ "$tmp" == "Create A New Playlist" ]]; then
			createaplaylist
		else
			if [[ "$tmp" == "Rename A Playlist" ]]; then
				renameaplaylist
			else
				if [[ "$tmp" == "Edit A Playlist's Options" ]]; then
					editplaylistoptions
				else
					if ! [[ "$tmp" == "Go Back" ]]; then
						editaplaylist "$tmp"
					fi
				fi
			fi
		fi
	fi
}

renameaplaylist(){
	echo "zenity --list \\
	--text \"Which Playlist To Rename?\" \\
	--width=500 --height=350 \\
	--title=\"LiveStreamLinkGUI\" \\
	--column=\"Available Choices:\" \\" > $configdir/livestreamlinkgui-deleteme

	for i in $configdir/playlists/*; do
		if [ -f "$i" ]; then
			i=${i##*"/"}
			echo "	\"$i\" \\" >> $configdir/livestreamlinkgui-deleteme
		fi
	done

	tmp=$($configdir/livestreamlinkgui-deleteme)
	>$configdir/livestreamlinkgui-deleteme

	if ! [[ "$tmp" == "" ]]; then
		tmp2=$(getuserinputfromtextbox "What do you want to rename $tmp to?\n\nNOTES:\n-The playlist name will also be the filename so use appropriate characters.\n-Deleting playlists is outside the scope of LSLGUI, as rm is dangerous, so\n you can either rename and repurpose unused playlists, or manually delete\n any you create.\n\nYour playlists will be saved at $configdir/playlists/")
		if ! [[ "$tmp2" == "" ]]; then
			mv "$configdir/playlists/$tmp" "$configdir/playlists/$tmp2"
		else
			zenity --error --title="LiveStreamLinkGUI" --text="Canceled."
		fi
	else
		zenity --error --title="LiveStreamLinkGUI" --text="Canceled."
	fi

	>$configdir/livestreamlinkgui-deleteme
}

mainmenu(){
	if ! [[ "$baseurl" == "" ]]; then
		echo "zenity --list \\
		--text \"$reopentext\" \\
		--width=500 --height=350 \\
		--title=\"LiveStreamLinkGUI: $(gettitlename)\" \\
		--column=\"What Now?:\" \\
		\"Attempt to Reopen\" \\
		\"Reopen Stream And Chat(if possible)\" \\
		\"Loop Forever\" \\
		\"Save Link: $baseurl\" \\
		\"Open Link in Browser: $(removethename "$baseurl")\" \\
		\"Open A New Link\" \\
		\"Save A New Link\" \\" > $configdir/livestreamlinkgui-deleteme
	else
		echo "zenity --list \\
		--text \"Main Menu:\" \\
		--width=500 --height=350 \\
		--title=\"LiveStreamLinkGUI\" \\
		--column=\"Available Choices:\" \\
		\"Open A New Link\" \\
		\"Save A New Link\" \\" > $configdir/livestreamlinkgui-deleteme
	fi

	tmp=false
	for i in $configdir/playlists/*; do
		if [ -f "$i" ]; then
			if [[ $tmp == false ]]; then
				echo "	\"Create/Edit Playlists\" \\" >> $configdir/livestreamlinkgui-deleteme
				tmp=true
			fi
			i=${i##*"/"}
			echo "	\"$i\" \\" >> $configdir/livestreamlinkgui-deleteme
		fi
	done
	if [[ $tmp == false ]]; then
		echo "	\"Create A Playlist\" \\" >> $configdir/livestreamlinkgui-deleteme
	fi

	while read line
	do
		string=$(getpingstring "$line")
		echo "	\"$string\" \\" >> $configdir/livestreamlinkgui-deleteme

	done < "$configdir/history"
	echo "	\"Remove A Saved Link\" \\" >> $configdir/livestreamlinkgui-deleteme
	echo "	\"Close Program\"" >> $configdir/livestreamlinkgui-deleteme

	checklist=$($configdir/livestreamlinkgui-deleteme)
	tmp=$?
	>$configdir/livestreamlinkgui-deleteme

	if [[ "$tmp" == 0 ]]; then
		if [[ "$checklist" == "" ]]; then
			if [[ "$baseurl" == "" ]]; then
				checklist="Open A New Link"
			else
				checklist="Attempt to Reopen"
			fi
		fi
		case "$checklist" in
		"Close Program")
			exit
			;;
		"Save A New Link")
			question=$(getuserinputfromtextbox "URL To Save?\nYou can name links by putting the name before the link.\nThis is completely optional.\nEXAMPLE: \"Don't Do Drugs https://www.ispot.tv/ad/7mvR/the-partnership-at-drugfreeorg-awkward-silence\"")
			if [ $? == 0 ]; then
				addtohistory "$question"
				baseurl=""
				mainmenu
			else
				zenity --error --title="LiveStreamLinkGUI" --text="No URL detected."
				baseurl=""
				mainmenu
			fi
			;;
		*"Dig"*"HTTP"*)
			question=$(getuserinputfromtextbox "URL?")
			if [ $? == 0 ]; then
				baseurl="$question"
				digforurl http
			else
				zenity --error --title="LiveStreamLinkGUI" --text="No URL detected."
				baseurl=""
				mainmenu
			fi
			;;
		*"Dig"*"HLS"*)
			question=$(getuserinputfromtextbox "URL?")
			if [ $? == 0 ]; then
				baseurl="$question"
				digforurl hls
			else
				zenity --error --title="LiveStreamLinkGUI" --text="No URL detected."
				baseurl=""
				mainmenu
			fi
			;;
		"Remove A Saved Link")
			removefromhistorydialog
			;;
		"Open A New Link")
			urlwrangler
			;;
		*"Save Link:"*)
			question=$(getuserinputfromtextbox "Name To Save?\nYou can name links. The name will appear before the link.\nIf you don't care about giving it a name, just click \"OK\".\nEXAMPLE: \"Name $(removethename "$baseurl")\"\nIf this link is already in your history:\n\tSaving a new name will overwrite the previous name.\n\tCanceling or leaving this blank will not change the name.\nNOTE: Don't put a space after the name.")
			if [ $? == 0 ]; then
				if [[ "$question" == "" ]]; then
					addtohistory "$baseurl"
				else
					baseurl=$(removethename "$baseurl")
					baseurl="$question $baseurl"
					addtohistory "$baseurl"
				fi
				mainmenu
			else
				zenity --error --title="LiveStreamLinkGUI" --text="No name given. Saving without name."
				addtohistory "$baseurl"
			fi
			;;
		*"Open Link in Browser: "*)
			xdg-open $(removethename "$baseurl") &
			mainmenu
			;;
		"Attempt to Reopen")
			openstream
			;;
		"Reopen Stream And Chat"*)
			openchat &
			openstream
			;;
		"Loop Forever")
			loopforever=true
			playercmd="$playercmd --fullscreen"
			shouldreopencheck=false
			openstream
			;;
		"Create A Playlist")
			createaplaylist
			mainmenu
			;;
		"Create/Edit Playlists")
			editplaylistsmenu
			mainmenu
			;;
		*)
			baseurl="$checklist"

			if [ -f "$configdir/playlists/$baseurl" ]; then
				#only for playlists
				shouldreopencheck=false
				playlistmode=true
				#check options
				tmp=$(sed '1q;d' "$configdir/playlists/$baseurl")
				if [[ "$tmp" == *"Chat"* ]]; then
					chatopenpref="ask"
				else
					chatopenpref=""
				fi
				if [[ "$tmp" == *"Forever"* ]]; then
					loopforever=true
				fi
				if [[ "$tmp" == *"Fullscreen"* ]]; then
					playercmd="$playercmd --fullscreen"
				fi
				tmp=$(sed $playlistnum'q;d' "$configdir/playlists/$baseurl")
				url=$(removethename "$tmp")
			else
				putlinkattopofhistory "$baseurl"
			fi

			urlwrangler "$baseurl"
			;;
		esac
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
		mkdir -p $configdir/playlists
		mkdir -p $configdir/plugins
		>$configdir/livestreamlinkgui-deleteme
		chmod u+x $configdir/livestreamlinkgui-deleteme

		#Ask about stream quality priority.
		question=$(zenity --entry --text="Stream quality priority?\nUse commas to separate different qualities.\nThese values are saved at $configdir/qualitypriority.\nSome examples: high, medium, low, 1080p, 720p, best, worst" --entry-text="$lsquality" --title="LiveStreamLinkGUI")
		if [[ $? == 1 ]]; then
			#Canceled.
			zenity --warning --text="Canceled. No configuration was written. Setup has been halted. If you want to run the setup again, delete $configdir and run this script again. Otherwise all user specific configurations will have to be created manually." --title="LiveStreamLinkGUI"
		else
			#Write config for quality priority.
			echo "$question" > $configdir/qualitypriority

			#Ask about chat prompt.
			question=$(zenity --list --text="Some streams have popout chat windows for your webbrowser\n(such as Twitch and Vaughnlive) and LiveStreamLinkGUI supports\nopening chat windows for some of these websites.\nIf LiveStreamLinkGUI can open a stream's chat in your browser,\nit will ask you if you want to open it every time.\n\nDo you want to enable this?\n\nThis value is saved at $configdir/chatopenpref" --title="LiveStreamLinkGUI" --width=600 --height=400 --column="Options:" "Always Ask" "Always Open Without Asking" "Never Ask Or Open")

			if [[ $? == 1 ]] || [[ "$question" == "" ]]; then
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
