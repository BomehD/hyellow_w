import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  // We now accept the existing controller and its initialization future
  final VideoPlayerController controller;
  final Future<void> initializeVideoFuture;

  const FullScreenVideoPlayer({
    Key? key,
    required this.controller,
    required this.initializeVideoFuture,
  }) : super(key: key);

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  // No need to create a new controller, we'll use the one from the widget
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;

    // We already know the controller is initialized from the parent,
    // but we can ensure it's playing when we open full screen.
    // We don't need to call initialize() again.
    _controller.play();
  }

  @override
  void dispose() {
    // IMPORTANT: We do not dispose of the controller here!
    // The parent widget (PostScreen) is responsible for the controller's lifecycle.
    // Disposing it here would cause an error when returning to the PostScreen.
    _controller.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wait for the initialization future to complete before building the video player.
    // This handles the case where the video is still initializing when a user
    // taps on it to go full-screen very quickly.
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder(
        future: widget.initializeVideoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
                Positioned(
                  top: 50,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        iconSize: 50,
                        icon: Icon(
                          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _controller.value.isPlaying
                                ? _controller.pause()
                                : _controller.play();
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
