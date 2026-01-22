workflows:
  ios-dev-ipa:
    name: iOS Dev IPA (Lean)
    environment:
      flutter: stable
      xcode: latest
    scripts:
      - flutter clean
      - flutter pub get
      - flutter build ipa --release
    artifacts:
      - build/ios/ipa/*.ipa
