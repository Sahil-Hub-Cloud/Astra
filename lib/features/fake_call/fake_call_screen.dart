import "package:go_router/go_router.dart";
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class FakeCallScreen extends StatefulWidget {
  final String callerName;
  const FakeCallScreen({super.key, this.callerName = 'Mom'});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playRingtone();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _playRingtone() async {
    // Using a default system sound URL since we don't have local assets
    await _audioPlayer.play(UrlSource('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'));
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              const SizedBox(height: 100),
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white.withAlpha(26),
                child: const Icon(Icons.person, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                widget.callerName,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Text(
                'Incoming call...',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 60),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCallButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  onPressed: () => context.pop(),
                ),
                _buildCallButton(
                  icon: Icons.call,
                  color: Colors.green,
                  onPressed: () {
                    _audioPlayer.stop();
                    // In a real app, show a fake call "active" screen
                    context.pop();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.1).animate(_controller),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withAlpha(102), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 36),
        ),
      ),
    );
  }
}
