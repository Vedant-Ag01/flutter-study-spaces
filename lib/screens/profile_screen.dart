import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/spaces_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadExistingAvatar();
  }

  // 1.Checking if they already have a photo when the screen opens
  Future<void> _loadExistingAvatar() async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      //loiking inside the storage to check if there really is an avatar photo or not
      final files = await supabase.storage.from('avatars').list(path: user.id);

      // If the list is empty, they haven't uploaded a photo yet.
      if (files.isEmpty) {
        setState(() {
          _avatarUrl =
              null; // This tells the UI to show the default Icon(Icons.person)
        });
        return;
      }

      // If we passed the check above, the file exists, Now it is safe to generate the URL.
      final url = supabase.storage
          .from('avatars')
          .getPublicUrl('${user.id}/profile.jpg');

      //used something here called "Cache - Busting" tricking the phone into thinkingit is a new address
      setState(() {
        _avatarUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      });
    } catch (e) {
      // If the folder doesn't exist yet, it might throw an error so hire we catch it and show the default icon.
      setState(() {
        _avatarUrl = null;
      });
    }
  }

  // 2.function to open the camera roll and upload!
  Future<void> _uploadNewAvatar() async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Open the phone's gallery
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600, // Compressing the image so it uploads instantly
      maxHeight: 600,
    );

    if (imageFile == null) return; // User canceled the picker

    setState(() => _isUploading = true);

    try {
      // Convert the image to raw bytes
      final bytes = await imageFile.readAsBytes();
      final path = '${user.id}/profile.jpg';

      // Upload to the 'avatars' bucket in Supabase!
      // upsert: true means it will overwrite their old photo if they change it.
      await supabase.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
        _loadExistingAvatar(); // Refresh the picture on screen
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(supabaseProvider).auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //AVATAR CIRCLE
            GestureDetector(
              onTap: _isUploading ? null : _uploadNewAvatar,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 80,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null
                        ? const Icon(Icons.person, size: 80, color: Colors.grey)
                        : null,
                  ),

                  // Show a loading spinner right on top of the image while uploading
                  if (_isUploading)
                    const CircularProgressIndicator(color: Colors.deepPurple),

                  // A little camera icon to tell them it's clickable
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
            const SizedBox(height: 24),

            // USER'S EMAIL
            Text(
              user?.email ?? 'Unknown User',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap your photo to change it',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
