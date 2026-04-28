import 'package:flutter/material.dart';
import 'package:app/utils/colors.dart';

class CustomRefreshScroll extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const CustomRefreshScroll({
    Key? key,
    required this.child,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primaryColor,
      onRefresh: onRefresh,
      child: child,
    );
  }
}
