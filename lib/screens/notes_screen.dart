import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';

class NotesScreen extends StatefulWidget {
  final String spaceId; // to know which room these notes belong to

  const NotesScreen({super.key, required this.spaceId});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  // 1. The Brain: This controls all the text and formatting
  final QuillController _controller = QuillController.basic();
  final TextEditingController _titleController = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  // 2. The Save Function

  void _saveNote() {
    final title = _titleController.text;

    // We ask Quill for the document, convert it to a Delta, and turn it into a JSON string!
    final noteContentJson = jsonEncode(_controller.document.toDelta().toJson());

    // For today, just printing it. Tomorrow, will send this to Supabase.
    print("=== SAVING NOTE ===");
    print("TITLE: $title");
    print("CONTENT: $noteContentJson");
    print("===================");

    // Optional: Show a little pop-up so the user knows it worked
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Note saved to console!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Notes'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveNote),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: "Note Title",
                border: InputBorder.none,
              ),
            ),
          ),
          // 2. The Toolbar: All the formatting buttons
          QuillSimpleToolbar(
            controller: _controller,
            config: const QuillSimpleToolbarConfig(),
          ),
          //divider to separate the tools from the paper
          const Divider(height: 1, thickness: 1),

          // 3. The Canvas: Where the user actually types
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: QuillEditor.basic(controller: _controller),
            ),
          ),
        ],
      ),
    );
  }
}
