import 'package:flutter/material.dart';
import '../yaveran/Degiskenler.dart';
import '../yaveran/app_theme.dart';
import '../yaveran/MusicApiService.dart';
import '../yaveran/audio_service.dart';
import 'sync_dialog.dart';
import '../screens/log_view_screen.dart';
import '../yaveran/log_service.dart';

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

  void _showSettingsPanel(BuildContext context, AppTheme initialTheme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ValueListenableBuilder<AppTheme>(
        valueListenable: Degiskenler.currentThemeNotifier,
        builder: (context, theme, _) => Container(
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                // Volume Section
                ValueListenableBuilder<double>(
                  valueListenable: AudioService.volumeNotifier,
                  builder: (context, volume, _) {
                    return _buildSettingSection(
                      theme,
                      "Ses Ayarları",
                      Icons.volume_up_outlined,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  volume == 0
                                      ? Icons.volume_off_rounded
                                      : volume < 0.5
                                          ? Icons.volume_down_rounded
                                          : Icons.volume_up_rounded,
                                  color: theme.accentColor,
                                ),
                                onPressed: () => AudioService.toggleMute(),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 8),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 16),
                                    activeTrackColor: theme.accentColor,
                                    inactiveTrackColor:
                                        theme.accentColor.withOpacity(0.1),
                                    thumbColor: theme.accentColor,
                                    overlayColor:
                                        theme.accentColor.withOpacity(0.2),
                                  ),
                                  child: Slider(
                                    value: volume,
                                    min: 0,
                                    max: 1,
                                    onChanged: (val) =>
                                        AudioService.setVolume(val),
                                  ),
                                ),
                              ),
                              Text(
                                "${(volume * 100).round()}%",
                                style: TextStyle(
                                  color: theme.textColor.withOpacity(0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 48.0, top: 4.0),
                            child: Text(
                              "* Bu ayar cihazın ana ses seviyesi içinde uygulama içi özel bir ses oranı belirler ve her açılışta bu seviyeyle başlar (Sessiz konum kaydedilmez).",
                              style: TextStyle(
                                color: theme.textColor.withOpacity(0.4),
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
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
                      null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (remainingTime > 0) ...[
                            Text(
                              statusText,
                              style: TextStyle(
                                color: theme.accentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            IconButton(
                              onPressed: () => AudioService.cancelSleepTimer(),
                              icon: const Icon(Icons.cancel_outlined,
                                  color: Colors.redAccent, size: 20),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  theme.accentColor.withOpacity(0.15),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () =>
                                _showSleepTimerDialog(context, theme),
                            child: Text(
                                remainingTime > 0 ? "Güncelle" : "Ayarla",
                                style: TextStyle(
                                    color: theme.accentColor,
                                    fontSize: 12,
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
                    return GestureDetector(
                      onTap: () {
                        if (!isSynced) {
                          SyncDialog.show(context);
                        }
                      },
                      child: _buildSettingSection(
                        theme,
                        "Senkronizasyon",
                        isSynced
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isSynced ? "Bağlı" : "Bağlı Değil",
                              style: TextStyle(
                                color: isSynced
                                    ? Colors.greenAccent
                                    : theme.subTextColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isSynced)
                              TextButton.icon(
                                onPressed: () =>
                                    _showLogoutDialog(context, theme),
                                icon: const Icon(Icons.logout_rounded,
                                    color: Colors.redAccent, size: 18),
                                label: const Text("Bağlantıyı Kes",
                                    style: TextStyle(
                                        color: Colors.redAccent, fontSize: 13)),
                              )
                            else
                              Icon(Icons.arrow_forward_ios_rounded,
                                  color: theme.accentColor, size: 14),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // System Logs Section
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LogViewScreen()),
                    );
                    LogService().info("Sistem logları görüntülendi", tag: "UI");
                  },
                  child: _buildSettingSection(
                    theme,
                    "Sistem Logları",
                    Icons.terminal_rounded,
                    null,
                    trailing: Icon(Icons.arrow_forward_ios_rounded,
                        color: theme.accentColor, size: 16),
                  ),
                ),

                const SizedBox(height: 24),

                const SizedBox(height: 24),

                // Theme Section
                _buildSettingSection(
                  theme,
                  "Uygulama Teması",
                  Icons.palette_outlined,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sabit Önizleme Alanı
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: theme.backgroundColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: theme.accentColor.withOpacity(0.3),
                              width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: theme.accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "${theme.name} Paleti",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Renk Blokları
                            Row(
                              children: [
                                _buildColorPreviewBlock("Zemin",
                                    theme.backgroundColor, theme.accentColor),
                                const SizedBox(width: 12),
                                _buildColorPreviewBlock(
                                    "Kart", theme.cardColor, theme.accentColor),
                                const SizedBox(width: 12),
                                _buildColorPreviewBlock(
                                    "Vurgu", theme.accentColor, Colors.white),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Örnek Kart Görünümü
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.music_note_rounded,
                                      color: theme.accentColor, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                            height: 6,
                                            width: 80,
                                            decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.7),
                                                borderRadius:
                                                    BorderRadius.circular(3))),
                                        const SizedBox(height: 4),
                                        Container(
                                            height: 4,
                                            width: 120,
                                            decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(2))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.9,
                        ),
                        itemCount: AppTheme.themes.length,
                        itemBuilder: (context, index) {
                          final t = AppTheme.themes[index];
                          bool isSelected = theme.name == t.name;
                          return GestureDetector(
                            onTap: () {
                              Degiskenler.currentThemeNotifier.value = t;
                              Degiskenler.saveTheme(t);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              alignment: Alignment.center,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: t.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? t.accentColor
                                      : Colors.white.withOpacity(0.1),
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      t.name,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 11,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Contact Section
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
      ),
    );
  }

  Widget _buildColorPreviewBlock(String label, Color color, Color accentColor) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 35,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSection(
      AppTheme theme, String title, IconData icon, Widget? content,
      {Widget? trailing}) {
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
              if (trailing != null) ...[
                Spacer(),
                trailing,
              ],
            ],
          ),
          if (content != null) ...[
            SizedBox(height: 16),
            content,
          ],
        ],
      ),
    );
  }
}
