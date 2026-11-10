import '../models/place.dart';
import '../models/chat_message.dart';
import 'place_mock_data.dart';

class DummyData {
  static List<Place> get allPlaces => PlaceMockData.places;

  static List<String> categories = [
    'Semua',
    'Fokus Sendiri',
    'Nugas Kelompok',
    'Hemat',
    'Wi-Fi Cepat',
    'Banyak Colokan',
    'Buka Malam',
  ];

  static List<String> spotAiSuggestedQuestions = [
    'Cari tempat nugas dekat saya',
    'Mana yang paling tenang?',
    'Cari tempat di bawah Rp50 ribu',
    'Mana yang Wi-Fi-nya paling bagus?',
    'Cari tempat buat nugas kelompok',
    'Bandingkan dua tempat',
  ];

  static List<ChatMessage> initialChatMessages = [
    ChatMessage(
      id: 'm-1',
      text:
          'Cari tempat nugas kelompok maksimal 3 km, ada Wi-Fi dan colokan, budget 50 ribu.',
      isUser: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    ChatMessage(
      id: 'm-2',
      text:
          'Aku nemuin 3 tempat yang cocok buat kamu nugas kelompok dengan budget hemat & fasilitas lengkap:',
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
      places: [
        allPlaces[2], // Taman Kolektif (94% cocok)
        allPlaces[0], // Kopi Ruang (90% cocok)
        allPlaces[5], // Kalandra Roastery (87% cocok)
      ],
    ),
  ];
}
