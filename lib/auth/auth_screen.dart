import 'package:flutter/material.dart';

import 'auth_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthSuccess;

  const AuthScreen({
    super.key,
    required this.onAuthSuccess,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _apiKeyController =
      TextEditingController();

  final TextEditingController _pinController =
      TextEditingController();

  bool _hasSavedAuth = false;
  bool _isLoading = true;

  String? _message;

  @override
  void initState() {
    super.initState();
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final hasSavedAuth =
        await _authService.hasSavedAuth();

    setState(() {
      _hasSavedAuth = hasSavedAuth;
      _isLoading = false;
    });
  }

  Future<void> _saveApiKey() async {
    final apiKey =
        _apiKeyController.text.trim();

    if (apiKey.isEmpty) {
      setState(() {
        _message = "Введите API ключ";
      });

      return;
    }

    try {
      final provider =
          _authService.detectProvider(apiKey);

      final pin =
          await _authService
              .saveApiKeyAndGeneratePin(
                  apiKey);

      final balance =
          await _authService.getBalance();

      setState(() {
        _hasSavedAuth = true;

        _message =
            "Ключ проверен\n\n"
            "Провайдер: $provider\n"
            "Баланс: ${balance?.toStringAsFixed(2)}\n"
            "Ваш PIN: $pin";
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
      });
    }
  }

  Future<void> _checkPin() async {
    final result =
        await _authService.checkPin(
      _pinController.text.trim(),
    );

    if (result) {
      widget.onAuthSuccess();
    } else {
      setState(() {
        _message = "Неверный PIN";
      });
    }
  }

  Future<void> _resetKey() async {
    await _authService.resetAuth();

    setState(() {
      _hasSavedAuth = false;
      _message = null;
      _apiKeyController.clear();
      _pinController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFF1A0F0A),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end:
                Alignment.bottomRight,
            colors: [
              Color(0xFF4A160A),
              Color(0xFF2A0E07),
              Color(0xFF120A07),
            ],
          ),
        ),

        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 500,
              margin:
                  const EdgeInsets.all(
                      20),

              padding:
                  const EdgeInsets.all(
                      25),

              decoration:
                  BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),

                borderRadius:
                    BorderRadius
                        .circular(
                            25),

                border: Border.all(
                  color:
                      Colors.orange,
                  width: 1,
                ),
              ),

              child: _hasSavedAuth
                  ? _buildPinForm()
                  : _buildApiKeyForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeyForm() {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [

        const Text(
          "Первый вход",
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
            height: 15),

        const Text(
          "Введите API ключ\nдля проверки и доступа",
          textAlign:
              TextAlign.center,
          style: TextStyle(
            color:
                Colors.orange,
            fontSize: 18,
          ),
        ),

        const SizedBox(
            height: 30),

        TextField(
          controller:
              _apiKeyController,
          style: const TextStyle(
              color:
                  Colors.white),

          decoration:
              InputDecoration(
            labelText:
                "API ключ",

            labelStyle:
                const TextStyle(
              color: Colors
                  .orangeAccent,
            ),

            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius
                      .circular(
                          15),

              borderSide:
                  const BorderSide(
                color:
                    Colors.orange,
              ),
            ),

            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius
                      .circular(
                          15),

              borderSide:
                  const BorderSide(
                color: Colors
                    .deepOrange,
                width: 2,
              ),
            ),
          ),
        ),

        const SizedBox(
            height: 25),

        SizedBox(
          width: double.infinity,
          height: 55,

          child: ElevatedButton(
            onPressed:
                _saveApiKey,

            style:
                ElevatedButton
                    .styleFrom(
              backgroundColor:
                  Colors
                      .deepOrange,

              foregroundColor:
                  Colors.white,

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                            15),
              ),
            ),

            child: const Text(
              "Проверить ключ",
              style:
                  TextStyle(
                fontSize: 18,
              ),
            ),
          ),
        ),

        if (_message != null)
          Padding(
            padding:
                const EdgeInsets
                    .only(
                    top: 25),

            child: Text(
              _message!,
              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 16,
              ),
            ),
          )
      ],
    );
  }

  Widget _buildPinForm() {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [

        const Text(
          "Вход по PIN",
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
            height: 20),

        TextField(
          controller:
              _pinController,

          maxLength: 4,

          obscureText: true,

          style: const TextStyle(
            color: Colors.white,
          ),

          decoration:
              const InputDecoration(
            labelText: "PIN",

            labelStyle:
                TextStyle(
              color: Colors
                  .orangeAccent,
            ),
          ),
        ),

        const SizedBox(
            height: 20),

        SizedBox(
          width: double.infinity,
          height: 55,

          child: ElevatedButton(
            onPressed:
                _checkPin,

            style:
                ElevatedButton
                    .styleFrom(
              backgroundColor:
                  Colors
                      .deepOrange,
            ),

            child: const Text(
              "Войти",
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize: 18,
              ),
            ),
          ),
        ),

        TextButton(
          onPressed:
              _resetKey,

          child: const Text(
            "Сбросить ключ",
            style: TextStyle(
              color:
                  Colors.orange,
            ),
          ),
        ),

        if (_message != null)
          Padding(
            padding:
                const EdgeInsets
                    .only(
                    top: 25),

            child: Text(
              _message!,
              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                color:
                    Colors.white,
              ),
            ),
          )
      ],
    );
  }
}