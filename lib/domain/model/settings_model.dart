class AppSettings {
  bool isNotifyEnabled;
  bool isSyncEnabled;
  bool isBackupEnabled;
  String language;

  AppSettings({
    this.isNotifyEnabled = true,
    this.isSyncEnabled = true,
    this.isBackupEnabled = false,
    this.language = 'Tiếng Việt',
  });
}
