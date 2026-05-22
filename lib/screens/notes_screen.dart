import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _isLoading = true;
  String? _existingNoteId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  // 1. The Load Function
  Future<void> _loadNote() async {
    try {
      // asking Supabase: "Do you have a note for this specific space?"
      final data = await Supabase.instance.client
          .from('notes')
          .select()
          .eq('space_id', widget.spaceId)
          .maybeSingle(); // maybeSingle returns null if the room is empty

      //If a note exists, unpack it into the editor
      if (data != null) {
        _existingNoteId =
            data['id']; // Saving the ID so we don't duplicate it later
        _titleController.text =
            data['title']; // Put the title in the text field

        // Convert the JSON string back into a Quill Delta
        final contentJson = jsonDecode(data['content']);
        _controller.document = Document.fromJson(contentJson);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading note: $e')));
      }
    } finally {
      // 3. Whether it succeeded or failed, turn off the loading spinner
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 2. The Save Function
  Future<void> _saveNote() async {
    final title = _titleController.text;

    // avoiding storing empty notes
    if (title.isEmpty || _controller.document.isEmpty()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title and some notes!')),
      );
      return;
    }

    // 2. Grab the VIP Wristband (User ID)
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return; // Failsafe in case they are logged out

    // 3. Extract the JSON Delta
    final noteContentJson = jsonEncode(_controller.document.toDelta().toJson());

    try {
      // THE NEW LOGIC: Update vs Insert
      if (_existingNoteId != null) {
        // UPDATE MODE: Overwrite the existing note
        await Supabase.instance.client
            .from('notes')
            .update({'title': title, 'content': noteContentJson})
            .eq('id', _existingNoteId!); // Target this specific note ID
      } else {
        // INSERT MODE: Create a brand new note
        await Supabase.instance.client.from('notes').insert({
          'space_id': widget.spaceId,
          'user_id': userId,
          'title': title,
          'content': noteContentJson,
        });

        // Immediately fetch the new ID so we don't create duplicates if they hit save again!
        final newNote = await Supabase.instance.client
            .from('notes')
            .select('id')
            .eq('space_id', widget.spaceId)
            .single();
        _existingNoteId = newNote['id'];
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note successfully saved to the cloud! ☁️'),
          ),
        );
        Navigator.pop(context); // Send them back to the space screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
      }
    }
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            ) // 1. Show spinner if loading
          : Column(
              // 2. Show the editor if finished loading
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: "Note Title",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                QuillSimpleToolbar(
                  controller: _controller,
                  config: const QuillSimpleToolbarConfig(),
                ),
                const Divider(height: 1, thickness: 1),
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
