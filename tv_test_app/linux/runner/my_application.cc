#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <stdlib.h>

#include "flutter/generated_plugin_registrant.h"

// The title every window of this app shows, on the desktop and in the
// streaming container's virtual screen.
static const char kWindowTitle[] = "Thumb Party TV";

// The size a desktop window opens with.
static const int kDefaultWindowWidth = 1280;
static const int kDefaultWindowHeight = 720;

// The streaming container asks for the size its capture pipeline encodes
// (1920x1080 by default) through these variables, so the picture it streams is
// the app's own pixels and not a scaled window.
static const char kWindowWidthEnv[] = "THUMB_PARTY_WINDOW_WIDTH";
static const char kWindowHeightEnv[] = "THUMB_PARTY_WINDOW_HEIGHT";

// A width or height outside this range is a mistake and is ignored.
static const long kMinWindowSize = 320;
static const long kMaxWindowSize = 16384;

// Which renderer Flutter draws with (M15 k1-2): Impeller, the engine's own
// default, or Skia when this variable says `0` or `false`. The streaming
// container has no engine-switch variable to do this, so the comparison runs
// through here. Skia measured a 1080p frame's raster at 4.6 ms against
// Impeller's 9.9 and drew 52-55 fps against 48.5-51.9 in the Arena round
// (two runs each, streaming/README.md), so it is a switch for the next phase
// rather than the default.
static const char kImpellerEnv[] = "THUMB_PARTY_IMPELLER";

// Reads a wanted window size from the environment, or returns `fallback` when
// the variable is unset or is not a number in range.
static int window_size_from_env(const char* name, int fallback) {
  const char* value = g_getenv(name);
  if (value == nullptr || *value == '\0') {
    return fallback;
  }

  char* end = nullptr;
  const long size = strtol(value, &end, 10);
  if (end == value || *end != '\0' || size < kMinWindowSize ||
      size > kMaxWindowSize) {
    return fallback;
  }

  return static_cast<int>(size);
}

// Whether the renderer is Impeller: on unless the environment says `0` or
// `false`, so a launch that says nothing gets the engine's own default.
static gboolean impeller_from_env() {
  const char* value = g_getenv(kImpellerEnv);
  if (value == nullptr || *value == '\0') {
    return TRUE;
  }
  return g_strcmp0(value, "0") != 0 && g_ascii_strcasecmp(value, "false") != 0;
}

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, kWindowTitle);
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, kWindowTitle);
  }

  gtk_window_set_default_size(
      window, window_size_from_env(kWindowWidthEnv, kDefaultWindowWidth),
      window_size_from_env(kWindowHeightEnv, kDefaultWindowHeight));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_enable_impeller(project, impeller_from_env());
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
