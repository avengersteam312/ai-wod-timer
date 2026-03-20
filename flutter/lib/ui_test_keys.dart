import 'package:flutter/widgets.dart';

final class UiTestKeys {
  static const manualTab = ValueKey<String>('manual_tab');
  static const dashboardTab = ValueKey<String>('dashboard_tab');
  static const historyTab = ValueKey<String>('history_tab');

  static const manualScreen = ValueKey<String>('manual_screen');
  static const manualTimerTypeSelector =
      ValueKey<String>('manual_timer_type_selector');
  static const manualStartButton = ValueKey<String>('manual_start_button');
  static const manualSaveButton = ValueKey<String>('manual_save_button');

  static const dashboardScreen = ValueKey<String>('dashboard_screen');
  static const dashboardTextInput = ValueKey<String>('dashboard_text_input');
  static const dashboardCreateTimerButton =
      ValueKey<String>('dashboard_create_timer_button');
  static const dashboardTextModeToggle =
      ValueKey<String>('dashboard_text_mode_toggle');
  static const dashboardImageModeToggle =
      ValueKey<String>('dashboard_image_mode_toggle');
  static const dashboardTakePhotoButton =
      ValueKey<String>('dashboard_take_photo_button');
  static const dashboardChooseGalleryButton =
      ValueKey<String>('dashboard_choose_gallery_button');
  static const dashboardResumeButton =
      ValueKey<String>('dashboard_resume_button');
  static const dashboardViewAllSavedWorkouts =
      ValueKey<String>('dashboard_view_all_saved_workouts');
  static const timerEditAction = ValueKey<String>('timer_edit_action');
  static const timerCameraAction = ValueKey<String>('timer_camera_action');
  static const timerCancelButton = ValueKey<String>('timer_cancel_button');
  static const timerPlayPauseButton =
      ValueKey<String>('timer_play_pause_button');
  static const timerResetButton = ValueKey<String>('timer_reset_button');
  static const timerStopButton = ValueKey<String>('timer_stop_button');

  static const historyScreen = ValueKey<String>('history_screen');
  static const historyRetryButton = ValueKey<String>('history_retry_button');

  static const myWorkoutsScreen = ValueKey<String>('my_workouts_screen');
  static const myWorkoutsRefreshButton =
      ValueKey<String>('my_workouts_refresh_button');

  static const saveTemplateNameField =
      ValueKey<String>('save_template_name_field');
  static const saveTemplateSubmitButton =
      ValueKey<String>('save_template_submit_button');
  static const saveTemplateCancelButton =
      ValueKey<String>('save_template_cancel_button');

  static const authButton = ValueKey<String>('auth_button');
  static const loginEmailField = ValueKey<String>('login_email_field');
  static const loginPasswordField = ValueKey<String>('login_password_field');
  static const loginSubmitButton = ValueKey<String>('login_submit_button');

  static const videoScreen = ValueKey<String>('video_screen');
  static const videoCloseButton = ValueKey<String>('video_close_button');
  static const videoRecordButton = ValueKey<String>('video_record_button');
  static const videoStopButton = ValueKey<String>('video_stop_button');

  static ValueKey<String> dashboardSavedWorkout(String workoutId) =>
      ValueKey<String>('dashboard_saved_workout_$workoutId');

  static ValueKey<String> historySession(String sessionId) =>
      ValueKey<String>('history_session_$sessionId');

  static ValueKey<String> myWorkout(String workoutId) =>
      ValueKey<String>('my_workout_$workoutId');
}
