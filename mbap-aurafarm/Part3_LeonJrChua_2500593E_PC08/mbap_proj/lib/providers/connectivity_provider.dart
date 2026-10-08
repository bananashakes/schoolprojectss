import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ADDITIONAL FEATURE - Offline Mode Detection & Handling (connectivity_plus)
// described in the Part 1 proposal: the app watches the connection state,
// warns the user with a banner, and blocks online-only actions such as AI
// generation and posting until the connection returns.

// live stream of whether the device currently has a connection.
// connectivity_plus reports a list of active connection types; the device
// is offline when the list only contains "none".
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final Connectivity connectivity = Connectivity();

  // emit the current state first so the UI is right on app start
  final List<ConnectivityResult> initial = await connectivity
      .checkConnectivity();
  yield !initial.contains(ConnectivityResult.none);

  await for (final List<ConnectivityResult> results
      in connectivity.onConnectivityChanged) {
    yield !results.contains(ConnectivityResult.none);
  }
});
