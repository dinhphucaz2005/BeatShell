import 'dart:convert';
import 'dart:io';

class YoutubeItemMetadata {
  final String id;
  final String title;
  final String cover;

  YoutubeItemMetadata({required this.id, required this.title, required this.cover});

  factory YoutubeItemMetadata.fromJson(Map<String, dynamic> json) {
    return YoutubeItemMetadata(id: json['id'] as String, title: json['title'] as String, cover: json['cover'] as String);
  }
}

Process? currentPlayer;

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  print('Server running at http://${server.address.address}:${server.port}/');

  await for (HttpRequest request in server) {
    if (request.method == 'POST' && request.uri.path == '/play') {
      try {
        final content = await utf8.decoder.bind(request).join();
        final metadataMap = jsonDecode(content) as Map<String, dynamic>;
        final youtubeItem = YoutubeItemMetadata.fromJson(metadataMap);

        // Lấy URL audio
        final ytProcess = await Process.start('yt-dlp', ['-f', 'bestaudio', '-g', youtubeItem.id]);
        final url = (await ytProcess.stdout.transform(utf8.decoder).join()).trim();

        if (url.isEmpty) {
          final err = await ytProcess.stderr.transform(utf8.decoder).join();
          request.response
            ..statusCode = 500
            ..write('Error fetching URL: $err')
            ..close();
          continue;
        }

        // Kill tiến trình cũ nếu đang chạy
        if (currentPlayer != null) {
          print('Stopping previous track...');
          currentPlayer!.kill(ProcessSignal.sigkill);
          currentPlayer = null;
        }

        // Phát bài mới
        currentPlayer = await Process.start('ffplay', ['-nodisp', '-autoexit', url]);
        print('Playing: ${youtubeItem.title}');

        request.response
          ..statusCode = 200
          ..write('Playing: ${youtubeItem.title}')
          ..close();
      } catch (e) {
        request.response
          ..statusCode = 500
          ..write('Error: $e')
          ..close();
      }
    } else {
      request.response
        ..statusCode = 404
        ..write('Not Found')
        ..close();
    }
  }
}