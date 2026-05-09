# AGENTS.md - CariPasal Development Guide

## Build/Test Commands

### Admin Dashboard (React + TypeScript)
```bash
cd admin-dashboard

# Development
npm run dev                    # Start dev server

# Build & Typecheck
npm run build                  # Build production bundle (includes typecheck)

# Code Quality
# npm run lint                  # ESLint not configured (no eslint.config.js)
```

### Flutter Mobile App
```bash
cd pasal_mobile_app

# Development
flutter run                    # Run app
flutter pub get                # Install dependencies

# Code Generation (Drift database)
flutter pub run build_runner build --delete-conflicting-outputs

# Testing
flutter test                   # Run all tests
flutter test test/unit/services/archive_service_test.dart  # Run single test file

# Analysis
flutter analyze                # Run static analysis
```

## Code Style Guidelines

### React/TypeScript (Admin Dashboard)

**Imports**: Group imports by category (external libs, internal components, pages)
```typescript
import { Routes, Route } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { api } from '@/lib/api'
import { DashboardPage } from './pages/DashboardPage'
```

**Components**: Named exports with PascalCase
```typescript
export function DashboardPage() { ... }
```

**Types**: Use generated types from `src/lib/database.types.ts`
```typescript
import type { Pasal, UndangUndang, PasalInsert } from '@/lib/database.types'
```

**State Management**: React Query for server state, Context for global state
```typescript
const { data, isLoading } = useQuery({ queryKey: ['pasal'], queryFn: fetchPasal })
```

**Error Handling**: Distinguish between server errors and user errors
```typescript
const isServerDown = /failed to fetch|timeout|502|503/i.test(error.message)
if (isServerDown) setServerDown(true)
```

**File Naming**: PascalCase components (`DashboardPage.tsx`), camelCase utilities

**UI Library**: Mantine v7 components, use prop shorthands (`c`, `w`, `p`, `gap`)

### Flutter/Dart (Mobile App)

**Imports**: Order: dart stdlib → flutter packages → internal packages
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/data_service.dart';
```

**Naming**: PascalCase classes, camelCase variables/funcs, snake_case files
```dart
class PasalModel { ... }       // class_name.dart
final String pasalName;        // variable
void fetchData() { ... }        // function
```

**Models**: Include `fromJson` factory for JSON parsing
```dart
class PasalModel {
  final String id;
  final String nomor;

  PasalModel({required this.id, required this.nomor});

  factory PasalModel.fromJson(Map<String, dynamic> json) {
    return PasalModel(id: json['id'] ?? '', nomor: json['nomor'] ?? '');
  }
}
```

**Services**: Singleton pattern, static methods
```dart
class DataService {
  static late AppDatabase _database;
  static Future<void> initialize() async { ... }
}
```

**State**: StatefulWidget with setState, ValueNotifier for reactive state
```dart
class _HomeScreenState extends State<HomeScreen> {
  List<PasalModel> _data = [];
  final ValueNotifier<bool> _loading = ValueNotifier(false);

  void _fetchData() async {
    setState(() => _loading.value = true);
    // ...
  }
}
```

**Error Handling**: Custom result types, user-friendly messages in Indonesian
```dart
class SyncResult {
  final bool success;
  final String message;  // "Data sudah up-to-date", "Sync berhasil"
  final SyncError? error;
}
```

**Testing**: Group tests by functionality, use mocks
```dart
void main() {
  group('ArchiveService', () {
    test('returns false when pasal is not archived', () { ... });
    test('adds pasal to archive when not already archived', () async { ... });
  });
}
```

**Colors**: Centralized in `lib/core/config/app_colors.dart`, support dark mode
```dart
Color scaffoldColor(bool isDark) => isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight;
```

## Common Patterns

### Type Safety
- React: Use shared API/data types from `database.types.ts`
- Flutter: Use Drift-generated types, avoid `any`/`dynamic` when possible

### Async Operations
- React: React Query with `useQuery`/`useMutation`
- Flutter: `async`/`await` with proper error boundaries

### Null Safety
- React: Optional chaining `user?.email`, nullish coalescing `??`
- Flutter: Sound null safety, `String?` for nullable, `String!` for non-null

### Code Generation
- React: None (Vite + TS compilation)
- Flutter: Run `build_runner` after modifying Drift tables

## Architecture Notes

- **Backend**: Laravel + PostgreSQL + Sanctum
- **Admin Dashboard**: React + Mantine + React Query + TypeScript
- **Mobile App**: Flutter + Drift (SQLite) + Laravel API sync
- **Database Schema**: Laravel migrations in `backend-laravel/database/migrations/`

## Key Files

- `backend-laravel/database/migrations/*.php` - Database schema changes
- `backend-laravel/routes/api.php` - Laravel API routes
- `admin-dashboard/src/lib/api.ts` - Admin API client
- `admin-dashboard/src/lib/database.types.ts` - Shared TypeScript data types
- `pasal_mobile_app/lib/core/database/app_database.dart` - Drift table definitions
- `admin-dashboard/src/contexts/AuthContext.tsx` - Authentication state
- `pasal_mobile_app/lib/core/services/data_service.dart` - Data sync service
