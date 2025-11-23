import 'package:flutter/material.dart';
import 'dart:ui';
import 'models.dart';

// Constants
const Color kNeonCyan = Color(0xFF00FFFF);
const Color kNeonPink = Color(0xFFFF00FF);
const Color kBgBlack = Color(0xFF050510);
const TextStyle kMonoStyle = TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold);

class HUD extends StatelessWidget {
  final int score;
  final bool autoPilot;
  final bool showHUDButton;
  final VoidCallback onToggleAutoPilot;
  final VoidCallback onPause;
  final VoidCallback onSettings;
  final AIState aiState;
  final bool debugViz;

  const HUD({
    super.key,
    required this.score,
    required this.autoPilot,
    required this.showHUDButton,
    required this.onToggleAutoPilot,
    required this.onPause,
    required this.onSettings,
    required this.aiState,
    required this.debugViz,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top Bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Controls
                Row(
                  children: [
                    _buildIconButton(Icons.pause, onPause),
                    const SizedBox(width: 8),
                    _buildIconButton(Icons.settings, onSettings),
                  ],
                ),
                Expanded(child: Container()),
                // AI Toggle
                if (showHUDButton)
                  GestureDetector(
                    onTap: onToggleAutoPilot,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: autoPilot ? Colors.cyan.withOpacity(0.2) : Colors.black45,
                        border: Border.all(color: autoPilot ? kNeonCyan : Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: autoPilot ? [BoxShadow(color: kNeonCyan, blurRadius: 10, spreadRadius: -5)] : [],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: autoPilot ? kNeonCyan : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            autoPilot ? "AUTO-PILOT ACTIVE" : "ENGAGE AUTO-PILOT",
                            style: kMonoStyle.copyWith(
                              color: autoPilot ? kNeonCyan : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Score (Centered Top)
        Positioned(
          top: 16,
          left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              transform: Matrix4.skewX(-0.2),
              decoration: BoxDecoration(
                color: Colors.black54,
                border: const Border(left: BorderSide(color: kNeonCyan, width: 4), right: BorderSide(color: kNeonCyan, width: 4)),
              ),
              child: Column(
                children: [
                  Text("SCORE", style: kMonoStyle.copyWith(color: kNeonCyan, fontSize: 10, letterSpacing: 4)),
                  Text(
                    score.toString().padLeft(6, '0'),
                    style: kMonoStyle.copyWith(color: Colors.white, fontSize: 32, letterSpacing: 2),
                  ),
                ],
              ),
            ),
          ),
        ),

        // AI Debug Overlay
        if (autoPilot && debugViz)
          Positioned(
            bottom: 32, right: 32,
            child: Container(
              width: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                border: Border.all(color: kNeonPink.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("NEURAL_NET_DEBUG", style: kMonoStyle.copyWith(color: kNeonPink, fontSize: 12)),
                      Text("${aiState.confidence.toInt()}%", style: kMonoStyle.copyWith(color: aiState.confidence < 50 ? Colors.red : Colors.green, fontSize: 12)),
                    ],
                  ),
                  const Divider(color: kNeonPink, height: 16),
                  _buildDebugRow("ACTION:", aiState.action.toString().split('.').last.toUpperCase()),
                  _buildDebugRow("THREAT:", "${aiState.nearestThreatDist.toStringAsFixed(1)}m"),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: Colors.black45,
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: kMonoStyle.copyWith(color: Colors.white54, fontSize: 10)),
          Text(value, style: kMonoStyle.copyWith(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class SettingsModal extends StatefulWidget {
  final AudioSettings audioSettings;
  final AISettings aiSettings;
  final Function(AudioSettings) onUpdateAudio;
  final Function(AISettings) onUpdateAI;
  final VoidCallback onClose;
  final bool autoPilot;
  final Function(bool) onToggleAutoPilot;

  const SettingsModal({
    super.key,
    required this.audioSettings,
    required this.aiSettings,
    required this.onUpdateAudio,
    required this.onUpdateAI,
    required this.onClose,
    required this.autoPilot,
    required this.onToggleAutoPilot,
  });

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  String activeTab = 'AUDIO';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black54),
          ),
        ),
        Center(
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 700),
            decoration: BoxDecoration(
              color: kBgBlack,
              border: Border.all(color: kNeonCyan.withOpacity(0.5)),
              boxShadow: const [BoxShadow(color: kNeonCyan, blurRadius: 20, spreadRadius: -10)],
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 24, fontStyle: FontStyle.italic, fontWeight: FontWeight.w900),
                          children: const [
                            TextSpan(text: "SYSTEM ", style: TextStyle(color: Colors.white)),
                            TextSpan(text: "CONFIG", style: TextStyle(color: kNeonCyan)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Text("[CLOSE]", style: kMonoStyle.copyWith(color: kNeonCyan, fontSize: 18)),
                      ),
                    ],
                  ),
                ),

                // Tabs
                Row(
                  children: [
                    _buildTab("AUDIO MIXER", 'AUDIO', kNeonCyan),
                    _buildTab("AI NEURAL NET", 'AI', kNeonPink),
                  ],
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: activeTab == 'AUDIO' ? _buildAudioContent() : _buildAIContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, String id, Color color) {
    bool isActive = activeTab == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => activeTab = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: isActive ? color.withOpacity(0.2) : Colors.black26,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isActive ? color : Colors.transparent, width: 2)),
          ),
          child: Center(
            child: Text(
              label,
              style: kMonoStyle.copyWith(
                color: isActive ? color : Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioContent() {
    return Column(
      children: [
        _buildSlider("MUSIC VOLUME", widget.audioSettings.musicVolume, (v) {
          widget.audioSettings.musicVolume = v;
          widget.onUpdateAudio(widget.audioSettings);
        }),
        _buildSlider("ENGINE VOLUME", widget.audioSettings.engineVolume, (v) {
          widget.audioSettings.engineVolume = v;
          widget.onUpdateAudio(widget.audioSettings);
        }),
        _buildSlider("SFX VOLUME", widget.audioSettings.sfxVolume, (v) {
          widget.audioSettings.sfxVolume = v;
          widget.onUpdateAudio(widget.audioSettings);
        }),
      ],
    );
  }

  Widget _buildAIContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Auto Pilot Toggle Row
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kNeonCyan.withOpacity(0.1),
            border: Border.all(color: kNeonCyan.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("AUTO-PILOT MODULE", style: kMonoStyle.copyWith(color: kNeonCyan, fontWeight: FontWeight.bold)),
                  Text("Toggle via HUD or press 'P'", style: kMonoStyle.copyWith(color: Colors.grey, fontSize: 12)),
                ],
              ),
              GestureDetector(
                onTap: () => widget.onToggleAutoPilot(!widget.autoPilot),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.autoPilot ? kNeonCyan.withOpacity(0.2) : Colors.transparent,
                    border: Border.all(color: widget.autoPilot ? kNeonCyan : Colors.grey),
                  ),
                  child: Text(widget.autoPilot ? "ENGAGED" : "DISENGAGED", style: kMonoStyle.copyWith(color: widget.autoPilot ? kNeonCyan : Colors.grey)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Show HUD Toggle
        Row(
          children: [
            Checkbox(
              value: widget.aiSettings.showHUDButton,
              activeColor: kNeonCyan,
              onChanged: (v) {
                widget.aiSettings.showHUDButton = v!;
                widget.onUpdateAI(widget.aiSettings);
              },
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("SHOW IN-GAME AI BUTTON", style: kMonoStyle.copyWith(color: Colors.white, fontSize: 14)),
                Text("Hide HUD button for immersion", style: kMonoStyle.copyWith(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildSlider("RISK TOLERANCE", widget.aiSettings.riskTolerance, (v) {
          widget.aiSettings.riskTolerance = v;
          widget.onUpdateAI(widget.aiSettings);
        }),

        // Heuristic
        Row(
          children: [
            Expanded(
              child: _buildHeuristicOption(
                "SURVIVAL",
                "Prioritizes safety.",
                widget.aiSettings.heuristic == AIHeuristic.survival,
                Colors.green,
                () {
                  widget.aiSettings.heuristic = AIHeuristic.survival;
                  widget.onUpdateAI(widget.aiSettings);
                }
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildHeuristicOption(
                "GREED",
                "Prioritizes score.",
                widget.aiSettings.heuristic == AIHeuristic.coins,
                Colors.amber,
                () {
                  widget.aiSettings.heuristic = AIHeuristic.coins;
                  widget.onUpdateAI(widget.aiSettings);
                }
              ),
            ),
          ],
        ),

        const Spacer(),
        // Debug Viz
        Row(
          children: [
            Checkbox(
              value: widget.aiSettings.debugViz,
              activeColor: kNeonPink,
              onChanged: (v) {
                widget.aiSettings.debugViz = v!;
                widget.onUpdateAI(widget.aiSettings);
              },
            ),
            Text("DEBUG OVERLAY", style: kMonoStyle.copyWith(color: kNeonPink)),
          ],
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: kMonoStyle.copyWith(color: kNeonCyan, fontSize: 12)),
            Text("${(value * 100).toInt()}%", style: kMonoStyle.copyWith(color: kNeonCyan, fontSize: 12)),
          ],
        ),
        Slider(
          value: value,
          onChanged: onChanged,
          activeColor: kNeonCyan,
          inactiveColor: Colors.grey[800],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHeuristicOption(String title, String subtitle, bool isSelected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: isSelected ? color : Colors.grey[800]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: isSelected ? color : Colors.grey, fontWeight: FontWeight.bold)),
            Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class MainMenu extends StatelessWidget {
  final VoidCallback onStart;

  const MainMenu({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
                children: const [
                  TextSpan(text: "NEON", style: TextStyle(color: Colors.white, shadows: [Shadow(color: kNeonCyan, blurRadius: 20)])),
                  TextSpan(text: "RUNNER", style: TextStyle(color: kNeonPink, shadows: [Shadow(color: kNeonPink, blurRadius: 20)])),
                ],
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: onStart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                decoration: BoxDecoration(
                  border: Border.all(color: kNeonCyan, width: 2),
                  borderRadius: BorderRadius.circular(4),
                  color: kNeonCyan.withOpacity(0.1),
                  boxShadow: const [BoxShadow(color: kNeonCyan, blurRadius: 10)],
                ),
                child: const Text("INITIATE RUN", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
