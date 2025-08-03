import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:mongo_dart/mongo_dart.dart' as M;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // State variables
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _selectedGender;
  File? _profileImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 35),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/logo-app.png', height: 80),
                    const SizedBox(width: 10),
                  ],
                ),
                const SizedBox(height: 30),
                const Text(
                  'Tạo tài khoản mới',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                    controller: _emailController,
                    labelText: 'Email',
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _buildPasswordField(
                  controller: _passwordController,
                  labelText: 'Mật khẩu',
                  isPasswordVisible: _isPasswordVisible,
                  onToggleVisibility: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  labelText: 'Xác nhận mật khẩu',
                  isPasswordVisible: _isConfirmPasswordVisible,
                  onToggleVisibility: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  labelText: 'Số điện thoại',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildGenderDropdown(),
                const SizedBox(height: 16),
                _buildImagePickerField(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAF99),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(35.0), // CHỈNH SỬA Ở ĐÂY
                    ),
                  ),
                  child: const Text(
                    'Đăng ký',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Bạn đã có tài khoản?"),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          color: Color(0xFFFFAF99),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  void _registerUser() async {
    final email = _emailController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final phone = _phoneController.text;
    final gender = _selectedGender;

    if (email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        phone.isEmpty ||
        gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng điền đầy đủ tất cả các trường.')));
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mật khẩu xác nhận không khớp.')));
      return;
    }
    String? base64Image;
    if (_profileImage != null) {
      final imageBytes = await _profileImage!.readAsBytes();
      base64Image = base64Encode(imageBytes);
    }
    var id = M.ObjectId();
    final data = {
      "_id": id,
      "email": email,
      "password": password,
      "phone": phone,
      "gender": gender,
      "profile_image_base64": base64Image,
      "role": "user", // Tự động gán vai trò 'user'
    };
    await MongoDatabase.userCollection.insert(data);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký tài khoản thành công!')));
    Navigator.pop(context);
  }

  Widget _buildImagePickerField() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade600),
          borderRadius: BorderRadius.circular(35.0), // CHỈNH SỬA Ở ĐÂY
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Text(
                  _profileImage == null
                      ? 'Chọn ảnh đại diện (tùy chọn)'
                      : _profileImage!.path.split('/').last,
                  style: TextStyle(
                    color: _profileImage == null
                        ? Colors.grey.shade700
                        : Colors.black,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(Icons.photo_library_outlined, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String labelText,
      TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(35.0), // CHỈNH SỬA Ở ĐÂY
        ),
        floatingLabelStyle: const TextStyle(color: Colors.black),
         enabledBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(35.0), // CHỈNH SỬA Ở ĐÂY
             borderSide: const BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
              ),
            focusedBorder: OutlineInputBorder(
               borderRadius: BorderRadius.circular(35.0), // CHỈNH SỬA Ở ĐÂY
               borderSide: const BorderSide(color: Color.fromARGB(255, 0, 0, 0), width: 2),
              ),
      ),
    );
  }

  Widget _buildPasswordField(
      {required TextEditingController controller,
      required String labelText,
      required bool isPasswordVisible,
      required VoidCallback onToggleVisibility}) {
    return TextField(
      controller: controller,
      obscureText: !isPasswordVisible,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(35.0), // CHỈNH SỬA Ở ĐÂY
        ),
        floatingLabelStyle: const TextStyle(color: Colors.black),
        suffixIcon: IconButton(
          icon: Icon(
            isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: onToggleVisibility,
        ),
         enabledBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(35.0), // CHỈNH SỬA Ở ĐÂY
             borderSide: const BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
              ),
            focusedBorder: OutlineInputBorder(
               borderRadius: BorderRadius.circular(35.0), // CHỈNH SỬA Ở ĐÂY
               borderSide: const BorderSide(color: Color.fromARGB(255, 0, 0, 0), width: 2),
              ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Giới tính',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(35.0), // CHỈNH SỬA Ở ĐÂY
        ),
        floatingLabelStyle: const TextStyle(color: Colors.black),
         enabledBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(35.0), // CHỈNH SỬA Ở ĐÂY
             borderSide: const BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
              ),
            focusedBorder: OutlineInputBorder(
               borderRadius: BorderRadius.circular(35.0), // CHỈNH SỬA Ở ĐÂY
               borderSide: const BorderSide(color: Color.fromARGB(255, 0, 0, 0), width: 2),
              ),
      ),
      value: _selectedGender,
      items: ['Nam', 'Nữ', 'Khác'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedGender = newValue;
        });
      },
    );
  }
}