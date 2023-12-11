import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_html/flutter_html.dart'; 


void main() {
  initializeDateFormatting().then((_) => runApp(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: ChatPage(),
      );
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<types.Message> _messages = [];
  final _user = const types.User(
    id: '82091008-a484-4a89-ae75-a22bf8d6f3ac',
  );
  final _bot = const types.User(
    id: '90909090-9090-9090-9090-909090909090',
  );

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImageSelection();
                },
                child: const Align(
                  alignment: AlignmentDirectional.center,
                  child: Text('Photo'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Align(
                  alignment: AlignmentDirectional.center,
                  child: Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final message = types.FileMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        mimeType: lookupMimeType(result.files.single.path!),
        name: result.files.single.name,
        size: result.files.single.size,
        uri: result.files.single.path!,
      );

      _addMessage(message);
    }
  }

final endpoint = 'https://bard-proxy-virid.vercel.app/v1beta2/models/chat-bison-001:generateMessage?key=AIzaSyASkuYqpJRIvx1rzQ2c6tKDS9l63LUNuQE';

Future<String?> generateMessage(String ocr) async {
  final response = await http.post(
    Uri.parse(endpoint),
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'prompt': {
        'context': 'you are helping me think of an good answer to continue this tinder conversation.',
        'messages': [{'author':"0", 'content': ocr}],
      },
      'temperature': 0.9,
      'top_k': 40,
      'top_p': 0.95,
      'candidate_count': 1,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    print(data);
    return data['candidates'][0]['content'] as String;
  }

  return null;
}

Future<String?> askBard(String ocr) async {
  final response = await http.post(
    Uri.parse(endpoint),
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'prompt': {
        'context': 'you are helping me with general life advice.',
        'messages': [{'author':"0", 'content': ocr}],
      },
      'temperature': 0.9,
      'top_k': 40,
      'top_p': 0.95,
      'candidate_count': 1,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    print(data);
    return data['candidates'][0]['content'] as String;
  }

  return null;
}

void _handleImageSelection() async {
  final result = await ImagePicker().pickImage(
    imageQuality: 70,
    maxWidth: 1440,
    source: ImageSource.gallery,
  );

  if (result != null) {
    try {
      final file = File(result.path!);
      final mimeType = lookupMimeType(file.path);      
      final bytes = await result.readAsBytes();
      final image = await decodeImageFromList(bytes);


      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://54.68.100.78:3000/upload'),
      );

      final message = types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),        
        name: result.name,
        size: bytes.length,
        uri: result.path,
        width: image.width.toDouble(),

      );

      _addMessage(message);

      // Add image file to the request
      request.files.add(http.MultipartFile(
        'sampleFile',
        file.readAsBytes().asStream(),
        file.lengthSync(),
        filename: result.name,
        contentType: MediaType.parse(mimeType ?? 'application/octet-stream'),
      ));

      // Send the request
      final response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200) {
        final loadingMessage = types.TextMessage(
          author: _bot,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          text: "alright let me think...",
        );

        _addMessage(loadingMessage);

        // Successfully uploaded
        final responseText = response.body;
        print('Image uploaded successfully: $responseText');
        var aiResponse = await generateMessage(responseText);

        // Create a simple TextMessage with the server response
        final message = types.TextMessage(
          author: _bot,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          text: aiResponse!,
        );

        _addMessage(message);

      } else {
        // Handle the error
        print('Failed to upload image. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // Handle any exceptions
      print('Error uploading image: $e');
    }
  }
}

String _stripHtmlTags(String htmlString) {
  // Use Flutter's Html widget to decode HTML entities and strip tags
  return Html(data: htmlString).toString();
}


  void _handleMessageTap(BuildContext _, types.Message message) async {
    if (message is types.FileMessage) {
      var localPath = message.uri;

      if (message.uri.startsWith('http')) {
        try {
          final index =
              _messages.indexWhere((element) => element.id == message.id);
          final updatedMessage =
              (_messages[index] as types.FileMessage).copyWith(
            isLoading: true,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });

          final client = http.Client();
          final request = await client.get(Uri.parse(message.uri));
          final bytes = request.bodyBytes;
          final documentsDir = (await getApplicationDocumentsDirectory()).path;
          localPath = '$documentsDir/${message.name}';

          if (!File(localPath).existsSync()) {
            final file = File(localPath);
            await file.writeAsBytes(bytes);
          }
        } finally {
          final index =
              _messages.indexWhere((element) => element.id == message.id);
          final updatedMessage =
              (_messages[index] as types.FileMessage).copyWith(
            isLoading: null,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });
        }
      }

      await OpenFilex.open(localPath);
    }
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final updatedMessage = (_messages[index] as types.TextMessage).copyWith(
      previewData: previewData,
    );

    setState(() {
      _messages[index] = updatedMessage;
    });
  }

  void _handleSendPressed(types.PartialText message) async {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );

    _addMessage(textMessage);
    var aiResponse = await askBard(message.text);

    // Create a simple TextMessage with the server response
    final response = types.TextMessage(
      author: _bot,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: aiResponse!,
    );

    _addMessage(response);

  }

void _loadMessages() async {
  // Skip loading messages from messages.json
  // _messages = (jsonDecode(await rootBundle.loadString('assets/messages.json')) as List)
  //     .map((e) => types.Message.fromJson(e as Map<String, dynamic>))
  //     .toList();

  // Set the initial message list to empty
  _messages = [];
  // Create a simple TextMessage with the server response
  final message = types.TextMessage(
    author: _bot,
    createdAt: DateTime.now().millisecondsSinceEpoch,
    id: const Uuid().v4(),
    text:"Welcome to d8bot - a dating coach, select a screenshot and I'll tell you what I think",
  );

  _addMessage(message);
}

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Chat(
          messages: _messages,
          onAttachmentPressed: _handleAttachmentPressed,
          onMessageTap: _handleMessageTap,
          onPreviewDataFetched: _handlePreviewDataFetched,
          onSendPressed: _handleSendPressed,
          showUserAvatars: true,
          showUserNames: true,
          user: _user,
          isLeftStatus: true,
          theme: const DefaultChatTheme(
            seenIcon: Text(
              'read',
              style: TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
        ),
      );
}
