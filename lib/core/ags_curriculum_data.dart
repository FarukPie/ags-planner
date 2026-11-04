import 'package:flutter/material.dart';

/// MEB-AGS curriculum, following the official ÖSYM documents:
/// * AGS (80 soru) + Özel Eğitim ÖABT: "AGS Konu Dağılımı" 08.01.2026
///   (dokuman.osym.gov.tr/pdfdokuman/2026/MEB-AGS/konudagilimi08012026.pdf)
/// * Other 16 ÖABT fields: "MEB-AGS Açıklama ve Konu Dağılımları" 16.01.2025
///   (dokuman.osym.gov.tr/pdfdokuman/2025/MEB-AGS/konudagilimi16012025.pdf)
/// * Which fields have an ÖABT / use YDS: 2026-MEB-AGS Kılavuzu md. 1.3, 3.1.
///
/// Topic names and weights (%) are official. `detail` texts in quotes from the
/// documents are official; the rest are study hints (marked in [CurriculumTopic]).
///
/// Topic ids are derived from the lesson key + topic NAME (see [topicId]), so
/// lists can be reordered safely; renaming a topic starts its progress fresh.

class CurriculumTopic {
  final String name;

  /// Approximate share of the test (%), when the official document gives it.
  final double? weight;

  /// Scope description shown under the topic.
  final String? detail;

  /// True when [detail] is quoted from the official document.
  final bool officialDetail;

  const CurriculumTopic(this.name, {this.weight, this.detail, this.officialDetail = false});
}

class CurriculumLesson {
  final String key;
  final String name;
  final List<CurriculumTopic> topics;

  /// Approximate number of questions in the real exam (null = not an exam test).
  final int? questions;

  /// Share of its test (%), e.g. 18.75 of AGS.
  final double? share;

  /// Official long name when [name] is shortened for the UI.
  final String? officialName;

  const CurriculumLesson(this.key, this.name, this.topics, {this.questions, this.share, this.officialName});

  String topicId(int index) => '${key}_${slug(topics[index].name)}';

  /// Turkish-aware ASCII slug: "Sözcükte Anlam" → "sozcukte_anlam".
  static String slug(String s) {
    const map = {'ç': 'c', 'ğ': 'g', 'ı': 'i', 'İ': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', 'â': 'a', 'î': 'i', 'û': 'u'};
    final b = StringBuffer();
    for (final ch in s.replaceAll('I', 'ı').toLowerCase().split('')) {
      b.write(map[ch] ?? ch);
    }
    return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  }
}

/// One scored test/subtest in a mock exam (used by the exam editor).
typedef ExamSection = ({String name, int questions});

/// How a field is assessed in MEB-AGS.
enum BranchCategory {
  /// Common AGS + Öğretmenlik Alan Bilgisi Testi (50 soru).
  oabt('ÖABT Alanları', 'AGS + Alan Bilgisi Testi'),

  /// Foreign languages: AGS + YDS/e-YDS score instead of ÖABT.
  language('Yabancı Diller', 'AGS + YDS / e-YDS'),

  /// Every other field: only the AGS (MEB-AGS-P1) score.
  agsOnly('Diğer Alanlar', 'Yalnızca AGS (P1)');

  const BranchCategory(this.title, this.assessment);

  final String title;
  final String assessment;
}

class FieldBranch {
  final String key;
  final String name;
  final BranchCategory category;
  final IconData icon;
  final Color color;

  /// ÖABT duration in minutes (null for non-ÖABT fields).
  final int? oabtMinutes;
  final List<CurriculumLesson> lessons;

  /// True when ÖSYM scores the ÖABT lessons as separate subtests
  /// (only Din Kültürü / İHL Meslek Dersleri).
  final bool scoredBySubtest;

  const FieldBranch(
    this.key,
    this.name,
    this.category,
    this.icon,
    this.color, {
    this.oabtMinutes,
    this.lessons = const [],
    this.scoredBySubtest = false,
  });

  String get examInfo => switch (category) {
        BranchCategory.oabt => 'ÖABT • 50 soru • $oabtMinutes dk',
        BranchCategory.language => 'YDS / e-YDS puanı',
        BranchCategory.agsOnly => 'Yalnızca AGS puanı',
      };

