package client.players;

import Types.PlayerType;
import Types.VideoData;
import Types.VideoDataRequest;
import Types.VideoItem;
import client.Main.getEl;
import haxe.Http;
import haxe.Json;
import js.Browser.document;
import js.html.Element;
import js.youtube.Youtube as YtInit;
import js.youtube.YoutubePlayer;
import utils.YoutubeUtils;

class Youtube implements IPlayer {
	final videosUrl = "https://www.googleapis.com/youtube/v3/videos";
	final playlistUrl = "https://www.googleapis.com/youtube/v3/playlistItems";
	final urlTitleDuration = "?part=snippet,contentDetails&fields=items(snippet/title,contentDetails/duration)";
	final urlVideoId = "?part=snippet&fields=nextPageToken,items(snippet/resourceId/videoId)";
	final main:Main;
	final player:Player;
	final playerEl:Element = getEl("#ytapiplayer");
	var apiKey:String;
	var video:Element;
	var youtube:YoutubePlayer;
	var isLoaded = false;

	public function new(main:Main, player:Player) {
		this.main = main;
		this.player = player;
	}

	public function getPlayerType():PlayerType {
		return YoutubeType;
	}

	public function isSupportedLink(url:String):Bool {
		return extractVideoId(url) != "" || extractPlaylistId(url) != "";
	}

	public function extractVideoId(url:String) {
		return YoutubeUtils.extractVideoId(url);
	}

	public function extractPlaylistId(url:String) {
		return YoutubeUtils.extractPlaylistId(url);
	}

	public function isPlaylistUrl(url:String):Bool {
		return extractVideoId(url) == "" && extractPlaylistId(url) != "";
	}

	final matchHours = ~/([0-9]+)H/;
	final matchMinutes = ~/([0-9]+)M/;
	final matchSeconds = ~/([0-9]+)S/;

	function convertTime(duration:String):Float {
		var total = 0;
		final hours = matchHours.match(duration);
		final minutes = matchMinutes.match(duration);
		final seconds = matchSeconds.match(duration);
		if (hours) total += Std.parseInt(matchHours.matched(1)) * 3600;
		if (minutes) total += Std.parseInt(matchMinutes.matched(1)) * 60;
		if (seconds) total += Std.parseInt(matchSeconds.matched(1));
		return total;
	}

