/// TrackIT wordmark assets — light/dark variants from the Ionic web app.
abstract final class AppBranding {
  static const logoLight = 'assets/images/trackit-logo-light.png';
  static const logoDark = 'assets/images/trackit-logo-dark.png';

  static String logoForDarkMode(bool isDark) => isDark ? logoDark : logoLight;
}
