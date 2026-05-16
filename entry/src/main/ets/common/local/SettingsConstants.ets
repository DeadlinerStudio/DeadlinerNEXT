export class SettingsConstants {
  static readonly PREF_NAME = 'deadliner_settings';

  static readonly KEY_PRIVACY_AGREE = 'is_privacy_agreed';

  static readonly KEY_BASIC_MODE = 'key_basic_mode';

  static readonly KEY_CLOUD_SYNC_ENABLE = 'cloud_sync_enable';
  static readonly KEY_CLOUD_SYNC_MODE = 'cloud_sync_mode';
  static readonly KEY_WEBDAV_URL = 'webdav_url';
  static readonly KEY_WEBDAV_USERNAME = 'webdav_username';
  static readonly KEY_WEBDAV_PASSWORD = 'webdav_password';
  static readonly KEY_THEME_MODE = 'theme_mode'; // 0:跟随系统, 1:浅色, 2:深色

  static readonly KEY_VIBRATION_ENABLE = 'vibration';
  static readonly KEY_PROGRESS_DIRECTION = 'progress_direction';
  static readonly KEY_EXCITEMENT_TEXT = 'excitement_text';
  static readonly KEY_CONFETTI_AFTER_FINISHED = 'confetti_after_finished';
  static readonly KEY_FULL_SCREEN_ADD = 'full_screen_add'

  static readonly KEY_AI_PROVIDER = 'ai_provider';
  static readonly KEY_AI_MODEL = 'ai_model';
  static readonly KEY_AI_DEEPSEEK_API_KEY = 'ai_deepseek_api_key';
  static readonly KEY_AI_BASE_URL = 'ai_base_url';

  static readonly KEY_MAIN_LEFT_BUTTON = 'main_left_button';
  static readonly KEY_MAIN_RIGHT_BUTTON = 'main_right_button';

  static readonly KEY_WIDGET_BG_IMAGE = 'widget_bg_image';
  static readonly KEY_WIDGET_TEXT_WHITE = 'widget_text_white';

  static readonly KEY_NOTIFY_DDL_WARNING = 'notify_ddl_warning';
  static readonly KEY_NOTIFY_HABIT_REMINDER = 'notify_habit_reminder';
  static readonly KEY_NOTIFY_SUMMARY_ENABLE = 'notify_summary_enable';
  static readonly KEY_NOTIFY_SUMMARY_TIME = 'notify_summary_time';

  static readonly KEY_STARTUP_PAGE = 'startup_page';
  static readonly KEY_SHOW_GUIDE_NEXT_LAUNCH = 'show_guide_next_launch';

  static readonly KEY_ENGLISH_SOMEWHERE = 'english_somewhere';
  static readonly KEY_HABIT_PROGRESS_STYLE = 'habit_progress_style';

  static readonly KEY_ADD_SYMBOL_WEIGHT = 'add_symbol_weight';
  static readonly KEY_ENABLE_TABLET_UI = 'enable_tablet_ui';
  static readonly KEY_TABLET_SIDE_DASHBOARD = 'tablet_side_dashboard';

  static readonly KEY_SHOW_AI_INPUT = 'show_ai_input';
  static readonly KEY_DIRECT_ADD_ON_AI = 'direct_add_on_ai';
  static readonly KEY_AI_SILENT_TASK_ADD = 'ai_silent_task_add';
  static readonly KEY_SHOW_PAPERTALK_SHARE = 'show_papertalk_share';

  static readonly KEY_AUTO_ARCHIVE_DAYS = 'auto_archive_days';
  static readonly KEY_TOMBSTONE_RETENTION_DAYS = 'tombstone_retention_days';

  static readonly KEY_ENABLE_API23 = 'enable_api23';
  static readonly KEY_API23_MATERIAL_LEVEL = 'material_level';
  static readonly KEY_EXPERIMENTAL_COMPONENTS = 'experimental_components';

  static readonly KEY_OVERVIEW_CARD_ORDER = 'overview_card_order';
  static readonly KEY_TREND_CARD_ORDER = 'trend_card_order';
  static readonly KEY_MONTHLY_ANALYSIS = 'monthly_analysis';
  static readonly KEY_LAST_ANALYZED_MONTH = 'last_analyzed_month';
}
