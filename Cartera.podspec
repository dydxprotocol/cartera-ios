Pod::Spec.new do |s|
  s.name             = 'Cartera'
  s.version          = '0.1.7'
  s.summary          = 'Web3 mobile wallet connection library for iOS'
  s.homepage         = 'https://github.com/dydxprotocol/cartera-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Rui' => 'rui@dydx.exchange' }
  s.source           = { :git => 'git@github.com:dydxprotocol/cartera-ios.git', :tag => s.version.to_s }
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'
  s.source_files = 'Sources/Cartera/**/*'
  s.dependency 'CoinbaseWalletSDK'
  s.dependency 'WalletConnectSwift'
  s.dependency 'WalletConnectSwiftV2'
  s.dependency 'Starscream'
  s.dependency 'BigInt'
  s.dependency 'web3.swift'
  s.dependency 'secp256k1.swift'
  s.resource_bundles = {
    'Cartera_Cartera' => [ # Match the name SPM Generates
       'Sources/Cartera/Resources/*.json',
    ]
  }
end
