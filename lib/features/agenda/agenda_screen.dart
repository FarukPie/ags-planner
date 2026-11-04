import 'package:flutter/material.dart';

import 'agenda_tab.dart';

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajanda')),
      body: const AgendaTab(),
    );
  }
}
