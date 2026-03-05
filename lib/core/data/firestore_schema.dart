// Firestore schema specification for the AutoPlanner AI platform.
//
// This file documents the intended cloud schema. Each model includes
// toFirestore() and fromFirestore() for when cloud sync is enabled.
// The schema supports multi-user, multi-device sync with subcollections.

// FIRESTORE SCHEMA
// ================
//
// users/{uid}
// ├── displayName: string
// ├── email: string
// ├── photoUrl: string?
// ├── createdAt: timestamp
// ├── lastLoginAt: timestamp
// ├── plan: string  ("free" | "pro" | "enterprise")
// ├── settings: map
// │   ├── theme: string  ("light" | "dark" | "system")
// │   ├── defaultCalendarSource: string
// │   ├── aiModel: string
// │   └── timezone: string
// │
// ├── tasks/{taskId}
// │   ├── title: string
// │   ├── startTime: timestamp
// │   ├── endTime: timestamp?
// │   ├── note: string?
// │   ├── isCompleted: bool
// │   ├── priority: int (0-3)
// │   ├── tags: array<string>
// │   ├── linkedNoteIds: array<string>
// │   ├── createdAt: timestamp
// │   └── updatedAt: timestamp
// │
// ├── notes/{noteId}
// │   ├── title: string
// │   ├── content: string
// │   ├── summary: string?
// │   ├── tags: array<string>
// │   ├── linkedTaskIds: array<string>
// │   ├── isPinned: bool
// │   ├── createdAt: timestamp
// │   └── updatedAt: timestamp
// │
// ├── calendar_events/{eventId}
// │   ├── title: string
// │   ├── description: string?
// │   ├── startTime: timestamp
// │   ├── endTime: timestamp
// │   ├── source: string ("local" | "google" | "outlook")
// │   ├── linkedTaskId: string?
// │   ├── colorValue: int
// │   ├── isAllDay: bool
// │   ├── createdAt: timestamp
// │   └── updatedAt: timestamp
// │
// ├── memories/{memoryId}
// │   ├── content: string
// │   ├── sourceType: string ("task"|"note"|"calendar"|"ai"|"user")
// │   ├── sourceId: string?
// │   ├── tags: array<string>
// │   ├── relevanceScore: double
// │   ├── createdAt: timestamp
// │   └── embedding: array<double>?   ← future vector storage
// │
// └── ai_logs/{logId}
//     ├── model: string
//     ├── action: string
//     ├── promptTokens: int
//     ├── completionTokens: int
//     ├── latencyMs: int
//     ├── success: bool
//     └── timestamp: timestamp
//
// ── Global collections (admin use) ──
//
// ai_usage_summary/{date}
// ├── totalTokens: int
// ├── totalCalls: int
// ├── avgLatency: double
// └── userBreakdown: map<uid, int>
//
// feature_flags/{flagId}
// ├── enabled: bool
// ├── rolloutPercentage: double
// └── description: string
// ```

class FirestoreUserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final String plan; // free, pro, enterprise
  final UserSettings settings;

  const FirestoreUserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.createdAt,
    required this.lastLoginAt,
    this.plan = 'free',
    this.settings = const UserSettings(),
  });

  Map<String, dynamic> toFirestore() => {
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl,
    'createdAt': createdAt.toIso8601String(),
    'lastLoginAt': lastLoginAt.toIso8601String(),
    'plan': plan,
    'settings': settings.toMap(),
  };

  factory FirestoreUserProfile.fromFirestore(
    String uid,
    Map<String, dynamic> data,
  ) {
    return FirestoreUserProfile(
      uid: uid,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      createdAt: DateTime.parse(data['createdAt']),
      lastLoginAt: DateTime.parse(data['lastLoginAt']),
      plan: data['plan'] ?? 'free',
      settings: UserSettings.fromMap(data['settings'] ?? {}),
    );
  }
}

class UserSettings {
  final String theme; // light, dark, system
  final String defaultCalendarSource;
  final String aiModel;
  final String timezone;

  const UserSettings({
    this.theme = 'system',
    this.defaultCalendarSource = 'local',
    this.aiModel = 'gemini-2.0-flash',
    this.timezone = 'UTC',
  });

  Map<String, dynamic> toMap() => {
    'theme': theme,
    'defaultCalendarSource': defaultCalendarSource,
    'aiModel': aiModel,
    'timezone': timezone,
  };

  factory UserSettings.fromMap(Map<String, dynamic> m) {
    return UserSettings(
      theme: m['theme'] ?? 'system',
      defaultCalendarSource: m['defaultCalendarSource'] ?? 'local',
      aiModel: m['aiModel'] ?? 'gemini-2.0-flash',
      timezone: m['timezone'] ?? 'UTC',
    );
  }
}

// Firestore-ready converters for existing Hive models.
// These extensions add toFirestore/fromFirestore to each model
// without modifying the core model files.

extension TaskFirestore on Map<String, dynamic> {
  static Map<String, dynamic> taskToFirestore({
    required String title,
    required DateTime startTime,
    DateTime? endTime,
    String? note,
    bool isCompleted = false,
    int priority = 1,
    List<String> tags = const [],
    List<String> linkedNoteIds = const [],
  }) => {
    'title': title,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'note': note,
    'isCompleted': isCompleted,
    'priority': priority,
    'tags': tags,
    'linkedNoteIds': linkedNoteIds,
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

extension NoteFirestore on Map<String, dynamic> {
  static Map<String, dynamic> noteToFirestore({
    required String title,
    required String content,
    String? summary,
    List<String> tags = const [],
    List<String> linkedTaskIds = const [],
    bool isPinned = false,
  }) => {
    'title': title,
    'content': content,
    'summary': summary,
    'tags': tags,
    'linkedTaskIds': linkedTaskIds,
    'isPinned': isPinned,
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

extension MemoryFirestore on Map<String, dynamic> {
  static Map<String, dynamic> memoryToFirestore({
    required String content,
    required String sourceType,
    String? sourceId,
    List<String> tags = const [],
    double relevanceScore = 0.5,
    List<double>? embedding,
  }) => {
    'content': content,
    'sourceType': sourceType,
    'sourceId': sourceId,
    'tags': tags,
    'relevanceScore': relevanceScore,
    'embedding': embedding,
    'createdAt': DateTime.now().toIso8601String(),
  };
}
