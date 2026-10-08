import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai_service.dart';

// gives every screen the same AiService instance
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService();
});
