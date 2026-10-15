# SignFix App — API Connect Report

**Date:** 2025-07-17  
**Task:** Connect all mock APIs to real backend at `https://signfix-2.onrender.com/api`

---

## Changes Made

### 1. `lib/services/api_client.dart` (Customer API)

- ✅ `mockMode = false` — default changed from `true` to `false`
- ✅ `chat()` real path fixed: `/ai/chat` → `/customer/ai/chat`
- ✅ `DELETE` case added to `_request()` switch
- ✅ `logout()` now calls `POST /auth/logout` on backend before clearing local state (fire-and-forget)
- ✅ `register()` real branch now stores returned token in memory and SharedPreferences
- ✅ New methods added (real HTTP, no mock branch):
  - `getCustomerDashboard()`
  - `cancelOrder(id)`, `cancelService(id)`
  - `confirmServiceCompletion(serviceId, otp)`
  - `reviewService(serviceId, data)`, `reviewOrder(orderId, data)`
  - `getQuotations()`, `getQuotation(id)`, `approveQuotation(id)`, `rejectQuotation(id)`, `requestQuotationChanges(id, message)`
  - `createPaymentIntent(data)`, `verifyPayment(paymentId, data)`, `reportPaymentFailure(paymentId)`, `getPayments()`
  - `getAiConfig()`, `getAiConversations()`
  - `changePassword(oldPassword, newPassword)`
  - `deleteAccount()` — calls `DELETE /customer/account` then `logout()`

---

### 2. `lib/technician/services/api_client.dart` (Technician API)

- ✅ `baseUrl` default changed from `http://10.0.2.2:4000/api` → `https://signfix-2.onrender.com/api`
- ✅ `mockMode = false` — default changed from `true` to `false`
- ✅ `jobs()` real path fixed: `/jobs` → `/technician/jobs`
- ✅ `updateJob()` real path fixed: `/jobs/` → `/technician/jobs/`
- ✅ Registration paths updated:
  - `sendOtp` → `POST /auth/resend-registration-otp` with `{identifier, purpose}`
  - `verifyOtp` → `POST /auth/verify-otp` with `{identifier, otp, purpose}`; stores `data.token` as `technician_token`
  - `register` → `POST /auth/register` with `{...data, portal: 'technician'}`; stores returned token
  - `registrationStatus` → `GET /auth/me`
- ✅ New methods added:
  - `getJobDetail(jobId)`
  - `sendCompletionOtp(jobId)`
  - `confirmJobCompletion(jobId, otp)`
  - `updateLocation(jobId, lat, lng)`
  - `uploadEvidence(jobId, photos, notes)` — multipart upload

---

### 3. `lib/screens/payment/payment_screen.dart`

- ✅ Import added: `import '../../services/api_client.dart';`
- ✅ `required this.api` added to constructor; `final ApiClient api;` field added
- ✅ Razorpay key changed to `String.fromEnvironment('RAZORPAY_KEY', defaultValue: 'rzp_test_YourKeyHere')`
- ✅ `_launch()` converted to `async Future<void>`
- ✅ `createPaymentIntent` called before checkout; backend `order_id` passed into Razorpay options
- ✅ `_onSuccess` calls `verifyPayment` (fire-and-forget) with full Razorpay signature data
- ✅ `_onError` calls `reportPaymentFailure` (fire-and-forget) using payment_id from error metadata
- ✅ `onPay: () { _launch(); }` — satisfies `VoidCallback` type

---

### 4. `lib/screens/orders/order_wizard.dart` (PaymentScreen call site)

- ✅ `api: widget.api` added to the `PaymentScreen(...)` instantiation

---

### 5. `lib/technician/screens/registration/otp_verification_screen.dart`

- ✅ `kDebugMode` guard already present — no change needed

---

## Verification

| Check | Status |
|-------|--------|
| `mockMode = false` in customer `api_client.dart` | ✅ |
| `mockMode = false` in technician `api_client.dart` | ✅ |
| Technician `baseUrl = https://signfix-2.onrender.com/api` | ✅ |
| `flutter analyze` — zero error-level issues | ✅ |
| OTP demo hint wrapped in `kDebugMode` | ✅ (was already done) |
| `PaymentScreen` uses real backend calls | ✅ |
| All `PaymentScreen` call sites updated with `api:` parameter | ✅ (1 call site: `order_wizard.dart`) |

### flutter analyze result

Only 3 pre-existing `info`-level hints in `lib/screens/ai/ai_chat.dart`  
(`prefer_const_constructors` — style-only, not errors, file not modified).  
**Zero warnings or errors in any modified file.**
