import 'dart:async';

import 'package:flowlog/settings/brew_location_store.dart';
import 'package:flutter/material.dart';

/// Simple screen for setting the current brew location label.
class BrewLocationScreen extends StatefulWidget {
  const BrewLocationScreen({
    super.key,
    this.store,
  });

  final BrewLocationStore? store;

  @override
  State<BrewLocationScreen> createState() => _BrewLocationScreenState();
}

class _BrewLocationScreenState extends State<BrewLocationScreen> {
  late final BrewLocationStore _store;
  late final TextEditingController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? BrewLocationStore();
    _controller = TextEditingController();
    unawaited(_load());
  }

  Future<void> _load() async {
    final location = await _store.load();
    if (!mounted) {
      return;
    }
    _controller.text = location ?? '';
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    await _store.save(value.isEmpty ? null : value);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brew location'),
        actions: [
          TextButton(
            key: const Key('brew_location_save'),
            onPressed: _ready ? () => unawaited(_save()) : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Optional label saved on new shots (no GPS yet).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('brew_location_field'),
              controller: _controller,
              enabled: _ready,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Current location',
                hintText: 'e.g. Home kitchen',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => unawaited(_save()),
            ),
          ],
        ),
      ),
    );
  }
}