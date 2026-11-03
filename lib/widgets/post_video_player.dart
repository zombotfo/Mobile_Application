import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Video player with playback, seeking, duration and volume controls.
class PostVideoPlayer extends StatefulWidget {
  const PostVideoPlayer({super.key, required this.videoUrl, this.width});

  final String videoUrl;
  final double? width;

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;
  double _volume = 1;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initFuture = _controller.initialize();
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            width: widget.width,
            height: 200,
            color: const Color(0xFFF0F0F1),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        }
        if (snapshot.hasError || !_controller.value.isInitialized) {
          return Container(
            width: widget.width,
            height: 140,
            color: const Color(0xFFF0F0F1),
            alignment: Alignment.center,
            child: const Icon(Icons.videocam_off_outlined, color: Colors.black26),
          );
        }

        final ratio = _controller.value.aspectRatio > 0
            ? _controller.value.aspectRatio
            : 16 / 9;
        return SizedBox(
          width: widget.width,
          child: AspectRatio(
            aspectRatio: ratio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayer(_controller),
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final totalMs = value.duration.inMilliseconds;
                    final positionMs = value.position.inMilliseconds
                        .clamp(0, totalMs > 0 ? totalMs : 0)
                        .toDouble();
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(8, 18, 8, 4),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: value.isPlaying ? 'Pause' : 'Play',
                                  color: Colors.white,
                                  onPressed: () => value.isPlaying
                                      ? _controller.pause()
                                      : _controller.play(),
                                  icon: Icon(value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow),
                                ),
                                Text(
                                  _formatTime(value.position),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 5,
                                      ),
                                      overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 10,
                                      ),
                                    ),
                                    child: Slider(
                                      min: 0,
                                      max: totalMs > 0 ? totalMs.toDouble() : 1,
                                      value: positionMs,
                                      activeColor: Colors.white,
                                      inactiveColor: Colors.white38,
                                      onChanged: totalMs <= 0
                                          ? null
                                          : (ms) => _controller.seekTo(
                                                Duration(milliseconds: ms.round()),
                                              ),
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatTime(value.duration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _volume == 0
                                      ? Icons.volume_off
                                      : _volume < 0.5
                                          ? Icons.volume_down
                                          : Icons.volume_up,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(
                                  width: 64,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 5,
                                      ),
                                      overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 9,
                                      ),
                                    ),
                                    child: Slider(
                                      min: 0,
                                      max: 1,
                                      value: _volume,
                                      activeColor: Colors.white,
                                      inactiveColor: Colors.white38,
                                      onChanged: (volume) {
                                        setState(() => _volume = volume);
                                        _controller.setVolume(volume);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
