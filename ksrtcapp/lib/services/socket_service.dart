import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'api_service.dart';

class SocketService {
  static IO.Socket? _socket;
  static String? _joinedScheduleId;

  static IO.Socket get socket {
    if (_socket == null) {
      connect();
    }
    return _socket!;
  }

  static void connect() {
    // Reuse an existing socket instead of creating duplicates.
    if (_socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      }
      return;
    }

    _socket = IO.io(
      ApiService.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      // Rejoin the schedule room after reconnecting.
      final scheduleId = _joinedScheduleId;
      if (scheduleId != null && scheduleId.isNotEmpty) {
        _socket!.emit('joinSchedule', scheduleId);
      }
    });

    _socket!.onConnectError((error) {
      print('Socket connection error: $error');
    });

    _socket!.onDisconnect((reason) {
      print('Socket disconnected: $reason');
    });

    _socket!.connect();
  }

  static void joinSchedule(String scheduleId) {
    if (scheduleId.isEmpty) return;

    connect();

    final previousScheduleId = _joinedScheduleId;

    if (previousScheduleId != null &&
        previousScheduleId.isNotEmpty &&
        previousScheduleId != scheduleId) {
      _socket?.emit('leaveSchedule', previousScheduleId);
    }

    _joinedScheduleId = scheduleId;

    if (_socket?.connected == true) {
      _socket!.emit('joinSchedule', scheduleId);
    }
  }

  static void leaveSchedule() {
    final scheduleId = _joinedScheduleId;

    if (scheduleId != null && scheduleId.isNotEmpty) {
      _socket?.emit('leaveSchedule', scheduleId);
    }

    _joinedScheduleId = null;
  }

  static void on(String event, Function(dynamic) callback) {
    connect();
    _socket?.on(event, callback);
  }

  static void off(String event) {
    _socket?.off(event);
  }

  static void disconnect() {
    leaveSchedule();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
