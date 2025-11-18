import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatBadgeButton extends StatelessWidget {
  final VoidCallback onTap;
  final int unreadCount;
  final bool isExpanded;

  const ChatBadgeButton({
    Key? key,
    required this.onTap,
    required this.unreadCount,
    this.isExpanded = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isExpanded ? 16 : 12,
            vertical: isExpanded ? 14 : 10
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF2E5BFF).withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_rounded, size: 16, color: Colors.white),
            SizedBox(width: 8),

            if (isExpanded) ...[
              Text(
                'Open Chat & Send Media',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Spacer(),
            ] else ...[
              Text(
                'Chat',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 6),
            ],

            // UNREAD BADGE
            if (unreadCount > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E5BFF),
                  ),
                ),
              ),

            if (isExpanded)
              Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}