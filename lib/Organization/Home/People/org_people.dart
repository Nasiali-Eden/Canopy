import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';

/// ====================== MAIN SCREEN ======================
class OrgPeopleScreen extends StatefulWidget {
  const OrgPeopleScreen({super.key});

  @override
  State<OrgPeopleScreen> createState() => _OrgPeopleScreenState();
}

class _OrgPeopleScreenState extends State<OrgPeopleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGreen.withOpacity(0.08),
      appBar: AppBar(
        title: const Text('People'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.darkGreen,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.darkGreen,
          unselectedLabelColor: AppTheme.darkGreen.withOpacity(0.6),
          indicatorColor: AppTheme.tertiary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Team'),
            Tab(text: 'Volunteers'),
            Tab(text: 'Members'),
            Tab(text: 'Facilitators'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search people...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  onPressed: () => _showInviteSheet(context),
                  backgroundColor: AppTheme.tertiary,
                  child: const Icon(Icons.person_add, color: Colors.white),
                ),
              ],
            ),
          ),

          // Quick Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _PeopleStat(value: '18', label: 'Team'),
                _PeopleStat(value: '142', label: 'Volunteers'),
                _PeopleStat(value: '874', label: 'Members'),
                _PeopleStat(value: '24', label: 'Facilitators'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _PeopleListTab(title: "Core Team", type: PeopleType.team),
                _PeopleListTab(title: "Active Volunteers", type: PeopleType.volunteers),
                _PeopleListTab(title: "Community Members", type: PeopleType.members),
                _PeopleListTab(title: "Facilitators & Mentors", type: PeopleType.facilitators),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInviteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _InvitePeopleSheet(),
    );
  }
}

// ====================== DATA MODEL ======================
enum PeopleType { team, volunteers, members, facilitators }

class PersonData {
  final String name;
  final String role;
  final String? avatarUrl;
  final bool isVerified;
  final String? status;
  final List<String> services;

  PersonData({
    required this.name,
    required this.role,
    this.avatarUrl,
    this.isVerified = false,
    this.status,
    this.services = const [],
  });
}

// ====================== REUSABLE WIDGETS ======================

class _PeopleStat extends StatelessWidget {
  final String value;
  final String label;

  const _PeopleStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkGreen,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.darkGreen.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PeopleListTab extends StatelessWidget {
  final String title;
  final PeopleType type;

  const _PeopleListTab({super.key, required this.title, required this.type});

  @override
  Widget build(BuildContext context) {
    // Example data — replace with Firestore StreamBuilder later
    final List<PersonData> sampleData = _getSampleData(type);

    if (sampleData.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No $title yet", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text("Invite people to get started",
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: sampleData.length,
      itemBuilder: (context, index) {
        return PersonCard(
          data: sampleData[index],
          showStatus: type == PeopleType.volunteers,
          onTap: () {
            // TODO: Navigate to detailed person profile
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Opened ${sampleData[index].name}')),
            );
          },
        );
      },
    );
  }

  List<PersonData> _getSampleData(PeopleType type) {
    switch (type) {
      case PeopleType.team:
        return [
          PersonData(
            name: "Mary Wanjiku",
            role: "Founder & Director",
            isVerified: true,
            services: ["Mentorship", "Strategy"],
          ),
          PersonData(
            name: "John Kamau",
            role: "Field Coordinator",
            isVerified: true,
            services: ["Cleanup Drives", "Tree Planting"],
          ),
        ];
      case PeopleType.volunteers:
        return [
          PersonData(
            name: "Aisha Njeri",
            role: "Volunteer • 48 hrs this month",
            status: "Active",
            services: ["Cleanup"],
          ),
          PersonData(
            name: "Kevin Ochieng",
            role: "Volunteer • 12 hrs",
            status: "Active",
            services: ["Tree Planting"],
          ),
        ];
      default:
        return [];
    }
  }
}

// ====================== PERSON CARD ======================
class PersonCard extends StatelessWidget {
  final PersonData data;
  final bool showStatus;
  final VoidCallback? onTap;

  const PersonCard({
    super.key,
    required this.data,
    this.showStatus = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
              backgroundImage: data.avatarUrl != null
                  ? NetworkImage(data.avatarUrl!)
                  : null,
              child: data.avatarUrl == null
                  ? Text(
                data.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join(''),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGreen,
                  fontSize: 18,
                ),
              )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (data.isVerified)
                        const Icon(Icons.verified, color: AppTheme.tertiary, size: 18),
                    ],
                  ),
                  Text(
                    data.role,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.darkGreen.withOpacity(0.75),
                    ),
                  ),
                  if (data.services.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: data.services
                          .map((service) => Chip(
                        label: Text(
                          service,
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: AppTheme.lightGreen.withOpacity(0.15),
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                          .toList(),
                    ),
                ],
              ),
            ),
            if (showStatus && data.status != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.tertiary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data.status!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.tertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ====================== INVITE SHEET ======================
class _InvitePeopleSheet extends StatelessWidget {
  const _InvitePeopleSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite Someone',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Phone number or Canopy username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Role / Position',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invitation sent!')),
                );
              },
              child: const Text('Send Invitation'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}