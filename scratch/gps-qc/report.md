**Spot Nugas — GPS Integrity & Location Fallback QC**

20 Oktober 2026, Asia/Jakarta. Flutter 3.44.2 / Dart 3.12.2.

1. **Kondisi repository aktual.** Workspace `/Users/apple/Spot Nugas Apps`, branch `master`, belum memiliki commit awal. Source masih untracked, sehingga tidak ada baseline Git untuk mengatribusikan setiap baris perubahan lama. Review menggunakan file aktual, arsitektur provider/repository, dan test. Tidak dibuat commit, push, checkout, reset, clean, atau perubahan backend. Ruang disk saat awal sekitar 4,2 GiB; setelah QC sekitar 2,0 GiB. `.secrets/geoapify.dev.json` tersedia dan diabaikan Git; nilainya tidak dicetak.

2. **Perubahan warisan yang dipertahankan.** Service meneruskan koordinat Geolocator secara langsung; repository memperluas radius 5 km ke 20 km dengan origin yang sama; parsing kategori memprioritaskan cafe/coworking/library; Gradle sudah tidak berisi pembacaan atau injeksi secret implisit. Konfigurasi VS Code menggunakan file dart-define secara eksplisit. APK lama tersedia, tetapi keberadaannya tidak dianggap bukti seluruh QC lama berhasil. Hasil checkpoint 153 test tidak dipakai sebagai hasil working tree saat ini.

3. **Substitusi GPS Mountain View.** Tidak ditemukan lagi penggantian otomatis koordinat Mountain View menjadi Jakarta dalam jalur produksi. Diverifikasi melalui test terhadap implementasi Geolocator, state notifier, GPS emulator, label aplikasi, venue aktual, dan peta pada APK final. Koordinat emulator sekitar `37.421997,-122.084000` merupakan hasil pembulatan platform dari input `37.4219983,-122.084`.

4. **Fallback diam-diam ke Jakarta.** Repository mempertahankan origin ketika memperluas radius. Lokasi awal produksi kini unresolved; pencarian tidak dijalankan menggunakan placeholder Jakarta sebelum GPS atau pilihan manual tersedia. Beranda, Search, Jelajah, nearby provider, dan pemuatan SpotAI mengikuti aturan ini. Respons lama tidak dapat menimpa pilihan lokasi yang lebih baru. Pilihan manual membatalkan hasil GPS/geocoding yang masih berjalan. Error lama dapat dibersihkan ketika deteksi atau pemilihan berikutnya berhasil.

5. **Hasil runtime pada APK final.** AVD yang ditemukan: `SpotNugas_API_34`, runtime ID `emulator-5554`, Android 14 / API 34. Beranda, Search, dan Jelajah diperiksa untuk setiap kota dan untuk empty/error state.

| Skenario | Input latitude, longitude | Label/hasil aplikasi | Respons Places | Venue dikembalikan |
| --- | --- | --- | --- | --- |
| Jakarta Selatan | -6.2297, 106.8295 | Setiabudi, Jakarta Selatan; Caffe Bene | HTTP 200, 5 km | 20 |
| Bandung | -6.9175, 107.6191 | Merdeka, Kota Bandung; Kedai Kopi Oh | HTTP 200, 5 km | 20 |
| Mountain View | 37.4219983, -122.084 | Mountain View; Costa | HTTP 200, 5 km | 20 |
| Empty nyata di Samudra Pasifik | 0, -140 | Lokasi Terdeteksi; ketiga layar kosong | HTTP 200 pada 5 km dan 20 km | 0 |
| Jaringan emulator dimatikan | 1, -140 | Ketiga layar menunjukkan error dan tombol coba lagi | Koneksi gagal; tidak ada status HTTP | Tidak tersedia |
| Izin OS ditolak | GPS tidak diakses aplikasi | Izin Lokasi Dinonaktifkan; tidak ada pencarian otomatis | Tidak ada request sebelum pemilihan manual | Tidak berlaku |
| Bandung manual setelah izin ditolak | -6.9175, 107.6191 | Bandung; source manual; Kedai Kopi Oh | HTTP 200, 5 km | 20 |
| Bandung manual saat fix GPS Mountain View valid | Manual Bandung; GPS 37.421997,-122.084000 | Bandung tetap aktif | Cache respons Bandung HTTP 200 sebelumnya | 20 |

6. **Makna status/count dan bukti.** Angka 20 adalah jumlah hasil yang dikembalikan dengan limit 20, bukan total seluruh venue kota. Geoapify menghasilkan venue aktual; fallback kafe demo pada empty/error Jelajah dan Beranda dihapus. Respons malformed, HTTP 401/429/500, kegagalan detail, dan timeout tetap menjadi error pada test terkontrol. Pembesaran radius diuji dengan pemeriksaan exact `filter` dan `bias`, selain runtime empty nyata. Raw transport/parse exception tidak disisipkan ke log atau pesan UI. Provider tile menekan exception ber-URL. Pemeriksaan exact key pada raw log PID aplikasi tidak menemukan key asli di semua snapshot yang disimpan.

   Bukti JSON dan screenshot tersedia di folder ini: [Jakarta](jakarta.json), [Bandung](bandung.json), [Mountain View](mountain-view.json), [empty](empty-ocean.json), [network error](network-error.json), [izin ditolak + manual](denied-manual-bandung.json), dan [manual Bandung dengan GPS Mountain View](manual-bandung-gps-mountain-view.json). Saat izin ditolak, posisi terakhir Android masih posisi ocean dari skenario sebelumnya; injeksi Mountain View baru dikonfirmasi sebagai fix valid setelah izin dipulihkan. Bukti manual terakhir menunjukkan fix Mountain View dan Bandung manual secara bersamaan.