  /// ÖABT tests as they appear on the answer sheet.
  List<ExamSection> get oabtSections => switch (category) {
        BranchCategory.oabt when scoredBySubtest => [
            for (final l in lessons) (name: l.name, questions: l.questions ?? 0),
          ],
        BranchCategory.oabt => const [(name: 'ÖABT', questions: 50)],
        _ => const [],
      };
}

typedef _T = CurriculumTopic;

class AgsCurriculum {
  AgsCurriculum._();

  static const agsQuestions = 80;
  static const agsMinutes = 110;
  static const oabtQuestions = 50;

  /// AGS — taken by every candidate (2026 distribution).
  static const List<CurriculumLesson> commonLessons = [
    CurriculumLesson('sozel', 'Sözel Yetenek', questions: 15, share: 18.75, [
      _T('Sözcükte Anlam', detail: 'Gerçek, mecaz ve yan anlam; deyim ve atasözleri; sözcükler arası anlam ilişkileri'),
      _T('Cümlede Anlam', detail: 'Cümle yorumlama; neden-sonuç, amaç-sonuç, koşul; öznel ve nesnel yargılar'),
      _T('Anlatımın Oluşması', detail: 'Anlatım biçimleri ve düşünceyi geliştirme yolları; anlatım bozuklukları'),
      _T('Paragrafta Anlam', detail: 'Ana ve yardımcı düşünce; paragraf tamamlama ve akışı bozan cümle'),
      _T('Sözel Mantık', detail: 'Sıralama, eşleştirme ve gruplama içeren sözel akıl yürütme'),
    ]),
    CurriculumLesson('sayisal', 'Sayısal Yetenek', questions: 15, share: 18.75, [
      _T('Temel Matematik',
          detail: 'Sayılar, bölünebilme, rasyonel sayılar, üslü-köklü ifadeler, oran-orantı, denklemler ve problemler'),
      _T('Grafik ve Tablo Yorumlama', detail: 'Sütun, çizgi ve daire grafikleri; tablo okuma ve karşılaştırma'),
      _T('Mantıksal Muhakeme Problemleri', detail: 'Sayısal mantık, örüntüler, sıralama ve olasılık temelli akıl yürütme'),
    ]),
    CurriculumLesson('tarih', 'Tarih', questions: 6, share: 7.5, [
      _T('Osmanlı Öncesi Türk Devletleri Tarihi',
          detail: 'Siyasal, sosyal, ekonomik ve kültürel gelişmeler', officialDetail: true),
      _T('Osmanlı Tarihi',
          detail: 'XIII. yüzyıldan XX. yüzyıl başlarına kadar yaşanan siyasal, sosyal, ekonomik ve kültürel gelişmeler',
          officialDetail: true),
      _T('Atatürk İlkeleri ve İnkılap Tarihi',
          detail: 'Osmanlı Devleti\'nin yıkılışından İkinci Dünya Savaşı\'nın sonuna kadar Türkiye tarihinde yaşanan '
              'siyasal, sosyal, ekonomik ve kültürel gelişmeler',
          officialDetail: true),
      _T('Çağdaş Türk ve Dünya Tarihi',
          detail: 'XX. yüzyılın başlangıcından günümüze dünyada; İkinci Dünya Savaşı\'ndan günümüze Türkiye\'de yaşanan '
              'gelişmeler',
          officialDetail: true),
    ]),
    CurriculumLesson('cografya', 'Türkiye Coğrafyası', questions: 6, share: 7.5, [
      _T('Türkiye Fiziki Coğrafyası', detail: 'Konum, yer şekilleri, iklim, bitki örtüsü, toprak ve su kaynakları'),
      _T('Türkiye Beşerî ve Ekonomik Coğrafyası',
          detail: 'Nüfus, yerleşme ve göç; tarım, hayvancılık, madenler, enerji, sanayi, ulaşım, ticaret ve turizm'),
    ]),
    CurriculumLesson('egitim', 'Eğitim Bilimleri', questions: 30, share: 37.5,
        officialName: 'Eğitim Bilimleri ve Türk Millî Eğitim Sistemi', [
      _T('Eğitim Tarihi, Felsefi, Toplumsal, Ekonomik ve Politik Temelleri'),
      _T('Öğretim Yöntem ve Teknikleri'),
      _T('Sınıf Yönetimi'),
      _T('Program Okuryazarlığı'),
      _T('Eğitimde Ölçme ve Değerlendirme'),
      _T('Öğrenme Psikolojisi'),
      _T('Gelişim Psikolojisi'),
      _T('Rehberlik'),
      _T('Eğitim ve Öğretim Teknolojileri'),
      _T('Türk Millî Eğitim Sisteminin Genel Yapısı'),
      _T('Türkiye Yüzyılı Maarif Modeli'),
    ]),
    CurriculumLesson('mevzuat', 'Mevzuat', questions: 8, share: 10, [
      _T('Türkiye Cumhuriyeti Anayasası', detail: 'Kanun No: 2709, Kabul Tarihi: 18/10/1982', officialDetail: true),
      _T('İnsan Hakları Hukuku'),
      _T('1739 sayılı Millî Eğitim Temel Kanunu'),
      _T('222 sayılı İlköğretim ve Eğitim Kanunu'),
      _T('7528 sayılı Öğretmenlik Mesleği Kanunu'),
    ]),
  ];

