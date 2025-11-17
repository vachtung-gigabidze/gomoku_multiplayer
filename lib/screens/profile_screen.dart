import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:gomoku_multiplayer/providers/game_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  File? _selectedImage;
  bool _isEditing = false;
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.userProfile == null) {
      await gameProvider.loadUserProfile();
    }

    if (_isMounted) {
      setState(() {
        _usernameController.text = gameProvider.userProfile?['username'] ?? gameProvider.username ?? 'Player';
        _emailController.text = gameProvider.email ?? '';
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500, maxHeight: 500, imageQuality: 80);

    if (pickedFile != null && _isMounted) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });

      // Автоматически загружаем изображение при выборе
      try {
        final gameProvider = Provider.of<GameProvider>(context, listen: false);
        await gameProvider.uploadAvatar(_selectedImage!);

        if (_isMounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar updated successfully!'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (_isMounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload avatar: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      await gameProvider.updateProfile(username: _usernameController.text.trim());

      if (_isMounted) {
        setState(() {
          _isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? '
          'This action cannot be undone and all your data will be lost.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      await gameProvider.deleteAccount();

      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted successfully'), backgroundColor: Colors.green));

        Navigator.pop(context); // Возвращаемся на предыдущий экран
      }
    } catch (e) {
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete account: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildAvatar() {
    final gameProvider = Provider.of<GameProvider>(context);
    final avatarUrl = gameProvider.userProfile?['avatar_url'];
    final username = gameProvider.userProfile?['username'] ?? 'Player';

    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) as ImageProvider : null,
            child: avatarUrl == null
                ? Text(
                    username.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(GameProvider gameProvider) {
    final stats = gameProvider.userStats ?? {};
    final gamesPlayed = stats['games_played'] ?? 0;
    final gamesWon = stats['games_won'] ?? 0;
    final winRate = gamesPlayed > 0 ? (gamesWon / gamesPlayed * 100) : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Game Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [_buildStatItem('Played', gamesPlayed.toString()), _buildStatItem('Won', gamesWon.toString()), _buildStatItem('Win Rate', '${winRate.toStringAsFixed(1)}%')],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  @override
  void dispose() {
    _isMounted = false;
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            actions: [
              if (_isEditing) IconButton(icon: const Icon(Icons.save), onPressed: _saveProfile) else IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _isEditing = true)),
            ],
          ),
          body: gameProvider.isProfileLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Avatar Section
                      Column(
                        children: [
                          _buildAvatar(),
                          const SizedBox(height: 16),
                          Text(gameProvider.userProfile?['username'] ?? 'Player', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text(gameProvider.email ?? '', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Statistics
                      _buildStatsCard(gameProvider),

                      const SizedBox(height: 24),

                      // Profile Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                              enabled: _isEditing,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter username';
                                }
                                if (value.length < 3) {
                                  return 'Username must be at least 3 characters';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                              enabled: false, // Email нельзя изменить напрямую
                              readOnly: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Danger Zone
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Danger Zone',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Once you delete your account, there is no going back. '
                                'Please be certain.',
                                style: TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _showDeleteAccountDialog,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  child: const Text('Delete Account'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
