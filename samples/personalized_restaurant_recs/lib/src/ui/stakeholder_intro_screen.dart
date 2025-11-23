import 'package:flutter/material.dart';
import '../models/user_persona.dart';

/// First screen: Stakeholder conversation and input collection
class StakeholderIntroScreen extends StatefulWidget {
  const StakeholderIntroScreen({
    required this.personas,
    required this.onContinue,
    super.key,
  });

  final List<UserPersona> personas;
  final Function(String zipCode, UserPersona persona) onContinue;

  @override
  State<StakeholderIntroScreen> createState() => _StakeholderIntroScreenState();
}

class _StakeholderIntroScreenState extends State<StakeholderIntroScreen> {
  final _zipCodeController = TextEditingController();
  UserPersona? _selectedPersona;

  @override
  void dispose() {
    _zipCodeController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    final zipCode = _zipCodeController.text.trim();
    if (zipCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a zip code')),
      );
      return;
    }

    if (_selectedPersona == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a diner type')),
      );
      return;
    }

    widget.onContinue(zipCode, _selectedPersona!);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section
          Text(
            '🍽️ Welcome to Intelligent Restaurant Recommendations',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),

          // Problem statement
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why This Tool?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Finding the perfect restaurant is hard. Traditional recommendation '
                    'systems give you generic ratings that don\'t match YOUR preferences.\n\n'
                    'This tool uses advanced AI to:\n'
                    '• Analyze thousands of reviews through multiple lenses\n'
                    '• Understand YOUR unique dining preferences\n'
                    '• Self-improve its analysis process in real-time\n'
                    '• Provide personalized, evidence-based recommendations',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Input section
          Text(
            'Tell Us About You',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Zip code input
          TextField(
            controller: _zipCodeController,
            decoration: const InputDecoration(
              labelText: 'Zip Code',
              hintText: 'Enter your zip code (e.g., 85281)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),

          // Persona selection
          Text(
            'What Type of Diner Are You?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          ...widget.personas.map((persona) {
            final isSelected = _selectedPersona?.name == persona.name;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedPersona = persona;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            persona.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 40.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(persona.description),
                            const SizedBox(height: 4),
                            Text(
                              'Priorities: ${persona.priorities.join(', ')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 32),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _handleContinue,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Find My Perfect Restaurant'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
