import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const GratitudeApp());
}

class GratitudeEntry {
  final String id;
  final DateTime date;
  final String text;

  GratitudeEntry({
    required this.id,
    required this.date,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'text': text,
      };

  factory GratitudeEntry.fromJson(Map<String, dynamic> json) => GratitudeEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        text: json['text'] as String,
      );
}

class EntryStorage {
  static const _key = 'gratitude_entries';

  static Future<List<GratitudeEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((e) => GratitudeEntry.fromJson(jsonDecode(e)))
        .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> saveEntry(GratitudeEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((e) {
      final decoded = jsonDecode(e) as Map<String, dynamic>;
      return decoded['id'] == entry.id;
    });
    raw.add(jsonEncode(entry.toJson()));
    await prefs.setStringList(_key, raw);
  }

  static Future<void> deleteEntry(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((e) {
      final decoded = jsonDecode(e) as Map<String, dynamic>;
      return decoded['id'] == id;
    });
    await prefs.setStringList(_key, raw);
  }
}

Rect? _getWidgetBounds(GlobalKey key) {
  final box = key.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return null;
  final position = box.localToGlobal(Offset.zero);
  return position & box.size;
}

const kBar = Color(0xFF6B7C3A);
const kBg = Color(0xFFF4F6EC);
const kAccent = Color(0xFF8A9E4A);
const kLight = Color(0xFFDDE5C0);

class GratitudeApp extends StatelessWidget {
  const GratitudeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gratitude',
      scrollBehavior: const ScrollBehavior().copyWith(overscroll: false),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kBar),
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
        fontFamily: 'Gill Sans',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBar,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kBar,
            side: const BorderSide(color: kBar),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedImage;
  bool _isProcessing = false;

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  final GlobalKey _shareButtonKey = GlobalKey();

  Future<void> _pickImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: kLight,
                child: Icon(Icons.photo_library, color: kBar),
              ),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: kLight,
                child: Icon(Icons.camera_alt, color: kBar),
              ),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await _picker.pickImage(source: source);

    if (image != null) {
      final imageFile = File(image.path);
      setState(() {
        _selectedImage = imageFile;
        _textController.clear();
        _isProcessing = true;
      });
      await _recognizeText(imageFile);
    }
  }

  Future<void> _recognizeText(File imageFile) async {
    try {
      final apiKey = dotenv.env['ANTHROPIC_API_KEY'] ?? '';
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 1024,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': 'image/jpeg',
                    'data': base64Image,
                  },
                },
                {
                  'type': 'text',
                  'text':
                      'This is a photo of a handwritten gratitude list. Please transcribe exactly what is written, preserving the numbered list format. Return only the transcribed text, nothing else.',
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['content'][0]['text'] as String;
        setState(() {
          _textController.text = text;
          _isProcessing = false;
        });
      } else {
        setState(() {
          _textController.text =
              'Error: ${response.statusCode} — ${response.body}';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _textController.text = 'Error: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveEntry() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate == null) return;
    if (!mounted) return;

    final entry = GratitudeEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: pickedDate,
      text: text,
    );

    await EntryStorage.saveEntry(entry);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry saved!'),
        backgroundColor: kBar,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    setState(() {
      _selectedImage = null;
      _textController.clear();
    });
  }

  void _shareText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final bounds = _getWidgetBounds(_shareButtonKey);
    Share.share(text,
        subject: 'My Gratitude List', sharePositionOrigin: bounds);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBar,
          surfaceTintColor: kBar,
          shadowColor: Colors.transparent,
          title: const Text(
            'Gratitude',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.list_alt, color: Colors.white),
              tooltip: 'Saved entries',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EntriesScreen()),
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                '${today.month}/${today.day}/${today.year}',
                style: const TextStyle(
                  color: kBar,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.document_scanner),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Scan handwritten list',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_selectedImage != null)
                Expanded(
                  child: Container(
                    color: kBg,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_selectedImage!),
                          ),
                          const SizedBox(height: 20),
                          if (_isProcessing)
                            const Center(
                              child: CircularProgressIndicator(color: kBar),
                            )
                          else ...[
                            const Text(
                              'Edit recognized text',
                              style: TextStyle(
                                color: kBar,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _textController,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: kAccent, width: 2),
                                ),
                                hintText:
                                    'Recognized text will appear here...',
                                hintStyle: TextStyle(
                                    color: Colors.grey.shade400),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _saveEntry,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 14),
                                      child: Text('Save entry'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  key: _shareButtonKey,
                                  child: OutlinedButton.icon(
                                    onPressed: _shareText,
                                    icon: const Icon(Icons.share),
                                    label: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 14),
                                      child: Text('Share'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EntriesScreen extends StatefulWidget {
  const EntriesScreen({super.key});

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  List<GratitudeEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await EntryStorage.loadEntries();
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _deleteEntry(String id) async {
    await EntryStorage.deleteEntry(id);
    setState(() {
      _entries.removeWhere((e) => e.id == id);
    });
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBar,
        surfaceTintColor: kBar,
        shadowColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Saved Entries',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kBar))
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.eco, size: 64, color: kLight),
                      const SizedBox(height: 16),
                      const Text(
                        'No entries yet.\nScan your first gratitude list!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kBar, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return Dismissible(
                      key: Key(entry.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child:
                            const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteEntry(entry.id),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EntryDetailScreen(entry: entry),
                            ),
                          );
                          _loadEntries();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: kBar.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: kAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _formatDate(entry.date),
                                    style: const TextStyle(
                                      color: kBar,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(Icons.chevron_right,
                                  color: kAccent),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class EntryDetailScreen extends StatefulWidget {
  final GratitudeEntry entry;

  const EntryDetailScreen({super.key, required this.entry});

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  late TextEditingController _textController;
  late DateTime _selectedDate;
  final GlobalKey _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.entry.text);
    _selectedDate = widget.entry.date;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _changeDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveChanges() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final updated = GratitudeEntry(
      id: widget.entry.id,
      date: _selectedDate,
      text: text,
    );

    await EntryStorage.saveEntry(updated);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry updated!'),
        backgroundColor: kBar,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );

    Navigator.pop(context);
  }

  void _shareEntry() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final bounds = _getWidgetBounds(_shareButtonKey);
    Share.share(text,
        subject: 'My Gratitude List', sharePositionOrigin: bounds);
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBar,
          surfaceTintColor: kBar,
          shadowColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Entry',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _changeDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: kLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_calendar,
                          size: 18, color: kBar),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(_selectedDate),
                        style: const TextStyle(
                          color: kBar,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: kAccent, width: 2),
                    ),
                    hintText: 'Edit your gratitude list...',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade400),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Save changes'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    key: _shareButtonKey,
                    child: OutlinedButton.icon(
                      onPressed: _shareEntry,
                      icon: const Icon(Icons.share),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Share'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}