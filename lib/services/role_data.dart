import 'package:flutter/material.dart';

class RoleData {
  final String name;
  final String image;
  final String description;
  final Color color; 

  RoleData({
    required this.name,
    required this.image,
    required this.description,
    required this.color,
  });
}

// Mappa dei ruoli con colori
final Map<String, RoleData> rolesData = {
  'Werewolf': RoleData(
    name: 'Werewolf',
    image: 'assets/images/logo.png',
    description: 'You hunt at night. Your goal is to eliminate all villagers without being discovered.',
    color: const Color(0xFF8B0000), // Rosso scuro
  ),
  'Doctor': RoleData(
    name: 'Doctor',
    image: 'assets/images/doctor.png',
    description: 'Each night, you can protect one player from the werewolves\' attack.',
    color: const Color(0xFF5A8920), // Verde
  ),
  'Seer': RoleData(
    name: 'Seer',
    image: 'assets/images/seer.png',
    description: 'Each night, you can learn the true identity of one player.',
    color: const Color(0xFF166AF1), // Blu
  ),
  'Medium': RoleData(
    name: 'Medium',
    image: 'assets/images/medium.png',
    description: 'You can communicate with the dead and learn secrets from beyond.',
    color: const Color(0xFF9A5EA8), // Viola
  ),
  'Farmer': RoleData(
    name: 'Farmer',
    image: 'assets/images/farmer.png',
    description: 'You are a simple villager. Help find the werewolves during the day!',
    color: const Color.fromARGB(255, 141, 134, 29), // Giallo
  ),
  'Spectator': RoleData(
    name: 'Spectator',
    image: 'assets/images/spectator.png',
    description: 'You are a silent observer, watching from the shadows. You see everything that unfolds, but cannot interfere. Your knowledge dies with you—unless you witness the truth.',
    color: const Color(0xFFAFAFAF), // colorScheme.secondary
  ),
};
