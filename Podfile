# Uncomment the next line to define a global platform for your project
platform :ios, '12.2'

target 'MediaEditor' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for MediaEditor
#pod 'SwiftProtobuf', ">= 1.14.0"

pod 'SignalCoreKit', git: 'https://github.com/signalapp/SignalCoreKit.git', testspecs: ["Tests"]
#pod 'SignalCoreKit', path: '/Users/admin/Desktop/MediaEditor'
# pod 'SignalCoreKit', path: '../SignalCoreKit', testspecs: ["Tests"]
#pod 'LibSignalClient', git: 'https://github.com/signalapp/libsignal-client.git', testspecs: ["Tests"]
#pod 'LibSignalClient', git: 'https://github.com/signalapp/libsignal-client.git', tag: 'v0.16.0', testspecs: ["Tests"]
# pod 'LibSignalClient', path: '../libsignal-client', testspecs: ["Tests"]

#pod 'Curve25519Kit', git: 'https://github.com/signalapp/Curve25519Kit', testspecs: ["Tests"], branch: 'feature/SignalClient-adoption'
# pod 'Curve25519Kit', path: '../Curve25519Kit', testspecs: ["Tests"]

pod 'blurhash', git: 'https://github.com/signalapp/blurhash', branch: 'signal-master'
# pod 'blurhash', path: '../blurhash'
#pod 'OpenSSL-Universal', git: 'https://github.com/signalapp/GRKOpenSSLFramework'

pod 'GRDB.swift/SQLCipher', '~> 5.23.0'
pod 'SQLCipher'
pod 'PureLayout'
pod 'Mantle', git: 'https://github.com/signalapp/Mantle', branch: 'signal-master'
pod 'SignalServiceKit', path: '/Users/admin/Desktop/MediaEditor'

  target 'MediaEditorTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'MediaEditorUITests' do
    # Pods for testing
  end

end
