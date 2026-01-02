import 'package:flutter/material.dart';

class ImageHelper {
  
  static const String coverKuhp = 'assets/images/kuhp.jpg';
  static const String coverKuhap = 'assets/images/kuhap.jpg';
  static const String coverUuIte = 'assets/images/uuite.jpg';
  static const String coverKuhper = 'assets/images/kkkk.jpg';
  static const String coverDefault = 'assets/images/logo.png'; 

  static String getCover(String kodeUU) {
    final code = kodeUU.toUpperCase().trim();
    
    if (code == 'KUHP') return coverKuhp; 
    if (code.contains('KUHAP')) return coverKuhap;
    if (code.contains('ITE')) return coverUuIte;
    if (code.contains('KUHPER') || code.contains('PERDATA')) return coverKuhper;
    
    return coverDefault;
  }

  static Color getBookColor(String kodeUU) {
    final code = kodeUU.toUpperCase().trim();

    if (code.contains('KUHPER') || code.contains('PERDATA')) {
      return Colors.orange.shade800; 
    }
    if (code == 'KUHP') {
      return const Color(0xFF8B0000);
    }
    if (code.contains('KUHAP')) {
      return Colors.blue.shade800;   
    }
    if (code.contains('ITE')) {
      return Colors.green.shade800;  
    }

    return Colors.grey; 
  }
}