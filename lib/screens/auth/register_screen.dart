import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../main.dart';
import '../../widgets/google_logo.dart';
import 'dart:math' as math;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _gender = 'Laki-laki';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        gender: _gender,
        age: int.tryParse(_ageController.text.trim()) ?? 0,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthWrapper()),
              (route) => false,
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 'Registrasi gagal.'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Login Google gagal.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: screenHeight,
          ),
          child: IntrinsicHeight(
            child: Stack(
              children: [
                // Top Wave Header with Topographical Lines
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: screenHeight * 0.28, // Shorter header to prevent overflow on forms
                  child: ClipPath(
                    clipper: RegisterWaveClipper(),
                    child: Container(
                      color: AppTheme.primaryBlue, // Blue color instead of Red
                      child: CustomPaint(
                        painter: RegisterTopographyPainter(
                          lineColor: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: screenHeight * 0.31), // Position right below header
                      
                      // Heading "Sign up"
                      SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(_slideAnimation),
                        child: FadeTransition(
                          opacity: _slideAnimation,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sign up',
                                style: GoogleFonts.inter(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textDark,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 45,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Form
                      Expanded(
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(_slideAnimation),
                          child: FadeTransition(
                            opacity: _slideAnimation,
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Full Name Field
                                  Text(
                                    'Nama Lengkap',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _fullNameController,
                                    keyboardType: TextInputType.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      color: AppTheme.textDark,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Masukkan nama lengkap',
                                      hintStyle: GoogleFonts.inter(
                                        color: Colors.grey.shade400,
                                      ),
                                      filled: false,
                                      border: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.person_outline_rounded, color: Colors.grey.shade400, size: 20),
                                            const SizedBox(width: 10),
                                            Text('|', style: TextStyle(color: Colors.grey.shade300, fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Masukkan nama lengkap Anda';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // Email Field
                                  Text(
                                    'Email',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      color: AppTheme.textDark,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'nama@email.com',
                                      hintStyle: GoogleFonts.inter(
                                        color: Colors.grey.shade400,
                                      ),
                                      filled: false,
                                      border: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.mail_outline_rounded, color: Colors.grey.shade400, size: 20),
                                            const SizedBox(width: 10),
                                            Text('|', style: TextStyle(color: Colors.grey.shade300, fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Masukkan email Anda';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Gender & Age Row
                                  Row(
                                    children: [
                                      // Gender Selector
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Jenis Kelamin',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            DropdownButtonFormField<String>(
                                              initialValue: _gender,
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                color: AppTheme.textDark,
                                              ),
                                              decoration: InputDecoration(
                                                filled: false,
                                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                                border: UnderlineInputBorder(
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                enabledBorder: UnderlineInputBorder(
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                focusedBorder: const UnderlineInputBorder(
                                                  borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                                                ),
                                              ),
                                              items: const [
                                                DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                                                DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                                              ],
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setState(() => _gender = val);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      // Age field
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Umur',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            TextFormField(
                                              controller: _ageController,
                                              keyboardType: TextInputType.number,
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                color: AppTheme.textDark,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'Tahun',
                                                hintStyle: GoogleFonts.inter(
                                                  color: Colors.grey.shade400,
                                                ),
                                                filled: false,
                                                border: UnderlineInputBorder(
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                enabledBorder: UnderlineInputBorder(
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                focusedBorder: const UnderlineInputBorder(
                                                  borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                              ),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Kosong';
                                                }
                                                if (int.tryParse(value) == null) {
                                                  return 'Harus angka';
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Password Field
                                  Text(
                                    'Password',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      color: AppTheme.textDark,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'enter your password',
                                      hintStyle: GoogleFonts.inter(
                                        color: Colors.grey.shade400,
                                      ),
                                      filled: false,
                                      border: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                      suffixIcon: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                        child: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: Colors.grey.shade400,
                                          size: 20,
                                        ),
                                      ),
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400, size: 20),
                                            const SizedBox(width: 10),
                                            Text('|', style: TextStyle(color: Colors.grey.shade300, fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a password';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Confirm Password Field
                                  Text(
                                    'Confirm Password',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirm,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      color: AppTheme.textDark,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Confirm your password',
                                      hintStyle: GoogleFonts.inter(
                                        color: Colors.grey.shade400,
                                      ),
                                      filled: false,
                                      border: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                      suffixIcon: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _obscureConfirm = !_obscureConfirm;
                                          });
                                        },
                                        child: Icon(
                                          _obscureConfirm
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: Colors.grey.shade400,
                                          size: 20,
                                        ),
                                      ),
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400, size: 20),
                                            const SizedBox(width: 10),
                                            Text('|', style: TextStyle(color: Colors.grey.shade300, fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value != _passwordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 28),
                                  
                                  // Google Sign Up Button (Placed above Create Account)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: OutlinedButton(
                                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        backgroundColor: Colors.white,
                                        foregroundColor: AppTheme.textDark,
                                        elevation: 0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const GoogleLogo(size: 20),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Continue with Google',
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Create Account Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handleRegister,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryBlue,
                                        disabledBackgroundColor: AppTheme.primaryBlue.withOpacity(0.7),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : Text(
                                              'Create Account',
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Bottom Sign In Link
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an Account! ',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppTheme.textGrey,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Text(
                                  'Login',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryBlue, // Blue color instead of Red
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.82); // Start point on the left
    
    // Wave curves up first, then down, then up
    final controlPoint1 = Offset(size.width * 0.28, size.height * 0.62);
    final controlPoint2 = Offset(size.width * 0.72, size.height * 1.05);
    final endPoint = Offset(size.width, size.height * 0.85);
    
    path.cubicTo(
      controlPoint1.dx, controlPoint1.dy,
      controlPoint2.dx, controlPoint2.dy,
      endPoint.dx, endPoint.dy,
    );
    
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class RegisterTopographyPainter extends CustomPainter {
  final Color lineColor;
  RegisterTopographyPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Center point for concentric irregular ellipses
    final center = Offset(size.width * 0.55, size.height * 0.35);

    for (int i = 1; i <= 8; i++) {
      final double radius = i * 22.0;
      final path = Path();

      for (int angle = 0; angle <= 360; angle += 8) {
        final double rad = angle * math.pi / 180;
        
        // Organic distortion matching topographic map pattern
        final double distortion = 1.0 + 
            0.12 * math.sin(3.5 * rad) + 
            0.08 * math.cos(5.0 * rad);
            
        final double x = center.dx + radius * distortion * math.cos(rad);
        final double y = center.dy + radius * distortion * 0.8 * math.sin(rad);

        if (angle == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
