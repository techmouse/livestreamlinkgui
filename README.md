# LiveStreamLinkGUI
![alt-text](screenshot.png)

This is LiveStreamLinkGUI. It's a lightweight GUI for Livestreamer, Streamlink, and any future forks. I made it for the personal use of my family and myself, but when I looked around, I saw people making requests for things I've already implemented. So I decided to share it. Its only requirements are BASH, rtmpdump, and zenity. I wrote it in Linux, for Linux, but because it's a BASH script, it should (in theory) work for any platform that supports BASH and its requirements. I hear Win10 has some kind of BASH support but I have no idea how capable it is of running this or any other script.

## Features
### Open Chats
Some websites have popout chats, such as twitch and vaughnlive. When you give LiveStreamLinkGUI a link for one of these sites, it can ask if you want to open the chat for that stream in your browser. It's important to know only the chat will be opened. So you don't have to worry about your browser eating up a lot of your system resources just to take part in the chat. I designed LiveStreamLinkGUI in a way where adding support for other sites shouldn't be difficult at all. All you need to know is the popout chat's URL and how to parse it.

### Save Links
LiveStreamLinkGUI can also save links. This makes it easy to keep track of your favorite streams and even open them without running your browser.

### Loop Forever
If the stream is lost or closed for whatever reason, you have the option to "loop forever". While doing so, LiveStreamLinkGUI will keep trying to reopen the stream until the script is manually killed. This is best used in a media setup, so you can keep watching your streams while you fall asleep, work, clean the house, or whatever. It works very well with the shutdown command. An example of the shutdown command (which can differ from distro to distro) is `sudo shutdown -hP {minutes}`, which will shutdown the system after the specified number of minutes. So it's similar to sleepmode for TVs.

### Dig for URL (Currently experimental)
This is a new mode that will "dig" through a link and search for common video types and automatically pipe them into a video player. If you're trying to view a stream or a video, that isn't supported by Livestreamer, Streamlink or other forks, you can take a crack at it with this mode. Keep in mind, it is experimental, so run LiveStreamLinkGUI through a terminal when playing with this just in case something very unexpected happens. That said I tested it using sites like imgur and twit.tv, and it worked completely fine. But I doubt this will work with videos that play using flash. It's important to note this is intended for testing and adding support for non-supported sites. Saving links for unsupported sites is not advised.

### Additional sites
I've added support for sites like arconaitv.me, funhaus.roosterteeth.com, and a few other sites. LiveStreamLinkGUI is designed so that adding support for other sites shouldn't be much of a chore.

### Configurations
All of the user specific configurations are at the top of the script. I would recommend going through them before running the script, but there is also a first time setup GUI which will help take you through the more basic configurations.

## How to use
If you want to open a new stream, all you have to do is execute the script and select "Open A New Link". A text input box will appear and you can drag and drop the link to that text box and click "OK". You can also copy-paste the link or manually type it in, if you so choose.

When the player closes, you're presented with a list of options. You can reopen it (if the stream is online), save the link for future use, loop it forever, open a new stream, open a saved stream, etc, etc. To save you a click, selecting "Close Program", is the same as clicking "Cancel", pressing ESC, or closing the window in any other way. So you don't have to scroll to the bottom every time you're done with the script.

For ease of use, I have a launcher for LiveStreamLinkGUI in my DE's panel. For media machines, I also keep a launcher for timed shutdowns. It makes it very easy to watch streams while falling asleep using only a pointer device. I'm not telling you what to do, I'm just telling you what I do.

As a side note, there's a VLC script that allows VLC to play Youtube playlists. Naturally, LiveStreamLinkGUI gets along very well with this.

## Last but not least...
Feel free to make whatever changes you want with this. If you make a change, such as adding chat support for other sites, or site support for any sites livestreamer/streamlink don't support, please let me know so I can add the changes too. If you redistribute this script, I would like to ask that you please give me credit as "Mouse". Thank you and enjoy!