	public function getVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		final url = data.url;
		apiKey ??= main.getYoutubeApiKey();
		final id = extractVideoId(url);
		if (id == "") {
			getPlaylistVideoData(data, callback);
			return;
		}
		final dataUrl = '$videosUrl$urlTitleDuration&id=$id&key=$apiKey';
		final http = new Http(dataUrl);
		http.onData = text -> {
			final json = Json.parse(text);
			if (json.error != null) {
				youtubeApiError(json.error);
				getRemoteDataFallback(url, callback);
				return;
			}
			final items:Array<Dynamic> = json.items;
			if (items == null || items.length == 0) {
				callback({duration: 0});
				return;
			}
			for (item in items) {
				final title:String = item.snippet.title;
				final duration:String = item.contentDetails.duration;
				final duration = convertTime(duration);
				// duration is PT0S for streams
				if (duration == 0) {
					final mute = main.isAutoplayAllowed() ? "" : "&mute=1";
					callback({
						duration: 99 * 60 * 60,
						title: title,
						url: '<iframe src="https://www.youtube.com/embed/$id?autoplay=1$mute" frameborder="0"
							allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture"
							allowfullscreen></iframe>',
						playerType: IframeType
					});
					continue;
				}
				callback({
					duration: duration,
					title: title,
					url: url
				});
			}
		}
		http.onError = msg -> getRemoteDataFallback(url, callback);
		http.request();
	}

	function getPlaylistVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		final url = data.url;
		final id = extractPlaylistId(url);
		var maxResults = main.getYoutubePlaylistLimit();
		final dataUrl = '$playlistUrl$urlVideoId&maxResults=$maxResults&playlistId=$id&key=$apiKey';

		function loadJson(url:String):Void {
			final http = new Http(url);
			http.onData = text -> {
				final json = Json.parse(text);
				if (json.error != null) {
					youtubeApiError(json.error);
					callback({duration: 0});
					return;
				}
				final items:Array<Dynamic> = json.items;
				if (items == null || items.length == 0) {
					callback({duration: 0});
					return;
				}
				if (!data.atEnd) main.sortItemsForQueueNext(items);
				function loadNextItem():Void {
					final item = items.shift();
					final id:String = item.snippet.resourceId.videoId;
					final obj:VideoDataRequest = {
						url: 'https://youtu.be/$id',
						atEnd: data.atEnd
					};
					getVideoData(obj, data -> {
						callback(data);
						maxResults--;
						if (maxResults <= 0) return;
						if (items.length > 0) loadNextItem();
						else if (json.nextPageToken != null) {
							loadJson('$dataUrl&pageToken=${json.nextPageToken}');
						}
					});
				}
				loadNextItem();
			}
			http.onError = msg -> callback({duration: 0});
			http.request();
		}
		loadJson(dataUrl);
	}

	function youtubeApiError(error:Dynamic):Void {
		final code:Int = error.code;
		final msg:String = error.message;
		Main.instance.serverMessage('Error $code: $msg', false);
	}

	function getRemoteDataFallback(url:String, callback:(data:VideoData) -> Void):Void {
		if (!YtInit.isLoadedAPI) {
			YtInit.init(() -> getRemoteDataFallback(url, callback));
			return;
		}
		final video = document.createDivElement();
		video.className = "temp-videoplayer";
		playerEl.prepend(video);
		var tempYoutube:YoutubePlayer = null;
		tempYoutube = new YoutubePlayer(video.id, {
			videoId: extractVideoId(url),
			playerVars: {
				modestbranding: 1,
				rel: 0,
				showinfo: 0
			},
			events: {
				onReady: e -> {
					if (playerEl.contains(video)) playerEl.removeChild(video);
					callback({
						duration: tempYoutube.getDuration()
					});
					tempYoutube.destroy();
				},
				onError: e -> {
					// TODO message error codes
					trace('Error ${e.data}');
					if (playerEl.contains(video)) playerEl.removeChild(video);
					callback({duration: 0});
					tempYoutube.destroy();
				}
			}
		});
	}

	public function loadVideo(item:VideoItem):Void {
		if (!YtInit.isLoadedAPI) {
			YtInit.init(() -> loadVideo(item));
			return;
		}
		if (youtube != null) {
			youtube.loadVideoById({
				videoId: extractVideoId(item.url)
			});
			return;
		}
		isLoaded = false;
		video = document.createDivElement();
		video.id = "videoplayer";
		playerEl.appendChild(video);

		youtube = new YoutubePlayer(video.id, {
			videoId: extractVideoId(item.url),
			playerVars: {
				autoplay: 1,
				// play videos inline instead of fullscreen on iOS
				playsinline: 1,
				// related videos only from same channel
				rel: 0,
			},
			events: {
				onReady: e -> {
					if (!main.isAutoplayAllowed()) e.target.mute();
					isLoaded = true;
					if (main.lastState.paused) youtube.pauseVideo();
					player.onCanBePlayed();
				},
				onStateChange: e -> {
					switch (e.data) {
						case UNSTARTED:
						case ENDED:
						case PLAYING:
							player.onPlay();
						case PAUSED:
							player.onPause();
						case BUFFERING:
							player.onSetTime();
						case CUED:
					}
				},
				onPlaybackRateChange: e -> {
					player.onRateChange();
				},
				onError: e -> {
					// TODO message error codes
					trace('Error ${e.data}');
					// final item = player.getCurrentItem() ?? return;
					// rawSourceFallback(item.url);
				}
			}
		});
	}

	public function removeVideo():Void {
		if (video == null) return;
		isLoaded = false;
		youtube.destroy();
		youtube = null;
		if (playerEl.contains(video)) playerEl.removeChild(video);
		video = null;
	}

	public function isVideoLoaded():Bool {
		return isLoaded;
	}

	public function play():Void {
		youtube.playVideo();
	}

	public function pause():Void {
		youtube.pauseVideo();
	}

	public function isPaused():Bool {
		return youtube.getPlayerState() == PAUSED;
	}

	public function getTime():Float {
		return youtube.getCurrentTime();
	}

	public function setTime(time:Float):Void {
		youtube.seekTo(time, true);
	}

	public function getPlaybackRate():Float {
		return youtube.getPlaybackRate();
	}

	public function setPlaybackRate(rate:Float):Void {
		youtube.setPlaybackRate(rate);
	}

	public function getVolume():Float {
		if (youtube.isMuted()) return 0;
		return youtube.getVolume() / 100;
	}

	public function setVolume(volume:Float):Void {
		youtube.setVolume(Std.int(volume * 100));
	}

	public function unmute():Void {
		youtube.unMute();
	}
}
