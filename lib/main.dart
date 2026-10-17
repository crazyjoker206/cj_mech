import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const appName = 'C.J MECH';

// UI strings. To add a language: add a new entry here and in `languages`.
const Map<String, Map<String, String>> strings = {
  'en': {
    'projects': 'Projects',
    'about': 'About',
    'language': 'Language',
    'choose_language': 'Choose your language',
    'components': 'Components',
    'watch_video': 'Watch video',
    'open_link': 'Open link',
    'no_projects': 'No projects yet',
    'contact': 'Contact',
  },
  'ar': {
    'projects': 'المشاريع',
    'about': 'عني',
    'language': 'اللغة',
    'choose_language': 'اختار لغتك',
    'components': 'المكونات',
    'watch_video': 'شاهد الفيديو',
    'open_link': 'افتح الرابط',
    'no_projects': 'مفيش مشاريع لسه',
    'contact': 'تواصل معايا',
  },
};

// Name shown for each language in the picker (always in its own language).
const Map<String, String> languages = {
  'en': 'English',
  'ar': 'العربية',
};

String t(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  return strings[code]?[key] ?? strings['en']![key] ?? key;
}

// Reads a {en: ..., ar: ...} map in the current language (falls back to en).
String loc(BuildContext context, dynamic value) {
  if (value is Map) {
    final code = Localizations.localeOf(context).languageCode;
    return (value[code] ?? value['en'] ?? '').toString();
  }
  return (value ?? '').toString();
}

Future<void> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<Map<String, dynamic>> loadData() async {
  final raw = await rootBundle.loadString('assets/projects.json');
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() => runApp(const CjMechApp());

class CjMechApp extends StatefulWidget {
  const CjMechApp({super.key});

  @override
  State<CjMechApp> createState() => _CjMechAppState();
}

class _CjMechAppState extends State<CjMechApp> {
  Locale? _locale;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadLang();
  }

  Future<void> _loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('lang');
    setState(() {
      _locale = code == null ? null : Locale(code);
      _loaded = true;
    });
  }

  Future<void> _setLang(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', code);
    setState(() => _locale = Locale(code));
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (!_loaded) {
      home = const Scaffold();
    } else if (_locale == null) {
      home = LanguagePage(onSelected: _setLang, firstRun: true);
    } else {
      home = HomePage(onLanguageChanged: _setLang);
    }

    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: languages.keys.map((c) => Locale(c)).toList(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          brightness: Brightness.dark,
        ),
      ),
      home: home,
    );
  }
}

class LanguagePage extends StatelessWidget {
  const LanguagePage({
    super.key,
    required this.onSelected,
    this.firstRun = false,
  });

  final Future<void> Function(String code) onSelected;
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: firstRun ? null : AppBar(title: Text(t(context, 'language'))),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (firstRun) ...[
                  const Icon(Icons.precision_manufacturing, size: 72),
                  const SizedBox(height: 12),
                  const Text(
                    appName,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  const Text('Choose your language / اختار لغتك'),
                  const SizedBox(height: 16),
                ],
                for (final entry in languages.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SizedBox(
                      width: 240,
                      child: FilledButton.tonal(
                        onPressed: () async {
                          await onSelected(entry.key);
                          if (!firstRun && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(entry.value),
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
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onLanguageChanged});

  final Future<void> Function(String code) onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actions: [
          IconButton(
            tooltip: t(context, 'language'),
            icon: const Icon(Icons.language),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LanguagePage(onSelected: onLanguageChanged),
              ),
            ),
          ),
          IconButton(
            tooltip: t(context, 'about'),
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: loadData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final projects =
              (snapshot.data!['projects'] as List?)?.cast<Map>() ?? [];
          if (projects.isEmpty) {
            return Center(child: Text(t(context, 'no_projects')));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: projects.length,
            itemBuilder: (context, i) {
              final p = projects[i];
              final images = (p['images'] as List?) ?? [];
              return Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProjectPage(project: p),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (images.isNotEmpty)
                        AssetImageBox(path: images.first.toString(), height: 180),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc(context, p['title']),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              loc(context, p['desc']),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AssetImageBox extends StatelessWidget {
  const AssetImageBox({super.key, required this.path, this.height = 220});

  final String path;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: double.infinity,
        color: Colors.black26,
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
  }
}

class ProjectPage extends StatelessWidget {
  const ProjectPage({super.key, required this.project});

  final Map project;

  @override
  Widget build(BuildContext context) {
    final images = (project['images'] as List?) ?? [];
    final components = (project['components'] as List?) ?? [];
    final video = (project['video'] ?? '').toString();
    final link = (project['link'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: Text(loc(context, project['title']))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (images.isNotEmpty)
            SizedBox(
              height: 220,
              child: PageView(
                children: [
                  for (final img in images)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AssetImageBox(path: img.toString()),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            loc(context, project['desc']),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (components.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              t(context, 'components'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in components) Chip(label: Text(c.toString())),
              ],
            ),
          ],
          if (video.isNotEmpty) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => openUrl(video),
              icon: const Icon(Icons.play_circle_outline),
              label: Text(t(context, 'watch_video')),
            ),
          ],
          if (link.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openUrl(link),
              icon: const Icon(Icons.open_in_new),
              label: Text(t(context, 'open_link')),
            ),
          ],
        ],
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'about'))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: loadData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = (snapshot.data!['profile'] as Map?) ?? {};
          final contacts = (profile['contacts'] as List?)?.cast<Map>() ?? [];
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.precision_manufacturing, size: 72),
              const SizedBox(height: 12),
              Text(
                appName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                loc(context, profile['bio']),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (contacts.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  t(context, 'contact'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final c in contacts)
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(c['label'].toString()),
                    onTap: () => openUrl(c['url'].toString()),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
