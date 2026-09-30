import 'package:flutter/material.dart';

import '../main.dart' show pellet;
import '../services/tracker_service.dart';
import '../widgets/sparkline.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final service = TrackerService();
  final sourceCtrl = TextEditingController();
  DetectionMode mode = DetectionMode.yolo;
  double conf = 0.35;

  @override
  void initState() {
    super.initState();
    service.connect();
    sourceCtrl.addListener(() => setState(() {})); 
  }

  @override
  void dispose() {
    service.dispose();
    sourceCtrl.dispose();
    super.dispose();
  }

  Future<void> _editServer() async {
    final ctrl = TextEditingController(text: service.serverUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Backend address'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            helperText: 'Android emulator: http://10.0.2.2:4002',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Reconnect')),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) service.connect(url);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width > 900;
        final video = _VideoPanel(service: service);
        final side = _StatsPanel(service: service);
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Fish feeding tracker'),
            actions: [
              _ConnectionChip(connected: service.connected),
              IconButton(
                tooltip: 'Backend address',
                icon: const Icon(Icons.settings_ethernet),
                onPressed: _editServer,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _Controls(
                  service: service,
                  sourceCtrl: sourceCtrl,
                  mode: mode,
                  conf: conf,
                  onMode: (m) => setState(() => mode = m),
                  onConf: (c) => setState(() => conf = c),
                ),
                if (service.error != null) _ErrorBanner(service: service),
                const SizedBox(height: 12),
                Expanded(
                  child: wide
                      ? Row(children: [
                          Expanded(flex: 3, child: video),
                          const SizedBox(width: 12),
                          SizedBox(width: 320, child: side),
                        ])
                      : Column(children: [
                          Expanded(flex: 3, child: video),
                          const SizedBox(height: 12),
                          Expanded(flex: 2, child: side),
                        ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  final TrackerService service;
  final TextEditingController sourceCtrl;
  final DetectionMode mode;
  final double conf;
  final ValueChanged<DetectionMode> onMode;
  final ValueChanged<double> onConf;

  const _Controls({
    required this.service,
    required this.sourceCtrl,
    required this.mode,
    required this.conf,
    required this.onMode,
    required this.onConf,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 420,
          child: TextField(
            controller: sourceCtrl,
            enabled: !service.running,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              labelText: 'Video file path or camera index',
              hintText: r'C:\videos\feeding.mp4  or  0',
            ),
          ),
        ),
        SegmentedButton<DetectionMode>(
          segments: const [
            ButtonSegment(value: DetectionMode.yolo, label: Text('YOLO')),
            ButtonSegment(value: DetectionMode.sahi, label: Text('YOLO + SAHI')),
          ],
          selected: {mode},
          onSelectionChanged: service.running ? null : (s) => onMode(s.first),
        ),
        SizedBox(
          width: 240,
          child: Row(children: [
            Text('Confidence ${conf.toStringAsFixed(2)}'),
            Expanded(
              child: Slider(
                value: conf,
                min: 0.1,
                max: 0.9,
                onChanged: service.running ? null : onConf,
              ),
            ),
          ]),
        ),
        if (!service.running)
          FilledButton.icon(
            onPressed: service.connected && sourceCtrl.text.trim().isNotEmpty
                ? () => service.start(source: sourceCtrl.text.trim(), mode: mode, conf: conf)
                : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start tracking'),
          )
        else
          FilledButton.tonalIcon(
            onPressed: service.stop,
            icon: const Icon(Icons.stop),
            label: const Text('Stop tracking'),
          ),
      ],
    );
  }
}

class _VideoPanel extends StatelessWidget {
  final TrackerService service;
  const _VideoPanel({required this.service});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: service.frame != null
            ? Image.memory(service.frame!, fit: BoxFit.contain, gaplessPlayback: true)
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  service.running
                      ? 'Loading the model and opening the video...'
                      : 'Enter a video path or camera index, then start tracking.',
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  final TrackerService service;
  const _StatsPanel({required this.service});

  String _time(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toInt().toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final st = service.stats;
    final t = Theme.of(context).textTheme;
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Pellets counted', style: t.labelLarge),
          Text('${st.totalPellets}',
              style: t.displayLarge?.copyWith(color: pellet, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _row('Visible now', '${st.visiblePellets}'),
          _row('Peak visible', '${st.peakVisible}'),
          _row('Uneaten estimate', '${(st.uneatenRatio * 100).round()}%'),
          _row('Elapsed', _time(st.elapsedSeconds)),
          _row('Processing speed', '${st.fps.toStringAsFixed(1)} fps'),
          const SizedBox(height: 16),
          Text('Visible pellets over time', style: t.labelLarge),
          const SizedBox(height: 8),
          SizedBox(height: 70, child: Sparkline(values: service.visibleHistory, color: pellet)),
          if (service.finishedSessions.isNotEmpty) ...[
            const Divider(height: 32),
            Text('Previous runs', style: t.labelLarge),
            const SizedBox(height: 8),
            for (final s in service.finishedSessions)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${s.totalPellets} pellets'),
                subtitle: Text(
                    '${s.startedAt?.toLocal().toString().substring(0, 16) ?? ''}  |  ${_time(s.elapsedSeconds)}'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(k), Text(v, style: const TextStyle(fontWeight: FontWeight.w600))],
        ),
      );
}

class _ConnectionChip extends StatelessWidget {
  final bool connected;
  const _ConnectionChip({required this.connected});

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(Icons.circle,
            size: 10, color: connected ? Colors.greenAccent : Colors.redAccent),
        label: Text(connected ? 'Backend connected' : 'Backend offline'),
        visualDensity: VisualDensity.compact,
      );
}

class _ErrorBanner extends StatelessWidget {
  final TrackerService service;
  const _ErrorBanner({required this.service});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: MaterialBanner(
          content: Text(service.error!),
          leading: const Icon(Icons.error_outline),
          actions: [TextButton(onPressed: service.clearError, child: const Text('Dismiss'))],
        ),
      );
}
