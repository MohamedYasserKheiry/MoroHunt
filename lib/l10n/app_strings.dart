import '../providers/locale_provider.dart';

/// Centralized translation dictionary. Every user-facing string the
/// app knows how to localize lives here, keyed by a short snake_case
/// id, with one value per supported language.
///
/// NOTE ON AMAZIGH (زgh) STRINGS: these are a good-faith best-effort
/// pass, not a native-speaker-reviewed translation. Simple concrete
/// terms (خريطة/map, حفظ/save, إلغاء/cancel) got a semantic Tamazight
/// gloss; a few more abstract/institutional terms (e.g. "leaderboard",
/// "legal compliance") lean on a Tifinagh transliteration of the
/// French/English term where I wasn't confident a precise semantic
/// equivalent exists — this is common practice in real Tamazight tech
/// localization, but it still needs a native speaker to sign off
/// before shipping. Ship the mechanism now; get the Amazigh copy
/// reviewed before this goes live.
class AppStrings {
  AppStrings._();

  static const Map<String, Map<String, String>> _values = {
    // --- Bottom navigation --------------------------------------------
    'nav_map': {
      'ar': 'خريطة القنص',
      'zgh': 'ⵜⴰⴽⴰⵕⴹⴰ ⵏ ⵓⵚⵢⴰⴷ',
      'fr': 'Carte de chasse',
      'en': 'Hunting Map',
    },
    'nav_leaderboard': {
      'ar': 'لوحة الشرف',
      'zgh': 'ⵜⴰⴼⵍⵡⴰⵜ ⵏ ⵓⵚⵓⴱⵍ',
      'fr': "Tableau d'honneur",
      'en': 'Leaderboard',
    },
    'nav_group_hunt': {
      'ar': 'قنص جماعي',
      'zgh': 'ⴰⵚⵢⴰⴷ ⵏ ⵜⵔⴰⴱⴱⵓⵜ',
      'fr': 'Chasse en groupe',
      'en': 'Group Hunt',
    },
    'nav_profile': {
      'ar': 'الملف الشخصي',
      'zgh': 'ⴰⴽⴰⵕⴹⴰ ⵏⵏⴻⵎ',
      'fr': 'Profil',
      'en': 'Profile',
    },
    'log_new_catch': {
      'ar': 'تسجيل صيد جديد',
      'zgh': 'ⵙⵙⵉⴼⵍⴷ ⴰⵚⵢⴰⴷ ⴰⵎⴰⵢⵏⵓ',
      'fr': 'Enregistrer une nouvelle prise',
      'en': 'Log New Catch',
    },

    // --- Profile screen -------------------------------------------------
    'profile_title': {
      'ar': 'الملف الشخصي',
      'zgh': 'ⴰⴽⴰⵕⴹⴰ ⵏⵏⴻⵎ',
      'fr': 'Profil',
      'en': 'Profile',
    },
    'game_counter': {
      'ar': 'عداد الطرائد',
      'zgh': 'ⴰⵎⵙⵙⵉⴹⵏ ⵏ ⵜⵡⵓⵔⵉ',
      'fr': 'Compteur de gibier',
      'en': 'Game Counter',
    },
    'achievement_medals': {
      'ar': 'أوسمة الإنجاز',
      'zgh': 'ⵜⵉⵏⵙⴰⵢ ⵏ ⵓⵙⵙⵓⵜⵔ',
      'fr': 'Médailles de succès',
      'en': 'Achievement Medals',
    },
    'my_catch_logs': {
      'ar': 'سجلات الصيد الخاصة بي',
      'zgh': 'ⵉⵙⵙⵓⵖⴰⵍ ⵏ ⵓⵚⵢⴰⴷ ⵉⵏⵓ',
      'fr': 'Mes journaux de chasse',
      'en': 'My Catch Logs',
    },

    // --- Settings sheet ---------------------------------------------
    'settings_title': {
      'ar': 'الإعدادات',
      'zgh': 'ⵉⵙⴻⴼⴽⴰ',
      'fr': 'Paramètres',
      'en': 'Settings',
    },
    'change_language': {
      'ar': 'تغيير اللغة',
      'zgh': 'ⴱⴻⴹⴻⵍ ⵜⵓⵜⵍⴰⵢⵜ',
      'fr': 'Changer la langue',
      'en': 'Change Language',
    },
    'support_chat': {
      'ar': 'التواصل والدعم الذكي',
      'zgh': 'ⴰⵎⵢⴰⵡⴰⴹ ⴷ ⵓⵙⵎⵓⵜⵜⴳ',
      'fr': 'Support intelligent',
      'en': 'Smart Support & Contact',
    },
    'legal_compliance': {
      'ar': 'دستور وقوانين التطبيق',
      'zgh': 'ⴰⵣⵔⴼ ⴷ ⵉⵍⵓⴳⴰⵏ',
      'fr': "Charte et règles de l'application",
      'en': 'App Constitution & Rules',
    },
    'delete_account': {
      'ar': 'حذف الحساب',
      'zgh': 'ⴽⴽⵙ ⴰⵎⵉⴹⴰⵏ',
      'fr': 'Supprimer le compte',
      'en': 'Delete Account',
    },
    'logout': {
      'ar': 'تسجيل الخروج',
      'zgh': 'ⴼⴼⵖ',
      'fr': 'Déconnexion',
      'en': 'Log Out',
    },

    // --- Common actions ------------------------------------------------
    'cancel': {
      'ar': 'إلغاء',
      'zgh': 'ⵙⵔ',
      'fr': 'Annuler',
      'en': 'Cancel',
    },
    'save': {
      'ar': 'حفظ',
      'zgh': 'ⵃⴹⵓ',
      'fr': 'Enregistrer',
      'en': 'Save',
    },
    'ok': {
      'ar': 'حسنًا',
      'zgh': 'ⵢⴰⵓ',
      'fr': "D'accord",
      'en': 'OK',
    },
    'retry': {
      'ar': 'إعادة المحاولة',
      'zgh': 'ⴰⵍⵙ ⴰⵔⵎ',
      'fr': 'Réessayer',
      'en': 'Retry',
    },
    'points_suffix': {
      'ar': 'نقطة',
      'zgh': 'ⵜⴰⵏⵇⵇⵉⴹⵜ',
      'fr': 'points',
      'en': 'points',
    },
    'map_layers_title': {
      'ar': 'طبقات الخريطة',
      'zgh': 'ⵜⵉⵙⴻⴼⵙⵉⵢⵉⵏ ⵏ ⵜⴽⴰⵕⴹⴰ',
      'fr': 'Couches de la carte',
      'en': 'Map Layers',
    },

    // --- Map screen ------------------------------------------------
    'map_search_hint': {
      'ar': 'البحث في الخريطة',
      'zgh': 'ⵔⵣⵓ ⴳ ⵜⴽⴰⵕⴹⴰ',
      'fr': 'Rechercher sur la carte',
      'en': 'Search the map',
    },
    'toggle_satellite': {
      'ar': 'عرض التضاريس والخرائط الواقعية',
      'zgh': 'ⵙⴽⴻⵏ ⴰⴽⴰⵍ ⴷ ⵜⵡⵍⴰⴼⵉⵏ ⵏ ⵜⵉⴷⴻⵜ',
      'fr': 'Afficher le relief et les images satellite',
      'en': 'Show terrain & satellite imagery',
    },
    'photos_layer_tooltip': {
      'ar': 'صور الصيد',
      'zgh': 'ⵜⵉⵡⵍⴰⴼⵉⵏ ⵏ ⵓⵚⵢⴰⴷ',
      'fr': 'Photos de chasse',
      'en': 'Hunt Photos',
    },

    // --- Group hunt screen -------------------------------------------
    'group_hunt_subtitle': {
      'ar': 'ابدأ جلسة صيد جماعي وتتبع أعضاء فريقك مباشرة على الخريطة',
      'zgh': 'ⴱⴷⵓ ⵜⴰⵔⵎⵉⵜ ⵏ ⵓⵚⵢⴰⴷ ⵏ ⵜⵔⴰⴱⴱⵓⵜ ⵜⵟⵟⴻⴼⴹ ⵉⵎⵥⵍⴰ ⵏⵏⴻⵎ ⴳ ⵜⴽⴰⵕⴹⴰ',
      'fr': 'Démarrez une session de chasse en groupe et suivez votre équipe en direct sur la carte',
      'en': 'Start a group hunt session and track your team live on the map',
    },
    'create_room': {
      'ar': 'إنشاء غرفة صيد',
      'zgh': 'ⵙⵏⵓⵍⴼⵓ ⵜⴰⵅⵅⴰⵎⵜ ⵏ ⵓⵚⵢⴰⴷ',
      'fr': 'Créer une salle de chasse',
      'en': 'Create Hunt Room',
    },
    'join_room': {
      'ar': 'انضمام إلى غرفة',
      'zgh': 'ⵕⵥⵎ ⵖⴻⵔ ⵜⵅⵅⴰⵎⵜ',
      'fr': 'Rejoindre une salle',
      'en': 'Join Room',
    },
    'join_hunt_room': {
      'ar': 'انضم إلى غرفة الصيد',
      'zgh': 'ⵕⵥⵎ ⵖⴻⵔ ⵜⵅⵅⴰⵎⵜ ⵏ ⵓⵚⵢⴰⴷ',
      'fr': 'Rejoindre la salle de chasse',
      'en': 'Join Hunt Room',
    },
    'join': {
      'ar': 'انضمام',
      'zgh': 'ⵕⵥⵎ',
      'fr': 'Rejoindre',
      'en': 'Join',
    },
    'room_create_failed': {
      'ar': 'تعذر إنشاء الغرفة',
      'zgh': 'ⵓⵔ ⵢⴻⵥⵎⵉⵔ ⴰⴷ ⵢⵙⵏⵓⵍⴼⵓ ⵜⴰⵅⵅⴰⵎⵜ',
      'fr': 'Impossible de créer la salle',
      'en': 'Could not create the room',
    },
    'room_join_failed': {
      'ar': 'تعذر الانضمام إلى الغرفة',
      'zgh': 'ⵓⵔ ⵢⴻⵥⵎⵉⵔ ⴰⴷ ⵢⵕⵥⴻⵎ ⵖⴻⵔ ⵜⵅⵅⴰⵎⵜ',
      'fr': 'Impossible de rejoindre la salle',
      'en': 'Could not join the room',
    },
    'kicked_title': {
      'ar': 'تم إخراجك',
      'zgh': 'ⵜⵜⵡⴰⵙⵙⵓⴼⴼⴻⵖⴷ',
      'fr': 'Vous avez été retiré',
      'en': 'You Were Removed',
    },
    'kicked_message': {
      'ar': 'تم إخراجك من الغرفة بواسطة المشرف.',
      'zgh': 'ⵜⵜⵡⴰⵙⵙⵓⴼⴼⴻⵖⴷ ⵙⴻⴳ ⵜⵅⵅⴰⵎⵜ ⵙⴻⴳ ⵓⵏⴻⵖⴹⴰⵙ.',
      'fr': "Vous avez été retiré de la salle par l'administrateur.",
      'en': 'You were removed from the room by the admin.',
    },
    'max_hunters_per_room': {
      'ar': 'الحد الأقصى {n} قناصين لكل غرفة',
      'zgh': 'ⴰⵎⵉⵜⵔ ⴰⵎⴻⵇⵇⵔⴰⵏ {n} ⵏ ⵉⵎⵚⵢⴰⴷⵏ ⵉ ⵢⴰⵜ ⵜⵅⵅⴰⵎⵜ',
      'fr': 'Maximum {n} chasseurs par salle',
      'en': 'Max {n} hunters per room',
    },
    'hunt_room_title': {
      'ar': 'غرفة الصيد',
      'zgh': 'ⵜⴰⵅⵅⴰⵎⵜ ⵏ ⵓⵚⵢⴰⴷ',
      'fr': 'Salle de chasse',
      'en': 'Hunt Room',
    },
    'room_members_tooltip': {
      'ar': 'أعضاء الغرفة',
      'zgh': 'ⵉⵎⵥⵍⴰ ⵏ ⵜⵅⵅⴰⵎⵜ',
      'fr': 'Membres de la salle',
      'en': 'Room Members',
    },
    'share_room_code_tooltip': {
      'ar': 'مشاركة رمز الغرفة',
      'zgh': 'ⴱⴹⵓ ⴰⵙⴻⴽⴽⵉⵍ ⵏ ⵜⵅⵅⴰⵎⵜ',
      'fr': 'Partager le code de la salle',
      'en': 'Share Room Code',
    },
    'room_code_label': {
      'ar': 'رمز الغرفة',
      'zgh': 'ⴰⵙⴻⴽⴽⵉⵍ ⵏ ⵜⵅⵅⴰⵎⵜ',
      'fr': 'Code de la salle',
      'en': 'Room Code',
    },
    'leave_room': {
      'ar': 'مغادرة',
      'zgh': 'ⴼⴼⴻⵖ',
      'fr': 'Quitter',
      'en': 'Leave',
    },
    'end_session': {
      'ar': 'إنهاء الجلسة',
      'zgh': 'ⵙⵙⴻⵃⴱⵙ ⵜⴰⵔⵎⵉⵜ',
      'fr': 'Terminer la session',
      'en': 'End Session',
    },

    // --- Leaderboard screen -------------------------------------------
    'search_by_name_hint': {
      'ar': 'البحث بالاسم',
      'zgh': 'ⵔⵣⵓ ⵙ ⵢⵉⵙⴻⵎ',
      'fr': 'Rechercher par nom',
      'en': 'Search by name',
    },
    'no_hunters_yet': {
      'ar': 'لا يوجد قناصة مسجلون بعد',
      'zgh': 'ⵓⵔ ⵢⴻⵍⵍⵉ ⵢⴰⵏ ⵓⵎⵚⵢⴰⴷ ⵢⵜⵜⵡⴰⵙⵎⴻⴽⵜⵍ',
      'fr': 'Aucun chasseur inscrit pour le moment',
      'en': 'No hunters registered yet',
    },
    'no_matching_results': {
      'ar': 'لا توجد نتائج مطابقة',
      'zgh': 'ⵓⵔ ⵍⵍⵉⵏ ⵉⴳⴻⵎⵎⴰⴹ ⵢⵎⵙⴰⵙⴰⵏ',
      'fr': 'Aucun résultat correspondant',
      'en': 'No matching results',
    },
    'error_prefix': {
      'ar': 'خطأ',
      'zgh': 'ⴰⵎⴻⵏⵖⵉ',
      'fr': 'Erreur',
      'en': 'Error',
    },

    // --- Quick catch / log hunt modal ---------------------------------
    'log_hunt_title': {
      'ar': 'تسجيل صيد جديد',
      'zgh': 'ⵙⵙⵉⴼⵍⴷ ⴰⵚⵢⴰⴷ ⴰⵎⴰⵢⵏⵓ',
      'fr': 'Enregistrer une nouvelle prise',
      'en': 'Log New Catch',
    },
    'locating': {
      'ar': 'جارٍ تحديد الموقع...',
      'zgh': 'ⵜⵜⵡⴰⵙⵙⴽⴰⵏ ⵜⴰⵏⵣⵖⵜ...',
      'fr': 'Localisation en cours...',
      'en': 'Locating...',
    },
    'location_found': {
      'ar': 'تم تحديد موقعك تلقائيًا 📍',
      'zgh': 'ⵜⵜⵡⴰⵙⵙⴽⴻⵏ ⵜⴰⵏⵣⵖⵜ ⵏⵏⴻⵎ ⵙ ⵜⵓⴼⴼⵖⴰ 📍',
      'fr': 'Votre position a été détectée automatiquement 📍',
      'en': 'Your location was detected automatically 📍',
    },
    'location_failed_title': {
      'ar': 'تعذر تحديد الموقع',
      'zgh': 'ⵓⵔ ⵢⴻⵥⵎⵉⵔ ⴰⴷ ⵢⴰⴼ ⵜⴰⵏⵣⵖⵜ',
      'fr': 'Localisation impossible',
      'en': 'Could Not Get Location',
    },
    'location_failed_body': {
      'ar': 'لم نتمكن من تحديد موقعك الحالي. تأكد من تفعيل خدمة الموقع (GPS) ومنح التطبيق إذن الوصول إليه، ثم حاول مرة أخرى.',
      'zgh': 'ⵓⵔ ⵏⴻⵥⵎⵉⵔ ⴰⴷ ⵏⴰⴼ ⵜⴰⵏⵣⵖⵜ ⵏⵏⴻⵎ. ⵙⵙⴻⵏⵜⴰⵢ GPS ⴷ ⵜⵙⵉⵔⴰ ⵏ ⵓⵙⵏⴻⵃⵍⴻⵙ, ⵙⵓⵍ ⵄⴰⵡⴻⴷ ⴰⵔⵎ.',
      'fr': "Impossible de déterminer votre position actuelle. Assurez-vous que le GPS est activé et que l'application a la permission d'y accéder, puis réessayez.",
      'en': "We couldn't determine your current location. Make sure GPS is enabled and the app has location permission, then try again.",
    },
    'boar_weight_header': {
      'ar': 'وزن الخنزير البري 🐗',
      'zgh': 'ⴰⵥⴹⴰⵕ ⵏ ⵢⵉⵍⴼ 🐗',
      'fr': 'Poids du sanglier 🐗',
      'en': 'Boar Weight 🐗',
    },
    'weight_normal': {
      'ar': 'عادي',
      'zgh': 'ⴰⵎⴰⴳⵏⵓ',
      'fr': 'Normal',
      'en': 'Normal',
    },
    'weight_heavy': {
      'ar': 'ضخم',
      'zgh': 'ⴰⵎⵇⵇⵔⴰⵏ',
      'fr': 'Lourd',
      'en': 'Heavy',
    },
    'weight_monster': {
      'ar': 'وحش',
      'zgh': 'ⴰⵎⵇⵇⵔⴰⵏ ⴰⵜⴰⵙ',
      'fr': 'Monstre',
      'en': 'Monster',
    },
    'estimated_total_points': {
      'ar': 'إجمالي النقاط المتوقعة',
      'zgh': 'ⴰⵙⵎⴻⴹⵍ ⴰⴽⴻⵎⵎⴰⵍ ⵏ ⵜⵏⵇⵇⵉⴹⵉⵏ',
      'fr': 'Total de points estimé',
      'en': 'Estimated Total Points',
    },
    'confirm_and_log': {
      'ar': 'تأكيد وإضافة للسجل',
      'zgh': 'ⵙⵏⵜⴻⵎ ⵔⵏⵓ ⵖⴻⵔ ⵓⵙⵙⵓⵖⴻⵍ',
      'fr': 'Confirmer et ajouter au journal',
      'en': 'Confirm & Add to Log',
    },
    'new_achievement': {
      'ar': 'إنجاز جديد 🏆',
      'zgh': 'ⴰⵙⵙⴰⵖ ⴰⵎⴰⵢⵏⵓ 🏆',
      'fr': 'Nouveau succès 🏆',
      'en': 'New Achievement 🏆',
    },
    'awesome': {
      'ar': 'رائع!',
      'zgh': 'ⵉⴼⵓⵍⴽⵉ!',
      'fr': 'Génial !',
      'en': 'Awesome!',
    },
    'species_perdrix_short': {
      'ar': 'حجل',
      'zgh': 'ⴰⵊⴻⴷⴽⵉⵜ',
      'fr': 'Perdrix',
      'en': 'Partridge',
    },
    'species_lievre_short': {
      'ar': 'أرنب',
      'zgh': 'ⴰⵡⵜⵓⵍ',
      'fr': 'Lièvre',
      'en': 'Hare',
    },
    'species_sanglier_short': {
      'ar': 'خنزير بري',
      'zgh': 'ⵉⵍⴼ',
      'fr': 'Sanglier',
      'en': 'Boar',
    },
    'species_caille_short': {
      'ar': 'سمان',
      'zgh': 'ⴰⵙⵉⵎⵎⴻⵕ',
      'fr': 'Caille',
      'en': 'Quail',
    },
    'weight_normal_sublabel': {
      'ar': '< 60 كغ · 100 نقطة',
      'zgh': '< 60 ⴽⴳ · 100 ⵜⵏⵇⵇⵉⴹⵜ',
      'fr': '< 60 kg · 100 points',
      'en': '< 60 kg · 100 points',
    },
    'weight_heavy_sublabel': {
      'ar': '60-90 كغ · 120 نقطة',
      'zgh': '60-90 ⴽⴳ · 120 ⵜⵏⵇⵇⵉⴹⵜ',
      'fr': '60-90 kg · 120 points',
      'en': '60-90 kg · 120 points',
    },
    'weight_monster_sublabel': {
      'ar': '+90 كغ · 150 نقطة',
      'zgh': '+90 ⴽⴳ · 150 ⵜⵏⵇⵇⵉⴹⵜ',
      'fr': '+90 kg · 150 points',
      'en': '+90 kg · 150 points',
    },
    'estimated_total_points_prefix': {
      'ar': 'إجمالي النقاط المتوقعة',
      'zgh': 'ⴰⵙⵎⴻⴹⵍ ⴰⴽⴻⵎⵎⴰⵍ ⵏ ⵜⵏⵇⵇⵉⴹⵉⵏ',
      'fr': 'Total de points estimé',
      'en': 'Estimated total points',
    },
    'catch_submit_failed': {
      'ar': 'تعذر تسجيل الصيد',
      'zgh': 'ⵓⵔ ⵢⴻⵥⵎⵉⵔ ⴰⴷ ⵢⵙⵙⵉⴼⴻⴹ ⴰⵚⵢⴰⴷ',
      'fr': "Impossible d'enregistrer la prise",
      'en': 'Could not log the catch',
    },
    'catch_logged_success': {
      'ar': 'تم تسجيل {n} طريدة بنجاح ✅',
      'zgh': 'ⵜⵜⵡⴰⵙⵙⵉⴼⴹ {n} ⵏ ⵜⵡⵓⵔⵉ ⵙ ⵜⵎⴻⵏⵜⵉⵍⵜ ✅',
      'fr': '{n} prise(s) enregistrée(s) avec succès ✅',
      'en': '{n} catch(es) logged successfully ✅',
    },
    'congrats_badge_message': {
      'ar': 'مبروك يا بطل! 🥳 لقد حصلت على وسام {badge} لـ {species} بعد وصولك إلى {count} طريدة!',
      'zgh': 'ⵜⴰⵏⵎⵎⵉⵔⵜ ⴰ ⴰⵎⴰⵀⵉⵔ! 🥳 ⵜⴻⵜⵜⵡⴻⵜ ⴰⵙⵙⴰⵖ {badge} ⵏ {species} ⵎⵏⵏⴻⴽ ⵜⵓⵙⵉⴷ ⵖⴻⵔ {count}!',
      'fr': "Bravo champion ! 🥳 Vous avez obtenu la médaille {badge} pour {species} en atteignant {count} prises !",
      'en': "Congrats, champion! 🥳 You earned the {badge} badge for {species} after reaching {count} catches!",
    },

    // --- Map screen: search & modals -----------------------------------
    'search_no_results': {
      'ar': 'لم يتم العثور على نتائج لهذا البحث',
      'zgh': 'ⵓⵔ ⵢⵜⵜⵡⴰⴼ ⵡⴰⵍⵓ ⵉ ⵓⵔⵣⵣⵓ ⴰⴷ',
      'fr': 'Aucun résultat trouvé pour cette recherche',
      'en': 'No results found for this search',
    },
    'search_failed': {
      'ar': 'تعذر إتمام البحث، حاول مرة أخرى',
      'zgh': 'ⵓⵔ ⵢⴻⵥⵎⵉⵔ ⴰⴷ ⵢⴻⴽⵎⴰⵍ ⴰⵔⵣⵣⵓ, ⴰⵍⵙ ⴰⵔⵎ',
      'fr': 'Recherche impossible, réessayez',
      'en': 'Search failed, please try again',
    },
    'location_failed_generic': {
      'ar': 'تعذر تحديد موقعك الحالي',
      'zgh': 'ⵓⵔ ⵢⴻⵥⵎⵉⵔ ⴰⴷ ⵢⴰⴼ ⵜⴰⵏⵣⵖⵜ ⵏⵏⴻⵎ',
      'fr': 'Impossible de déterminer votre position actuelle',
      'en': 'Could not determine your current location',
    },
    'uploading_photos': {
      'ar': 'جارٍ رفع الصور...',
      'zgh': 'ⵜⵜⵡⴰⵙⵙⵉⵍⵢ ⵜⵉⵡⵍⴰⴼⵉⵏ...',
      'fr': 'Téléchargement des photos...',
      'en': 'Uploading photos...',
    },
    'photo_upload_failed': {
      'ar': 'تعذر رفع الصور',
      'zgh': 'ⵓⵔ ⵢⴻⵥⵎⵉⵔ ⴰⴷ ⵢⵙⵙⵉⵍⵢ ⵜⵉⵡⵍⴰⴼⵉⵏ',
      'fr': 'Échec du téléchargement des photos',
      'en': 'Failed to upload photos',
    },
    'prey_type_label': {
      'ar': 'نوع الطريدة',
      'zgh': 'ⴰⵏⴰⵡ ⵏ ⵜⵡⵓⵔⵉ',
      'fr': 'Type de gibier',
      'en': 'Prey Type',
    },
    'choose_up_to_5_photos': {
      'ar': 'اختر حتى 5 صور',
      'zgh': 'ⴼⵔⴻⵏ ⴰⵔ 5 ⵏ ⵜⵡⵍⴰⴼⵉⵏ',
      'fr': "Choisissez jusqu'à 5 photos",
      'en': 'Choose up to 5 photos',
    },
    'selected_n_photos': {
      'ar': 'تم اختيار {n} صورة',
      'zgh': 'ⵜⵜⵡⴰⴼⵔⴻⵏ {n} ⵏ ⵜⵡⵍⴰⴼⵉⵏ',
      'fr': '{n} photo(s) sélectionnée(s)',
      'en': '{n} photo(s) selected',
    },
    'upload_photos_button': {
      'ar': 'رفع الصور',
      'zgh': 'ⵙⵙⵉⵍⵉ ⵜⵉⵡⵍⴰⴼⵉⵏ',
      'fr': 'Télécharger les photos',
      'en': 'Upload Photos',
    },
    'normal_map': {
      'ar': 'خريطة عادية',
      'zgh': 'ⵜⴰⴽⴰⵕⴹⴰ ⵜⴰⵎⴰⴳⵏⵓⵜ',
      'fr': 'Carte normale',
      'en': 'Normal Map',
    },
    'satellite_imagery': {
      'ar': 'صور الأقمار الصناعية',
      'zgh': 'ⵜⵉⵡⵍⴰⴼⵉⵏ ⵏ ⵢⵉⵜⵔⴰⵏ',
      'fr': 'Images satellite',
      'en': 'Satellite Imagery',
    },
    'forbidden_zone_notif_title': {
      'ar': '⚠️ منطقة محمية',
      'zgh': '⚠️ ⵜⴰⵎⵍⴻⵍⵜ ⵜⵜⵡⴰⵎⴻⵍⵍⴻⵜ',
      'fr': '⚠️ Zone protégée',
      'en': '⚠️ Protected Zone',
    },
    'forbidden_zone_notif_body': {
      'ar': 'أنت الآن داخل "{zone}" — الصيد ممنوع في هذه المنطقة.',
      'zgh': 'ⵜⴻⵍⵍⵉⴷ ⴷⴰ ⴳ "{zone}" — ⴰⵚⵢⴰⴷ ⵢⴻⴳⴷⴻⵍ ⴳ ⵜⵎⵍⴻⵍⵜ ⴰⴷ.',
      'fr': 'Vous êtes maintenant dans "{zone}" — la chasse est interdite dans cette zone.',
      'en': 'You are now inside "{zone}" — hunting is forbidden in this zone.',
    },

    // --- Auth screen -----------------------------------------------
    'unexpected_error': {
      'ar': 'حدث خطأ غير متوقع. حاول مرة أخرى.',
      'zgh': 'ⵢⴻⴹⵕⴰ ⵢⴰⵏ ⵓⵎⵏⵖⵉ ⵓⵔ ⵢⵜⵜⵡⴰⵔⵊⴰⵏ. ⴰⵍⵙ ⴰⵔⵎ.',
      'fr': "Une erreur inattendue s'est produite. Réessayez.",
      'en': 'An unexpected error occurred. Please try again.',
    },
    'network_error': {
      'ar': 'تعذر الاتصال بالخادم. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.',
      'zgh': 'ⵓⵔ ⵢⴰⵎⵎⴻⴹ ⵓⵎⵢⴰⴳⵔ ⴰⴽⴽ ⴰⵙⵔⴼⵉ. ⵙⵏⵎⴰⵍⴰ ⴰⵎⵢⴰⴳⵔ ⵏⵏⴽ ⵙ ⵜⵎⵖⵢⵍⵜ ⴰⵎⵙ ⴰⵔⵎ.',
      'fr':
          "Impossible de joindre le serveur. Vérifiez votre connexion internet et réessayez.",
      'en':
          'Could not reach the server. Check your internet connection and try again.',
    },
    'enter_full_name': {
      'ar': 'الرجاء إدخال الاسم الكامل',
      'zgh': 'ⵙⴽⴻⵛⵎ ⵉⵙⴻⵎ ⴰⴽⴻⵎⵎⴰⵍ',
      'fr': 'Veuillez saisir le nom complet',
      'en': 'Please enter your full name',
    },
    'weak_password_message': {
      'ar': 'كلمة المرور ضعيفة: يجب أن تحتوي على 8 أحرف على الأقل، حرف كبير، حرف صغير، رقم، ورمز خاص (@ # \$ ...)',
      'zgh': 'ⴰⵡⴰⵍ ⵓⴼⴼⵉⵔ ⴷⵔⵓⵙ: ⵢⵙⵙⴻⴼⴽ ⴰⴷ ⵢⵉⵍⵉ 8 ⵏ ⵢⵉⵙⴽⴽⵉⵍⵏ, ⴰⵙⴻⴽⴽⵉⵍ ⴰⵎⴻⵇⵇⵔⴰⵏ ⴷ ⴰⵎⴻⵥⵥⵢⴰⵏ, ⴰⵎⴻⵟⵟⴰ, ⴷ ⵢⴰⵏ ⵓⵣⴰⵎⵓⵍ ⵓⵥⵍⵉⵏ (@ # \$ ...)',
      'fr': 'Mot de passe faible : au moins 8 caractères, une majuscule, une minuscule, un chiffre et un caractère spécial (@ # \$ ...)',
      'en': 'Weak password: must have at least 8 characters, an uppercase letter, a lowercase letter, a number, and a special character (@ # \$ ...)',
    },
    'invalid_birthdate': {
      'ar': 'تاريخ الميلاد غير صالح',
      'zgh': 'ⴰⵣⴻⵎⵣ ⵏ ⵜⵍⴰⵍⵉⵜ ⵓⵔ ⵢⵚⵃⵉⵃ',
      'fr': 'Date de naissance invalide',
      'en': 'Invalid birthdate',
    },
    'account_created_message': {
      'ar': 'تم إنشاء الحساب. تحقق من بريدك الإلكتروني للتأكيد إذا لزم الأمر.',
      'zgh': 'ⵜⵜⵡⴰⵙⵏⵓⵍⴼⵓ ⵓⵎⵉⴹⴰⵏ. ⵥⵕ ⴰⵎⴰⵢⵍ ⵏⵏⴻⵎ ⵉ ⵓⵙⵏⵜⴻⵎ ⵎⴰ ⵢⵍⵍⴰ.',
      'fr': 'Compte créé. Vérifiez votre e-mail pour confirmation si nécessaire.',
      'en': 'Account created. Check your email to confirm if required.',
    },
    'create_account_title': {
      'ar': 'إنشاء حساب جديد',
      'zgh': 'ⵙⵏⵓⵍⴼⵓ ⴰⵎⵉⴹⴰⵏ ⴰⵎⴰⵢⵏⵓ',
      'fr': 'Créer un nouveau compte',
      'en': 'Create New Account',
    },
    'login_title': {
      'ar': 'تسجيل الدخول',
      'zgh': 'ⴽⵛⴻⵎ',
      'fr': 'Connexion',
      'en': 'Log In',
    },
    'full_name_label': {
      'ar': 'الاسم الكامل',
      'zgh': 'ⵉⵙⴻⵎ ⴰⴽⴻⵎⵎⴰⵍ',
      'fr': 'Nom complet',
      'en': 'Full Name',
    },
    'email_label': {
      'ar': 'البريد الإلكتروني',
      'zgh': 'ⴰⵎⴰⵢⵍ',
      'fr': 'E-mail',
      'en': 'Email',
    },
    'password_label': {
      'ar': 'كلمة المرور',
      'zgh': 'ⴰⵡⴰⵍ ⵓⴼⴼⵉⵔ',
      'fr': 'Mot de passe',
      'en': 'Password',
    },
    'password_hint': {
      'ar': '8 أحرف على الأقل، حرف كبير وصغير، رقم، ورمز خاص',
      'zgh': '8 ⵏ ⵢⵉⵙⴽⴽⵉⵍⵏ, ⴰⵙⴻⴽⴽⵉⵍ ⴰⵎⴻⵇⵇⵔⴰⵏ ⴷ ⴰⵎⴻⵥⵥⵢⴰⵏ, ⴰⵎⴻⵟⵟⴰ, ⴷ ⵓⵣⴰⵎⵓⵍ ⵓⵥⵍⵉⵏ',
      'fr': 'Au moins 8 caractères, majuscule et minuscule, chiffre, caractère spécial',
      'en': 'At least 8 characters, upper & lowercase, a number, a special character',
    },
    'gender_label': {
      'ar': 'الجنس',
      'zgh': 'ⴰⵏⴰⵡ',
      'fr': 'Genre',
      'en': 'Gender',
    },
    'gender_male': {
      'ar': 'ذكر',
      'zgh': 'ⴰⵔⴳⴰⵣ',
      'fr': 'Homme',
      'en': 'Male',
    },
    'gender_female': {
      'ar': 'أنثى',
      'zgh': 'ⵜⴰⵎⵖⴰⵔⵜ',
      'fr': 'Femme',
      'en': 'Female',
    },
    'city_label': {
      'ar': 'المدينة',
      'zgh': 'ⵜⴰⵎⴷⵉⵏⵜ',
      'fr': 'Ville',
      'en': 'City',
    },
    'choose_city': {
      'ar': 'اختر المدينة',
      'zgh': 'ⴼⵔⴻⵏ ⵜⴰⵎⴷⵉⵏⵜ',
      'fr': 'Choisir la ville',
      'en': 'Choose City',
    },
    'birthdate_label': {
      'ar': 'تاريخ الميلاد',
      'zgh': 'ⴰⵣⴻⵎⵣ ⵏ ⵜⵍⴰⵍⵉⵜ',
      'fr': 'Date de naissance',
      'en': 'Birthdate',
    },
    'age_label': {
      'ar': 'العمر: {n} سنة',
      'zgh': 'ⴰⵙⴻⴳⴳⴰⵙ: {n}',
      'fr': 'Âge : {n} ans',
      'en': 'Age: {n}',
    },
    'toggle_to_login': {
      'ar': 'لديك حساب بالفعل؟ تسجيل الدخول',
      'zgh': 'ⵖⵓⵔⴻⴽ ⴰⵎⵉⴹⴰⵏ ⵢⴰⴷ? ⴽⵛⴻⵎ',
      'fr': 'Vous avez déjà un compte ? Connexion',
      'en': 'Already have an account? Log In',
    },
    'toggle_to_signup': {
      'ar': 'ليس لديك حساب؟ إنشاء حساب جديد',
      'zgh': 'ⵓⵔ ⵖⵓⵔⴻⴽ ⴰⵎⵉⴹⴰⵏ? ⵙⵏⵓⵍⴼⵓ ⴰⵎⴰⵢⵏⵓ',
      'fr': "Vous n'avez pas de compte ? Créer un compte",
      'en': "Don't have an account? Create One",
    },

    // --- Legal / rules screen -------------------------------------------
    // Translation of MoroHunt's own app policy text (not a
    // reproduction of Moroccan hunting law itself — see the
    // doc-comment in legal_compliance_screen.dart). This is a
    // best-effort translation of the app's wording; if this text
    // carries real legal weight for your users, it's worth a
    // professional review before relying on the FR/EN copy and
    // ESPECIALLY the Amazigh copy, which needed the same non-native-
    // speaker caveat as the rest of this file.
    'legal_title': {
      'ar': 'دستور وقوانين التطبيق',
      'zgh': 'ⴰⵣⵔⴼ ⴷ ⵉⵍⵓⴳⴰⵏ ⵏ ⵓⵙⵏⴻⴼⵍ',
      'fr': "Charte et règles de l'application",
      'en': 'App Constitution & Rules',
    },
    'legal_section1_title': {
      'ar': 'الالتزام بالقوانين المغربية للصيد',
      'zgh': 'ⴰⵎⵢⴰⵡⴰⵙ ⴷ ⵉⵍⵓⴳⴰⵏ ⵉⵎⵖⵔⴰⴱⵉⵢⴻⵏ ⵏ ⵓⵚⵢⴰⴷ',
      'fr': 'Respect des lois marocaines sur la chasse',
      'en': 'Compliance with Moroccan Hunting Laws',
    },
    'legal_section1_body': {
      'ar':
          'يلتزم كل مستخدم لتطبيق MoroHunt التزامًا صارمًا وكاملاً بالقوانين '
          'والأنظمة الصادرة عن الجهات الوصية على قطاع الصيد في المملكة المغربية، '
          'وعلى رأسها وزارة الفلاحة والصيد البحري والتنمية القروية والمياه والغابات '
          'وقطاع المياه والغابات التابع لها. يشمل هذا الالتزام على وجه الخصوص:\n\n'
          '  •  احترام الأنصبة القانونية اليومية المسموح بها لكل نوع من الطرائد، '
          'والتي تُحدَّد وتُراجَع سنويًا بقرارات وزارية رسمية.\n'
          '  •  احترام مواسم الصيد القانونية المفتوحة والمغلقة لكل نوع ولكل منطقة، '
          'والتي قد تختلف من سنة لأخرى.\n'
          '  •  الحصول على رخصة الصيد السارية المفعول وحمل الوثائق المطلوبة أثناء أي '
          'نشاط صيد ميداني.\n\n'
          'لا يقدّم التطبيق بأي شكل من الأشكال أرقامًا أو تواريخ محددة للأنصبة أو '
          'المواسم داخل هذا النص، نظرًا لتغيّرها الدوري؛ يجب دائمًا الرجوع إلى '
          'المصادر الرسمية للجهات الوصية للتأكد من الأرقام والتواريخ السارية حاليًا.',
      'fr':
          "Chaque utilisateur de MoroHunt s'engage à respecter strictement et "
          "intégralement les lois et règlements émis par les autorités "
          "responsables du secteur de la chasse au Royaume du Maroc, au premier "
          "rang desquelles le Ministère de l'Agriculture, de la Pêche Maritime, "
          "du Développement Rural et des Eaux et Forêts. Cet engagement inclut "
          "notamment :\n\n"
          "  •  Le respect des quotas quotidiens légaux autorisés pour chaque "
          "espèce de gibier, fixés et révisés chaque année par décision "
          "ministérielle officielle.\n"
          "  •  Le respect des saisons de chasse légales, ouvertes et fermées, "
          "pour chaque espèce et chaque région, qui peuvent varier d'une année "
          "à l'autre.\n"
          "  •  L'obtention d'un permis de chasse valide et le port des "
          "documents requis lors de toute activité de chasse sur le terrain.\n\n"
          "L'application ne fournit en aucun cas de chiffres ou de dates "
          "précises pour les quotas ou les saisons dans ce texte, en raison de "
          "leur changement périodique ; il faut toujours se référer aux sources "
          "officielles des autorités compétentes pour connaître les chiffres et "
          "dates actuellement en vigueur.",
      'en':
          "Every MoroHunt user strictly and fully commits to the laws and "
          "regulations issued by the authorities responsible for the hunting "
          "sector in the Kingdom of Morocco, foremost among them the Ministry "
          "of Agriculture, Maritime Fisheries, Rural Development, and Water "
          "and Forests. This commitment specifically includes:\n\n"
          "  •  Respecting the legal daily quotas allowed for each prey "
          "species, which are set and reviewed annually by official "
          "ministerial decisions.\n"
          "  •  Respecting the legal open and closed hunting seasons for each "
          "species and region, which may vary from year to year.\n"
          "  •  Holding a valid hunting license and carrying the required "
          "documents during any field hunting activity.\n\n"
          "The app does not provide specific quota or season figures or dates "
          "anywhere in this text, since they change periodically; always refer "
          "to the official sources of the competent authorities to confirm "
          "the currently valid figures and dates.",
      'zgh':
          "Yal aseqdac n MoroHunt iqbel ad ismenyaf s telqayt ilugan d "
          "iânagen i d-ifka uneɣlaf yettwaklen ɣef umnaḍ n uṣyad di Tgeldit "
          "n Lmerruk, xas tamezwarut Taneɣlift n Tfellaḥt, Aṣyad Agraw, "
          "Asnerni Aqṛuri d Waman d Tegmatin. Amnay-a yezmer ad d-yawi:\n\n"
          "  •  Aqbal n telqayt n wussan ittusirgen i yal tawsit n tweɣzi.\n"
          "  •  Aqbal n tamiwin n uṣyad iṣeḥḥan, ittwaldin d ittwamedlen.\n"
          "  •  Asmizwer n tsaramt n uṣyad d wafarnas n izuraf ittwasran.",
    },
    'legal_section2_title': {
      'ar': 'المحتوى الممنوع منعًا باتًا',
      'zgh': 'ⴰⴳⴻⵏⵏⵓ ⵢⴻⴳⴷⴻⵍ ⵙ ⵡⴰⵡⴰⵍ',
      'fr': 'Contenu strictement interdit',
      'en': 'Strictly Prohibited Content',
    },
    'legal_section2_body': {
      'ar':
          'يُمنع منعًا باتًا تسجيل أو رفع أي محتوى يوثّق أو يروّج لأي من الممارسات '
          'التالية عبر التطبيق:\n\n'
          '  •  الصيد خارج المواسم القانونية المفتوحة.\n'
          '  •  استهداف أو اصطياد أنواع محمية أو مهددة بالانقراض.\n'
          '  •  الصيد الليلي غير المرخّص.\n'
          '  •  استعمال معدات أو أسلحة أو وسائل صيد غير قانونية (كالفخاخ الممنوعة).\n\n'
          'أي محاولة للتحايل على هذه القواعد، سواء عبر التلاعب بالإحداثيات المسجَّلة '
          'أو إخفاء طبيعة الطريدة أو أي وسيلة أخرى، تُعتبر مخالفة صريحة لشروط '
          'استخدام هذا التطبيق.',
      'fr':
          "Il est strictement interdit d'enregistrer ou de télécharger tout "
          "contenu documentant ou promouvant l'une des pratiques suivantes via "
          "l'application :\n\n"
          "  •  La chasse en dehors des saisons légales ouvertes.\n"
          "  •  Le ciblage ou la capture d'espèces protégées ou menacées "
          "d'extinction.\n"
          "  •  La chasse nocturne non autorisée.\n"
          "  •  L'utilisation d'équipements, d'armes ou de moyens de chasse "
          "illégaux (comme les pièges interdits).\n\n"
          "Toute tentative de contourner ces règles, que ce soit en falsifiant "
          "les coordonnées enregistrées, en dissimulant la nature du gibier, ou "
          "par tout autre moyen, est considérée comme une violation explicite "
          "des conditions d'utilisation de cette application.",
      'en':
          "It is strictly forbidden to log or upload any content that "
          "documents or promotes any of the following practices via the "
          "app:\n\n"
          "  •  Hunting outside the legal open seasons.\n"
          "  •  Targeting or hunting protected or endangered species.\n"
          "  •  Unlicensed night hunting.\n"
          "  •  Using illegal hunting equipment, weapons, or methods (such as "
          "banned traps).\n\n"
          "Any attempt to circumvent these rules — whether by falsifying "
          "logged coordinates, concealing the true species, or any other "
          "means — is considered an explicit violation of this app's terms "
          "of use.",
      'zgh':
          "Yegdel s wawal ad tsekles neɣ ad tsersed kra n ugennu i "
          "issalayen neɣ issikkaren yiwet seg tikliwin-a s useqdec n "
          "usnefel:\n\n"
          "  •  Aṣyad ur nelli deg tmiwin n usyad iṣeḥḥan.\n"
          "  •  Aṣyad n twesɣiwin ittwaḥerzen neɣ ittuɣalen d timattiwin.\n"
          "  •  Aṣyad n yiḍ war tsaramt.\n"
          "  •  Aseqdec n yifecka neɣ imyagen ur nelli d izerfanen.",
    },
    'legal_section3_title': {
      'ar': 'حق الإدارة في حذف المحتوى وتعليق الحسابات',
      'zgh': 'Azref n unedbal deg ukkes n ugennu d usewḥel n imiḍanen',
      'fr': "Droit de l'administration de supprimer du contenu et suspendre des comptes",
      'en': "Administration's Right to Remove Content and Suspend Accounts",
    },
    'legal_section3_body': {
      'ar':
          'تحتفظ إدارة التطبيق بالحق المطلق، دون الحاجة لإشعار مسبق، في:\n\n'
          '  •  حذف أي سجل صيد يُشتبه في مخالفته للقوانين المذكورة أعلاه.\n'
          '  •  إعادة ضبط أي إحصائيات أو نقاط تبيّن أنها نتيجة تلاعب أو غش.\n'
          '  •  تعليق أو حذف أي حساب مستخدم يثبت تكرار مخالفته لقواعد الاستخدام.\n\n'
          'تُتخذ هذه الإجراءات وفق التقدير الكامل للإدارة، وهي غير قابلة للطعن '
          'داخل التطبيق.',
      'fr':
          "L'administration de l'application se réserve le droit absolu, sans "
          "préavis, de :\n\n"
          "  •  Supprimer tout journal de chasse suspecté de violer les lois "
          "mentionnées ci-dessus.\n"
          "  •  Réinitialiser toute statistique ou tout point s'avérant "
          "résulter d'une manipulation ou d'une triche.\n"
          "  •  Suspendre ou supprimer tout compte utilisateur dont il est "
          "prouvé qu'il enfreint de manière répétée les règles "
          "d'utilisation.\n\n"
          "Ces mesures sont prises à l'entière discrétion de l'administration "
          "et ne sont pas contestables au sein de l'application.",
      'en':
          "The app administration reserves the absolute right, without prior "
          "notice, to:\n\n"
          "  •  Delete any catch log suspected of violating the "
          "above-mentioned laws.\n"
          "  •  Reset any statistics or points found to result from "
          "manipulation or cheating.\n"
          "  •  Suspend or delete any user account proven to repeatedly "
          "violate the usage rules.\n\n"
          "These actions are taken at the administration's sole discretion "
          "and are not contestable within the app.",
      'zgh':
          "Anedbal n usnefel yeṭṭef azref ummid, war ula d alɣu, ad:\n\n"
          "  •  Ikkes yal asekles n uṣyad ittwaḍennen deg ubḍa n ilugan i "
          "d-yeqqimen sennig.\n"
          "  •  Yales asezmel n tmiḍanin neɣ tenqiḍin i d-ifɣen si tqerqact.\n"
          "  •  Isewḥel neɣ ikkes amiḍan n useqdac i ibedden deg ubḍa n "
          "ilugan n useqdec.",
    },
    'legal_section4_title': {
      'ar': 'إخلاء المسؤولية',
      'zgh': 'ⴰⵙⴻⵔⵔⴻⵃ ⵏ ⵜⴰⵎⴰⵡⴰⵍⵜ',
      'fr': 'Clause de non-responsabilité',
      'en': 'Disclaimer',
    },
    'legal_section4_body': {
      'ar':
          'تطبيق MoroHunt هو أداة توثيق وتنظيم رقمية بحتة (خريطة، تتبع جماعي، '
          'سجل صيد)، وليس جهة ترخيص أو إشراف قانوني على ممارسة الصيد. '
          'المستخدم وحده يتحمّل المسؤولية الشخصية والجنائية والقانونية الكاملة '
          'عن جميع أنشطته الميدانية المتعلقة بالصيد، بما في ذلك على سبيل المثال '
          'لا الحصر: مدى امتلاكه لرخصة سارية، احترامه للمواسم والأنصبة القانونية، '
          'واستعماله لمعدات وأسلحة مرخّصة. لا تتحمّل إدارة التطبيق أي مسؤولية '
          'عن أي مخالفة يرتكبها أي مستخدم خارج إطار التطبيق.',
      'fr':
          "L'application MoroHunt est un outil purement numérique de "
          "documentation et d'organisation (carte, suivi de groupe, journal "
          "de chasse), et non un organisme de délivrance de permis ou de "
          "supervision légale de la pratique de la chasse. L'utilisateur "
          "seul assume l'entière responsabilité personnelle, pénale et "
          "juridique de toutes ses activités de chasse sur le terrain, y "
          "compris, sans s'y limiter : la détention d'un permis valide, le "
          "respect des saisons et quotas légaux, et l'utilisation "
          "d'équipements et d'armes autorisés. L'administration de "
          "l'application n'assume aucune responsabilité pour toute infraction "
          "commise par un utilisateur en dehors du cadre de l'application.",
      'en':
          "MoroHunt is a purely digital documentation and organization tool "
          "(map, group tracking, catch log), not a licensing body or legal "
          "supervisory authority over hunting practice. The user alone bears "
          "full personal, criminal, and legal responsibility for all their "
          "field hunting activities, including but not limited to: holding a "
          "valid license, respecting legal seasons and quotas, and using "
          "licensed equipment and weapons. The app administration bears no "
          "responsibility for any violation committed by a user outside the "
          "scope of the app.",
      'zgh':
          "Usnefel MoroHunt d afecku uzɣin kan (takarḍa, aḍfaṛ n twacult, "
          "asekles n uṣyad), mačči d amsizwer n tsaramt neɣ n uɛessi "
          "azrfan ɣef useqdec n uṣyad. Aseqdac kan i yeṭṭfen tamawalt "
          "tummidt ɣef tikliwin-is n uṣyad, deg-sent: asmizwer n tsaramt "
          "iṣeḥḥan, aqbal n tmiwin d telqayt, aseqdec n yifecka "
          "ittwasirgen. Anedbal n usnefel ur yeṭṭif ara tamawalt ɣef kra n "
          "ubḍa i d-yeḍṛun zdat useqdac beṛṛa i usnefel.",
    },

    // --- Profile screen: age / default-data note ------------------------
    'age_suffix': {
      'ar': 'سنة',
      'zgh': 'ⵉⵙⴳⴳⵯⴰⵙⵏ',
      'fr': 'ans',
      'en': 'years',
    },
    'default_data_note': {
      'ar': 'بيانات افتراضية — اضغط للتعديل',
      'zgh': 'ⵉⵙⴻⴼⴽⴰ ⵉⵎⴰⴳⵏⵓⵏ — ⵙⵉⵜⵢ ⴰⴷ ⵜⴱⴻⴹⵍⴻⴹ',
      'fr': 'Données par défaut — appuyez pour modifier',
      'en': 'Default data — tap to edit',
    },

    // --- Profile screen: edit-name dialog --------------------------------
    'edit_name_title': {
      'ar': 'تعديل الاسم',
      'zgh': 'ⴱⴻⴹⴻⵍ ⵉⵙⴻⵎ',
      'fr': 'Modifier le nom',
      'en': 'Edit Name',
    },
    'username_label': {
      'ar': 'اسم المستخدم',
      'zgh': 'ⵉⵙⴻⵎ ⵏ ⵓⵙⴻⵎⵔⵙ',
      'fr': "Nom d'utilisateur",
      'en': 'Username',
    },
    'update_photo_failed': {
      'ar': 'تعذر تحديث الصورة',
      'zgh': 'ⵓⵔ ⵢⴻⵥⵎⵉⵔ ⴰⴷ ⵢⵙⵎⵉⵔⴻⴳ ⵜⴰⵡⵍⴰⴼⵜ',
      'fr': 'Échec de la mise à jour de la photo',
      'en': 'Failed to update photo',
    },
    'update_name_failed': {
      'ar': 'تعذر تحديث الاسم',
      'zgh': 'ⵓⵔ ⵢⴻⵥⵎⵉⵔ ⴰⴷ ⵢⵙⵎⵉⵔⴻⴳ ⵉⵙⴻⵎ',
      'fr': 'Échec de la mise à jour du nom',
      'en': 'Failed to update name',
    },
    'update_data_failed': {
      'ar': 'تعذر تحديث البيانات',
      'zgh': 'ⵓⵔ ⵢⴻⵥⵎⵉⵔ ⴰⴷ ⵢⵙⵎⵉⵔⴻⴳ ⵉⵙⴻⴼⴽⴰ',
      'fr': 'Échec de la mise à jour des données',
      'en': 'Failed to update data',
    },

    // --- Profile screen: delete-record dialog ----------------------------
    'delete_record_title': {
      'ar': 'حذف السجل',
      'zgh': 'ⴽⴽⵙ ⴰⵙⵙⵓⵖⴻⵍ',
      'fr': "Supprimer l'entrée",
      'en': 'Delete Record',
    },
    'delete_record_body_multi': {
      'ar': 'سيتم حذف جميع الصور ({n}) المرتبطة بهذا الموقع نهائيًا. لا يمكن حذف صورة واحدة فقط.',
      'zgh': 'ⴰⴷ ⵜⵜⵡⴰⴽⴽⵙⴻⵏⵜ ⵎⴻⵕⵕⴰ ⵜⵡⵍⴰⴼⵉⵏ ({n}) ⵉⵜⵜⵡⴰⵇⵇⵏⴻⵏ ⵖⴻⵔ ⵜⴻⵥⵖⵜ ⴰⴷ ⵙ ⵡⴰⵡⴰⵍ. ⵓⵔ ⵢⴻⵥⵎⵉⵔ ⴰⴷ ⵜⵜⵡⴰⴽⴽⵙ ⵢⴰⵜ ⵜⵡⵍⴰⴼⵜ ⵜⵉⴽⴽⴻⵍⵜ.',
      'fr': 'Toutes les photos ({n}) associées à cet emplacement seront définitivement supprimées. Impossible de supprimer une seule photo.',
      'en': 'All photos ({n}) linked to this location will be permanently deleted. A single photo cannot be deleted alone.',
    },
    'delete_record_body_single': {
      'ar': 'سيتم حذف هذا السجل نهائيًا من الخريطة.',
      'zgh': 'ⴰⴷ ⵢⵜⵜⵡⴰⴽⴽⵙ ⵓⵙⵙⵓⵖⴻⵍ ⴰⴷ ⵙ ⵡⴰⵡⴰⵍ ⵙⴻⴳ ⵜⴽⴰⵕⴹⴰ.',
      'fr': 'Cette entrée sera définitivement supprimée de la carte.',
      'en': 'This record will be permanently deleted from the map.',
    },
    'delete': {
      'ar': 'حذف',
      'zgh': 'ⴽⴽⵙ',
      'fr': 'Supprimer',
      'en': 'Delete',
    },
    'delete_record_failed': {
      'ar': 'تعذر حذف السجل',
      'zgh': 'ⵓⵔ ⵢⴻⵥⵎⵉⵔ ⴰⴷ ⵢⴽⴽⴻⵙ ⴰⵙⵙⵓⵖⴻⵍ',
      'fr': "Échec de la suppression de l'entrée",
      'en': 'Failed to delete record',
    },

    // --- Profile screen: report-user dialog ------------------------------
    'report_reason_offensive_photo': {
      'ar': 'صورة مسيئة',
      'zgh': 'ⵜⴰⵡⵍⴰⴼⵜ ⵢⴻⵅⵛⴻⵏ',
      'fr': 'Photo inappropriée',
      'en': 'Offensive Photo',
    },
    'report_reason_inappropriate_name': {
      'ar': 'اسم غير لائق',
      'zgh': 'ⵉⵙⴻⵎ ⵓⵔ ⵢⵎⵓⵏ',
      'fr': 'Nom inapproprié',
      'en': 'Inappropriate Name',
    },
    'report_reason_stats_cheating': {
      'ar': 'غش في الأرقام',
      'zgh': 'ⴰⵙⵅⴰⵜⵉ ⴳ ⵜⵎⵉⴹⴰⵏ',
      'fr': 'Triche sur les statistiques',
      'en': 'Stats Cheating',
    },
    'report_reason_illegal_content': {
      'ar': 'محتوى صيد غير قانوني',
      'zgh': 'ⴰⴳⴻⵏⵏⵓ ⵏ ⵓⵚⵢⴰⴷ ⵓⵔ ⵢⵍⵍⵉ ⴷ ⴰⵣⵔⴼⴰⵏ',
      'fr': 'Contenu de chasse illégal',
      'en': 'Illegal Hunting Content',
    },
    'report_reason_abuse_harassment': {
      'ar': 'إساءة أو تحرش',
      'zgh': 'ⴰⵅⵛⴰⵏ ⵏⴻⵖ ⴰⵃⴻⵔⵔⵉⵛ',
      'fr': 'Abus ou harcèlement',
      'en': 'Abuse or Harassment',
    },
    'report_reason_other': {
      'ar': 'أخرى',
      'zgh': 'ⵢⴰⴹⵏⵉⵏ',
      'fr': 'Autre',
      'en': 'Other',
    },
    'report_user_title': {
      'ar': 'إبلاغ عن هذا المستخدم',
      'zgh': 'ⵎⵍⴻⵖ ⵅⴻⴼ ⵓⵙⴻⵎⵔⵙ ⴰⴷ',
      'fr': 'Signaler cet utilisateur',
      'en': 'Report This User',
    },
    'report_user_button': {
      'ar': 'إبلاغ عن هذا المستخدم',
      'zgh': 'ⵎⵍⴻⵖ ⵅⴻⴼ ⵓⵙⴻⵎⵔⵙ ⴰⴷ',
      'fr': 'Signaler cet utilisateur',
      'en': 'Report This User',
    },
    'choose_report_reason': {
      'ar': 'اختر سبب الإبلاغ:',
      'zgh': 'ⴼⵔⴻⵏ ⴰⵙⴻⴱⴱⴰ ⵏ ⵜⵎⵍⵉⵜ:',
      'fr': 'Choisissez la raison du signalement :',
      'en': 'Choose the reason for reporting:',
    },
    'additional_details_optional': {
      'ar': 'تفاصيل إضافية (اختياري)',
      'zgh': 'ⵉⵙⴻⴼⴽⴰ ⵢⵉⴹⵏ (ⴷ ⴰⵅⵢⴰⵕ)',
      'fr': 'Détails supplémentaires (facultatif)',
      'en': 'Additional details (optional)',
    },
    'send_report': {
      'ar': 'إرسال البلاغ',
      'zgh': 'ⴰⵣⴻⵏ ⵜⴰⵎⵍⵉⵜ',
      'fr': 'Envoyer le signalement',
      'en': 'Send Report',
    },
    'report_sent_thanks': {
      'ar': 'تم إرسال البلاغ، شكرًا لك.',
      'zgh': 'ⵜⵜⵡⴰⵣⵏ ⵜⵎⵍⵉⵜ, ⵜⴰⵏⵎⵎⵉⵔⵜ.',
      'fr': 'Signalement envoyé, merci.',
      'en': 'Report sent, thank you.',
    },
    'send_report_failed': {
      'ar': 'تعذر إرسال البلاغ',
      'zgh': 'ⵓⵔ ⵢⴻⵥⵎⵉⵔ ⴰⴷ ⵢⴰⵣⴻⵏ ⵜⴰⵎⵍⵉⵜ',
      'fr': "Échec de l'envoi du signalement",
      'en': 'Failed to send report',
    },

    // --- Profile screen: misc chrome --------------------------------------
    'notifications_tooltip': {
      'ar': 'مركز الإشعارات',
      'zgh': 'ⴰⵎⵎⴰⵙ ⵏ ⵢⵉⵙⴰⵍⴰⵏ',
      'fr': 'Centre de notifications',
      'en': 'Notification Center',
    },
    'no_catches_yet': {
      'ar': 'لم تقم بتسجيل أي صيد بعد. اضغط مطولاً على الخريطة لتسجيل صيدك الأول.',
      'zgh': 'ⵓⵔ ⵜⵙⵙⵉⴼⴹⴻⴹ ⵡⴰⵍⵓ ⵏ ⵓⵚⵢⴰⴷ ⴷⵖⵉ. ⵙⵉⵜⵢ ⴰⵟⵟⴰⵙ ⵅⴻⴼ ⵜⴽⴰⵕⴹⴰ ⵉ ⵓⵙⵙⵉⴼⴻⴹ ⵏ ⵓⵚⵢⴰⴷ ⵏⵏⴻⴽ ⴰⵎⴻⵣⵡⴰⵔⵓ.',
      'fr': "Vous n'avez pas encore enregistré de prise. Appuyez longuement sur la carte pour enregistrer votre première prise.",
      'en': "You haven't logged any catch yet. Long-press the map to log your first catch.",
    },
    'edit_personal_details_title': {
      'ar': 'تعديل البيانات الشخصية',
      'zgh': 'ⴱⴻⴹⴻⵍ ⵉⵙⴻⴼⴽⴰ ⵓⴷⵎⴰⵡⴰⵏⴻⵏ',
      'fr': 'Modifier les informations personnelles',
      'en': 'Edit Personal Details',
    },

    // --- Notification center ---------------------------------------------
    'notifications_title': {
      'ar': 'مركز الإشعارات',
      'zgh': 'ⴰⵎⵎⴰⵙ ⵏ ⵢⵉⵙⴰⵍⴰⵏ',
      'fr': 'Centre de notifications',
      'en': 'Notification Center',
    },
    'no_notifications': {
      'ar': 'لا توجد إشعارات حاليًا',
      'zgh': 'ⵓⵔ ⵍⵍⵉⵏ ⵉⵙⴰⵍⴰⵏ ⴷⵖⵉ',
      'fr': 'Aucune notification pour le moment',
      'en': 'No notifications right now',
    },
  };

  /// Looks up [key] for the given [language]. Falls back to Arabic if
  /// that language is missing an entry, then to the raw key itself if
  /// even Arabic is missing it — so a typo/missing translation shows
  /// up as an obviously-wrong string in dev rather than crashing.
  static String translate(String key, AppLanguage language) {
    final entry = _values[key];
    if (entry == null) return key;
    return entry[language.locale.languageCode] ?? entry['ar'] ?? key;
  }
}
