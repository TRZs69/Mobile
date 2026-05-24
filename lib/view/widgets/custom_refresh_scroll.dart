import 'package:flutter/material.dart';
import 'package:app/utils/colors.dart';

class CustomRefreshScroll extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const CustomRefreshScroll({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primaryColor,
      onRefresh: onRefresh,
      child: child,
    );
  }
}
