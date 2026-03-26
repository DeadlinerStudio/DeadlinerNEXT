interface StoreConfigInterface {
  name: string;
  securityLevel: number;
}

export class DbConstants {
  static readonly STORE_CONFIG: StoreConfigInterface = {
    name: 'deadliner.db',
    securityLevel: 1 // S1
  };

  static readonly VERSION_V2 = 22;

  static readonly TABLE_NAME = "ddl_items";
  static readonly COLUMN_ID = "id";
  static readonly COLUMN_NAME = "name";
  static readonly COLUMN_START_TIME = "start_time";
  static readonly COLUMN_END_TIME = "end_time";
  static readonly COLUMN_STATE = "state";
  static readonly COLUMN_IS_COMPLETED = "is_completed";
  static readonly COLUMN_COMPLETE_TIME = "complete_time";
  static readonly COLUMN_NOTE = "note";
  static readonly COLUMN_IS_ARCHIVED = "is_archived";
  static readonly COLUMN_IS_STARED = "is_stared";
  static readonly COLUMN_TYPE = "type";
  static readonly COLUMN_HABIT_COUNT = "habit_count";
  static readonly COLUMN_HABIT_TOTAL_COUNT = "habit_total_count";
  static readonly COLUMN_CALENDAR_EVENT_ID = "calendar_event";
  static readonly COLUMN_TIMESTAMP = "timestamp";

  // Sync columns
  static readonly COLUMN_UID = "uid";
  static readonly COLUMN_DELETED = "deleted";
  static readonly COLUMN_VER_TS = "ver_ts";
  static readonly COLUMN_VER_CTR = "ver_ctr";
  static readonly COLUMN_VER_DEV = "ver_dev";
  static readonly COLUMN_HABIT_APPLIED_VER_TS = "habit_applied_ver_ts";
  static readonly COLUMN_HABIT_APPLIED_VER_CTR = "habit_applied_ver_ctr";
  static readonly COLUMN_HABIT_APPLIED_VER_DEV = "habit_applied_ver_dev";

  // Habit Table
  static readonly TABLE_HABIT = "habits";
  static readonly HABIT_ID = "id";
  static readonly HABIT_DDL_ID = "ddl_id";
  static readonly HABIT_NAME = "name";
  static readonly HABIT_DESC = "description";
  static readonly HABIT_COLOR = "color";
  static readonly HABIT_ICON_KEY = "icon_key";
  static readonly HABIT_PERIOD = "period";
  static readonly HABIT_TIMES_PER_PERIOD = "times_per_period";
  static readonly HABIT_GOAL_TYPE = "goal_type";
  static readonly HABIT_TOTAL_TARGET = "total_target";
  static readonly HABIT_CREATED_AT = "created_at";
  static readonly HABIT_UPDATED_AT = "updated_at";
  static readonly HABIT_STATUS = "status";
  static readonly HABIT_SORT_ORDER = "sort_order";
  static readonly HABIT_ALARM_TIME = "alarm_time";

  // Habit Record Table
  static readonly TABLE_HABIT_RECORD = "habit_records";
  static readonly HR_ID = "id";
  static readonly HR_HABIT_ID = "habit_id";
  static readonly HR_DATE = "date";
  static readonly HR_COUNT = "count";
  static readonly HR_STATUS = "status";
  static readonly HR_CREATED_AT = "created_at";

  // SubTask Table
  static readonly TABLE_SUBTASK = "subtasks";
  static readonly ST_ID = "id";
  static readonly ST_DDL_ID = "ddl_id";
  static readonly ST_CONTENT = "content";
  static readonly ST_IS_COMPLETED = "is_completed";
  static readonly ST_SORT_ORDER = "sort_order";
  static readonly ST_UID = "uid";
  static readonly ST_DELETED = "deleted";
  static readonly ST_VER_TS = "ver_ts";
  static readonly ST_VER_CTR = "ver_ctr";
  static readonly ST_VER_DEV = "ver_dev";
}
