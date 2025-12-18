import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

// Enhanced Shift Card Widget with Modern Design
class ImprovedShiftCard extends StatefulWidget {
  final Map<String, dynamic> shift;
  final bool isCurrentShift;
  final bool isOnDuty;
  final Map<String, dynamic> statusInfo;
  final Function(String, String)? onStartTimer;

  const ImprovedShiftCard({
    required this.shift,
    required this.isCurrentShift,
    required this.isOnDuty,
    required this.statusInfo,
    this.onStartTimer,
  });

  @override
  State<ImprovedShiftCard> createState() => _ImprovedShiftCardState();
}

class _ImprovedShiftCardState extends State<ImprovedShiftCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Duration _remaining = Duration.zero;
  double _progress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    // Start timer if active shift
    if (widget.isCurrentShift && widget.isOnDuty) {
      _startShiftTimer(
        widget.shift['startTime'] ?? '06:00',
        widget.shift['endTime'] ?? '14:00',
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startShiftTimer(String start, String end) {
    try {
      final now = TimeOfDay.now();
      final startTime = TimeOfDay(
        hour: int.parse(start.split(":")[0]),
        minute: int.parse(start.split(":")[1]),
      );
      final endTime = TimeOfDay(
        hour: int.parse(end.split(":")[0]),
        minute: int.parse(end.split(":")[1]),
      );

      final nowMinutes = now.hour * 60 + now.minute;
      final startMinutes = startTime.hour * 60 + startTime.minute;
      final endMinutes = endTime.hour * 60 + endTime.minute;

      final total = endMinutes - startMinutes;
      final elapsed = nowMinutes - startMinutes;

      if (elapsed < 0 || elapsed > total) return;

      setState(() {
        _remaining = Duration(minutes: total - elapsed);
        _progress = elapsed / total;
      });

      _timer?.cancel();
      _timer = Timer.periodic(Duration(seconds: 1), (_) {
        setState(() {
          if (_remaining.inSeconds > 0) {
            _remaining -= Duration(seconds: 1);
            _progress += 1 / (total * 60);
          }
        });
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final shiftTime = widget.shift['shiftTime'] ?? 'N/A';
    final shiftDate = widget.shift['shiftDate'] ?? '';
    final startTime = widget.shift['startTime'] ?? '06:00';
    final endTime = widget.shift['endTime'] ?? '14:00';
    final isExcused = widget.shift['isExcused'] ?? false;
    final isOffShift = shiftTime.toString().toUpperCase() == 'OFF';
    final isActiveShift = widget.isCurrentShift && widget.isOnDuty;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0)
          .animate(_animationController),
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)
            .animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        )),
        child: Container(
          margin: EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            gradient: _buildGradient(isActiveShift),
            color: _buildBackgroundColor(isActiveShift),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _buildBorderColor(isActiveShift),
              width: isActiveShift ? 2.0 : 1.2,
            ),
            boxShadow: _buildBoxShadow(isActiveShift),
          ),
          child: Stack(
            children: [
              // DECORATIVE BACKGROUND ELEMENT
              if (isActiveShift)
                Positioned(
                  top: -40,
                  right: -40,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withOpacity(0.08),
                    ),
                  ),
                ),

              // ACTIVE SHIFT BADGE
              if (isActiveShift)
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildActiveBadge(),
                ),

              // MAIN CONTENT
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    // HEADER ROW
                    _buildHeaderRow(
                      shiftTime,
                      shiftDate,
                      isActiveShift,
                      isOffShift,
                      isExcused,
                    ),

                    SizedBox(height: 18),

                    // TIMER AND TIME RANGE
                    if (isActiveShift)
                      _buildActiveShiftLayout(startTime, endTime)
                    else
                      _buildInactiveShiftLayout(startTime, endTime),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(
      String shiftTime,
      String shiftDate,
      bool isActiveShift,
      bool isOffShift,
      bool isExcused,
      ) {
    return Row(
      children: [
        // ICON CONTAINER
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.statusInfo['accentColor'].withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            widget.statusInfo['icon'],
            color: widget.statusInfo['accentColor'],
            size: 22,
          ),
        ),
        SizedBox(width: 14),

        // SHIFT DETAILS
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shiftTime,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1F36),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  _buildStatusBadge(),
                ],
              ),
              SizedBox(height: 6),
              Text(
                shiftDate,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFB0B8C8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: widget.statusInfo['badgeColor'].withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.statusInfo['badgeColor'].withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Text(
        widget.statusInfo['statusText'] ?? 'Scheduled',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: widget.statusInfo['badgeColor'],
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildActiveBadge() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade600.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 1,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flash_on_rounded, color: Colors.white, size: 15),
            SizedBox(width: 6),
            Text(
              "ON DUTY NOW",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveShiftLayout(String startTime, String endTime) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$startTime - $endTime",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 6),
              Text(
                "Active shift in progress",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFB0B8C8),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 16),
        _buildModernCircularTimer(),
      ],
    );
  }

  Widget _buildInactiveShiftLayout(String startTime, String endTime) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(0xFFFAFBFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Color(0xFFE8EAEF),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 18,
            color: Color(0xFFB0B8C8),
          ),
          SizedBox(width: 10),
          Text(
            '$startTime - $endTime',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1F36),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCircularTimer() {
    final hours = _remaining.inHours.toString().padLeft(2, '0');
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.shade50,
              border: Border.all(
                color: Color(0xFFE8EAEF),
                width: 1.5,
              ),
            ),
          ),

          // Animated progress indicator
          RotationTransition(
            turns: Tween<double>(begin: 0, end: 1).animate(_animationController),
            child: CircularProgressIndicator(
              value: _progress.clamp(0.0, 1.0),
              strokeWidth: 7,
              backgroundColor: Color(0xFFE8EAEF),
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.green.shade600,
              ),
            ),
          ),

          // Timer text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "$hours:$minutes:$seconds",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.green.shade700,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "remaining",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFB0B8C8),
                ),
              ),
            ],
          ),

          // Decorative checkmark (optional)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: Color(0xFFE8EAEF),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 16,
                color: Color(0xFFB0B8C8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Gradient? _buildGradient(bool isActiveShift) {
    if (!isActiveShift) return null;
    return LinearGradient(
      colors: [
        Colors.green.shade50.withOpacity(0.6),
        Colors.white.withOpacity(0.3),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color? _buildBackgroundColor(bool isActiveShift) {
    if (isActiveShift) return null;
    return Color(0xFFFBFCFE);
  }

  Color _buildBorderColor(bool isActiveShift) {
    if (isActiveShift) return Colors.green.shade400;
    return Color(0xFFE8EAEF);
  }

  List<BoxShadow> _buildBoxShadow(bool isActiveShift) {
    if (!isActiveShift) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];
    }

    return [
      BoxShadow(
        color: Colors.green.shade200.withOpacity(0.35),
        blurRadius: 20,
        spreadRadius: 0,
        offset: Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.green.shade100.withOpacity(0.2),
        blurRadius: 40,
        spreadRadius: 4,
        offset: Offset(0, 12),
      ),
    ];
  }
}