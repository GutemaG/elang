// Controllable fake for [ConnectivityMonitor], used across widget tests so
// online/offline behavior can be exercised deterministically without
// depending on a real platform connectivity channel.
//
// Mocking here is at the plugin boundary only, per `coding-standards.md`'s
// "mock at the network/DB boundary only" testing convention.

import 'dart:async';

import 'package:elang/shared/services/connectivity_monitor.dart';

class FakeConnectivityMonitor implements ConnectivityMonitor {
  // The public param name (`online`) is deliberately friendlier than the
  // private field it seeds, so an initializing formal isn't used here.
  // ignore: prefer_initializing_formals
  FakeConnectivityMonitor({bool online = true}) : _online = online;

  bool _online;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void setOnline(bool value) {
    _online = value;
    _controller.add(value);
  }

  void dispose() => _controller.close();
}
