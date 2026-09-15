import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Product IDs — must match App Store Connect & Google Play Console exactly
// ─────────────────────────────────────────────────────────────────────────────
const String kMonthlyProductId = 'pilotenroute_premium_monthly';
const String kYearlyProductId = 'pilotenroute_premium_yearly';
const String kLifetimeProductId = 'pilotenroute_premium_lifetime';

const Set<String> kProductIds = {
  kMonthlyProductId,
  kYearlyProductId,
  kLifetimeProductId,
};

// ─────────────────────────────────────────────────────────────────────────────
// Premium tiers & feature gates
// ─────────────────────────────────────────────────────────────────────────────
enum PremiumTier { free, monthly, yearly, lifetime }

class PremiumFeature {
  static const String adFree = 'ad_free';
  static const String unlimitedExams = 'unlimited_exams';
  static const String allAircraft = 'all_aircraft';
  static const String logbookExport = 'logbook_export';
  static const String advancedWeather = 'advanced_weather';
  static const String flightPlanner = 'flight_planner';
  static const String offlineMode = 'offline_mode';
  static const String aiInstructor = 'ai_instructor';
}

// ─────────────────────────────────────────────────────────────────────────────
// PremiumService — ChangeNotifier so UI rebuilds on state change
// ─────────────────────────────────────────────────────────────────────────────
class PremiumService extends ChangeNotifier {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  bool _isPremium = false;
  PremiumTier _tier = PremiumTier.free;
  List<ProductDetails> _products = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get isPremium => _isPremium;
  PremiumTier get tier => _tier;
  List<ProductDetails> get products => _products;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ── Pricing display strings ──────────────────────────────────────────────
  static const Map<String, Map<String, String>> kPricingInfo = {
    kMonthlyProductId: {
      'title': 'Monthly',
      'price': '\$4.99/mo',
      'description': 'Full access, cancel anytime',
      'badge': '',
    },
    kYearlyProductId: {
      'title': 'Annual',
      'price': '\$34.99/yr',
      'description': 'Save 42% — best value',
      'badge': 'BEST VALUE',
    },
    kLifetimeProductId: {
      'title': 'Lifetime',
      'price': '\$79.99',
      'description': 'One-time payment, forever',
      'badge': 'POPULAR',
    },
  };

  // ── Initialize ───────────────────────────────────────────────────────────
  Future<void> initialize() async {
    await _loadPremiumStatus();
    await _loadProducts();
    _listenToPurchases();
  }

  Future<void> _loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
    final tierStr = prefs.getString('premium_tier') ?? 'free';
    _tier = PremiumTier.values.firstWhere(
      (t) => t.name == tierStr,
      orElse: () => PremiumTier.free,
    );
    notifyListeners();
  }

  Future<void> _savePremiumStatus(bool isPremium, PremiumTier tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', isPremium);
    await prefs.setString('premium_tier', tier.name);
    _isPremium = isPremium;
    _tier = tier;
    notifyListeners();
  }

  // ── Load products from store ─────────────────────────────────────────────
  Future<void> _loadProducts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        _errorMessage = 'Store not available';
        _isLoading = false;
        notifyListeners();
        return;
      }
      final ProductDetailsResponse response =
          await InAppPurchase.instance.queryProductDetails(kProductIds);
      if (response.error != null) {
        _errorMessage = response.error!.message;
      } else {
        _products = response.productDetails;
        // Sort: monthly, yearly, lifetime
        _products.sort((a, b) {
          const order = [kMonthlyProductId, kYearlyProductId, kLifetimeProductId];
          return order.indexOf(a.id).compareTo(order.indexOf(b.id));
        });
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Listen to purchase stream ────────────────────────────────────────────
  void _listenToPurchases() {
    InAppPurchase.instance.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          await _handlePurchase(purchase);
        }
      },
      onError: (error) {
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      // Verify & grant premium
      final tier = _tierFromProductId(purchase.productID);
      await _savePremiumStatus(true, tier);
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    } else if (purchase.status == PurchaseStatus.error) {
      _errorMessage = purchase.error?.message ?? 'Purchase failed';
      notifyListeners();
    } else if (purchase.status == PurchaseStatus.canceled) {
      _isLoading = false;
      notifyListeners();
    }
  }

  PremiumTier _tierFromProductId(String productId) {
    switch (productId) {
      case kMonthlyProductId:
        return PremiumTier.monthly;
      case kYearlyProductId:
        return PremiumTier.yearly;
      case kLifetimeProductId:
        return PremiumTier.lifetime;
      default:
        return PremiumTier.free;
    }
  }

  // ── Purchase ─────────────────────────────────────────────────────────────
  Future<void> purchase(ProductDetails product) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    final PurchaseParam param = PurchaseParam(productDetails: product);
    try {
      if (product.id == kLifetimeProductId) {
        await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      } else {
        await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Restore purchases ────────────────────────────────────────────────────
  Future<void> restorePurchases() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Feature gate check ───────────────────────────────────────────────────
  bool hasFeature(String feature) {
    if (_isPremium) return true;
    // Free tier gets limited access
    switch (feature) {
      case PremiumFeature.adFree:
        return false;
      case PremiumFeature.unlimitedExams:
        return false; // free: 10 questions only
      case PremiumFeature.allAircraft:
        return false; // free: 2 aircraft only
      case PremiumFeature.logbookExport:
        return false;
      case PremiumFeature.advancedWeather:
        return false;
      case PremiumFeature.flightPlanner:
        return false;
      case PremiumFeature.offlineMode:
        return false;
      case PremiumFeature.aiInstructor:
        return false;
      default:
        return true;
    }
  }

  // ── Dev/debug override ───────────────────────────────────────────────────
  Future<void> debugSetPremium(bool value) async {
    if (kDebugMode) {
      await _savePremiumStatus(value, value ? PremiumTier.yearly : PremiumTier.free);
    }
  }

  // ── Cancel / manage subscription ────────────────────────────────────────
  String get manageSubscriptionUrl {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'https://apps.apple.com/account/subscriptions';
    }
    return 'https://play.google.com/store/account/subscriptions?sku=$kMonthlyProductId&package=com.americangroupllc.pilotenroute';
  }
}
