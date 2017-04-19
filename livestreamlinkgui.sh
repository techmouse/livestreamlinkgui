#!/bin/bash

########################################
#LiveStreamLinkGUI
#By Mouse
#Last edited: 19-Apr-17
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
export playercmd="vlc --network-caching=15000 --no-qt-error-dialogs"

#Extra flags for livestreamer/streamlink. If you want to add some extra flags for livestreamer, streamlink or any future forks, add them to the variable below.
export extralsflags=""

#Youtube preferred resolution. This is for what resolution you prefer when opening Youtube videos and streams.
export youtuberesolution="360p"
#Extra flags for playing Youtube videos in VLC. This is for any extra flags you would like to have when opening Youtube videos.
export extrayoutubeflags="--play-and-exit"

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

launchplayer(){
	$streamercmd -p "$playercmd $@" $extralsflags $url $lsquality
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

addtohistory(){
	shouldadd=1
	while read line
	do
		if [[ $1 == $line ]]; then
			shouldadd=0
		fi
	done < "$configdir/history"
	if [ $shouldadd == 1 ]; then
		echo "$1" >> $configdir/history
		putlinkattopofhistory "$1"
	fi
}

removefromhistory(){
	cp $configdir/history $configdir/livestreamlinkgui-deleteme
	>$configdir/history
	while read line
	do
		if ! [[ $1 == $line ]]; then
			echo "$line" >> $configdir/history
		fi
	done < "$configdir/livestreamlinkgui-deleteme"
	>$configdir/livestreamlinkgui-deleteme
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
		if [[ $choice == "Go Back" ]]; then
			mainmenu
		else
			removefromhistory $choice
			mainmenu
		fi
	else
		mainmenu
	fi
}

putlinkattopofhistory(){
	if [ $1 ]; then
		removefromhistory $1
		cp $configdir/history $configdir/livestreamlinkgui-deleteme
		echo $1 > $configdir/history
		while read line
		do
			if ! [[ $1 == $line ]]; then
				echo "$line" >> $configdir/history
			fi
		done < "$configdir/livestreamlinkgui-deleteme"		
		>$configdir/livestreamlinkgui-deleteme
	fi
}

inhistorycheck(){
	if [ $1 ]; then
		found=0
		while read line
		do
			if [[ $1 == $line ]]; then
				found=1
			fi
		done < "$configdir/history"
		if [ $found == 1 ]; then
			putlinkattopofhistory $1
		fi
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
	while read line
	do

# Experimental:
# Very useful but takes a really long time to load the main menu if the saved history is long. Takes about 3-4 minutes with a saved history of 41.
# It also lacks support for sites livestreamer/streamlink doesn't support.
#		$streamercmd $line
#		if [[ $? == 0 ]]; then
#			echo "	FALSE \"$line (Online!)\" \\" >> $configdir/livestreamlinkgui-deleteme
#		else
#			echo "	FALSE \"$line\" \\" >> $configdir/livestreamlinkgui-deleteme
#		fi

		echo "	FALSE \"$line\" \\" >> $configdir/livestreamlinkgui-deleteme
	done < "$configdir/history"
	echo "	FALSE \"Remove A Saved Link\" \\" >> $configdir/livestreamlinkgui-deleteme
	echo "	FALSE \"Close Program\"" >> $configdir/livestreamlinkgui-deleteme
	baseurl=$($configdir/livestreamlinkgui-deleteme)
	>$configdir/livestreamlinkgui-deleteme
	#Can't use a case statement here because of the save history (without monkeying with arrays). So nested if statements are used instead. It's probably better like this anyways to conserve system resources.
	if [[ $baseurl ]]; then
		if [[ $baseurl == "Close Program" ]]; then
			exit
		else
			if [[ $baseurl == "Save A New Link" ]]; then
				question=$(zenity --entry --text="URL To Save?" --title="LiveStreamLinkGUI" --width=600)
				if [ $? == 0 ]; then
					addtohistory $question
					mainmenu
				else
					zenity --error --text="No URL detected."
					mainmenu
				fi
			else
				if [[ $baseurl == "Remove A Saved Link" ]]; then
					removefromhistorydialog
				else
					if [[ $baseurl == "Open A New Link" ]]; then
						urlwrangler
					else
						putlinkattopofhistory $baseurl
						urlwrangler $baseurl
					fi
				fi
			fi
		fi
	else
		exit
	fi
}

urlwrangler(){
	if ! [ $1 ]; then
		baseurl=$(zenity --entry --text="URL?" --title="LiveStreamLinkGUI" --width=600)
	fi
	url=$baseurl
	shouldreopencheck=true
	if [ $url ]; then
		inhistorycheck $baseurl
		echo "Opening $url"
		checkforchat &

		streamname=0

		case $url in
			#twitch check
			*"twitch.tv"*)
				streamname=${url##*/}
				#Use livestreamer --twitch-oauth-authenticate to get this token (it's in the url):
				extralsflags=$extralsflags""

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

			*"funhaus.rooster"*)
				wget $baseurl -O $configdir/livestreamlinkgui-deleteme
				tempfile=$(cat $configdir/livestreamlinkgui-deleteme)
				#filter out the m3u8 link.
				tempfile=${tempfile#*file:\ \'}
				tempfile=${tempfile%%\',*}
				url="$tempfile"
				#rm is dangerous; make the file empty instead:
				>$configdir/livestreamlinkgui-deleteme
				if [[ $url =~ "m3u8" ]]; then
					$playercmd --zoom .5 $url
				else
					zenity --error --text="m3u8 link not found. Exiting."
				fi
			;;


#			*"ssh101.com"*)
#				wget $baseurl -O $configdir/livestreamlinkgui-deleteme
#				tempfile=$(cat $configdir/livestreamlinkgui-deleteme)
#				#filter out the m3u8 link.
#				tempfile=${tempfile#*src=\"http\:\/\/}
#				tempfile=${tempfile%%\"\>*}
#				url="http://$tempfile"
				#rm is dangerous; make the file empty instead:
#				>$configdir/livestreamlinkgui-deleteme
#						if [[ $url =~ "m3u8" ]]; then
#							$playercmd $url
#						else
#					zenity --error --text="m3u8 link not found."
#				fi
#			;;


			#yt check
			*"youtube.com"*)
				shouldreopencheck=false
				$playercmd --preferred-resolution $youtuberesolution $url $extrayoutubeflags
			;;
			*"youtu.be"*)
				shouldreopencheck=false
				$playercmd --preferred-resolution $youtuberesolution $url $extrayoutubeflags
			;;

			#veetle check
			*"veetle.com"*)
				extralsflags=$extralsflags" --player-continuous-http"
				openstream
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
	fi
	if [ $chatopenpref == "always" ]; then
		openchat
	fi
}

