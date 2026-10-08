import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/export_service.dart';

// gives every screen the same ExportService instance
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});
