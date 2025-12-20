import 'package:flutter/material.dart';

class ImageHelper {
  static String getCover(String kodeUU) {
    final kode = kodeUU.toUpperCase();

    if (kode.contains("KUHP") && !kode.contains("PERDATA") && !kode.contains("ACARA")) {
      return "assets/images/kuhp.jpg"; 
    }
    if (kode.contains("PERDATA") || kode.contains("KUHPER")) {
      return "assets/images/kkkk.jpg";
    }
    if (kode.contains("KUHAP")) {
      return "assets/images/kuhap.jpg";
    }
    if (kode.contains("ITE")) {
      return "assets/images/uuite.jpg";
    }
    
    return "assets/images/book_placeholder.jpg"; 
  }

  static Color getBookColor(String kodeUU) {
    final kode = kodeUU.toUpperCase();
    
    if (kode.contains("KUHP") && !kode.contains("PERDATA")) return const Color(0xFFB71C1C); 
    if (kode.contains("PERDATA")) return const Color(0xFF1B5E20); 
    if (kode.contains("ITE")) return const Color(0xFF0D47A1); 
    if (kode.contains("KUHAP")) return const Color(0xFFE65100);
    
    return Colors.blueGrey; 
  }
}