openstream() {
	if [[ $baseurl =~ "arconaitv.me" ]]; then
		wget $baseurl -O $configdir/livestreamlinkgui-deleteme
		tempfile=$(cat $configdir/livestreamlinkgui-deleteme)
		#filter out the m3u8 link.
		tempfile=${tempfile#*source src=\"}
		tempfile=${tempfile%%\"\ *}
		url="hls://$tempfile"
		#rm is dangerous; make the file empty instead:
		>$configdir/livestreamlinkgui-deleteme
		if [[ ! $url =~ "m3u8" ]]; then
			zenity --error --text="m3u8 link not found."
		fi
	fi

	if [[ $baseurl =~ "ssh101.com" ]]; then
		wget $baseurl -O $configdir/livestreamlinkgui-deleteme
		tempfile=$(cat $configdir/livestreamlinkgui-deleteme)
		#filter out the m3u8 link.
		tempfile=${tempfile#*src=\"http\:\/\/}
		tempfile=${tempfile%%\"\>*}
		url="hlsvariant://http://$tempfile"
		#rm is dangerous; make the file empty instead:
		>$configdir/livestreamlinkgui-deleteme
		if [[ ! $url =~ "m3u8" ]]; then
			zenity --error --text="m3u8 link not found."
		fi
	fi

	if [ $loopforever == true ]; then
		while [ $loopforever == true ]; do
			launchplayer --fullscreen
			sleep 1
		done
	else
		launchplayer
	fi

	# Exit status 1 might mean streamer closed it or stream not present. Exit status 0 might mean closed by user.
	exitstatus=$?
	echo "Exit status: $exitstatus"
	if [ $exitstatus == 1 ]; then
		reopentext="$(gettitlename)\'s Stream Lost Or Not Found."
	fi
	if [ $exitstatus == 0 ]; then
		reopentext="$(gettitlename)\'s Stream Closed By $USER."
	fi

	if [[ $shouldreopencheck == true && $loopforever == false ]]; then
		reopencheck
	fi
}

gettitlename() {
	if [ $streamname != 0 ]; then
		echo $streamname
	else
		echo $baseurl
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
	FALSE \"Open A New Link\" \\
	FALSE \"Save A New Link\" \\" > $configdir/livestreamlinkgui-deleteme
	while read line
	do
		echo "	FALSE \"$line\" \\" >> $configdir/livestreamlinkgui-deleteme
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
				addtohistory $baseurl
				mainmenu
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
									openstream
								else
									if [[ $checklist == "Save A New Link" ]]; then
										question=$(zenity --entry --text="URL To Save?" --title="LiveStreamLinkGUI" --width=600)
										if [ $? == 0 ]; then
											addtohistory $question
											mainmenu
										else
											zenity --error --text="No URL detected."
											mainmenu
										fi
									else
										baseurl=$checklist
										putlinkattopofhistory $baseurl
										urlwrangler $baseurl
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
				if [[ $question == "Always Ask" ]]; then
					echo "ask" > $configdir/chatopenpref
				fi
				if [[ $question == "Always Open Without Asking" ]]; then
					echo "always" > $configdir/chatopenpref
				fi
				if [[ $question == "Never Ask Or Open" ]]; then
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
