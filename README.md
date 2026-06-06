# INTERFLEX - Secure International Money Transfer

## Security Features Implemented
1. **Biometric Authentication**: Using `local_auth` for Fingerprint/FaceID access.
2. **Secure Storage**: All sensitive data (JWT, Session tokens) are stored using AES encryption via `flutter_secure_storage`.
3. **API Security**: 
   - JWT Authorization headers.
   - Request timeout and error handling.
   - Anti-tampering headers (`X-Device-Id`).
4. **Data Masking**: Sensitive fields are handled securely in UI components.
5. **Secure Input**: OTP screens use `pinput` for obfuscated and restricted input.

## Features
- **Global Money Transfer**: Support for multiple currencies (UI Template).
- **Service & Goods Payment**: QR Code scanning integration (UI Ready).
- **Wallet Management**: Real-time balance and transaction history.

## Getting Started
1. Run `flutter pub get` to install dependencies.
2. Ensure you have Android/iOS folders set up (`flutter create .` if needed).
3. Connect your backend API to `lib/services/api_service.dart`.
