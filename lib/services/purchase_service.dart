import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'database_service.dart';

/// Product ID registered in Google Play Console.
/// TODO: Register this product ID in Google Play Console before publishing.
const kRemoveAdsProductId = 'remove_ads';

/// Key used to persist premium status in Hive configBox.
const _premiumKey = 'isPremium';

/// Manages in-app purchases. Handles buying and restoring the "Remove Ads"
/// non-consumable product.
class PurchaseService {
  final DatabaseService _db;

  PurchaseService(this._db);

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Whether the user has purchased the Remove Ads product.
  bool get isPremium => _db.settingsBox.get(_premiumKey) as bool? ?? false;

  /// Persists premium status to Hive.
  Future<void> _setPremium(bool value) async {
    await _db.settingsBox.put(_premiumKey, value);
  }

  /// Initialize the purchase listener. Must be called once on app start.
  /// Returns a stream that emits updated [isPremium] values.
  StreamController<bool> initialize() {
    final controller = StreamController<bool>.broadcast();

    try {
      _subscription = InAppPurchase.instance.purchaseStream.listen(
        (purchases) async {
          for (final purchase in purchases) {
            await _handlePurchase(purchase, controller);
          }
        },
        onError: (e) => debugPrint('PurchaseService stream error: $e'),
      );
    } catch (e) {
      // Google Play Billing not available (e.g. emulator without Play Store).
      debugPrint('PurchaseService: billing unavailable — $e');
    }

    return controller;
  }

  Future<void> _handlePurchase(
    PurchaseDetails purchase,
    StreamController<bool> controller,
  ) async {
    if (purchase.productID != kRemoveAdsProductId) return;

    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      // Deliver the product
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
      await _setPremium(true);
      controller.add(true);
    } else if (purchase.status == PurchaseStatus.error) {
      debugPrint('Purchase error: ${purchase.error}');
    }
  }

  /// Fetch product details from the store. Returns null if unavailable.
  Future<ProductDetails?> fetchProductDetails() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) return null;

    final response = await InAppPurchase.instance
        .queryProductDetails({kRemoveAdsProductId});
    if (response.productDetails.isEmpty) return null;
    return response.productDetails.first;
  }

  /// Initiate the purchase flow. Returns false if store is unavailable.
  Future<bool> buyRemoveAds() async {
    final product = await fetchProductDetails();
    if (product == null) return false;

    final param = PurchaseParam(productDetails: product);
    return InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  /// Restore previously completed purchases (required by store policies).
  Future<void> restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
  }

  void dispose() {
    _subscription?.cancel();
  }
}
