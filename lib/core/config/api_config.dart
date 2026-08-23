class ApiConfig {
  ApiConfig._();

  /// عنوان Kayan API على Railway
  static const String kayanApiBase =
      'https://kayan-api-production-b2a7.up.railway.app';

  /// نقاط نهاية Kayan API
  static const String agoraTokenEndpoint   = '$kayanApiBase/agora/token';
  static const String coinsRechargeEndpoint = '$kayanApiBase/coins/recharge';
  static const String authVerifyEndpoint    = '$kayanApiBase/auth/verify';
  static const String micTokenEndpoint      = '$kayanApiBase/mic/token';
}
