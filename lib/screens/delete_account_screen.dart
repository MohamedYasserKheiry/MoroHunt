import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

/// "حذف الحساب بطلب أمان" — forces re-entry of the account's email +
/// password before permanently deleting it. The actual privileged
/// deletion runs server-side (see supabase/functions/delete-account);
/// this screen only handles the re-auth confirmation UX and surfacing
/// any errors.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController.text =
        Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد نهائي'),
        content: const Text(
          'سيتم حذف حسابك وجميع بياناتك (الصور المسجَّلة، الإحصائيات، الكلاب) '
          'نهائيًا ولا يمكن التراجع عن هذا الإجراء. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، احذف حسابي'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.instance.deleteAccountWithReauth(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // No manual navigation needed — signing out inside
      // deleteAccountWithReauth triggers _RootGate's auth listener to
      // redirect to the sign-in screen automatically.
    } on AuthException catch (e) {
      setState(() => _errorMessage = 'فشل التحقق من كلمة المرور: ${e.message}');
    } catch (e) {
      setState(() => _errorMessage = 'تعذر حذف الحساب: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حذف الحساب')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'هذا الإجراء نهائي ولا يمكن التراجع عنه. سيتم حذف جميع '
                      'بياناتك بشكل دائم.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'لأسباب أمنية، يرجى إعادة إدخال بريدك الإلكتروني وكلمة المرور '
              'لتأكيد هويتك قبل المتابعة.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null) ...[
              Text(_errorMessage!,
                  style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
            ],
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _confirmDelete,
                  child: const Text('تأكيد حذف الحساب'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
