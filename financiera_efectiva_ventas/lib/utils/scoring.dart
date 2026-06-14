import 'package:flutter/material.dart';

import '../config/theme.dart';

String classifyFinal(double score, bool veto) {
  if (veto) return 'NO APLICA';
  if (score >= 750) return 'PREMIER';
  if (score >= 550) return 'ESTANDAR';
  if (score >= 350) return 'BASICO';
  return 'NO APLICA';
}

Color segmentColor(String segment) {
  return switch (segment) {
    'PREMIER' => AppTheme.brandBlue,
    'ESTANDAR' => AppTheme.brandNavy,
    'BASICO' => AppTheme.brandGold,
    'Bajo' => Colors.green,
    'Medio' => AppTheme.brandGold,
    'Alto' => AppTheme.brandCoral,
    'Rechazo automatico' => AppTheme.brandCoral,
    _ => AppTheme.brandCoral,
  };
}
