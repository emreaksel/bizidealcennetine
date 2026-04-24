import 'package:flutter/material.dart';
import '../yaveran/Degiskenler.dart';
import '../yaveran/app_theme.dart';
import '../yaveran/MusicApiService.dart';
import '../yaveran/audio_service.dart';
import 'sync_dialog.dart';

class SettingsMenu extends StatelessWidget {
  final MusicApiService _apiService = MusicApiService();

  void _showLogoutDialog(BuildContext context, AppTheme theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Oturumu Sırla',
            style:
                TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
        content: Text('Cihazın senkronizasyonunu dinlendirmek istiyor musunuz?',
            style: TextStyle(color: theme.subTextColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Şimdi Değil',
                style: TextStyle(color: theme.subTextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await _apiService.logout();
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context); // Close settings menu
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cihaz bağlantısı başarıyla dinlendirildi.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Evet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context, AppTheme theme) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController customTimeController =
            TextEditingController();
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Zamanlayıcı',
              style: TextStyle(
                  color: theme.textColor, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title:
                    Text("10 Dakika", style: TextStyle(color: theme.textColor)),
                onTap: () {
                  AudioService.startSleepTimer(10);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title:
                    Text("20 Dakika", style: TextStyle(color: theme.textColor)),
                onTap: () {
                  AudioService.startSleepTimer(20);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title:
                    Text("30 Dakika", style: TextStyle(color: theme.textColor)),
                onTap: () {
                  AudioService.startSleepTimer(30);
                  Navigator.pop(context);
                },
              ),
              Divider(color: theme.textColor.withOpacity(0.1)),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customTimeController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: theme.textColor),
                        decoration: InputDecoration(
                          hintText: 'Özel (dk)',
                          hintStyle: TextStyle(color: theme.subTextColor),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: theme.textColor.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.accentColor),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final val = int.tryParse(customTimeController.text);
                        if (val != null && val > 0) {
                          AudioService.startSleepTimer(val);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Başlat',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showContactForm(BuildContext context, AppTheme theme) {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController messageController = TextEditingController();
    String selectedReason = "Teşekkür";

    final List<String> reasons = [
      "Teşekkür",
      "Teknik Sorun",
      "Parça Önerisi",
      "Diğer",
    ];

    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.textColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.mail_outline_rounded,
                          color: theme.accentColor, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        "İrtibat",
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildLabel("Sebep", theme),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.textColor),
                    decoration: _inputDecoration(theme),
                    items: reasons.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        selectedReason = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildLabel("İsim", theme),
                  TextFormField(
                    controller: nameController,
                    style: TextStyle(color: theme.textColor),
                    decoration: _inputDecoration(theme, hint: "İsim"),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen isim giriniz.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildLabel("E-posta Adresiniz", theme),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: theme.textColor),
                    decoration:
                        _inputDecoration(theme, hint: "ornek@email.com"),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen e-posta adresinizi girin.';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Lütfen geçerli bir e-posta girin.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildLabel("Mesajınız", theme),
                  TextFormField(
                    controller: messageController,
                    maxLines: 5,
                    style: TextStyle(color: theme.textColor),
                    decoration: _inputDecoration(theme, hint: "Mesajınız..."),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen mesajınızı yazın.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isSending
                          ? null
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                setState(() => isSending = true);

                                bool success =
                                    await _apiService.sendContactMessage(
                                  name: nameController.text,
                                  email: emailController.text,
                                  message: messageController.text,
                                  reason: selectedReason,
                                );

                                if (context.mounted) {
                                  setState(() => isSending = false);
                                  if (success) Navigator.pop(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success
                                          ? 'Mesajınız başarıyla iletildi.'
                                          : 'Mesaj gönderilirken bir hata oluştu.'),
                                      backgroundColor: success
                                          ? Colors.green
                                          : Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isSending
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Mesajı Gönder",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: theme.textColor.withOpacity(0.7),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(AppTheme theme, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: theme.subTextColor.withOpacity(0.5)),
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.textColor.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.accentColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.15), width: 1.0),
            ),
            child: Icon(Icons.tune_rounded,
                color: Colors.white.withOpacity(0.6), size: 22),
          ),
          onPressed: () {
            _showSettingsPanel(context, theme);
          },
        );
      },
    );
  }

  void _showSettingsPanel(BuildContext context, AppTheme theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5)
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.textColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              // Sleep Timer Section
              ValueListenableBuilder<int>(
                valueListenable: Degiskenler.sleepTimerRemainingNotifier,
                builder: (context, remainingTime, _) {
                  String statusText = remainingTime > 0
                      ? "${remainingTime ~/ 60}:${(remainingTime % 60).toString().padLeft(2, '0')}"
                      : "";

                  return _buildSettingSection(
                    theme,
                    "Zamanlayıcı",
                    Icons.timer_outlined,
                    Row(
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            color: remainingTime > 0
                                ? theme.accentColor
                                : theme.subTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (remainingTime > 0)
                          IconButton(
                            onPressed: () => AudioService.cancelSleepTimer(),
                            icon: const Icon(Icons.cancel_outlined,
                                color: Colors.redAccent),
                          ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.accentColor.withOpacity(0.2),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () =>
                              _showSleepTimerDialog(context, theme),
                          child: Text("Ayarla",
                              style: TextStyle(
                                  color: theme.accentColor,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Sync Section
              ValueListenableBuilder<bool>(
                valueListenable: Degiskenler.isSyncedNotifier,
                builder: (context, isSynced, _) {
                  return _buildSettingSection(
                    theme,
                    "Senkronizasyon",
                    isSynced
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    InkWell(
                      onTap: isSynced ? null : () => SyncDialog.show(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          Text(
                            isSynced ? "Bağlı" : "Bağlı Değil",
                            style: TextStyle(
                              color: isSynced
                                  ? Colors.greenAccent
                                  : theme.subTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (isSynced)
                            TextButton.icon(
                              onPressed: () =>
                                  _showLogoutDialog(context, theme),
                              icon: const Icon(Icons.logout_rounded,
                                  color: Colors.redAccent, size: 18),
                              label: const Text("Bağlantıyı Sırla",
                                  style: TextStyle(color: Colors.redAccent)),
                            )
                          else
                            Icon(Icons.arrow_forward_ios_rounded,
                                color: theme.accentColor, size: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Contact Section
              GestureDetector(
                onTap: () => _showContactForm(context, theme),
                child: _buildSettingSection(
                  theme,
                  "İrtibat",
                  Icons.chat_bubble_outline_rounded,
                  Row(
                    children: [
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: theme.accentColor, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Theme Section
              _buildSettingSection(
                theme,
                "Uygulama Teması",
                Icons.palette_outlined,
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppTheme.themes.map((t) {
                    bool isSelected = theme.name == t.name;
                    return GestureDetector(
                      onTap: () {
                        Degiskenler.currentThemeNotifier.value = t;
                        Degiskenler.saveTheme(t);
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: t.backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? t.accentColor
                                : theme.textColor.withOpacity(0.1),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: t.accentColor.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  )
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.name,
                              style: TextStyle(
                                color: t.accentColor,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.check_circle_rounded,
                                  color: t.accentColor, size: 16),
                            ]
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 48),
              Text(
                "Âteş-i Aşk",
                style: TextStyle(
                    color: theme.subTextColor.withOpacity(0.5), fontSize: 12),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingSection(
      AppTheme theme, String title, IconData icon, Widget content) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.accentColor, size: 20),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: theme.textColor.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          content,
        ],
      ),
    );
  }
}
