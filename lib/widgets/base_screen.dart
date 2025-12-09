import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:incident_reporting_frontend/providers/theme_provider.dart';
import 'package:incident_reporting_frontend/services/notifications_service.dart';
import 'package:incident_reporting_frontend/screens/notifications_screen.dart';
import 'package:incident_reporting_frontend/theme/app_theme.dart';

class BaseScreen extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool showNotifications;
  final bool showThemeToggle;
  final Color? backgroundColor;
  final bool useSafeArea;

  const BaseScreen({
    Key? key,
    required this.title,
    required this.child,
    this.actions,
    this.showBackButton = true,
    this.showNotifications = true,
    this.showThemeToggle = true,
    this.backgroundColor,
    this.useSafeArea = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final content = useSafeArea
        ? SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spaceM),
        child: child,
      ),
    )
        : child;

    return Scaffold(
      backgroundColor: backgroundColor ?? AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        leading: showBackButton
            ? IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          color: Theme.of(context).iconTheme.color,
        )
            : null,
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (showThemeToggle) _buildThemeToggle(context),
          if (showNotifications) _buildNotificationIcon(context),
          ...?actions,
        ],
      ),
      body: content,
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return IconButton(
          icon: Icon(
            themeProvider.isDarkMode
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => themeProvider.toggleTheme(),
          tooltip: themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
        );
      },
    );
  }

  Widget _buildNotificationIcon(BuildContext context) {
    return Consumer<NotificationsService>(
      builder: (context, notificationsService, _) {
        return Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_rounded,
                color: Theme.of(context).iconTheme.color,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NotificationsScreen()),
                );
              },
              tooltip: 'Notifications',
            ),
            if (notificationsService.unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    notificationsService.unreadCount > 99
                        ? '99+'
                        : '${notificationsService.unreadCount}',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}