  /// AGS subtests as scored by ÖSYM (6 alt test).
  static List<ExamSection> get agsSections => [
        for (final l in commonLessons) (name: l.name, questions: l.questions!),
      ];

  /// Every scored test for a mock exam in [branchKey]: AGS subtests + ÖABT.
  static List<ExamSection> examSections(String branchKey) =>
      [...agsSections, ...branchByKey(branchKey).oabtSections];

  static CurriculumLesson _oabt(String key, String name, List<CurriculumTopic> topics,
          {int questions = oabtQuestions, double share = 100}) =>
      CurriculumLesson(key, 'ÖABT – $name', topics, questions: questions, share: share);

  static const _ydsTopics = [
    _T('Kelime Bilgisi (Vocabulary)'),
    _T('Dil Bilgisi (Grammar)'),
    _T('Cloze Test'),
    _T('Cümle Tamamlama'),
    _T('Çeviri (Yabancı Dil → Türkçe)'),
    _T('Çeviri (Türkçe → Yabancı Dil)'),
    _T('Okuma Parçaları'),
    _T('Diyalog Tamamlama'),
    _T('Anlamca En Yakın Cümle'),
    _T('Paragraf Tamamlama'),
    _T('Anlam Bütünlüğünü Bozan Cümle'),
  ];

  static FieldBranch _language(String key, String name, Color color) => FieldBranch(
        key,
        '$name Öğretmenliği',
        BranchCategory.language,
        Icons.translate_rounded,
        color,
        lessons: [CurriculumLesson('yds_$key', 'YDS – $name', _ydsTopics)],
      );

  static FieldBranch _agsOnly(String key, String name, IconData icon, Color color) =>
      FieldBranch(key, name, BranchCategory.agsOnly, icon, color);

