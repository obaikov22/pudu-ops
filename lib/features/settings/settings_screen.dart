import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/ai_planner_service.dart';

const _primary = Color(0xFF7C6AF7);
const _surface = Color(0xFF13151C);
const _border = Color(0xFF1E2130);
const _textSecondary = Color(0xFF8B92A5);

const _languages = [
  'Arabic',
  'Chinese',
  'English',
  'French',
  'German',
  'Italian',
  'Japanese',
  'Kazakh',
  'Korean',
  'Polish',
  'Portuguese',
  'Romanian',
  'Russian',
  'Spanish',
  'Turkish',
  'Ukrainian',
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _loading = true;
  String _selectedLanguage = 'Russian';

  // Work schedule state
  String _shiftStart = '20:00';
  String _shiftEnd = '05:00';
  String _breakStart = '00:00';
  String _breakEnd = '01:00';
  String _washStart = '01:00';
  int _washDuration = 10;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final key = await AiPlannerService.getApiKey();
    final language = await AiPlannerService.getLanguage();
    final shiftStart = await AiPlannerService.getShiftStart();
    final shiftEnd = await AiPlannerService.getShiftEnd();
    final breakStart = await AiPlannerService.getBreakStart();
    final breakEnd = await AiPlannerService.getBreakEnd();
    final washStart = await AiPlannerService.getWashStart();
    final washDuration = await AiPlannerService.getWashDuration();
    if (!mounted) return;
    setState(() {
      _controller.text = key ?? '';
      _selectedLanguage = language;
      _shiftStart = shiftStart;
      _shiftEnd = shiftEnd;
      _breakStart = breakStart;
      _breakEnd = breakEnd;
      _washStart = washStart;
      _washDuration = washDuration;
      _loading = false;
    });
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    await AiPlannerService.saveApiKey(_controller.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
    Navigator.pop(context);
  }

  Future<void> _pickTime(
    String current,
    Future<void> Function(String formatted) onPicked,
  ) async {
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final time = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _primary,
            onPrimary: Colors.white,
            surface: Color(0xFF13151C),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) {
      final formatted =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      await onPicked(formatted);
    }
  }

  void _updateWashDuration(int newValue) {
    if (newValue < 1) return;
    HapticFeedback.lightImpact();
    setState(() => _washDuration = newValue);
    AiPlannerService.saveWashDuration(newValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Row(
          children: [
            Expanded(child: Divider(color: _border, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                title,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Expanded(child: Divider(color: _border, height: 1)),
          ],
        ),
      );

  Widget _timeTile(
    String label,
    String value,
    Future<void> Function(String) onPicked,
  ) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: Text(
          value,
          style: const TextStyle(
            color: _primary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        onTap: () => _pickTime(value, onPicked),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        title: const Text('Settings'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── AI Settings ──
                  _sectionHeader('AI SETTINGS'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Anthropic API key',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _controller,
                          obscureText: _obscure,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'sk-ant-...',
                            hintStyle: TextStyle(color: _textSecondary),
                            filled: true,
                            fillColor: const Color(0xFF0D0F14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: _border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: _border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: _primary),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: _textSecondary,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Get your API key at console.anthropic.com',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Response Language',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButton<String>(
                          value: _selectedLanguage,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF13151C),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                          underline: Container(height: 1, color: _border),
                          iconEnabledColor: _textSecondary,
                          items: _languages
                              .map(
                                (lang) => DropdownMenuItem(
                                  value: lang,
                                  child: Text(lang),
                                ),
                              )
                              .toList(),
                          onChanged: (val) async {
                            if (val == null) return;
                            setState(() => _selectedLanguage = val);
                            await AiPlannerService.saveLanguage(val);
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── Shift Schedule ──
                  const SizedBox(height: 8),
                  _sectionHeader('SHIFT SCHEDULE'),
                  Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      children: [
                        _timeTile('Shift Start', _shiftStart, (v) async {
                          setState(() => _shiftStart = v);
                          await AiPlannerService.saveShiftStart(v);
                        }),
                        Divider(height: 1, color: _border),
                        _timeTile('Shift End', _shiftEnd, (v) async {
                          setState(() => _shiftEnd = v);
                          await AiPlannerService.saveShiftEnd(v);
                        }),
                        Divider(height: 1, color: _border),
                        _timeTile('Break Start', _breakStart, (v) async {
                          setState(() => _breakStart = v);
                          await AiPlannerService.saveBreakStart(v);
                        }),
                        Divider(height: 1, color: _border),
                        _timeTile('Break End', _breakEnd, (v) async {
                          setState(() => _breakEnd = v);
                          await AiPlannerService.saveBreakEnd(v);
                        }),
                        Divider(height: 1, color: _border),
                        _timeTile('Wash Start', _washStart, (v) async {
                          setState(() => _washStart = v);
                          await AiPlannerService.saveWashStart(v);
                        }),
                        Divider(height: 1, color: _border),
                        // Wash duration — minus/plus row
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              const Text(
                                'Wash duration per robot',
                                style: TextStyle(color: Colors.white),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.remove, color: _primary),
                                onPressed: () =>
                                    _updateWashDuration(_washDuration - 1),
                              ),
                              Text(
                                '$_washDuration min',
                                style: const TextStyle(
                                  color: _primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: _primary),
                                onPressed: () =>
                                    _updateWashDuration(_washDuration + 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
