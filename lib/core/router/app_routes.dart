abstract final class AppRoutes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const setup = '/setup';
  static const noAccess = '/no-access';

  static const home = '/';
  static const scan = '/scan';
  static const deliver = '/deliver';
  static const cylinders = '/cylinders';
  static const labels = '/labels';
  static const customers = '/customers';
  static const staff = '/staff';
  static const settings = '/settings';

  static String cylinder(String serial) => '/cylinders/$serial';
  static String customer(String id) => '/customers/$id';

  /// Where a QR label's URL lands: `/c/{orgId}/{serial}`.
  static const qrLanding = '/c/:orgId/:serial';

  static const public = {splash, signIn, signUp};
}
