class DBEncryption {
  // Provides secure configuration parameters for encrypted SQLite storage
  static const String cipherVersion = '4';
  static String getSecurityPragma(String key) {
    return "PRAGMA key = '$key';";
  }
}