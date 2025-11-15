import "dart:convert";
import "dart:io";
import "dart:async";

late final HttpServer server;
Process? currentPlayer;
final Map<WebSocket, String> connectedClients = {};
bool _isPlaying = false;
String _currentTitle = "";

Future<void> main(List<String> args) async {
  try {
    server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  } catch (e) {
    print("Failed to bind server: $e");
    return;
  }
  print("Server running at http://${server.address.address}:${server.port}/");

  await for (HttpRequest request in server) {
    _handleRequest(request);
  }
}

void _handleRequest(HttpRequest request) async {
  try {
    if (request.uri.path == "/ws") {
      final websocket = await WebSocketTransformer.upgrade(request);
      _handleWebSocket(websocket);
    } else if (request.method == "POST" && request.uri.path == "/play") {
      await _handlePlayRequest(request);
    } else if (request.method == "GET" && request.uri.path == "/control") {
      await _handleControlRequest(request);
    } else if (request.method == "GET" && request.uri.path == "/status") {
      await _handleStatusRequest(request);
    } else if (request.method == "GET" && request.uri.path == "/") {
      await _serveWebInterface(request);
    } else {
      request.response
        ..statusCode = 404
        ..write('{"error": "Not Found"}')
        ..close();
    }
  } catch (e) {
    request.response
      ..statusCode = 500
      ..write('{"error": "${e.toString()}"}')
      ..close();
  }
}

Future<void> _serveWebInterface(HttpRequest request) async {
  String currentDirectory = Directory.current.path;
  final htmlFile = File('$currentDirectory/resource/index.html');

  if (await htmlFile.exists()) {
    final htmlContent = await htmlFile.readAsString();
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write(htmlContent)
      ..close();
  } else {
    // Fallback: Tạo trang web đơn giản nếu không tìm thấy file
    _serveFallbackWebInterface(request);
  }
}

void _serveFallbackWebInterface(HttpRequest request) {
  final currentDirectory = Directory.current.path;
  final htmlContent = File('$currentDirectory/resource/index.html').readAsStringSync();

  request.response
    ..statusCode = 200
    ..headers.contentType = ContentType.html
    ..write(htmlContent)
    ..close();
}

void _handleWebSocket(WebSocket websocket) {
  print("New WebSocket connection");
  connectedClients[websocket] = "anonymous";

  websocket.listen(
    (message) {
      _handleWebSocketMessage(websocket, message);
    },
    onDone: () {
      print("WebSocket disconnected");
      connectedClients.remove(websocket);
    },
    onError: (error) {
      print("WebSocket error: $error");
      connectedClients.remove(websocket);
    },
  );

  // Gửi trạng thái hiện tại khi kết nối
  _sendToWebSocket(websocket, {
    "type": "connected",
    "message": "Connected to audio remote controller",
    "currentStatus": _isPlaying ? "playing" : "stopped",
    "currentTitle": _currentTitle,
  });
}

void _handleWebSocketMessage(WebSocket websocket, dynamic message) {
  try {
    final data = jsonDecode(message) as Map<String, dynamic>;
    final action = data["action"] as String?;

    switch (action) {
      case "play":
        _handlePlayCommand(data);
        break;
      case "stop":
        _stopPlayer();
        break;
      case "pause":
        _pausePlayer();
        break;
      case "resume":
        _resumePlayer();
        break;
      case "volume":
        final volume = data["volume"];
        if (volume != null) {
          _setVolume(volume);
        }
        break;
      case "seek":
        final seconds = data["seconds"];
        if (seconds != null) {
          _seekPlayer(seconds);
        }
        break;
      default:
        _sendToWebSocket(websocket, {"type": "error", "message": "Unknown action: $action"});
    }
  } catch (e) {
    _sendToWebSocket(websocket, {"type": "error", "message": "Invalid message format: ${e.toString()}"});
  }
}

Future<void> _handlePlayRequest(HttpRequest request) async {
  final content = await utf8.decoder.bind(request).join();
  final metadataMap = jsonDecode(content) as Map<String, dynamic>;

  await _playAudio(metadataMap);

  request.response
    ..statusCode = 200
    ..headers.contentType = ContentType.json
    ..write(jsonEncode({"status": "playing", "title": metadataMap["title"]}))
    ..close();
}

Future<void> _handleControlRequest(HttpRequest request) async {
  final action = request.uri.queryParameters["action"];

  switch (action) {
    case "stop":
      _stopPlayer();
      break;
    case "pause":
      _pausePlayer();
      break;
    case "resume":
      _resumePlayer();
      break;
    case "volume":
      final volume = request.uri.queryParameters["value"];
      if (volume != null) {
        _setVolume(int.parse(volume));
      }
      break;
    default:
      request.response
        ..statusCode = 400
        ..write('{"error": "Unknown action"}')
        ..close();
      return;
  }

  request.response
    ..statusCode = 200
    ..write('{"status": "ok"}')
    ..close();
}

