import 'package:flutter/material.dart';
import '../yaveran/Degiskenler.dart';
import '../yaveran/MusicApiService.dart';

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
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
              const SizedBox(height: 24),
              Text(
                "Ayarlar",
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 32),

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
                        Navigator.pop(context); // Close the settings menu
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: t.backgroundColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? t.accentColor : theme.textColor.withOpacity(0.1),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: t.accentColor.withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 2)
                                ]
                              : [],
                        ),
                        child: isSelected
                            ? Icon(Icons.check_circle_rounded, color: t.accentColor, size: 24)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // Sync Section
              ValueListenableBuilder<bool>(
                valueListenable: Degiskenler.isSyncedNotifier,
                builder: (context, isSynced, _) {
                  return _buildSettingSection(
                    theme,
                    "Senkronizasyon",
                    isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    Row(
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
                            onPressed: () => _showLogoutDialog(context, theme),
                            icon: const Icon(Icons.logout_rounded,
                                color: Colors.redAccent, size: 18),
                            label: const Text("Bağlantıyı Sırla",
                                style: TextStyle(color: Colors.redAccent)),
                          )
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),
              Text(
                "Ateş-i Aşk",
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
