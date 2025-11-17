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
  final _formKey = GlobalKey<FormState>();

  File? _selectedImage;
  bool _isEditing = false;
  bool _isMounted = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    // Загружаем профиль если еще не загружен
    if (gameProvider.userProfile == null) {
      gameProvider.loadUserProfile().then((_) {
        if (_isMounted) {
          _updateControllers(gameProvider);
        }
      });
    } else {
      _updateControllers(gameProvider);
    }
  }

  void _updateControllers(GameProvider gameProvider) {
    if (_isMounted) {
      setState(() {
        _usernameController.text = gameProvider.userProfile?['username'] ?? gameProvider.username ?? 'Player';
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
      await _uploadAvatar(_selectedImage!);
    }
  }

  Future<void> _uploadAvatar(File imageFile) async {
    try {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final avatarUrl = await gameProvider.uploadAvatar(imageFile);

      if (_isMounted && avatarUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar updated successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload avatar: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isSaving) return; // Предотвращаем множественные сохранения

    setState(() {
      _isSaving = true;
    });

    try {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      await gameProvider.updateProfile(username: _usernameController.text.trim());

      if (_isMounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (_isMounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _cancelEdit() {
    // Восстанавливаем оригинальные значения
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    _usernameController.text = gameProvider.userProfile?['username'] ?? 'Player';

    setState(() {
      _isEditing = false;
      _selectedImage = null;
    });
  }

  Widget _buildAvatar(GameProvider gameProvider) {
    final avatarUrl = gameProvider.userProfile?['avatar_url'];
    final username = gameProvider.userProfile?['username'] ?? 'Player';

    return GestureDetector(
      onTap: _isEditing ? _pickImage : null,
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
          if (_isEditing)
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

  Widget _buildActionButtons() {
    if (_isSaving) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isEditing) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(onPressed: _cancelEdit, child: const Text('Cancel')),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(onPressed: _saveProfile, child: const Text('Save')),
          ),
        ],
      );
    } else {
      return ElevatedButton(onPressed: () => setState(() => _isEditing = true), child: const Text('Edit Profile'));
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    _usernameController.dispose();
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
            actions: _isEditing
                ? [IconButton(icon: const Icon(Icons.save), onPressed: _isSaving ? null : _saveProfile)]
                : [IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _isEditing = true))],
          ),
          body: gameProvider.isProfileLoading && gameProvider.userProfile == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Avatar Section
                      Column(
                        children: [
                          _buildAvatar(gameProvider),
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
                              enabled: _isEditing && !_isSaving,
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
                              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                              enabled: false,
                              initialValue: gameProvider.email ?? '',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      _buildActionButtons(),

                      const SizedBox(height: 32),

                      // Error Message
                      if (gameProvider.errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Text(gameProvider.errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
