import 'package:flutter/material.dart';

import '../data/email_auth_service.dart';
import 'glowing_mouse_icon.dart';

class TrackNestSignInDialog extends StatefulWidget {
  const TrackNestSignInDialog({super.key});

  @override
  State<TrackNestSignInDialog> createState() => _TrackNestSignInDialogState();
}

class _TrackNestSignInDialogState extends State<TrackNestSignInDialog> {
  final EmailAuthService _auth = EmailAuthService.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _codeSent = false;
  bool _working = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (!_auth.isConfigured) {
      _message = 'Email sign-in needs an account service connection before it can send codes.';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    if (!_codeSent && (email.isEmpty || !email.contains('@'))) {
      setState(() => _message = 'Enter a valid email address to continue.');
      return;
    }
    if (_codeSent && _codeController.text.trim().isEmpty) {
      setState(() => _message = 'Enter the one-time code from your email.');
      return;
    }
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      if (!_codeSent) {
        await _auth.sendCode(email);
        if (!mounted) return;
        setState(() {
          _codeSent = true;
          _message = 'Check your inbox for a one-time sign-in code.';
        });
      } else {
        final signedInEmail = await _auth.verifyCode(
          email: email,
          code: _codeController.text,
        );
        if (!mounted) return;
        setState(() => _message = 'Signed in as $signedInEmail.');
      }
    } on EmailAuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not reach the account service. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _working = true);
    try {
      await _auth.signOut();
      if (mounted) setState(() => _message = 'You are signed out.');
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not sign out. Try again.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final signedInEmail = _auth.signedInEmail;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const GlowingMouseIcon(size: 48),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          signedInEmail == null
                              ? 'Sign in to TrackNest'
                              : 'Your TrackNest account',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Use a one-time code sent to your email.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (signedInEmail != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: .24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: colors.primary,
                        size: 30,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        signedInEmail,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your music files remain stored on this PC.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: _working ? null : _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ] else ...[
                TextField(
                  controller: _emailController,
                  enabled: !_working && !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    enabled: !_working,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    decoration: const InputDecoration(
                      labelText: 'One-time code',
                      hintText: 'Enter the code from your email',
                      prefixIcon: Icon(Icons.password_rounded),
                    ),
                  ),
                ],
                if (_message case final message?) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      message,
                      style: TextStyle(
                        color: _auth.isConfigured
                            ? colors.onSurfaceVariant
                            : colors.tertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 17),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _working ? null : _continue,
                    icon: _working
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _codeSent
                                ? Icons.verified_user_outlined
                                : Icons.arrow_forward_rounded,
                          ),
                    label: Text(
                      _working
                          ? 'Please wait…'
                          : _codeSent
                          ? 'Verify code'
                          : 'Continue with email',
                    ),
                  ),
                ),
                if (_codeSent)
                  TextButton(
                    onPressed: _working
                        ? null
                        : () => setState(() {
                            _codeSent = false;
                            _codeController.clear();
                            _message = null;
                          }),
                    child: const Text('Use a different email'),
                  ),
              ],
              if (signedInEmail != null && _message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
