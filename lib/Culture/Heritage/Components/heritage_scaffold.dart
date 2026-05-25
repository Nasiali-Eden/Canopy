import 'package:flutter/material.dart';
import '../../../Shared/theme/app_theme.dart';
import '../heritage_theme.dart';

/// HeritageScaffold — wrapper Scaffold for Layer 4 screens
/// Sets warm background, consistent AppBar styling with tertiary accent
class HeritageScaffold extends StatelessWidget {
  final String title;
  final String? subtitle; // e.g., 'Layer 4 · Cultural Archive'
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final PreferredSizeWidget? bottomNavigationBar;

  const HeritageScaffold({
    required this.title,
    this.subtitle,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HeritageTheme.heritageBackground,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppTheme.darkGreen,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cormorant Garamond',
                fontStyle: FontStyle.italic,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    color: AppTheme.tertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: HeritageTheme.heritageBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.darkGreen,
        centerTitle: true,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
