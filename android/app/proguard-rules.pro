# Picked up by the Flutter Gradle plugin for release builds (R8).

# Razorpay Checkout (razorpay_flutter) — without these R8 strips the classes
# the checkout calls back into, and payment results never reach the app.
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/
-keepclasseswithmembers class * {
  public void onPayment*(...);
}
