import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../data/models/models.dart';

/// Takes the Thekedar through a checkout for a server-made [PaymentOrder] and
/// hands back what the gateway says happened.
///
/// A receipt is only a claim until `POST .../payment/verify` has checked its
/// signature — the gateway never decides a booking is paid by itself.
abstract interface class PaymentGateway {
  /// False where the native checkout does not exist (web, desktop), so the
  /// Online side of the payment sheet can say so instead of failing on tap.
  bool get isAvailable;

  /// Throws [PaymentCancelled] when the Thekedar backs out, [PaymentFailed]
  /// for anything the gateway refused.
  Future<PaymentReceipt> checkout(
    PaymentOrder order, {
    required String description,
  });
}

/// The Thekedar closed the checkout without paying. Not an error to shout
/// about — nothing was taken.
class PaymentCancelled implements Exception {
  const PaymentCancelled();
}

/// The gateway refused or broke. [message] is Razorpay's own, when it gave one.
class PaymentFailed implements Exception {
  const PaymentFailed([this.message]);

  final String? message;
}

/// Razorpay Standard Checkout, via `razorpay_flutter` (Android and iOS only).
class RazorpayGateway implements PaymentGateway {
  const RazorpayGateway();

  @override
  bool get isAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<PaymentReceipt> checkout(
    PaymentOrder order, {
    required String description,
  }) {
    // Registering a listener already talks to the native side, so on a
    // platform without it nothing may be constructed at all.
    if (!isAvailable) return Future.error(const PaymentFailed());

    final razorpay = Razorpay();
    final result = Completer<PaymentReceipt>();

    razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
        if (result.isCompleted) return;
        final paymentId = r.paymentId;
        final signature = r.signature;
        if (paymentId == null || signature == null) {
          result.completeError(const PaymentFailed());
          return;
        }
        result.complete(
          PaymentReceipt(
            orderId: r.orderId ?? order.orderId,
            paymentId: paymentId,
            signature: signature,
          ),
        );
      })
      ..on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        if (result.isCompleted) return;
        result.completeError(
          r.code == Razorpay.PAYMENT_CANCELLED
              ? const PaymentCancelled()
              : PaymentFailed(r.message),
        );
      })
      // No external wallets are offered in the options below, so this should
      // never fire — and if it did, there would be no receipt to verify.
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse _) {
        if (!result.isCompleted) result.completeError(const PaymentFailed());
      })
      ..open({
        'key': order.keyId,
        'order_id': order.orderId,
        'amount': order.amount * 100, // paise
        'currency': order.currency,
        'name': 'KaamJi',
        'description': description,
        'prefill': {
          'name': ?order.prefillName,
          'contact': ?order.prefillContact,
        },
        'theme': {'color': '#FFD600'},
      });

    return result.future.whenComplete(razorpay.clear);
  }
}

/// Stands in for Razorpay under the mock repository, so the demo build and the
/// widget tests can walk the whole online flow without a gateway account.
class SimulatedGateway implements PaymentGateway {
  const SimulatedGateway();

  @override
  bool get isAvailable => true;

  @override
  Future<PaymentReceipt> checkout(
    PaymentOrder order, {
    required String description,
  }) async => PaymentReceipt(
    orderId: order.orderId,
    paymentId: 'pay_mock_${order.bookingId}',
    signature: 'mock_signature',
  );
}
