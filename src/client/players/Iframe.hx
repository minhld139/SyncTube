package client.players;

import Types.PlayerType;
import Types.VideoData;
import Types.VideoDataRequest;
import Types.VideoItem;
import client.Main.getEl;
import js.Browser.document;
import js.html.Element;

class Iframe implements IPlayer {
	final main:Main;
	final player:Player;
	final playerEl:Element = getEl("#ytapiplayer");
	var video:Element;

	public function new(main:Main, player:Player) {
		this.main = main;
		this.player = player;
	}

	public function getPlayerType():PlayerType {
		return IframeType;
	}

	public function isSupportedLink(url:String):Bool {
		return true;
	}

	public function getVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		final iframe = document.createDivElement();
		iframe.innerHTML = data.url.trim();
		if (isValidIframe(iframe)) {
			callback({duration: 99 * 60 * 60});
		} else {
			callback({duration: 0});
		}
	}

	function isValidIframe(iframe:Element):Bool {
		if (iframe.children.length != 1) return false;
		return (iframe.firstChild.nodeName == "IFRAME"
			|| iframe.firstChild.nodeName == "OBJECT");
	}

	public function loadVideo(item:VideoItem):Void {
		removeVideo();
		video = document.createDivElement();
		video.innerHTML = item.url; // actually data
		if (!isValidIframe(video)) {
			video = null;
			return;
		}
		if (video.firstChild.nodeName == "IFRAME") {
			video.setAttribute("sandbox", "allow-scripts");
		}
		video.firstElementChild.id = "videoplayer";
		playerEl.appendChild(video);
	}

	public function removeVideo():Void {
		if (video == null) return;
		playerEl.removeChild(video);
		video = null;
	}

	public function isVideoLoaded():Bool {
		return video != null;
	}

	public function play():Void {}

	public function pause():Void {}

	public function isPaused():Bool {
		return false;
	}

	public function getTime():Float {
		return 0;
	}

	public function setTime(time:Float):Void {}

	public function getPlaybackRate():Float {
		return 1;
	}

	public function setPlaybackRate(rate:Float):Void {}

	public function getVolume():Float {
		return 1;
	}

	public function setVolume(volume:Float) {}

	public function unmute():Void {}
}
