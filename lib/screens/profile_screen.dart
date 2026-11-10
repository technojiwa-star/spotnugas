import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../constants/app_location.dart';
import '../data/place_mock_data.dart';
import '../models/place_types.dart';
import '../models/saved_place_item.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/saved_places_provider.dart';
import 'auth/login_screen.dart';
import 'place_detail_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _localEditedName;
  bool _notifyNewSpots = true;
  bool _notifyCrowdUpdates = true;
  bool _notifyReviewReplies = false;

  void _showEditProfileModal(
    BuildContext context,
    UserProfile? profile,
    String currentDisplayName,
  ) {
    if (profile?.isGuest == true) {
      showDialog(
        context: context,
        builder: (_) => const GuestReviewBlockedDialog(),
      );
      return;
    }

    final controller = TextEditingController(text: currentDisplayName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Edit Profil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Nama Lengkap',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Masukkan nama lengkap...',
                  filled: true,
                  fillColor: AppColors.lightCreamBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final newName = controller.text.trim();
                    if (newName.isEmpty) return;
                    if (profile != null) {
                      await ref
                          .read(authControllerProvider.notifier)
                          .updateProfileName(
                            currentProfile: profile,
                            newName: newName,
                          );
                    }
                    if (mounted) {
                      setState(() {
                        _localEditedName = newName;
                      });
                    }
                    if (!sheetCtx.mounted) return;
                    Navigator.pop(sheetCtx);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profil berhasil diperbarui!'),
                        backgroundColor: AppColors.primaryTealDark,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Simpan Perubahan',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationSettingsSheet(BuildContext context) {
    final locState = () {
      try {
        return ref.read(currentLocationProvider);
      } catch (_) {
        return LocationState.mockYogyakarta();
      }
    }();

    final presets = <(String, GeoCoordinates)>[
      (AppLocation.defaultJakartaLabel, AppLocation.defaultJakarta),
      (AppLocation.bandungLabel, AppLocation.bandung),
      (AppLocation.depokLabel, AppLocation.depok),
      (AppLocation.mockYogyakartaLabel, AppLocation.mockYogyakartaOrigin),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Pengaturan Lokasi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lokasi aktif: ${locState.label}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.primaryTealDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.primaryTeal,
                  ),
                  title: const Text(
                    'Deteksi GPS Saat Ini',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    try {
                      ref
                          .read(currentLocationProvider.notifier)
                          .detectDeviceLocation(force: true);
                    } catch (_) {}
                  },
                ),
                const Divider(),
                ...presets.map((p) {
                  final (label, coords) = p;
                  final isCurrent = locState.label == label;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.location_city_rounded,
                      color: isCurrent
                          ? AppColors.primaryTeal
                          : AppColors.textMuted,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: isCurrent
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primaryTeal,
                            size: 18,
                          )
                        : null,
                    onTap: () {
                      try {
                        ref
                            .read(currentLocationProvider.notifier)
                            .setManualLocation(coords, label);
                      } catch (_) {}
                      Navigator.pop(sheetCtx);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotificationSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Pengaturan Notifikasi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primaryTeal,
                  title: const Text(
                    'Rekomendasi Spot Nugas Baru',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Info cafe & coworking baru di sekitarmu',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _notifyNewSpots,
                  onChanged: (v) {
                    setModalState(() => _notifyNewSpots = v);
                    setState(() => _notifyNewSpots = v);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primaryTeal,
                  title: const Text(
                    'Update Jam Buka & Status Tempat',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Pemberitahuan perubahan jam operasional tempat tersimpan',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _notifyCrowdUpdates,
                  onChanged: (v) {
                    setModalState(() => _notifyCrowdUpdates = v);
                    setState(() => _notifyCrowdUpdates = v);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primaryTeal,
                  title: const Text(
                    'Aktivitas Review Komunitas',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Notifikasi saat ulasanmu membantu mahasiswa lain',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _notifyReviewReplies,
                  onChanged: (v) {
                    setModalState(() => _notifyReviewReplies = v);
                    setState(() => _notifyReviewReplies = v);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<(String, String)> items,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: AppColors.primaryTeal,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.$2,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text(
          'Keluar Akun?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun SpotNugas Anda?',
          style: TextStyle(fontSize: 14, color: AppColors.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              ref.read(savedPlacesRepositoryProvider).clearAll();
              await ref.read(authRepositoryProvider).signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(isFirstTime: false),
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracottaBrown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.valueOrNull;

    final savedItems = ref
        .watch(savedPlacesStreamProvider)
        .maybeWhen(
          data: (items) => items,
          orElse: () => const <SavedPlaceItem>[],
        );
    final savedCount = savedItems.isNotEmpty
        ? savedItems.length
        : PlaceMockData.places.where((p) => p.isSaved).length;

    final displayName = _localEditedName ?? profile?.name ?? 'Rian Adiputra';
    final displayEmail = profile != null
        ? (profile.isGuest
              ? 'Mode Tamu'
              : (profile.email ?? 'rian.adiputra@student.ac.id'))
        : 'rian.adiputra@student.ac.id';
    final isGuest = profile?.isGuest ?? false;
    return Scaffold(
      backgroundColor: AppColors.lightCreamBackground,
      appBar: AppBar(
        title: const Text('Profil Saya'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textDark,
            ),
            onPressed: () =>
                _showEditProfileModal(context, profile, displayName),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            children: [
              // 1. Profile Info Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryTeal,
                              width: 3,
                            ),
                            image: const DecorationImage(
                              image: AssetImage('assets/images/kopi-ruang.jpg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryTeal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayEmail,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTealSurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGuest
                                ? Icons.explore_rounded
                                : Icons.workspace_premium_rounded,
                            size: 14,
                            color: AppColors.primaryTeal,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isGuest
                                  ? 'Mode Tamu • Jelajah SpotNugas'
                                  : 'Nugas Explorer Lv. 4 • Mahasiswa UGM',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryTealDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Statistics Row
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    _buildStatItem('14', 'Review', Icons.rate_review_outlined),
                    _buildStatDivider(),
                    _buildStatItem(
                      '$savedCount',
                      'Tempat Tersimpan',
                      Icons.bookmark_border_rounded,
                    ),
                    _buildStatDivider(),
                    _buildStatItem(
                      '23',
                      'Tempat Dikunjungi',
                      Icons.check_circle_outline_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _buildMenuItem(
                      context,
                      'Edit Profil',
                      Icons.person_outline_rounded,
                      onTap: () =>
                          _showEditProfileModal(context, profile, displayName),
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      context,
                      'Review Saya',
                      Icons.star_border_rounded,
                      onTap: () => _showInfoSheet(
                        context,
                        title: 'Review Saya',
                        subtitle:
                            'Ulasan tempat nugas yang telah kamu bagikan ke komunitas:',
                        items: const [
                          (
                            'Kopi Ruang • ★ 5.0',
                            'Wi-Fi cepat dan banyak colokan di lantai 2.',
                          ),
                          (
                            'Ruang Temu Library & Cafe • ★ 4.9',
                            'Zona hening sangat kondusif untuk fokus skripsi.',
                          ),
                        ],
                      ),
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      context,
                      'Aktivitas',
                      Icons.history_rounded,
                      onTap: () => _showInfoSheet(
                        context,
                        title: 'Riwayat Aktivitas Nugas',
                        subtitle:
                            'Ringkasan eksplorasi dan tempat yang kamu simpan:',
                        items: [
                          (
                            '$savedCount Tempat Tersimpan di Favorit',
                            'Dapat diakses kapan saja melalui tab Tersimpan.',
                          ),
                          (
                            'Pencarian & Peta Interaktif Aktif',
                            'Terhubung dengan pencarian tempat nugas terdekat.',
                          ),
                        ],
                      ),
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      context,
                      'Notifikasi',
                      Icons.notifications_none_rounded,
                      badge: '2 Baru',
                      onTap: () => _showNotificationSettingsSheet(context),
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      context,
                      'Pengaturan Lokasi',
                      Icons.location_on_outlined,
                      onTap: () => _showLocationSettingsSheet(context),
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      context,
                      'Bantuan',
                      Icons.help_outline_rounded,
                      onTap: () => _showInfoSheet(
                        context,
                        title: 'Pusat Bantuan & Tentang SpotNugas',
                        subtitle: 'SpotNugas Android MVP • Panduan Pengguna',
                        items: const [
                          (
                            'Apa itu Skor Nugas?',
                            'Indeks produktivitas (0–10) berdasarkan kecepatan Wi-Fi, ketersediaan colokan, kenyamanan meja, ketenangan, dan harga.',
                          ),
                          (
                            'Akses Akun Tamu vs Terdaftar',
                            'Akun Tamu dapat menjelajah peta dan menyimpan tempat. Akun Terdaftar dapat menulis dan memperbarui review tempat.',
                          ),
                        ],
                      ),
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      context,
                      'Keluar',
                      Icons.logout_rounded,
                      isDestructive: true,
                      onTap: () => _handleLogout(context, ref),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryTeal),
          const SizedBox(height: 6),
          Text(
            count,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 38, color: AppColors.divider);
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon, {
    String? badge,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.terracottaBrown : AppColors.textDark,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: isDestructive ? AppColors.terracottaBrown : AppColors.textDark,
        ),
      ),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.terracottaBrown,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: AppColors.divider);
  }
}
