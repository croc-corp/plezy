// Browser media bridge for PlayerWeb. Keep this file local so the PWA can
// start offline; hls.js is copied to vendor/ by scripts/web/build.sh.
(() => {
  function emit(player, name, number = 0, message = null) {
    if (!player.disposed) player.callback(name, number, message);
  }

  function clearSubtitle(player) {
    if (player.video) {
      for (const track of player.video.querySelectorAll('track')) {
        track.track.mode = 'disabled';
        track.remove();
      }
    }
    if (player.subtitleObjectUrl) {
      URL.revokeObjectURL(player.subtitleObjectUrl);
      player.subtitleObjectUrl = null;
    }
  }

  function toWebVtt(body) {
    let text = body.replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n');
    if (/^WEBVTT(?:\s|$)/.test(text)) return text;
    if (!/^(?:\d+\n)?\d{1,2}:\d{2}:\d{2}[,.]\d{3}\s*-->/m.test(text)) {
      throw new Error('Unsupported text subtitle format');
    }
    text = text
      .replace(/^\d+\s*\n(?=\d{1,2}:\d{2}:\d{2}[,.]\d{3}\s*-->)/gm, '')
      .replace(/(\d{1,2}:\d{2}:\d{2}),(\d{3})/g, '$1.$2');
    return `WEBVTT\n\n${text.trim()}\n`;
  }

  function detachSource(player) {
    player.subtitleVersion++;
    clearSubtitle(player);
    if (player.hls) {
      player.hls.destroy();
      player.hls = null;
    }
    if (player.video) {
      player.video.pause();
      player.video.removeAttribute('src');
      player.video.load();
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
    const player = { callback, audioOnly, video: null, hls: null, pending: null, start: 0, autoPlay: false, volume: 1, rate: 1, subtitleUrl: '', subtitleVersion: 0, subtitleObjectUrl: null, disposed: false };
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
  window.plezyWebSubtitle = async (player, url) => {
    player.subtitleUrl = url;
    const version = ++player.subtitleVersion;
    clearSubtitle(player);
    const video = player.video;
    if (!video || !url) return;
    let objectUrl;
    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const vtt = toWebVtt(await response.text());
      objectUrl = URL.createObjectURL(new Blob([vtt], { type: 'text/vtt' }));
      if (player.disposed || player.subtitleVersion !== version || player.video !== video) return;
      const track = document.createElement('track');
      track.kind = 'subtitles';
      track.src = objectUrl;
      track.default = true;
      track.addEventListener('error', () => emit(player, 'subtitle-error', 0, 'Browser rejected the subtitle track'));
      player.subtitleObjectUrl = objectUrl;
      objectUrl = null;
      video.appendChild(track);
      track.track.mode = 'showing';
    } catch (error) {
      if (player.subtitleVersion === version) emit(player, 'subtitle-error', 0, String(error));
    } finally {
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    }
  };
  window.plezyWebDispose = (player) => {
    detachSource(player);
    player.disposed = true;
    player.video = null;
    player.callback = null;
  };
})();
