import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../services/supabase_service.dart';
import '../../services/cloudinary_service.dart';
import '../../providers/user_provider.dart';
import '../../config/r.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _signatureController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _selectedGender = 'male'; // male or female
  String _selectedCountry = 'EG';
  File? _selectedImage;
  bool _isLoading = false;
  DateTime? _selectedBirthday;

  final List<Map<String, String>> _arabCountries = [
    {'code': 'EG', 'name': 'مصر', 'flag': '🇪🇬'},
    {'code': 'SA', 'name': 'السعودية', 'flag': '🇸🇦'},
    {'code': 'AE', 'name': 'الإمارات', 'flag': '🇦🇪'},
    {'code': 'KW', 'name': 'الكويت', 'flag': '🇰🇼'},
    {'code': 'QA', 'name': 'قطر', 'flag': '🇶🇦'},
    {'code': 'BH', 'name': 'البحرين', 'flag': '🇧🇭'},
    {'code': 'OM', 'name': 'عمان', 'flag': '🇴🇲'},
    {'code': 'IQ', 'name': 'العراق', 'flag': '🇮🇶'},
    {'code': 'SY', 'name': 'سوريا', 'flag': '🇸🇾'},
    {'code': 'LB', 'name': 'لبنان', 'flag': '🇱🇧'},
    {'code': 'JO', 'name': 'الأردن', 'flag': '🇯🇴'},
    {'code': 'PS', 'name': 'فلسطين', 'flag': '🇵🇸'},
    {'code': 'YE', 'name': 'اليمن', 'flag': '🇾🇪'},
    {'code': 'DZ', 'name': 'الجزائر', 'flag': '🇩🇿'},
    {'code': 'MA', 'name': 'المغرب', 'flag': '🇲🇦'},
    {'code': 'TN', 'name': 'تونس', 'flag': '🇹🇳'},
    {'code': 'LY', 'name': 'ليبيا', 'flag': '🇱🇾'},
    {'code': 'SD', 'name': 'السودان', 'flag': '🇸🇩'},
    {'code': 'MR', 'name': 'موريتانيا', 'flag': '🇲🇷'},
    {'code': 'SO', 'name': 'الصومال', 'flag': '🇸🇴'},
    {'code': 'DJ', 'name': 'جيبوتي', 'flag': '🇩🇯'},
    {'code': 'KM', 'name': 'جزر القمر', 'flag': '🇰🇲'},
  ];

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر البلد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _arabCountries.length,
                  itemBuilder: (context, index) {
                    final country = _arabCountries[index];
                    return ListTile(
                      leading: Text(country['flag']!, style: const TextStyle(fontSize: 24)),
                      title: Text(country['name']!),
                      onTap: () {
                        setState(() {
                          _selectedCountry = country['code']!;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    if (user != null) {
      _nameController.text = user.name ?? '';
      _signatureController.text = user.signature ?? '';
      _ageController.text = (user.age ?? 18).toString();
      _selectedGender = user.gender ?? 'male';
      _selectedCountry = user.country ?? 'EG';
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إدخال الاسم')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم العثور على المستخدم')),
          );
        }
        return;
      }

      String photoUrl = currentUser.photoUrl ?? '';

      // Upload image if selected
      if (_selectedImage != null) {
        final cid = currentUser.customId.isNotEmpty ? currentUser.customId : currentUser.uid.replaceAll('-', '').substring(0, 7);
        photoUrl = await CloudinaryService().uploadImage(
          _selectedImage!,
          publicId: 'user_$cid',
        );
      }

      // Update user
      final updatedUser = currentUser.copyWith(
        name: _nameController.text.trim(),
        photoUrl: photoUrl,
        gender: _selectedGender,
        signature: _signatureController.text.trim(),
        country: _selectedCountry,
        age: int.tryParse(_ageController.text.trim()) ?? 18,
      );

      await SupabaseService().saveUser(updatedUser);

      // Load user in provider
      if (mounted) {
        await userProvider.loadUser(currentUser.uid);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              color: Colors.white,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Image.asset(
                      'assets/mipmap-xxhdpi/back_ic.webp',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'تعديل الملف الشخصي',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16151A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              'assets/mipmap-xxhdpi/mine_avatar_ic.webp',
                              width: 122,
                              height: 122,
                            ),
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFFFFFFFF), width: 4),
                              ),
                              child: ClipOval(
                                child: _selectedImage != null
                                    ? Image.file(
                                        _selectedImage!,
                                        fit: BoxFit.cover,
                                        width: 92,
                                        height: 92,
                                      )
                                    : (user?.photoUrl != null &&
                                            user?.photoUrl != '')
                                        ? Image(
                                            image: R.cachedImage(user!.photoUrl),
                                            fit: BoxFit.cover,
                                            width: 92,
                                            height: 92,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Image.asset(
                                                R.avaBoy,
                                                fit: BoxFit.cover,
                                              );
                                            },
                                          )
                                        : Image.asset(
                                            R.avaBoy,
                                            fit: BoxFit.cover,
                                          ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Name Field
                    _buildEditField(
                      'الاسم',
                      _nameController,
                      Icons.person,
                    ),
                    const SizedBox(height: 16),
                    // Age Field
                    _buildEditField(
                      'العمر',
                      _ageController,
                      Icons.cake,
                    ),
                    const SizedBox(height: 16),
                    // Country
                    _buildMenuField(
                      'البلد',
                      _arabCountries.firstWhere((c) => c['code'] == _selectedCountry, orElse: () => _arabCountries.first)['name']!,
                      Icons.flag,
                      _showCountryPicker,
                    ),
                    const SizedBox(height: 16),
                    // Gender
                    _buildGenderSelector(),
                    const SizedBox(height: 16),
                    // Signature
                    _buildEditField(
                      'السيرة الذاتية',
                      _signatureController,
                      Icons.edit,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 32),
                    // Save Button
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFCC80),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: const Text(
                                'حفظ',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF894916),
                                ),
                              ),
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
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9BA1B6),
            ),
          ),
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuField(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF16151A),
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9BA1B6),
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/mipmap-xxhdpi/common_next_4_ic.webp',
              width: 16,
              height: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الجنس',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF16151A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGender = 'male';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedGender == 'male'
                          ? const Color(0xFF3597FF)
                          : const Color(0xFFF2F5FC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/mipmap-xxhdpi/ic_sex_boy.webp',
                          width: 24,
                          height: 24,
                          color: _selectedGender == 'male'
                              ? Colors.white
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ذكر',
                          style: TextStyle(
                            color: _selectedGender == 'male'
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGender = 'female';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedGender == 'female'
                          ? const Color(0xFFFE72DC)
                          : const Color(0xFFF2F5FC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/mipmap-xxhdpi/ic_sex_girl.webp',
                          width: 24,
                          height: 24,
                          color: _selectedGender == 'female'
                              ? Colors.white
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'أنثى',
                          style: TextStyle(
                            color: _selectedGender == 'female'
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

