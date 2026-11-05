import 'package:flutter/material.dart';

import '../models/stat_metric.dart';
import 'app_colors.dart';

/// Every stat keeps the same color everywhere in the app.
extension StatMetricColors on StatMetric {
  Color get color => switch (this) {
        StatMetric.steps => AppColors.primary,
        StatMetric.sleep => AppColors.blue,
        StatMetric.workout => AppColors.orange,
        StatMetric.calories => AppColors.red,
        StatMetric.screenTime => AppColors.purple,
      };

  /// Darker partner for 3D edges.
  Color get edgeColor => switch (this) {
        StatMetric.steps => AppColors.primaryDark,
        StatMetric.sleep => AppColors.blueDark,
        StatMetric.workout => AppColors.orangeDark,
        StatMetric.calories => AppColors.redDark,
        StatMetric.screenTime => AppColors.purpleDark,
      };
}
