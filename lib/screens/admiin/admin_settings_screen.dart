import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:incident_reporting_frontend/theme/app_theme.dart';

import '../agency/agency_management_screen.dart';
import '../department/department_management_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _selectedTab = 0; // 0: Organization, 1: System, 2: Policies

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Tab Navigation
            _buildTabNavigation(),

            // Content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // HEADER
  // ============================================================================

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Settings',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Manage system configuration',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'ROOT',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB NAVIGATION
  // ============================================================================

  Widget _buildTabNavigation() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          _buildTabButton(
            label: 'Organization',
            icon: Icons.domain_rounded,
            isSelected: _selectedTab == 0,
            onTap: () => setState(() => _selectedTab = 0),
          ),
          SizedBox(width: 12),
          _buildTabButton(
            label: 'System',
            icon: Icons.settings_rounded,
            isSelected: _selectedTab == 1,
            onTap: () => setState(() => _selectedTab = 1),
          ),
          SizedBox(width: 12),
          _buildTabButton(
            label: 'Policies',
            icon: Icons.policy_rounded,
            isSelected: _selectedTab == 2,
            onTap: () => setState(() => _selectedTab = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Color(0xFF2E5BFF) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Color(0xFF2E5BFF) : Color(0xFF8F9BB3),
                size: 20,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Color(0xFF2E5BFF) : Color(0xFF8F9BB3),
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // CONTENT
  // ============================================================================

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return _buildOrganizationTab();
      case 1:
        return _buildSystemTab();
      case 2:
        return _buildPoliciesTab();
      default:
        return _buildOrganizationTab();
    }
  }

  // ============================================================================
  // ORGANIZATION TAB - Agency & Department Management
  // ============================================================================

  Widget _buildOrganizationTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Organization Overview Card
          _buildSectionCard(
            title: 'Organization Structure',
            subtitle: 'Manage agencies and departments',
            items: [
              _buildSectionItem(
                icon: Icons.business_rounded,
                title: 'Agencies',
                description: 'Create and manage law enforcement agencies',
                color: Color(0xFF2E5BFF),
                actionIcon: Icons.arrow_forward_ios_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AgencyManagementScreen()),
                ),
              ),
              _buildSectionItem(
                icon: Icons.domain_rounded,
                title: 'Departments',
                description: 'Create and organize departments within agencies',
                color: Color(0xFF667EEA),
                actionIcon: Icons.arrow_forward_ios_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DepartmentManagementScreen()),
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Organizational Hierarchy Card
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFFE4E9F2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFB75E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.account_tree_rounded,
                        color: Color(0xFFFFB75E),
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Organization Hierarchy',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1F36),
                            ),
                          ),
                          Text(
                            'System structure overview',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Color(0xFF8F9BB3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Hierarchy visualization
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _buildHierarchyLevel('Root Admin', 'System Administrator', 1),
                      Container(
                        width: 2,
                        height: 8,
                        color: Color(0xFFE4E9F2),
                      ),
                      _buildHierarchyLevel('Agencies', 'Multiple agencies', 2),
                      Container(
                        width: 2,
                        height: 8,
                        color: Color(0xFFE4E9F2),
                      ),
                      _buildHierarchyLevel('Departments', 'Within each agency', 2),
                      Container(
                        width: 2,
                        height: 8,
                        color: Color(0xFFE4E9F2),
                      ),
                      _buildHierarchyLevel('Police Stations', 'Operational units', 2),
                      Container(
                        width: 2,
                        height: 8,
                        color: Color(0xFFE4E9F2),
                      ),
                      _buildHierarchyLevel('Police Officers', 'Active personnel', 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyLevel(String title, String subtitle, int level) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: level * 16.0),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF2E5BFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF2E5BFF),
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Color(0xFF8F9BB3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SYSTEM TAB - General Settings
  // ============================================================================

  Widget _buildSystemTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Information
          _buildSectionCard(
            title: 'System Information',
            subtitle: 'General system settings',
            items: [
              _buildSettingItem(
                icon: Icons.info_rounded,
                title: 'System Version',
                value: 'v1.0.0',
              ),
              _buildSettingItem(
                icon: Icons.storage_rounded,
                title: 'Database Status',
                value: 'Connected',
                valueColor: AppTheme.successGreen,
              ),
              _buildSettingItem(
                icon: Icons.cloud_rounded,
                title: 'API Status',
                value: 'Active',
                valueColor: AppTheme.successGreen,
              ),
            ],
          ),

          SizedBox(height: 24),

          // Security Settings
          _buildSectionCard(
            title: 'Security',
            subtitle: 'Manage system security',
            items: [
              _buildToggleItem(
                icon: Icons.security_rounded,
                title: 'Two-Factor Authentication',
                description: 'Require 2FA for all admin accounts',
              ),
              _buildToggleItem(
                icon: Icons.vpn_lock_rounded,
                title: 'HTTPS Only',
                description: 'Enforce secure connections',
                isEnabled: true,
              ),
              _buildToggleItem(
                icon: Icons.verified_user_rounded,
                title: 'Activity Logging',
                description: 'Log all admin activities',
                isEnabled: true,
              ),
            ],
          ),

          SizedBox(height: 24),

          // Maintenance
          _buildMaintenanceCard(),
        ],
      ),
    );
  }

  // ============================================================================
  // POLICIES TAB
  // ============================================================================

  Widget _buildPoliciesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Policies
          _buildSectionCard(
            title: 'User Policies',
            subtitle: 'Manage user-related policies',
            items: [
              _buildPolicyItem(
                icon: Icons.person_add_rounded,
                title: 'User Registration',
                description: 'Public registration: Enabled',
                status: 'Active',
              ),
              _buildPolicyItem(
                icon: Icons.lock_clock_rounded,
                title: 'Password Policy',
                description: 'Minimum 8 characters required',
                status: 'Active',
              ),
              _buildPolicyItem(
                icon: Icons.timer_rounded,
                title: 'Session Timeout',
                description: 'Auto-logout after 30 minutes',
                status: 'Active',
              ),
            ],
          ),

          SizedBox(height: 24),

          // Incident Policies
          _buildSectionCard(
            title: 'Incident Policies',
            subtitle: 'Configure incident handling',
            items: [
              _buildPolicyItem(
                icon: Icons.warning_rounded,
                title: 'Incident Categories',
                description: '8 categories configured',
                status: 'Configured',
              ),
              _buildPolicyItem(
                icon: Icons.schedule_rounded,
                title: 'SLA Settings',
                description: 'Response time: 4 hours',
                status: 'Active',
              ),
              _buildPolicyItem(
                icon: Icons.accessibility_rounded,
                title: 'Accessibility',
                description: 'Citizens can report anonymously',
                status: 'Enabled',
              ),
            ],
          ),

          SizedBox(height: 24),

          // Audit Logs Card
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFFE4E9F2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xFF51CF66).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: Color(0xFF51CF66),
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audit Logs',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1F36),
                            ),
                          ),
                          Text(
                            'View all system activities',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Color(0xFF8F9BB3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Color(0xFF8F9BB3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPER WIDGETS
  // ============================================================================

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF2E5BFF).withOpacity(0.05),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1F36),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Color(0xFF8F9BB3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Items
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            return Column(
              children: [
                entry.value,
                if (!isLast)
                  Divider(height: 1, indent: 16, endIndent: 16),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSectionItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required IconData actionIcon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1F36),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Color(0xFF8F9BB3),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(actionIcon, size: 16, color: Color(0xFF8F9BB3)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFF2E5BFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Color(0xFF2E5BFF), size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1F36),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (valueColor ?? Color(0xFF2E5BFF)).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: valueColor ?? Color(0xFF2E5BFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String description,
    bool isEnabled = false,
  }) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppTheme.successGreen.withOpacity(0.1)
                  : Color(0xFF8F9BB3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isEnabled ? AppTheme.successGreen : Color(0xFF8F9BB3),
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Color(0xFF8F9BB3),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 28,
            decoration: BoxDecoration(
              color: isEnabled ? AppTheme.successGreen : Color(0xFFE4E9F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyItem({
    required IconData icon,
    required String title,
    required String description,
    required String status,
  }) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFF667EEA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Color(0xFF667EEA), size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Color(0xFF8F9BB3),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.successGreen.withOpacity(0.3),
              ),
            ),
            child: Text(
              status,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.successGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFFFE69C)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFFFFB75E).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.construction_rounded,
              color: Color(0xFFFFB75E),
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Maintenance Mode',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF856404),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Schedule system maintenance window',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Color(0xFF856404).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Color(0xFF856404),
          ),
        ],
      ),
    );
  }
}