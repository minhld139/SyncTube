package client;

import Types.PlayerType;
import Types.VideoData;
import Types.VideoDataRequest;
import Types.VideoItem;

interface IPlayer {
	function getPlayerType():PlayerType;
	function isSupportedLink(url:String):Bool;
	function getVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void;
	function loadVideo(item:VideoItem):Void;
	function removeVideo():Void;
	function isVideoLoaded():Bool;
	function play():Void;
	function pause():Void;
	function isPaused():Bool;
	function getTime():Float;
	function setTime(time:Float):Void;
	function getPlaybackRate():Float;
	function setPlaybackRate(rate:Float):Void;
	function getVolume():Float;
	function setVolume(volume:Float):Void;
	function unmute():Void;
}
