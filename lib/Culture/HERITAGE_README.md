# Culture Layer 4 — Heritage Archive Module

## Overview

The Culture module implements **Layer 4: Cultural Archive**, a distinct archival and editorial layer for organizations to preserve and manage cultural knowledge, stories, and artifacts. This module is visually and functionally separate from the Marketplace (Layer 2) and Community (Layer 3) screens.

## Design Identity

### Colour Palette
- **Background**: `Color(0xFFF5EDE0)` — warm parchment (aged paper)
- **Card Background**: `Color(0xFFFDF7F0)` — very slightly warm white
- **Primary Accent**: `AppTheme.tertiary` (gold `0xFFC4A961`)
- **Card Shadow**: Gold-tinted at 0.12 opacity (not black)
- **Body Text**: `AppTheme.darkGreen`

### Typography
- **Titles**: Serif italic (Cormorant Garamond or fallback) — archival, editorial quality
- **Body/UI**: Roboto standard (consistent with AppTheme)

## Folder Structure

```
lib/Culture/
├── culture_home.dart              # Main entry point, tabs container
├── index.dart                     # Module exports
└── Heritage/
    ├── heritage_theme.dart        # Colour constants & theme definitions
    ├── Components/
    │   ├── heritage_scaffold.dart      # Warm-themed Scaffold wrapper
    │   ├── heritage_card.dart          # Card with gold-tinted shadows
    │   ├── content_type_pill.dart      # Content type labels
    │   ├── visibility_dot.dart         # Visibility status indicator
    │   ├── heritage_tab_bar.dart       # 5-tab navigation
    │   └── index.dart                  # Component exports
    ├── Models/
    │   ├── cultural_entry.dart         # Archive entry model
    │   ├── cultural_comment.dart       # Feedback/comment model
    │   ├── cultural_relation.dart      # Entry relationship model
    │   ├── cultural_media.dart         # Image/audio media model
    │   └── index.dart                  # Model exports
    ├── Services/
    │   └── heritage_providers.dart     # Riverpod providers (Firestore)
    ├── Archive/
    │   └── heritage_archive_screen.dart # Screen 1: Entry list + filters
    ├── Feedback/
    │   └── heritage_feedback_screen.dart # Screen 2: Community feedback
    ├── Disputes/
    │   └── heritage_disputes_screen.dart # Screen 3: Council reviews
    ├── Connections/
    │   └── heritage_connections_screen.dart # Screen 4: Entry relationships
    └── Media/
        └── heritage_media_screen.dart  # Screen 5: Images & audio
```

## Five Heritage Screens

### 1. **Archive Screen** (`HeritageArchiveScreen`)
- **Purpose**: Browse and manage all cultural entries
- **Features**:
  - Summary strip (total entries, connections, comments)
  - Category filter (Stories, Food, Music, Ceremony, Craft, Place, Language, Ingredients)
  - Visibility filter (Public, Community Only, Restricted, Sealed)
  - Entry cards with cover images, metadata, and counts
  - Dispute indicator (amber left border if active)
  - FAB to add new entries
- **Data Source**: `heritageEntriesProvider` (Firestore)

### 2. **Feedback Screen** (`HeritageFeedbackScreen`)
- **Purpose**: View community feedback and suggestions on submissions
- **Features**:
  - Three tabs: All · Needs Response · Resolved
  - Comment cards showing commenter, content, action type
  - Voice tier badges (Community, Contributor, Open)
  - Reply button for engagement
  - Empty state when no feedback
- **Data Source**: `heritageCommentsListProvider` (Firestore)

### 3. **Disputes Screen** (`HeritageDisputesScreen`)
- **Purpose**: Track cultural sensitivity and accuracy disputes (private council reviews)
- **Features**:
  - Explanatory note: disputes are private until resolved
  - Status indicators by border colour:
    - Amber: Pending council review
    - Teal: Under review
    - Green: Resolved (update recommended)
    - Muted: Resolved (rejected)
  - Council recommendations with update actions
- **Data Source**: `heritageCommentsListProvider` filtered by `comment_action == 'dispute'`

### 4. **Connections Screen** (`HeritageConnectionsScreen`)
- **Purpose**: Manage relationships between entries (confirmed + suggested)
- **Features**:
  - Two tabs: Confirmed · Suggested
  - Horizontal three-section layout: entry → relationship → linked entry
  - Metadata: confirmation status, date, source
  - Suggest/endorse/dismiss actions
  - Propose connection button
- **Data Source**: `heritageRelationsProvider` (Firestore)

### 5. **Media Screen** (`HeritageMediaScreen`)
- **Purpose**: Organize images and audio across entries
- **Features**:
  - Images tab: 2-column grid with captions, entry titles, media roles
  - Audio tab: list with filename, duration, language, inline player
  - Full-screen image viewer via bottom sheet
  - Attach media to additional entries
- **Data Source**: `heritageMediaProvider` split by `media_type`

## Shared Components

