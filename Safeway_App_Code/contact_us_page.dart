import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({Key? key}) : super(key: key);

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSending = false;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitSupportRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final message = _messageController.text.trim();
    final user = _supabase.auth.currentUser;

    setState(() => _isSending = true);
    try {
      final response = await _supabase.from('support_messages').insert({
        'user_id': user?.id,
        'name': name,
        'email': email,
        'message': message,
      });

      // ignore: unused_local_variable
      final inserted = response;

      if (!mounted) return;

      _formKey.currentState!.reset();
      _nameController.clear();
      _emailController.clear();
      _messageController.clear();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Message sent'),
          content: const Text(
            'Thank you for contacting us.\n'
            'We have received your message and will get back to you.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 🔹 Arka plan gradient'i dark / light moda göre
    final backgroundGradientColors = isDark
        ? const [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF020617),
          ]
        : const [
            Color(0xFF1B63D0),
            Color(0xFF3D8BF5),
            Color(0xFFE6EEFF),
          ];

    // 🔹 Glass card rengi
    final cardBackgroundColor =
        isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.82);
    final cardBorderColor =
        isDark ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.8);

    // 🔹 TextField zemin & border renkleri
    final fieldFillColor =
        isDark ? const Color(0xFF020617) : const Color(0xFFF7F8FC);
    final fieldBorderColor =
        isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final fieldFocusedBorderColor =
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E88E5);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Contact us',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.8, -1),
            end: const Alignment(0.8, 1),
            colors: backgroundGradientColors,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Üst Hero Bölümü
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF42A5F5),
                                Color(0xFF1E88E5),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.support_agent_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Reach out, we're here for you!",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Have questions, feedback or issues with SafeWay?\nSend us a message and we’ll get back to you.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.92),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Mail Chip
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.email_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'infosafewayapp@gmail.com',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Glassmorphism Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            color: cardBackgroundColor,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(
                              color: cardBorderColor,
                              width: 1.0,
                            ),
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 22, 20, 20),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        height: 34,
                                        width: 4,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          gradient: const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Color(0xFF1E88E5),
                                              Color(0xFF42A5F5),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Send us a message',
                                            style: theme
                                                .textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight:
                                                  FontWeight.w700,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'We usually respond within a couple of days.',
                                            style: theme
                                                .textTheme.bodySmall
                                                ?.copyWith(
                                              color: isDark
                                                  ? Colors.grey[300]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Name
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      labelText: 'Your name',
                                      prefixIcon: const Icon(
                                          Icons.person_outline),
                                      filled: true,
                                      fillColor: fieldFillColor,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        borderSide: BorderSide(
                                          color: fieldBorderColor,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        borderSide: BorderSide(
                                          color: fieldBorderColor,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        borderSide: BorderSide(
                                          color: fieldFocusedBorderColor,
                                          width: 1.4,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  // Email
                                  TextFormField(
                                    controller: _emailController,
                                    decoration: InputDecoration(
                                      labelText: 'Your email',
                                      prefixIcon: const Icon(Icons
                                          .alternate_email_rounded),
                                      filled: true,
                                      fillColor: fieldFillColor,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        borderSide: BorderSide(
                                          color: fieldBorderColor,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        borderSide: BorderSide(
                                          color: fieldBorderColor,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        borderSide: BorderSide(
                                          color: fieldFocusedBorderColor,
                                          width: 1.4,
                                        ),
                                      ),
                                    ),
                                    keyboardType:
                                        TextInputType.emailAddress,
                                    validator: (value) {
                                      final text =
                                          value?.trim() ?? '';
                                      if (text.isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!text.contains('@')) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  // Message
                                  TextFormField(
                                    controller: _messageController,
                                    decoration: InputDecoration(
                                      labelText: 'Message',
                                      alignLabelWithHint: true,
                                      filled: true,
                                      fillColor: fieldFillColor,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 16,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(22),
                                        borderSide: BorderSide(
                                          color: fieldBorderColor,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(22),
                                        borderSide: BorderSide(
                                          color: fieldBorderColor,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(22),
                                        borderSide: BorderSide(
                                          color: fieldFocusedBorderColor,
                                          width: 1.4,
                                        ),
                                      ),
                                    ),
                                    minLines: 6,
                                    maxLines: 10,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please write your message';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),

                                  SizedBox(
                                    height: 50,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        backgroundColor:
                                            const Color(0xFF1E88E5),
                                      ),
                                      onPressed: _isSending
                                          ? null
                                          : _submitSupportRequest,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                            milliseconds: 220),
                                        transitionBuilder:
                                            (child, animation) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          );
                                        },
                                        child: _isSending
                                            ? Row(
                                                key: const ValueKey(
                                                    'sending'),
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .center,
                                                children: const [
                                                  SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2.2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Colors
                                                                  .white),
                                                    ),
                                                  ),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    'Sending...',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Row(
                                                key: const ValueKey(
                                                    'send'),
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .center,
                                                children: const [
                                                  Icon(
                                                    Icons.send_rounded,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Send',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
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
                    ),

                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
