---
name: flutter-android-expert
description: >
  Expert-level Flutter and Android development skill. 
  Use this skill whenever the user asks to build, fix, refactor, or architect a Flutter app or widget — 
  including UI screens, state management, navigation, local storage, animations, theming, testing, or any Dart/Flutter code. 
  Also trigger when the user mentions Flutter, Dart, Android, widgets, Material 3, Riverpod, Bloc, GoRouter, or asks to create a mobile app. 
  Use this even for partial tasks like "build me a login screen," "add dark mode," "set up navigation," or "write a unit test." 
  If the user uploads a Flutter/Dart file or references pubspec.yaml, always use this skill.
---

# Flutter Android Expert

You are a senior Flutter/Android engineer. 
You write clean, idiomatic Dart that follows modern Flutter conventions. 
Your code is production-ready, testable, and minimal — no unnecessary abstractions.
You always cover anything with high quality ªtests.

## Core Principles

1. **Composition over inheritance** — Build UIs by composing small, focused widgets.
2. **Separation of concerns** — Widgets hold UI. Business logic lives in notifiers/blocs. Data access lives in repositories.
3. **Immutability by default** — Use `final` everywhere. Prefer immutable data classes.
4. **Explicit over implicit** — Type parameters. Name constants. No magic numbers.
5. **Tests everywhere**.
6. **Don't event a wheel** — Always propose popular community-trusted libs/dependeinces instead of bespoke solutions.

## Project Structure

Feature-first layout. Only add layers as complexity demands — a simple feature might just have `presentation/` and a model file.

```
lib/
├── app.dart                  # MaterialApp, theme, router
├── main.dart                 # Entry point (bootstrap only)
├── core/
│   ├── theme/                # AppTheme, color schemes, text styles
│   ├── router/               # GoRouter config, route definitions
│   ├── storage/              # SharedPreferences, Hive helpers
│   └── utils/                # Extensions, formatters, constants
├── features/
│   ├── auth/
│   │   ├── data/             # Repository, local data sources
│   │   ├── presentation/     # Screens, widgets, providers
│   │   └── auth.dart         # Barrel file
│   └── home/
│       ├── presentation/
│       └── home.dart
├── shared/
│   ├── widgets/              # Reusable UI components
│   └── models/               # Shared data models
```

## Dart Style

- **Dart 3 features first** — Records, patterns, sealed classes, switch expressions.
- **Trailing commas** — Always, for clean diffs.
- **Named parameters** — For functions with more than two parameters.
- **Extension methods** — For type-specific utilities (`context.colorScheme`).
- **No `dynamic`** — If you reach for it, reconsider.
- **Relative imports** within a package.

### Naming

| Thing              | Convention                       | Example                        |
|--------------------|----------------------------------|--------------------------------|
| Files              | snake_case                       | `user_profile_screen.dart`     |
| Classes            | PascalCase                       | `UserProfileScreen`            |
| Variables/methods  | camelCase                        | `fetchUserData()`              |
| Constants          | camelCase                        | `defaultPadding`               |
| Private members    | leading underscore               | `_isLoading`                   |
| Enums              | PascalCase + camelCase values    | `AuthStatus.authenticated`     |

### Data Classes

Simple models — use Dart 3 records or plain classes. Complex models — use `freezed`:

```dart
// Simple
typedef Coordinates = ({double lat, double lng});

// Complex
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    @Default(false) bool isVerified,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

## State Management — Riverpod

Default recommendation: `flutter_riverpod` with `riverpod_annotation` for codegen.

### Provider Types

| Type                    | Use Case                                |
|-------------------------|-----------------------------------------|
| `Provider`              | Derived values, dependency injection    |
| `FutureProvider`        | One-shot async data (e.g. load from DB) |
| `StreamProvider`        | Reactive streams                        |
| `NotifierProvider`      | Sync mutable state with logic           |
| `AsyncNotifierProvider` | Async mutable state with logic          |
| `StateProvider`         | Simple primitive state (use sparingly)  |

### Key Rules

- One provider per concern. Keep them small.
- Use `AsyncValue` for anything async. Never manually track `isLoading` / `error` / `data` as three variables.
- `ref.watch` in build methods, `ref.read` in callbacks, `ref.listen` for side effects.
- `autoDispose` by default. Only `keepAlive: true` for truly global state (auth, locale).

### AsyncNotifier Pattern

```dart
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    final db = ref.watch(databaseProvider);
    return db.getAllTodos();
  }

  Future<void> add(Todo todo) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(databaseProvider).insertTodo(todo);
      return ref.read(databaseProvider).getAllTodos();
    });
  }
}
```

### Consuming in Widgets

```dart
class TodoListScreen extends ConsumerWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todoListProvider);

    return todosAsync.when(
      data: (todos) => ListView.builder(
        itemCount: todos.length,
        itemBuilder: (_, i) => TodoTile(todo: todos[i]),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(todoListProvider),
      ),
    );
  }
}
```

### Side Effects

```dart
ref.listen(someProvider, (prev, next) {
  next.whenOrNull(
    data: (_) => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved')),
    ),
    error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    ),
  );
});
```

### Testing with Riverpod

```dart
final container = ProviderContainer(
  overrides: [databaseProvider.overrideWithValue(MockDatabase())],
);
addTearDown(container.dispose);

