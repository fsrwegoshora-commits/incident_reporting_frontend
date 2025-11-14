import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/notifications_service.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationsService _notificationsService;
  String _selectedFilter = 'ALL'; // ALL, UNREAD, INCIDENTS, CHATS, SHIFTS

  @override
  void initState() {
    super.initState();
    _notificationsService = Provider.of<NotificationsService>(context, listen: false);
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    await _notificationsService.fetchNotifications();
  }

  Future<void> _refreshNotifications() async {
    await _notificationsService.refresh();
  }

  void _handleNotificationTap(NotificationModel notification) async {
    // Mark as read
    await _notificationsService.markAsRead(notification.uid);

    // Navigate based on type
    if (mounted) {
      switch (notification.type.toUpperCase()) {
        case 'INCIDENT_REPORTED':
        case 'INCIDENT_ASSIGNED':
        case 'INCIDENT_RESOLVED':
          if (notification.relatedEntityUid != null) {
            // Navigate to incident details if route exists
            // For now, just show a snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Incident details: ${notification.relatedEntityUid}')),
            );
          }
          break;
        case 'CHAT_MESSAGE':
          if (notification.relatedEntityUid != null) {
            // Navigate to chat if route exists
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Chat: ${notification.relatedEntityUid}')),
            );
          }
          break;
        case 'SHIFT_ASSIGNED':
        case 'SHIFT_REASSIGNED':
          // Navigate to shifts screen if route exists
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Check your shifts')),
          );
          break;
        default:
          break;
      }
    }
  }

  List<NotificationModel> _getFilteredNotifications() {
    final notifications = _notificationsService.notifications;

    switch (_selectedFilter) {
      case 'UNREAD':
        return notifications.where((n) => !n.isRead).toList();
      case 'INCIDENTS':
        return notifications.where((n) {
          final type = n.type.toUpperCase();
          return type.contains('INCIDENT');
        }).toList();
      case 'CHATS':
        return notifications.where((n) => n.type.toUpperCase() == 'CHAT_MESSAGE').toList();
      case 'SHIFTS':
        return notifications.where((n) {
          final type = n.type.toUpperCase();
          return type.contains('SHIFT');
        }).toList();
      default:
        return notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: Consumer<NotificationsService>(
        builder: (context, service, _) {
          if (service.isLoading && service.notifications.isEmpty) {
            return _buildLoadingState();
          }

          final filteredNotifications = _getFilteredNotifications();

          if (filteredNotifications.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _refreshNotifications,
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: filteredNotifications.length,
              itemBuilder: (context, index) {
                final notification = filteredNotifications[index];
                return _buildNotificationCard(notification);
              },
            ),
          );
        },
      ),
    );
  }

  // ============================================================================
  // APP BAR
  // ============================================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: Text(
        'Notifications',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1F36),
        ),
      ),
      actions: [
        Consumer<NotificationsService>(
          builder: (context, service, _) {
            if (service.unreadCount == 0) return SizedBox(width: 16);

            return Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFFF6B6B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${service.unreadCount}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================================
  // FILTER CHIPS
  // ============================================================================

  Widget _buildFilterChips() {
    final filters = ['ALL', 'UNREAD', 'INCIDENTS', 'CHATS', 'SHIFTS'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                filter,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Color(0xFF8F9BB3),
                ),
              ),
              backgroundColor: Colors.white,
              selectedColor: Color(0xFF2E5BFF),
              side: BorderSide(
                color: isSelected ? Color(0xFF2E5BFF) : Color(0xFFE8EBF0),
              ),
              onSelected: (selected) {
                setState(() => _selectedFilter = filter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================================
  // NOTIFICATION CARD
  // ============================================================================

  Widget _buildNotificationCard(NotificationModel notification) {
    final dateFormatter = DateFormat('MMM dd, HH:mm');
    final formattedDate = dateFormatter.format(notification.sentAt);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? Color(0xFFE8EBF0) : Color(0xFF2E5BFF).withOpacity(0.3),
        ),
        boxShadow: notification.isRead
            ? []
            : [
          BoxShadow(
            color: Color(0xFF2E5BFF).withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with icon, title, and timestamp
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: notification.getTypeColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        notification.getTypeIcon(),
                        color: notification.getTypeColor(),
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),

                    // Title and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title with unread indicator
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
                                    color: Color(0xFF1A1F36),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF2E5BFF),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 4),

                          // Type label
                          Text(
                            notification.getTypeLabel(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Color(0xFF8F9BB3),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Timestamp
                    Text(
                      formattedDate,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Color(0xFFA8B3C1),
                      ),
                    ),
                  ],
                ),

                // Message (if available)
                if (notification.message != null && notification.message!.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Text(
                    notification.message!,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Color(0xFF5F7285),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Action button
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleNotificationTap(notification),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: notification.getTypeColor(),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'View Details',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // LOADING STATE
  // ============================================================================

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
              ),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading notifications...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1F36),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // EMPTY STATE
  // ============================================================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Color(0xFFE8EBF0),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              size: 50,
              color: Color(0xFFA8B3C1),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Notifications',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1F36),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You\'re all caught up! Check back later.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Color(0xFF8F9BB3),
            ),
          ),
        ],
      ),
    );
  }
}