### **HeritageScaffold**
Wrapper Scaffold with warm background and consistent AppBar.
```dart
HeritageScaffold(
  title: 'Archive',
  subtitle: 'Layer 4 · Cultural Archive',
  body: content,
  floatingActionButton: fab,
)
```

### **HeritageCard**
Card wrapper with warm background, gold-tinted shadows, optional left border.
```dart
HeritageCard(
  leftBorder: BorderSide(color: Colors.amber, width: 4),
  child: content,
)
```

### **ContentTypePill**
Small coloured pill identifying content type (Stories, Food, Music, etc.).
```dart
ContentTypePill(contentType: 'Stories')
// Renders with copper-amber colour (0xFFB87333)
```

### **VisibilityDot**
8×8 rounded indicator + label showing entry visibility (public, community, restricted, sealed).
```dart
VisibilityDot(visibility: 'community')
// Renders with amber dot + "Community Only" label
```

### **HeritageTabBar**
5-tab navigation: Archive · Feedback · Disputes · Connections · Media. Optional badge counts.
```dart
HeritageTabBar(
  controller: tabController,
  feedbackBadgeCount: 3,
  disputesBadgeCount: 0,
)
```

## Data Models

### **CulturalEntry**
```dart
CulturalEntry(
  id: '...',
  orgId: '...',
  title: 'Maasai Beadwork Traditions',
  contentType: 'Craft',
  subcategory: 'Beadwork',
  visibility: 'public',
  locality: 'Nairobi, Kenya',
  commentCount: 5,
  connectionCount: 2,
  hasActiveDispute: false,
)
```

### **CulturalComment**
```dart
CulturalComment(
  id: '...',
  entryId: '...',
  commenterName: 'Jane Doe',
  voiceTier: 'community_voice',
  commentAction: 'add_variation',
  hasReply: false,
)
```

### **CulturalRelation**
```dart
CulturalRelation(
  fromEntryId: '...',
  toEntryId: '...',
  relationshipType: 'inspired_by',
  status: 'suggested',
  source: 'ai',
)
```

### **CulturalMedia**
```dart
CulturalMedia(
  entryId: '...',
  mediaType: 'image',
  fileName: 'ritual_ceremony.jpg',
  mediaRole: 'hero_image',
  durationSeconds: null, // Only for audio
)
```

## State Management

Uses **Riverpod** with Firestore StreamProviders for real-time updates:

- `heritageEntriesProvider(orgId)` — all entries for an org
- `heritageCommentsProvider(entryId)` — comments for one entry
- `heritageCommentsListProvider(entryIds)` — comments for multiple entries
- `heritageRelationsProvider(entryIds)` — relationships for entries
- `heritageMediaProvider(orgId)` — all media for an org
- `orgEntryIdsProvider(orgId)` — cached list of org entry IDs

## Firestore Collections

Expected Firestore structure:

```
cultural_entries/
  {entryId}: {
    org_id, title, content_type, visibility, locality,
    image_url, comment_count, connection_count, has_active_dispute,
    created_at, updated_at, ...
  }

cultural_comments/
  {commentId}: {
    entry_id, commenter_id, commenter_name, voice_tier,
    comment_body, comment_action, has_reply, created_at, ...
  }

cultural_relations/
  {relationId}: {
    from_entry_id, to_entry_id, relationship_type, status,
    source, suggested_by_name, confirmed_at, ...
  }

cultural_media/
  {mediaId}: {
    org_id, entry_id, attached_entry_ids,
    media_type, file_name, file_url, media_role, ...
  }
```

## Usage Example

```dart
import 'package:canopy/Culture/index.dart';

// Use the main entry point
CultureHomeScreen(orgId: currentOrgId)
```

## Integration Points

1. **Authentication**: Requires current user/org context from existing auth provider
2. **Navigation**: Add to org home or main app navigation
3. **Firestore Security Rules**: Implement appropriate rules for cultural_entries, cultural_comments, etc. collections
4. **File Storage**: Configure Firebase Storage for media uploads (images, audio)
5. **Permissions**: Implement org admin vs. member role checks for editing/deleting

## Theme Constants

All hardcoded colours are centralized in `heritage_theme.dart`:

```dart
class HeritageTheme {
  static const Color heritageBackground = Color(0xFFF5EDE0);
  static const Color heritageCardBackground = Color(0xFFFDF7F0);
  
  static const Map<String, Color> contentTypePillColours = {
    'Stories': Color(0xFFB87333),
    'Food': Color(0xFFD4873A),
    // ...
  };
}
```

All other colours use `AppTheme` constants (primary, tertiary, darkGreen, etc.).

## Future Extensions

- Audio player implementation (audioplayers or just_audio package)
- Media upload flow (Camera, Gallery, File picker)
- Contribute entry wizard
- Connection proposal form
- Community dispute reporting
- Archive analytics & insights
- Search & advanced filtering
- Entry detail view with full content

---

**Last Updated**: May 2026  
**Structure Version**: 1.0
