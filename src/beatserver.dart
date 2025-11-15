import "dart:convert";
import "dart:io";

late final HttpServer server;
Process? currentPlayer;

Future<void> main(List<String> args) async {
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  } catch (e) {
    print("Failed to bind server: $e");
    return;
  }
  print("Server running at http://${server.address.address}:${server.port}/");

  await for (HttpRequest request in server) {
    if (request.method == "POST" && request.uri.path == "/play") {
      try {
        final content = await utf8.decoder.bind(request).join();
        final metadataMap = jsonDecode(content) as Map<String, dynamic>;

        // Dừng bài đang phát trước đó
        if (currentPlayer != null) {
          print("Stopping previous track...");
          currentPlayer!.kill(ProcessSignal.sigterm);
          await Future.delayed(Duration(milliseconds: 100));
        }

        if (metadataMap["path"] != null) {
          // Phát file local
          currentPlayer = await Process.start("mpv", ["--no-video", metadataMap["path"]]);
          request.response
            ..statusCode = 200
            ..write("Playing local file: ${metadataMap["path"]}")
            ..close();
          continue;
        }

        // Lấy URL audio từ YouTube
        final ytDlpProcess = await Process.start("yt-dlp", ["-f", "bestaudio", "-g", metadataMap["id"]]);
        final url = (await ytDlpProcess.stdout.transform(utf8.decoder).join()).trim();

        if (url.isEmpty) {
          final err = await ytDlpProcess.stderr.transform(utf8.decoder).join();
          request.response
            ..statusCode = 500
            ..write("Error fetching URL: $err")
            ..close();
          continue;
        }

        // Phát bài mới với mpv
        currentPlayer = await Process.start("mpv", ["--no-video", url]);
        print("Playing: ${metadataMap["title"]}");

        request.response
          ..statusCode = 200
          ..write("Playing: ${metadataMap["title"]}")
          ..close();
      } catch (e) {
        request.response
          ..statusCode = 500
          ..write("Error : $e")
          ..close();
      }
    } else {
      request.response
        ..statusCode = 404
        ..write("Not Found")
        ..close();
    }
  }
}
