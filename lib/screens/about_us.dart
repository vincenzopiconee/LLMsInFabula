import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        title: Text(
          'About Us',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titolo gruppo
              Text(
                'Group 4: LLM in Fabula',
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Membri del gruppo
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PersonRow(
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        title: 'Member 1',
                        subtitle: 'Short bio / info here.',
                      ),
                      const SizedBox(height: 16),
                      _PersonRow(
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        title: 'Member 2',
                        subtitle: 'Short bio / info here.',
                      ),
                      const SizedBox(height: 16),
                      _PersonRow(
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        title: 'Member 3',
                        subtitle: 'Short bio / info here.',
                      ),
                      const SizedBox(height: 16),
                      _PersonRow(
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        title: 'Member 4',
                        subtitle: 'Short bio / info here.',
                      ),

                      const SizedBox(height: 32),

                      // Tutors
                      Text(
                        'Tutors',
                        style: textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PersonRow(
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        title: 'Tutor 1',
                        subtitle: 'Name and role.',
                      ),
                      const SizedBox(height: 16),
                      _PersonRow(
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        title: 'Tutor 2',
                        subtitle: 'Name and role.',
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Footer citazione
              const SizedBox(height: 8),
              Text(
                'We gratefully acknowledge the page ... for providing the icon ...',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final String title;
  final String subtitle;

  const _PersonRow({
    required this.colorScheme,
    required this.textTheme,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 34, // abbastanza grande per la foto
          backgroundColor: colorScheme.secondary,
          child: Icon(
            Icons.person,
            size: 40,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
