import 'package:flutter/material.dart';
import 'ios_background_service.dart';

/// Example widget showing how to use the iOS Background Service
class BackgroundServiceExample extends StatefulWidget {
  const BackgroundServiceExample({Key? key}) : super(key: key);

  @override
  State<BackgroundServiceExample> createState() =>
      _BackgroundServiceExampleState();
}

class _BackgroundServiceExampleState extends State<BackgroundServiceExample> {
  bool _isRunning = false;
  Map<String, dynamic> _status = {};
  String _message = '';

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await IOSBackgroundService.isServiceRunning();
    final status = await IOSBackgroundService.getServiceStatus();

    setState(() {
      _isRunning = isRunning;
      _status = status;
    });

    // Log the check
    await IOSBackgroundService.logInfo('Service status checked from Flutter');
  }

  Future<void> _startService() async {
    final result = await IOSBackgroundService.startBackgroundService();

    setState(() {
      _message = result['message'] ?? 'Service started';
    });

    await IOSBackgroundService.logInfo('User started service from Flutter');
    await _checkServiceStatus();
  }

  Future<void> _stopService() async {
    final result = await IOSBackgroundService.stopBackgroundService();

    setState(() {
      _message = result['message'] ?? 'Service stopped';
    });

    await IOSBackgroundService.logInfo('User stopped service from Flutter');
    await _checkServiceStatus();
  }

  Future<void> _testLogging() async {
    await IOSBackgroundService.logDebug('Debug message from Flutter');
    await IOSBackgroundService.logInfo('Info message from Flutter');
    await IOSBackgroundService.logWarning('Warning message from Flutter');
    await IOSBackgroundService.logError('Error message from Flutter');

    setState(() {
      _message = 'Test logs sent to native service';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('iOS Background Service'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Service Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _isRunning ? Icons.check_circle : Icons.cancel,
                          color: _isRunning ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRunning ? 'Running' : 'Stopped',
                          style: TextStyle(
                            fontSize: 16,
                            color: _isRunning ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      ..._status.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                entry.value.toString(),
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _startService,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Background Service'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isRunning ? _stopService : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Background Service'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _checkServiceStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _testLogging,
              icon: const Icon(Icons.bug_report),
              label: const Text('Test Logging'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            if (_message.isNotEmpty)
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _message,
                    style: TextStyle(
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ),
            const Spacer(),
            const Card(
              color: Colors.orange,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Important',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Location permission must be set to "Always Allow" for background service to work properly.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

