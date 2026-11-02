class BarcodeValidator {
  static bool isValidEAN13(String barcode) {
    if (barcode.length != 13 || !RegExp(r'^[0-9]+$').hasMatch(barcode)) {
      return false;
    }

    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(barcode[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }

    int checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(barcode[12]);
  }
}