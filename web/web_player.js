// Browser media bridge for PlayerWeb. Keep this file local so the PWA can
// start offline; hls.js is copied to vendor/ by scripts/web/build.sh.
(() => {
  function emit(player, name, number = 0, message = null) {
    if (!player.disposed) player.callback(name, number, message);
  }

  function detachSource(player) {
    if (player.hls) {
      player.hls.destroy();
      player.hls = null;
    }
    if (player.video) {
      player.video.pause();
      player.video.removeAttribute('src');
      player.video.load();
      for (const track of player.video.querySelectorAll('track')) track.remove();
    }
  }

  function load(player) {
    const video = player.video;
    const pending = player.pending;
    if (!video || !pending) return;
    detachSource(player);
    player.pending = null;
    player.start = pending.start;
    player.autoPlay = pending.play;
    if (/\.m3u8(?:[?#]|$)/i.test(pending.url) && window.Hls && Hls.isSupported()) {
      const hls = new Hls({ enableWorker: true });
      player.hls = hls;
      hls.on(Hls.Events.ERROR, (_event, data) => {
        if (data.fatal) emit(player, 'error', 0, `HLS playback failed: ${data.details}`);
      });
      hls.loadSource(pending.url);
      hls.attachMedia(video);
    } else if (/\.m3u8(?:[?#]|$)/i.test(pending.url) && !video.canPlayType('application/vnd.apple.mpegurl')) {
      emit(player, 'error', 0, 'This browser cannot play HLS streams');
    } else {
      video.src = pending.url;
      video.load();
    }
  }

  window.plezyWebCreate = (callback, audioOnly) => {
    const player = { callback, audioOnly, video: null, hls: null, pending: null, start: 0, autoPlay: false, volume: 1, rate: 1, subtitleUrl: '', disposed: false };
    if (audioOnly) window.plezyWebAttach(player, document.createElement('video'));
    return player;
  };

  window.plezyWebAttach = (player, video) => {
    if (player.disposed) return;
    player.video = video;
    video.preload = 'auto';
    video.playsInline = true;
    video.style.width = '100%';
    video.style.height = '100%';
    video.style.objectFit = 'contain';
    video.style.background = 'black';
    video.style.pointerEvents = 'none';
    video.volume = player.volume;
    video.playbackRate = player.rate;
    video.addEventListener('loadedmetadata', () => {
      if (player.start > 0 && video.seekable.length) {
        video.currentTime = player.start;
      }
      emit(player, 'loaded', Number.isFinite(video.duration) ? video.duration : 0);
      if (player.autoPlay) video.play().catch((error) => emit(player, 'error', 0, String(error)));
    });
    video.addEventListener('loadeddata', () => emit(player, 'frame', video.currentTime));
    video.addEventListener('playing', () => emit(player, 'playing'));
    video.addEventListener('pause', () => emit(player, 'paused'));
    video.addEventListener('waiting', () => emit(player, 'buffering'));
    video.addEventListener('stalled', () => emit(player, 'buffering'));
    video.addEventListener('timeupdate', () => emit(player, 'position', video.currentTime));
    video.addEventListener('durationchange', () => emit(player, 'duration', Number.isFinite(video.duration) ? video.duration : 0));
    video.addEventListener('progress', () => {
      const ranges = video.buffered;
      if (ranges.length) emit(player, 'buffer', ranges.end(ranges.length - 1));
    });
    video.addEventListener('ended', () => emit(player, 'ended'));
    video.addEventListener('error', () => {
      const error = video.error;
      if (error) emit(player, 'error', 0, error.message || `Media error ${error.code}`);
    });
    load(player);
    if (player.subtitleUrl) window.plezyWebSubtitle(player, player.subtitleUrl);
  };

  window.plezyWebOpen = (player, url, play, start) => {
    player.subtitleUrl = '';
    player.pending = { url, play, start };
    load(player);
  };
  window.plezyWebPlay = (player) => {
    player.autoPlay = true;
    if (player.video) player.video.play().catch((error) => emit(player, 'error', 0, String(error)));
  };
  window.plezyWebPause = (player) => {
    player.autoPlay = false;
    player.video?.pause();
  };
  window.plezyWebStop = (player) => {
    player.pending = null;
    player.autoPlay = false;
    detachSource(player);
  };
  window.plezyWebSeek = (player, seconds) => {
    if (player.video) player.video.currentTime = seconds;
  };
  window.plezyWebVolume = (player, volume) => {
    player.volume = Math.max(0, Math.min(1, volume));
    if (player.video) player.video.volume = player.volume;
  };
  window.plezyWebRate = (player, rate) => {
    player.rate = rate;
    if (player.video) player.video.playbackRate = rate;
  };
  window.plezyWebSubtitle = (player, url) => {
    player.subtitleUrl = url;
    const video = player.video;
    if (!video) return;
    for (const track of video.querySelectorAll('track')) track.remove();
    if (!url) return;
    const track = document.createElement('track');
    track.kind = 'subtitles';
    track.src = url;
    track.default = true;
    video.appendChild(track);
  };
  window.plezyWebDispose = (player) => {
    detachSource(player);
    player.disposed = true;
    player.video = null;
    player.callback = null;
  };
})();
