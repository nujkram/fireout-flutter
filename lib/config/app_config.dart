enum Environment {
  development,
  staging,
  production,
}

class AppConfig {
  static late AppConfig _instance;
  static AppConfig get instance => _instance;

  final Environment environment;
  final String appName;
  final String baseUrl;
  final String mongoConnectionString;
  final bool debugMode;

  AppConfig._({
    required this.environment,
    required this.appName,
    required this.baseUrl,
    required this.mongoConnectionString,
    required this.debugMode,
  });

  static void initialize() {
    // Get flavor from build configuration
    // For release builds, this should be set by the build system
    const String flavor = String.fromEnvironment('FLAVOR', defaultValue: 'production');
    
    print('🔧 App Config - Flavor from environment: $flavor');
    
    Environment environment;
    switch (flavor) {
      case 'staging':
        environment = Environment.staging;
        break;
      case 'production':
        environment = Environment.production;
        break;
      default:
        environment = Environment.development;
        break;
    }

    switch (environment) {
      case Environment.development:
        _instance = AppConfig._(
          environment: Environment.development,
          appName: 'Fireout Dev',
          baseUrl: 'http://localhost:5173',
          mongoConnectionString: 'mongodb+srv://mark:asdf1234@fire.qrebi.mongodb.net/bfpStaging',
          debugMode: true,
        );
        break;
      case Environment.staging:
        _instance = AppConfig._(
          environment: Environment.staging,
          appName: 'Fireout Staging',
          baseUrl: 'https://fireout-svelte.vercel.app',
          mongoConnectionString: 'mongodb+srv://mark:asdf1234@fire.qrebi.mongodb.net/bfpStaging',
          debugMode: true,
        );
        break;
      case Environment.production:
        _instance = AppConfig._(
          environment: Environment.production,
          appName: 'Fireout',
          baseUrl: 'https://fireout-svelte.vercel.app',
          mongoConnectionString: 'mongodb+srv://mark:asdf1234@fire.qrebi.mongodb.net/bfpProduction',
          debugMode: false,
        );
        break;
    }
  }

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;
}