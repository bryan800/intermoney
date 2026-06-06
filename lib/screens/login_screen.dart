import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'home_screen.dart';
import 'identity_verification_screen.dart';
import 'welcome_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialCreateAccount = false});

  final bool initialCreateAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _backgroundAsset = 'uploads/mney.png';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _dobController = TextEditingController();

  bool _isCreatingAccount = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String _selectedCountry = 'United States';

  @override
  void initState() {
    super.initState();
    _isCreatingAccount = widget.initialCreateAccount;
  }

  static const _countries = [
    'Algeria',
    'Angola',
    'Antigua and Barbuda',
    'Bahamas',
    'Barbados',
    'Belize',
    'Benin',
    'Botswana',
    'Burkina Faso',
    'Burundi',
    'Cabo Verde',
    'Cameroon',
    'Canada',
    'Central African Republic',
    'Chad',
    'Comoros',
    'Costa Rica',
    'Cote d\'Ivoire',
    'Cuba',
    'Democratic Republic of the Congo',
    'Djibouti',
    'Dominica',
    'Dominican Republic',
    'Egypt',
    'El Salvador',
    'Equatorial Guinea',
    'Eritrea',
    'Eswatini',
    'Ethiopia',
    'Gabon',
    'Gambia',
    'Ghana',
    'Grenada',
    'Guatemala',
    'Guinea',
    'Guinea-Bissau',
    'Haiti',
    'Honduras',
    'Jamaica',
    'Kenya',
    'Lesotho',
    'Liberia',
    'Libya',
    'Madagascar',
    'Malawi',
    'Mali',
    'Mauritania',
    'Mauritius',
    'Mexico',
    'Morocco',
    'Mozambique',
    'Namibia',
    'Nicaragua',
    'Niger',
    'Nigeria',
    'Panama',
    'Republic of the Congo',
    'Rwanda',
    'Saint Kitts and Nevis',
    'Saint Lucia',
    'Saint Vincent and the Grenadines',
    'Sao Tome and Principe',
    'Senegal',
    'Seychelles',
    'Sierra Leone',
    'Somalia',
    'South Africa',
    'South Sudan',
    'Sudan',
    'Tanzania',
    'Togo',
    'Trinidad and Tobago',
    'Tunisia',
    'Uganda',
    'United States',
    'Zambia',
    'Zimbabwe',
  ];

  static const Map<String, String> _countryIsoCodes = {
    'Algeria': 'DZ',
    'Angola': 'AO',
    'Antigua and Barbuda': 'AG',
    'Bahamas': 'BS',
    'Barbados': 'BB',
    'Belize': 'BZ',
    'Benin': 'BJ',
    'Botswana': 'BW',
    'Burkina Faso': 'BF',
    'Burundi': 'BI',
    'Cabo Verde': 'CV',
    'Cameroon': 'CM',
    'Canada': 'CA',
    'Central African Republic': 'CF',
    'Chad': 'TD',
    'Comoros': 'KM',
    'Costa Rica': 'CR',
    'Cote d\'Ivoire': 'CI',
    'Cuba': 'CU',
    'Democratic Republic of the Congo': 'CD',
    'Djibouti': 'DJ',
    'Dominica': 'DM',
    'Dominican Republic': 'DO',
    'Egypt': 'EG',
    'El Salvador': 'SV',
    'Equatorial Guinea': 'GQ',
    'Eritrea': 'ER',
    'Eswatini': 'SZ',
    'Ethiopia': 'ET',
    'Gabon': 'GA',
    'Gambia': 'GM',
    'Ghana': 'GH',
    'Grenada': 'GD',
    'Guatemala': 'GT',
    'Guinea': 'GN',
    'Guinea-Bissau': 'GW',
    'Haiti': 'HT',
    'Honduras': 'HN',
    'Jamaica': 'JM',
    'Kenya': 'KE',
    'Lesotho': 'LS',
    'Liberia': 'LR',
    'Libya': 'LY',
    'Madagascar': 'MG',
    'Malawi': 'MW',
    'Mali': 'ML',
    'Mauritania': 'MR',
    'Mauritius': 'MU',
    'Mexico': 'MX',
    'Morocco': 'MA',
    'Mozambique': 'MZ',
    'Namibia': 'NA',
    'Nicaragua': 'NI',
    'Niger': 'NE',
    'Nigeria': 'NG',
    'Panama': 'PA',
    'Republic of the Congo': 'CG',
    'Rwanda': 'RW',
    'Saint Kitts and Nevis': 'KN',
    'Saint Lucia': 'LC',
    'Saint Vincent and the Grenadines': 'VC',
    'Sao Tome and Principe': 'ST',
    'Senegal': 'SN',
    'Seychelles': 'SC',
    'Sierra Leone': 'SL',
    'Somalia': 'SO',
    'South Africa': 'ZA',
    'South Sudan': 'SS',
    'Sudan': 'SD',
    'Tanzania': 'TZ',
    'Togo': 'TG',
    'Trinidad and Tobago': 'TT',
    'Tunisia': 'TN',
    'Uganda': 'UG',
    'United States': 'US',
    'Zambia': 'ZM',
    'Zimbabwe': 'ZW',
  };

  String _flagEmojiFor(String country) {
    final iso = _countryIsoCodes[country];
    if (iso == null) return '';

    const flagBase = 0x1F1E6;
    final codeUnits = iso.toUpperCase().codeUnits;
    return String.fromCharCodes(codeUnits.map((c) => flagBase + (c - 0x41)));
  }

  Widget _countryLabel(String country) {
    final flag = _flagEmojiFor(country);
    return Text(
      flag.isEmpty ? country : '$flag $country',
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nationalIdController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _backgroundAsset,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, error, __) {
              debugPrint(
                'Failed to load login background "$_backgroundAsset": $error',
              );
              return Container(color: const Color(0xFFF2F3F5));
            },
          ),
          Container(color: const Color(0xFF061F18).withAlpha(142)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton.filledTonal(
                          tooltip: 'Back to welcome',
                          onPressed: _goBackToWelcome,
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 64,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'INTERFLEX',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isCreatingAccount
                            ? 'Create your account to get started.'
                            : 'Sign in to your account.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 28),
                      Card(
                        color: const Color(0xFFFAFEFB).withAlpha(244),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _isCreatingAccount
                                      ? 'Create account'
                                      : 'Login',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                if (_isCreatingAccount) ...[
                                  TextFormField(
                                    controller: _nameController,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Full name',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (value) {
                                      if (!_isCreatingAccount) return null;
                                      if (value == null ||
                                          value.trim().length < 2) {
                                        return 'Enter your name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    key: const Key('country_dropdown'),
                                    isExpanded: true,
                                    initialValue: _selectedCountry,
                                    decoration: const InputDecoration(
                                      labelText: 'Country',
                                      prefixIcon: Icon(Icons.public_outlined),
                                    ),
                                    items: _countries
                                        .map(
                                          (country) => DropdownMenuItem(
                                            value: country,
                                            child: _countryLabel(country),
                                          ),
                                        )
                                        .toList(),
                                    selectedItemBuilder: (context) => _countries
                                        .map(
                                            (country) => _countryLabel(country))
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _selectedCountry = value);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _nationalIdController,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Country national ID number',
                                      prefixIcon: Icon(Icons.badge_outlined),
                                    ),
                                    validator: (value) {
                                      if (!_isCreatingAccount) return null;
                                      final nationalId = value?.trim() ?? '';
                                      if (nationalId.length < 4) {
                                        return 'Enter your national ID number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _dobController,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Date of Birth',
                                      prefixIcon:
                                          Icon(Icons.calendar_month_outlined),
                                      hintText: 'Select your birth date',
                                    ),
                                    onTap: () async {
                                      final DateTime? pickedDate =
                                          await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now().subtract(
                                            const Duration(days: 365 * 18)),
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime.now(),
                                      );
                                      if (pickedDate != null) {
                                        setState(() {
                                          _dobController.text =
                                              "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                                        });
                                      }
                                    },
                                    validator: (value) {
                                      if (!_isCreatingAccount) return null;
                                      if (value == null || value.isEmpty) {
                                        return 'Please select your date of birth';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'User',
                                    prefixIcon: Icon(Icons.mail_outline),
                                  ),
                                  validator: (value) {
                                    final user = value?.trim() ?? '';
                                    if (user.isEmpty) {
                                      return 'Enter your user name or email';
                                    }
                                    if (user.length < 3) {
                                      return 'User must be at least 3 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: _isCreatingAccount
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    final password = value ?? '';
                                    if (password.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) {
                                    if (!_isCreatingAccount) _submit();
                                  },
                                ),
                                if (_isCreatingAccount) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    decoration: const InputDecoration(
                                      labelText: 'Confirm password',
                                      prefixIcon:
                                          Icon(Icons.lock_reset_outlined),
                                    ),
                                    validator: (value) {
                                      if (!_isCreatingAccount) return null;
                                      if (value != _passwordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                    onFieldSubmitted: (_) => _submit(),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    child: _isSubmitting
                                        ? const SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            _isCreatingAccount
                                                ? 'Create account'
                                                : 'Login',
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed:
                                      _isSubmitting ? null : _toggleAccountMode,
                                  child: Text(
                                    _isCreatingAccount
                                        ? 'Already have an account? Login'
                                        : 'New user? Create an account',
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
        ],
      ),
    );
  }

  void _toggleAccountMode() {
    setState(() {
      _isCreatingAccount = !_isCreatingAccount;
      _formKey.currentState?.reset();
      _confirmPasswordController.clear();
      _nationalIdController.clear();
      _selectedCountry = 'United States';
    });
  }

  void _goBackToWelcome() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final authService = context.read<AuthService>();
    final success = _isCreatingAccount
        ? await authService.createAccount(
            name: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
            country: _selectedCountry,
            nationalIdNumber: _nationalIdController.text,
            dob: _dobController.text,
          )
        : await authService.signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      if (authService.isAdmin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminDashboardScreen(),
          ),
        );
        return;
      }

      if (_isCreatingAccount && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const IdentityVerificationScreen(),
          ),
        );
        return;
      }

      if (!authService.pinChanged ||
          authService.identityVerificationStatus == 'pending') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const IdentityVerificationScreen(),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email or password is incorrect.'),
      ),
    );
  }
}