  /// All teaching fields, grouped by [BranchCategory].
  static final List<FieldBranch> fieldBranches = [
    // ------------------------------------------------------------ ÖABT (17)
    FieldBranch('sinif', 'Sınıf Öğretmenliği', BranchCategory.oabt, Icons.child_care_rounded,
        const Color(0xFF7B5CFA), oabtMinutes: 70, lessons: [
      _oabt('sinif_ab', 'Alan Bilgisi', questions: 17, share: 34, const [
        _T('İlkokulda Temel Matematik', weight: 6),
        _T('İlkokulda Temel Fen Bilimleri', weight: 10),
        _T('Türk Dili', weight: 6),
        _T('Türk Tarihi ve Kültürü', weight: 4),
        _T('Türkiye Coğrafyası ve Jeopolitiği', weight: 4),
        _T('Çocuk Edebiyatı', weight: 4),
      ]),
      _oabt('sinif_ae', 'Alan Eğitimi', questions: 33, share: 66, const [
        _T('Hayat Bilgisi Öğretimi'),
        _T('Sosyal Bilgiler Öğretimi'),
        _T('Din Kültürü ve Ahlak Bilgisi Öğretimi'),
        _T('Fen Bilgisi Öğretimi'),
        _T('Matematik Öğretimi'),
        _T('İlk Okuma ve Yazma Öğretimi'),
        _T('Drama'),
        _T('Görsel Sanatlar Öğretimi'),
        _T('Müzik Öğretimi'),
      ]),
    ]),
    FieldBranch('turkce', 'Türkçe Öğretmenliği', BranchCategory.oabt, Icons.menu_book_rounded,
        const Color(0xFFE85D9E), oabtMinutes: 70, lessons: [
      _oabt('turkce_ab', 'Türkçe', const [
        _T('Anlama ve Anlatma Teknikleri', weight: 32),
        _T('Dil Bilgisi ve Dil Bilimi', weight: 24),
        _T('Çocuk Edebiyatı', weight: 6),
        _T('Türk Halk Edebiyatı', weight: 10),
        _T('Eski Türk Edebiyatı', weight: 10),
        _T('Yeni Türk Edebiyatı', weight: 10),
        _T('Edebiyat Bilgi ve Kuramları', weight: 8),
      ]),
    ]),
    FieldBranch('matematik', 'İlköğretim Matematik Öğretmenliği', BranchCategory.oabt, Icons.calculate_rounded,
        const Color(0xFF4F7DF9), oabtMinutes: 90, lessons: [
      _oabt('ilkmat_ab', 'İlköğretim Matematik', const [
        _T('Analiz', weight: 36),
        _T('Cebir', weight: 24),
        _T('Geometri', weight: 24),
        _T('Uygulamalı Matematik', weight: 16),
      ]),
    ]),
    FieldBranch('fen', 'Fen Bilimleri Öğretmenliği', BranchCategory.oabt, Icons.science_rounded,
        const Color(0xFF00B8A9), oabtMinutes: 90, lessons: [
      _oabt('fen_ab', 'Fen Bilimleri', const [
        _T('Fizik', weight: 32),
        _T('Kimya', weight: 30),
        _T('Biyoloji', weight: 26),
        _T('Jeoloji (Yer Bilimi)', weight: 4),
        _T('Astronomi', weight: 4),
        _T('Çevre Bilimi', weight: 4),
      ]),
    ]),
    FieldBranch('sosyal', 'Sosyal Bilgiler Öğretmenliği', BranchCategory.oabt, Icons.groups_rounded,
        const Color(0xFFFF7A59), oabtMinutes: 70, lessons: [
      _oabt('sosyal_ab', 'Sosyal Bilgiler', const [
        _T('Tarih', weight: 44),
        _T('Coğrafya', weight: 24),
        _T('Siyaset Bilimi', weight: 16),
        _T('Diğer Sosyal Bilim Alanları',
            weight: 16,
            officialDetail: true,
            detail: 'Sosyal Bilgilerin Temelleri, Bilim Teknoloji ve Toplum, Sosyal Antropoloji ve Medeniyet Tarihi, '
                'Ekonomi, İnsan İlişkileri ve İletişim, Sosyoloji, Sosyal Proje Geliştirme'),
      ]),
    ]),
    FieldBranch('edebiyat', 'Türk Dili ve Edebiyatı Öğretmenliği', BranchCategory.oabt, Icons.history_edu_rounded,
        const Color(0xFF9B6BFF), oabtMinutes: 70, lessons: [
      _oabt('edebiyat_ab', 'Türk Dili ve Edebiyatı', const [
        _T('Eski Türk Dili ve Yeni Türk Dili', weight: 30),
        _T('Türk Halk Edebiyatı', weight: 20),
        _T('Eski Türk Edebiyatı', weight: 20),
        _T('Yeni Türk Edebiyatı', weight: 30),
      ]),
    ]),
    FieldBranch('tarih_ogr', 'Tarih Öğretmenliği', BranchCategory.oabt, Icons.account_balance_rounded,
        const Color(0xFFFF8A3D), oabtMinutes: 70, lessons: [
      _oabt('tarih_ab', 'Tarih', const [
        _T('Tarih Metodolojisi', weight: 8),
        _T('Osmanlı Türkçesi', weight: 6),
        _T('Eski Çağ Tarihi', weight: 4),
        _T('İlk Türk Devletleri Tarihi', weight: 10),
        _T('Orta Çağ İslam Tarihi', weight: 14),
        _T('Osmanlı Tarihi', weight: 18),
        _T('Türkiye Cumhuriyeti Tarihi', weight: 16),
        _T('Orta Çağ\'dan XX. Yüzyıl\'a Dünya Tarihi', weight: 14),
        _T('XX. Yüzyıl Türk ve Dünya Tarihi', weight: 10),
      ]),
    ]),
    FieldBranch('cografya_ogr', 'Coğrafya Öğretmenliği', BranchCategory.oabt, Icons.public_rounded,
        const Color(0xFF3FC380), oabtMinutes: 70, lessons: [
      _oabt('cografya_ab', 'Coğrafya', const [
        _T('Fiziki Coğrafya', weight: 40),
        _T('Beşerî ve Ekonomik Coğrafya', weight: 40),
        _T('Kıtalar ve Ülkeler Coğrafyası', weight: 20),
      ]),
    ]),
    FieldBranch('matematik_lise', 'Matematik Öğretmenliği (Lise)', BranchCategory.oabt, Icons.functions_rounded,
        const Color(0xFF5B6CF9), oabtMinutes: 90, lessons: [
      _oabt('mat_ab', 'Matematik', const [
        _T('Analiz', weight: 36),
        _T('Cebir', weight: 24),
        _T('Geometri', weight: 20),
        _T('Uygulamalı Matematik', weight: 20),
      ]),
    ]),
    FieldBranch('fizik', 'Fizik Öğretmenliği', BranchCategory.oabt, Icons.bolt_rounded,
        const Color(0xFF38B6F5), oabtMinutes: 90, lessons: [
      _oabt('fizik_ab', 'Fizik', const [
        _T('Mekanik', weight: 30),
        _T('Elektrik ve Manyetizma', weight: 24),
        _T('Maddenin Mekanik ve Isıl Özellikleri', weight: 10),
        _T('Dalgalar ve Optik', weight: 16),
        _T('Modern Fizik', weight: 20),
      ]),
    ]),
    FieldBranch('kimya', 'Kimya / Kimya Teknolojisi Öğretmenliği', BranchCategory.oabt, Icons.biotech_rounded,
        const Color(0xFFFFB648), oabtMinutes: 90, lessons: [
      _oabt('kimya_ab', 'Kimya', const [
        _T('Temel Kimya', weight: 32),
        _T('Analitik Kimya', weight: 20),
        _T('Anorganik Kimya', weight: 16),
        _T('Organik Kimya', weight: 20),
        _T('Fizikokimya', weight: 12),
      ]),
    ]),
    FieldBranch('biyoloji', 'Biyoloji Öğretmenliği', BranchCategory.oabt, Icons.eco_rounded,
        const Color(0xFF2EAD6B), oabtMinutes: 70, lessons: [
      _oabt('biyoloji_ab', 'Biyoloji', const [
        _T('Hücre ve Metabolizma', weight: 20),
        _T('Bitki Biyolojisi', weight: 12),
        _T('İnsan ve Hayvan Biyolojisi', weight: 28),
        _T('Ekoloji', weight: 12),
        _T('Canlıların Sınıflandırılması', weight: 8),
        _T('Genetik', weight: 20),
      ]),
    ]),
    FieldBranch('din', 'Din Kültürü ve Ahlâk Bilgisi / İHL Meslek Dersleri', BranchCategory.oabt,
        Icons.auto_stories_rounded, const Color(0xFF00A3A3), oabtMinutes: 70, scoredBySubtest: true, lessons: [
      _oabt('din_ortak', 'Ortak Alan Bilgisi', questions: 10, share: 20, const [
        _T('Kur\'an-ı Kerim ve Tecvid', weight: 8),
        _T('Fıkıh (Ortak)', weight: 4),
        _T('Akaid', weight: 2),
        _T('Siyer', weight: 6),
      ]),
      _oabt('din_temel', 'Temel İslam Bilimleri', questions: 23, share: 46, const [
        _T('Tefsir', weight: 10),
        _T('Hadis', weight: 10),
        _T('Fıkıh', weight: 10),
        _T('Kelam', weight: 10),
        _T('İslam Mezhepleri ve Akımları', weight: 6),
      ]),
      _oabt('din_tarih', 'İslam Tarihi, Felsefe ve Din Bilimleri', questions: 17, share: 34, const [
        _T('İslam Tarihi, Kültür ve Medeniyeti', weight: 10),
        _T('İslam Felsefesi', weight: 4),
        _T('Din Felsefesi', weight: 4),
        _T('Din Sosyolojisi', weight: 4),
        _T('Din Psikolojisi', weight: 4),
        _T('Din Eğitimi', weight: 4),
        _T('Dinler Tarihi', weight: 4),
      ]),
    ]),
    FieldBranch('rehberlik', 'Rehberlik ve Psikolojik Danışmanlık', BranchCategory.oabt, Icons.psychology_rounded,
        const Color(0xFFD96CF5), oabtMinutes: 70, lessons: [
      _oabt('rehberlik_ab', 'Rehberlik', const [
        _T('Temel Psikolojik Kavramlar', weight: 16),
        _T('Psikolojik Danışma Kuram, İlke ve Teknikleri', weight: 20),
        _T('Davranış ve Uyum Problemleri', weight: 12),
        _T('Bireyi Tanıma Teknikleri', weight: 14),
        _T('Bireyle ve Grupla Psikolojik Danışma', weight: 14),
        _T('Mesleki Rehberlik ve Kariyer Danışmanlığı', weight: 12),
        _T('PDR\'de Araştırma ve Program Geliştirme', weight: 8),
        _T('Meslek Etiği ve Yasal Konular', weight: 4),
      ]),
    ]),
    FieldBranch('okuloncesi', 'Okul Öncesi Öğretmenliği', BranchCategory.oabt, Icons.toys_rounded,
        const Color(0xFFFF6F91), oabtMinutes: 70, lessons: [
      _oabt('okuloncesi_ab', 'Alan Bilgisi', questions: 30, share: 60, const [
        _T('Erken Çocukluk Eğitimine Giriş', weight: 8),
        _T('Çocuk Sağlığı ve İlk Yardım', weight: 4),
        _T('Erken Çocukluk Döneminde Gelişim', weight: 12),
        _T('Çocuk Ruh Sağlığı', weight: 8),
        _T('Erken Çocukluk Dönemi Edebiyatı', weight: 6),
        _T('Erken Çocuklukta Program, Yöntem ve Yaklaşımlar', weight: 12),
        _T('Anne-Baba Eğitimi', weight: 6),
        _T('Çocuk Hakları', weight: 4),
      ]),
      _oabt('okuloncesi_ae', 'Alan Eğitimi', questions: 20, share: 40, const [
        _T('Erken Çocuklukta Fen Eğitimi'),
        _T('Erken Çocuklukta Matematik Eğitimi'),
        _T('Erken Çocuklukta Güzel Sanatlar Eğitimi'),
        _T('Erken Çocuklukta Müzik Eğitimi'),
        _T('Erken Çocukluk Eğitiminde Oyun'),
        _T('Erken Çocukluk Eğitiminde Drama'),
        _T('Erken Çocukluk Eğitiminde Öğrenme Yaklaşımları'),
        _T('Okula Uyum ve Erken Okuryazarlık Eğitimi'),
      ]),
    ]),
    FieldBranch('beden', 'Beden Eğitimi ve Spor Öğretmenliği', BranchCategory.oabt, Icons.sports_soccer_rounded,
        const Color(0xFFFF5F6D), oabtMinutes: 70, lessons: [
      _oabt('beden_ab', 'Beden Eğitimi', const [
        _T('Beden Eğitimi ve Sporun Temelleri', weight: 16),
        _T('İnsan Anatomisi ve Kinesiyoloji', weight: 8),
        _T('Sağlık Bilgisi ve İlk Yardım', weight: 6),
        _T('Egzersiz Fizyolojisi', weight: 8),
        _T('Antrenman Bilgisi', weight: 6),
        _T('Fiziksel Uygunluk', weight: 6),
        _T('Egzersiz ve Beslenme', weight: 4),
        _T('Engelliler İçin Beden Eğitimi ve Spor', weight: 4),
        _T('Psikomotor Gelişim', weight: 6),
        _T('Beden Eğitimi ve Spor Yönetimi', weight: 4),
        _T('Beceri Öğrenimi', weight: 6),
        _T('Atletizm', weight: 4),
        _T('Takım Sporları', weight: 10),
        _T('Ritim Eğitimi ve Dans, Halk Oyunları', weight: 4),
        _T('Jimnastik', weight: 4),
        _T('Eğitsel Oyunlar', weight: 4),
      ]),
    ]),
    FieldBranch('ozel_egitim', 'Özel Eğitim Öğretmenliği', BranchCategory.oabt, Icons.accessibility_new_rounded,
        const Color(0xFF8E7CFF), oabtMinutes: 70, lessons: [
      _oabt('ozel_ab', 'Alan Bilgisi', questions: 30, share: 60, const [
        _T('Zihin Yetersizliği ve Otizm Spektrum Bozukluğu', weight: 10),
        _T('Öğrenme Güçlüğü ve Özel Yetenek', weight: 6),
        _T('İşitme ve Görme Yetersizliği', weight: 10),
        _T('Erken Çocuklukta Özel Eğitim', weight: 4),
        _T('Uygulamalı Davranış Analizi', weight: 8),
        _T('Bireyselleştirilmiş Eğitim Programları', weight: 6),
        _T('Özel Eğitimde Değerlendirme', weight: 6),
        _T('Dil ve İletişim Becerilerinin Desteklenmesi', weight: 4),
        _T('Özel Eğitim Politikaları ve Yasal Düzenlemeler', weight: 6),
      ]),
      _oabt('ozel_ae', 'Alan Eğitimi', questions: 20, share: 40, const [
        _T('2024 TYMM Özel Eğitim Programları', weight: 4),
        _T('Özel Eğitimde Okuma-Yazma Öğretimi', weight: 4),
        _T('Özel Eğitimde Fen ve Sosyal Bilgiler Öğretimi', weight: 4),
        _T('Özel Eğitimde Matematik Öğretimi', weight: 4),
        _T('Özel Eğitimde Sanatsal Becerilerin Öğretimi', weight: 4),
        _T('Özel Eğitimde Fiziksel Eğitim ve Spor', weight: 4),
        _T('Özel Eğitimde Sosyal Uyum Becerilerinin Öğretimi', weight: 4),
        _T('Özel Eğitimde Türkçe Öğretimi', weight: 4),
        _T('Özel Eğitimde Oyun ve Müzik', weight: 4),
        _T('Özel Eğitimde Aile Eğitimi', weight: 4),
      ]),
    ]),

    // ------------------------------------------------------------ YDS (11)
    _language('ingilizce', 'İngilizce', const Color(0xFF4F7DF9)),
    _language('almanca', 'Almanca', const Color(0xFFFFB648)),
    _language('arapca', 'Arapça', const Color(0xFF3FC380)),
    _language('fransizca', 'Fransızca', const Color(0xFF5B6CF9)),
    _language('ispanyolca', 'İspanyolca', const Color(0xFFFF5F6D)),
    _language('italyanca', 'İtalyanca', const Color(0xFF2EAD6B)),
    _language('rusca', 'Rusça', const Color(0xFF38B6F5)),
    _language('cince', 'Çince', const Color(0xFFE53935)),
    _language('japonca', 'Japonca', const Color(0xFFE85D9E)),
    _language('korece', 'Korece', const Color(0xFF7B5CFA)),
    _language('farsca', 'Farsça', const Color(0xFF00A3A3)),

    // ------------------------------------------------------------ AGS only
    _agsOnly('bilisim', 'Bilişim Teknolojileri', Icons.computer_rounded, const Color(0xFF4F7DF9)),
    _agsOnly('gorsel', 'Görsel Sanatlar', Icons.palette_rounded, const Color(0xFFE85D9E)),
    _agsOnly('muzik', 'Müzik', Icons.music_note_rounded, const Color(0xFF9B6BFF)),
    _agsOnly('teknoloji_tasarim', 'Teknoloji ve Tasarım', Icons.design_services_rounded, const Color(0xFFFF7A59)),
    _agsOnly('felsefe', 'Felsefe', Icons.lightbulb_rounded, const Color(0xFFFFB648)),
    _agsOnly('elektrik', 'Elektrik-Elektronik Teknolojisi', Icons.electrical_services_rounded, const Color(0xFFFFB648)),
    _agsOnly('makine', 'Makine ve Tasarım Teknolojisi', Icons.precision_manufacturing_rounded, const Color(0xFF8D99AE)),
    _agsOnly('motorlu', 'Motorlu Araçlar Teknolojisi', Icons.directions_car_rounded, const Color(0xFF38B6F5)),
    _agsOnly('metal', 'Metal Teknolojisi', Icons.hardware_rounded, const Color(0xFF8D99AE)),
    _agsOnly('insaat', 'İnşaat Teknolojisi', Icons.construction_rounded, const Color(0xFFFF8A3D)),
    _agsOnly('muhasebe', 'Muhasebe ve Finansman', Icons.account_balance_wallet_rounded, const Color(0xFF3FC380)),
    _agsOnly('buro', 'Büro Yönetimi', Icons.business_center_rounded, const Color(0xFF5B6CF9)),
    _agsOnly('pazarlama', 'Pazarlama ve Perakende', Icons.storefront_rounded, const Color(0xFFFF6F91)),
    _agsOnly('cocuk_gelisimi', 'Çocuk Gelişimi ve Eğitimi', Icons.family_restroom_rounded, const Color(0xFFFF6F91)),
    _agsOnly('saglik', 'Sağlık Hizmetleri', Icons.health_and_safety_rounded, const Color(0xFFFF5F6D)),
    _agsOnly('yiyecek', 'Yiyecek İçecek Hizmetleri', Icons.restaurant_rounded, const Color(0xFFFF8A3D)),
    _agsOnly('konaklama', 'Konaklama ve Seyahat Hizmetleri', Icons.hotel_rounded, const Color(0xFF00B8A9)),
    _agsOnly('guzellik', 'Güzellik ve Saç Bakım Hizmetleri', Icons.face_retouching_natural_rounded, const Color(0xFFD96CF5)),
    _agsOnly('moda', 'Moda Tasarım Teknolojileri', Icons.checkroom_rounded, const Color(0xFFE85D9E)),
    _agsOnly('grafik', 'Grafik ve Fotoğraf', Icons.photo_camera_rounded, const Color(0xFF7B5CFA)),
    _agsOnly('mobilya', 'Mobilya ve İç Mekân Tasarımı', Icons.chair_rounded, const Color(0xFFB07D4F)),
    _agsOnly('tarim', 'Tarım', Icons.agriculture_rounded, const Color(0xFF2EAD6B)),
    _agsOnly('gida', 'Gıda Teknolojisi', Icons.bakery_dining_rounded, const Color(0xFFFFB648)),
    _agsOnly('harita', 'Harita-Tapu-Kadastro', Icons.map_rounded, const Color(0xFF00A3A3)),
    _agsOnly('el_sanatlari', 'El Sanatları Teknolojisi', Icons.brush_rounded, const Color(0xFFFF7A59)),
    _agsOnly('diger', 'Diğer / Listede Olmayan Alan', Icons.more_horiz_rounded, const Color(0xFF8D99AE)),
  ];

  static FieldBranch? tryBranch(String? key) =>
      fieldBranches.where((b) => b.key == key).firstOrNull;

  static FieldBranch branchByKey(String key) => tryBranch(key) ?? fieldBranches.first;

  /// Lessons the user studies: common section + their selected field branch.
  static List<CurriculumLesson> lessonsFor(String branchKey) =>
      [...commonLessons, ...branchByKey(branchKey).lessons];

  /// Lesson metadata by display name (null for legacy/unknown names).
  static CurriculumLesson? lessonNamed(String name) => [
        ...commonLessons,
        for (final b in fieldBranches) ...b.lessons,
      ].where((l) => l.name == name).firstOrNull;
}
