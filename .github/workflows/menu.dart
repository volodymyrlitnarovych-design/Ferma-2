
import 'package:flutter/material.dart';
class MainMenuOverlay extends StatelessWidget {
  static const id = 'main_menu';
  final void Function()? onPlay;
  final ValueChanged<String>? onLanguage;
  final ValueChanged<String>? onCharacterColor;
  final ValueChanged<double>? onDayLength;
  final String language;
  final String characterColor;
  final double dayLength;
  const MainMenuOverlay({super.key, this.onPlay, this.onLanguage, this.onCharacterColor, this.onDayLength, required this.language, required this.characterColor, required this.dayLength});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xEE000000),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          width: 820,
          decoration: BoxDecoration(color: const Color(0xFF101010), borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("OpenFarm PRO v0.7", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 12, alignment: WrapAlignment.center, children: [
              _block("Мова / Language", DropdownButton<String>(
                value: language, dropdownColor: const Color(0xFF222222), style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value:'uk', child: Text('Українська')),
                  DropdownMenuItem(value:'en', child: Text('English')),
                  DropdownMenuItem(value:'ru', child: Text('Русский')),
                ],
                onChanged: onLanguage,
              )),
              _block("Персонаж / Character", DropdownButton<String>(
                value: characterColor, dropdownColor: const Color(0xFF222222), style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value:'green', child: Text('Зелений')),
                  DropdownMenuItem(value:'blue', child: Text('Синій')),
                  DropdownMenuItem(value:'red', child: Text('Червоний')),
                ],
                onChanged: onCharacterColor,
              )),
              _block("Швидкість часу (сек/день)", Slider(
                value: dayLength, min: 60, max: 300, divisions: 24, label: dayLength.toStringAsFixed(0),
                onChanged: onDayLength,
              )),
            ]),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onPlay,
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10), child: Text("Грати / Play", style: TextStyle(fontSize: 18))),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _block(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: 360,
      decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        child
      ]),
    );
  }
}