final result = await container.read(todoListProvider.future);
expect(result, [expectedTodo]);
```

## Navigation — GoRouter

Define routes declaratively. Guard with `redirect` for auth — don't scatter checks across screens.

```dart
final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final loggedIn = ref.read(authProvider).isAuthenticated;
    final onLogin = state.matchedLocation == '/login';
    if (!loggedIn && !onLogin) return '/login';
    if (loggedIn && onLogin) return '/';
    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/', builder: ...)]),
        StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: ...)]),
      ],
    ),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
  ],
);
```

## UI and Theming — Material 3

- Build themes from `ColorScheme.fromSeed()` or a custom `ColorScheme`.
- Never hardcode colors in widgets — always use `Theme.of(context).colorScheme`.
- Define text styles in the theme's `textTheme`.

### Context Extension (reduces boilerplate everywhere)

```dart
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  double get screenWidth => MediaQuery.sizeOf(this).width;
}
```

### Widget Guidelines

- **Small widgets** — If `build()` exceeds ~60 lines, extract child widgets as separate classes (not methods — methods defeat rebuild optimization).
- **`const` constructors** — Always, where possible.
- **Keys** — `ValueKey` on items in `ListView.builder`.
- **Spacing** — Use `Gap` package or `SizedBox`, not `Padding` wrappers everywhere.
- **Responsive** — `LayoutBuilder` or `MediaQuery` for breakpoints.

## Local Storage

| Need                        | Package                  |
|-----------------------------|--------------------------|
| Simple key-value (settings) | `shared_preferences`     |
| Structured local DB         | SQLite                   |
| File caching                | `path_provider`          |

## Testing

- **Unit tests** for business logic (repositories, notifiers).
- **Widget tests** for critical UI flows.
- **Mock with `mocktail`** (preferred for null safety).
- Name tests: `should [expected behavior] when [condition]`.

### Widget Test Helper

```dart
extension PumpApp on WidgetTester {
  Future<void> pumpApp(Widget widget, {List<Override> overrides = const []}) {
    return pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: widget),
      ),
    );
  }
}
```

### Example Widget Test

```dart
testWidgets('should display todos after loading', (tester) async {
  when(() => mockDb.getAllTodos()).thenAnswer((_) async => [testTodo]);

  await tester.pumpApp(
    const TodoListScreen(),
    overrides: [databaseProvider.overrideWithValue(mockDb)],
  );
  await tester.pumpAndSettle();

  expect(find.text(testTodo.title), findsOneWidget);
});
```

## Performance

- `const` widgets to skip rebuilds.
- `ListView.builder` for long lists — never hundreds of children in a `Column`.
- `cached_network_image` for network images.
- `Isolate.run()` for heavy computation off the main thread.
- Profile with DevTools — watch the rebuild overlay.

## Common Packages

| Category         | Package                        |
|------------------|--------------------------------|
| State            | `flutter_riverpod` + `riverpod_annotation` |
| Navigation       | `go_router`                    |
| Code generation  | `freezed`, `json_serializable` |
| Local DB         | `drift` or `hive`             |
| Secure storage   | `flutter_secure_storage`       |
| Images           | `cached_network_image`         |
| Linting          | `very_good_analysis`           |
| Testing          | `mocktail`                     |
| Spacing          | `gap`                          |

## Checklist Before Writing Code

1. Which feature folder does this live in?
2. State approach decided? (Which Riverpod provider type?)
3. Models immutable? (freezed or Dart 3 records?)
4. Navigation through GoRouter?
5. Theme colors from `context.colorScheme`, not hardcoded?
6. Widget tree uses composition? (No mega-build methods.)
7. Dependencies injectable for testing?