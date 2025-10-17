// lib/services/admob_service.dart

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  static bool _isInitialized = false;
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;

  /// Test Ad Unit IDs (safe for development/testing)
  /// Replace these with your real Ad Unit IDs from AdMob console before release
  static const String _testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  /// YOUR REAL AD UNIT IDs (get these from AdMob console)
  /// Android: ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY
  /// iOS: ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY
  static const String _androidRewardedAdUnitId = 'ca-app-pub-4425611562080784/5470334627';
  static const String _iosRewardedAdUnitId = 'ca-app-pub-4425611562080784/5470334627';

  /// Get the appropriate Ad Unit ID based on platform
  static String get _rewardedAdUnitId {
    if (kDebugMode) {
      // Always use test ads in debug mode
      debugPrint('🧪 Using TEST Ad Unit ID');
      return _testRewardedAdUnitId;
    }

    // Use real ads in release mode
    if (Platform.isAndroid) {
      debugPrint('📱 Using REAL Android Ad Unit ID: $_androidRewardedAdUnitId');
      return _androidRewardedAdUnitId;
    } else if (Platform.isIOS) {
      debugPrint('📱 Using REAL iOS Ad Unit ID: $_iosRewardedAdUnitId');
      return _iosRewardedAdUnitId;
    }
    debugPrint('⚠️ Platform not recognized, falling back to test ad');
    return _testRewardedAdUnitId;
  }

  /// Initialize AdMob
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set up test devices ONLY in debug mode
      if (kDebugMode) {
        final configuration = RequestConfiguration(
          testDeviceIds: [
            // Add your device's advertising ID here
            // Example: '33BE2250-1C4C-4826-A00C-XXXXXXXXXX'
            // You can find this in: Settings > Google > Ads
            'bc7a3379-43ba-4cc4-bdfe-ce966a737847',
          ],
        );
        await MobileAds.instance.updateRequestConfiguration(configuration);
        debugPrint('🧪 Test device configuration enabled for debugging');
      } else {
        // In release mode, use production configuration
        debugPrint('📱 Production mode - using real ads');
      }

      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('✅ AdMob initialized successfully');

      // Pre-load first rewarded ad
      _instance._loadRewardedAd();
    } catch (e) {
      debugPrint('❌ Failed to initialize AdMob: $e');
      _isInitialized = false;
    }
  }

  /// Load a rewarded ad
  void _loadRewardedAd() {
    if (_isAdLoading || _rewardedAd != null) {
      debugPrint('⏳ Ad already loading or loaded');
      return;
    }

    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('✅ Rewarded ad loaded successfully');
          _rewardedAd = ad;
          _isAdLoading = false;

          // Set up full screen content callback
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (RewardedAd ad) {
              debugPrint('📺 Ad showed full screen content');
            },
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              debugPrint('❌ Ad dismissed');
              ad.dispose();
              _rewardedAd = null;
              // Pre-load next ad
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              debugPrint('❌ Ad failed to show: $error');
              ad.dispose();
              _rewardedAd = null;
              // Pre-load next ad
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('❌ Rewarded ad failed to load:');
          debugPrint('   Error Code: ${error.code}');
          debugPrint('   Error Domain: ${error.domain}');
          debugPrint('   Error Message: ${error.message}');
          debugPrint('   Response Info: ${error.responseInfo}');
          _isAdLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Show rewarded ad
  /// Returns true if ad was shown, false if not available
  /// onRewarded callback is called when user earns reward
  /// onFailed callback is called if ad fails or is dismissed without reward
  Future<bool> showRewardedAd({
    required Function() onRewarded,
    required Function(String error) onFailed,
  }) async {
    if (!_isInitialized) {
      debugPrint('❌ AdMob not initialized');
      onFailed('AdMob لم يتم تهيئة');
      return false;
    }

    if (_rewardedAd == null) {
      debugPrint('❌ No rewarded ad available');
      onFailed('الإعلان غير متاح حالياً. يرجى المحاولة لاحقاً');
      // Try to load ad for next time
      _loadRewardedAd();
      return false;
    }

    // Set the reward callback
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint('✅ User earned reward: ${reward.amount} ${reward.type}');
        onRewarded();
      },
    );

    // Wait a bit to see if ad shows
    await Future.delayed(const Duration(milliseconds: 500));

    // If ad didn't show, it will be disposed by fullScreenContentCallback
    // and _rewardedAd will be null

    return true;
  }

  /// Check if rewarded ad is ready
  bool get isRewardedAdReady => _rewardedAd != null;

  /// Dispose all ads
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