Future<void> _handleStatusRequest(HttpRequest request) async {
  final status = {
    "isPlaying": _isPlaying,
    "currentTitle": _currentTitle,
    "connectedClients": connectedClients.length,
    "timestamp": DateTime.now().toIso8601String(),
  };

  request.response
    ..statusCode = 200
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(status))
    ..close();
}

Future<void> _playAudio(Map<String, dynamic> metadataMap) async {
  // Luôn dừng bài đang phát trước đó
  await _stopPlayer();

  String url;
  String title;

  if (metadataMap["path"] != null) {
    // Phát file local
    url = metadataMap["path"];
    title = metadataMap["title"] ?? "Local File";
  } else {
    // Lấy URL audio từ YouTube
    final ytDlpProcess = await Process.start("yt-dlp", ["-f", "bestaudio", "-g", metadataMap["id"]]);
    url = (await ytDlpProcess.stdout.transform(utf8.decoder).join()).trim();
    title = metadataMap["title"] ?? "Unknown";

    if (url.isEmpty) {
      final error = await ytDlpProcess.stderr.transform(utf8.decoder).join();
      throw Exception("Failed to get audio URL: $error");
    }
  }

  // Phát bài mới với mpv
  print("Starting playback: $title");
  currentPlayer = await Process.start("mpv", ["--no-video", "--no-terminal", url]);

  _isPlaying = true;
  _currentTitle = title;

  // Theo dõi khi process kết thúc
  _monitorPlayerProcess();

  _broadcastToAll({"type": "playback_started", "title": title, "url": url, "timestamp": DateTime.now().toIso8601String()});

  print("🎵 Now playing: $title");
}

void _monitorPlayerProcess() {
  currentPlayer?.exitCode.then((exitCode) {
    print("Player process ended with exit code: $exitCode");
    _isPlaying = false;
    _currentTitle = "";
    currentPlayer = null;

    _broadcastToAll({"type": "playback_ended", "timestamp": DateTime.now().toIso8601String()});
  });
}

Future<void> _stopPlayer() async {
  if (currentPlayer != null) {
    print("🛑 Stopping player...");
    currentPlayer!.kill(ProcessSignal.sigterm);
    await currentPlayer!.exitCode;
    currentPlayer = null;
    _isPlaying = false;
    _currentTitle = "";

    _broadcastToAll({"type": "playback_stopped", "timestamp": DateTime.now().toIso8601String()});
  }
}

void _pausePlayer() {
  if (currentPlayer != null && _isPlaying) {
    currentPlayer!.kill(ProcessSignal.sigstop);
    _isPlaying = false;
    _broadcastToAll({"type": "playback_paused", "timestamp": DateTime.now().toIso8601String()});
    print("⏸️ Playback paused");
  }
}

void _resumePlayer() {
  if (currentPlayer != null && !_isPlaying) {
    currentPlayer!.kill(ProcessSignal.sigcont);
    _isPlaying = true;
    _broadcastToAll({"type": "playback_resumed", "timestamp": DateTime.now().toIso8601String()});
    print("▶️ Playback resumed");
  }
}

void _setVolume(int volume) {
  // MPV không hỗ trợ điều chỉnh volume qua signal
  // Cần implement IPC socket để điều khiển nâng cao
  print("🔊 Volume control would require MPV IPC socket");
}

void _seekPlayer(int seconds) {
  // MPV không hỗ trợ seek qua signal
  // Cần implement IPC socket để điều khiển nâng cao
  print("⏩ Seek control would require MPV IPC socket");
}

void _handlePlayCommand(Map<String, dynamic> data) async {
  try {
    await _playAudio(data);
  } catch (e) {
    _broadcastToAll({"type": "error", "message": "Playback failed: ${e.toString()}"});
  }
}

void _broadcastToAll(Map<String, dynamic> message) {
  final jsonMessage = jsonEncode(message);
  connectedClients.keys.toList().forEach((websocket) {
    try {
      websocket.add(jsonMessage);
    } catch (e) {
      print("Failed to send to WebSocket: $e");
      connectedClients.remove(websocket);
    }
  });
}

void _sendToWebSocket(WebSocket websocket, Map<String, dynamic> message) {
  try {
    websocket.add(jsonEncode(message));
  } catch (e) {
    print("Failed to send to WebSocket: $e");
  }
}