7. **File source/test yang diubah pada kelanjutan ini.** File Gradle dan AndroidManifest diperiksa dan tidak memerlukan perubahan lanjutan.

| File | Perubahan |
| --- | --- |
| `lib/services/device_location_service.dart` | Pesan error aman tanpa raw exception |
| `lib/services/reverse_geocoding_service.dart` | Log error aman tanpa URI/key |
| `lib/providers/location_provider.dart` | Unresolved state, pengaman request lama, error clearing, pilihan manual |
| `lib/providers/place_provider.dart` | Menunggu lokasi terpilih sebelum nearby query |
| `lib/datasources/geoapify_places_data_source.dart` | Error jaringan/parse aman, validasi respons, propagasi error detail |
| `lib/screens/home_screen.dart` | Manual startup, request sequencing, empty/error dan status GPS |
| `lib/screens/search_results_screen.dart` | Await/catch async, loading/error/retry, request sequencing |
| `lib/screens/explore_map_screen.dart` | Hapus seed fallback, empty/error/retry, origin dan tile error |
| `lib/screens/spot_ai_screen.dart` | Menunggu origin, memperbarui lokasi, mencegah rekomendasi seed pada live empty/error |
| `test/device_geolocation_test.dart` | Regresi GPS produksi, izin, timeout, race, recovery, provider gating, log aman |
| `test/geoapify_places_test.dart` | Origin/bias, perluasan radius, error, malformed response, key redaction |
| `test/discovery_location_integrity_test.dart` | Regresi UI untuk manual, unresolved, empty/error, respons lama, SpotAI |

   Artefak tambahan hanya berupa laporan, ringkasan QC, JSON, dan screenshot di `scratch/gps-qc/`. Firebase Auth, Firestore rules, dependensi, serta arsitektur review dipertahankan; Supabase dan upload foto review tidak ditambahkan.

8. **Flutter analyze.** `flutter analyze`: exit 0, **0 issues**. Formatter pada 12 file selesai exit 0. Satu import test yang tidak diperlukan ditemukan oleh analyzer dan sudah dihapus sebelum hasil final bersih.

9. **Flutter test.** `flutter test --reporter json`: exit 0, **198 passed, 0 failed, 2 skipped**. Dua test tersebut khusus cabang konfigurasi ber-key. `flutter test test/discovery_location_integrity_test.dart --dart-define=GEOAPIFY_API_KEY=qc-placeholder --reporter json`: exit 0, **15 passed, 0 failed, 0 skipped**, termasuk kedua test tadi. Key untuk suite tambahan adalah placeholder non-secret; repository test terkontrol. Ini adalah dua eksekusi dengan cakupan beririsan, bukan 213 test unik. [Ringkasan mesin](checks.json).

10. **APK debug.** `flutter build apk --debug --dart-define-from-file=.secrets/geoapify.dev.json`: exit 0, assembleDebug sekitar 25,3 detik. Artefak `build/app/outputs/flutter-apk/app-debug.apk`, ukuran 205.031.430 byte. Instalasi menggunakan `adb install -r` berhasil tanpa menghapus data aplikasi. SHA-256 APK lokal dan APK terpasang cocok: `5569f32fed8f2e97fd6a95f74f7b2b08e971ec6b12c7475b2093f933ac96429c`. Seluruh runtime di tabel menggunakan APK yang hash-nya cocok ini. Beberapa percobaan navigasi otomatis perlu diulang karena splash/posisi scroll; percobaan yang belum mencapai layar tujuan tidak dihitung sebagai keberhasilan skenario.

11. **Batas verifikasi dan catatan tersisa.** Belum ada pengujian pada Android fisik. HTTP 401/429/500 dan timeout diverifikasi lewat test terkontrol; runtime live menguji sukses, empty, koneksi putus, penolakan izin, dan manual. Build mengeluarkan warning kompatibilitas Kotlin Gradle Plugin pada firebase_auth/firebase_core untuk versi Flutter mendatang. Build debug tetap menyematkan key dari dart-define sesuai arsitektur prototipe. Build tanpa key masih memiliki mode demo bawaan; seluruh bukti live di laporan memakai key eksplisit. Label marker origin manual masih “Kamu di sini”, walaupun koordinatnya adalah area manual yang dipilih. Label ini merupakan keterbatasan UI kecil; pusat pencarian/peta dan pemisahan manual/GPS telah diverifikasi. Metadata venue mengikuti ketersediaan Geoapify. Ruang disk host tersisa sekitar 2,0 GiB.

12. **Kesiapan Android fisik.** **Siap untuk pengujian perangkat Android fisik menggunakan APK debug ini.** Validasi GPS fisik, kualitas akurasi, dan perilaku izin pada perangkat nyata merupakan tahap berikutnya. Jaringan dan izin lokasi emulator telah dipulihkan; fix GPS terakhir adalah Mountain View, dengan pilihan aplikasi Bandung manual untuk menunjukkan keduanya tetap independen.
