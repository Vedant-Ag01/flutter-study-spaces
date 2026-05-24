import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/spaces_provider.dart'; // Ensure this path is correct!

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;
  String? _avatarUrl;
  String _name = 'Loading...'; // Added state for the user's name

  @override
  void initState() {
    super.initState();
    _loadProfileData(); // Upgraded to load both photo AND name
  }

  // 1. Fetch Name and Photo from the database
  Future<void> _loadProfileData() async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Look at the public.profiles table
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _name = data?['name'] ?? 'Add your name';

          // If they have an avatar URL in the database, append a timestamp to bust the cache
          if (data?['avatar_url'] != null) {
            _avatarUrl =
                '${data!['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}';
          } else {
            _avatarUrl = null;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _name = 'Error loading profile');
    }
  }

  // 2. The Edit Name Popup
  Future<void> _showEditNameDialog() async {
    final nameController = TextEditingController(
      text: _name == 'Add your name' ? '' : _name,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Your Display Name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;

              final supabase = ref.read(supabaseProvider);
              final user = supabase.auth.currentUser;

              try {
                // Save the new name to the profiles table
                await supabase.from('profiles').upsert({
                  'id': user!.id,
                  'name': newName,
                  // Keep the existing avatar URL if it exists
                  if (_avatarUrl != null)
                    'avatar_url': _avatarUrl!.split('?').first,
                });

                if (mounted) {
                  setState(() => _name = newName);
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // 3. Upload Photo and update the database simultaneously
  Future<void> _uploadNewAvatar() async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
    );

    if (imageFile == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await imageFile.readAsBytes();
      final path = '${user.id}/profile.jpg';

      // 1. Upload to storage bucket
      await supabase.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // 2. Get the public URL
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);

      //Save this URL to the profiles table so the Chat can see it;p;l
      await supabase.from('profiles').upsert({
        'id': user.id,
        'name': _name == 'Add your name'
            ? null
            : _name, // Don't save the placeholder text
        'avatar_url': publicUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
        _loadProfileData(); // Refresh the screen
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading: $error')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AVATAR CIRCLE
            GestureDetector(
              onTap: _isUploading ? null : _uploadNewAvatar,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 80,
                    backgroundColor: Colors.deepPurple.shade50,
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.deepPurple,
                          )
                        : null,
                  ),
                  if (_isUploading)
                    const CircularProgressIndicator(color: Colors.deepPurple),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      radius: 24,
                      child: const Icon(Icons.camera_alt, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // NAME DISPLAY & EDIT BUTTON
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.grey),
                  onPressed: _showEditNameDialog,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // USER'S EMAIL
            Text(
              ref.read(supabaseProvider).auth.currentUser?.email ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
