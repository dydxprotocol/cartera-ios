
<h1 align="center">Cartera-iOS</h1>

<div align="center">
  <a href='https://github.com/dydxprotocol/cartera-ios/blob/main/LICENSE'>
    <img src='https://img.shields.io/badge/License-AGPL_v3-blue.svg' alt='License' />
  </a>
</div>


Cartera is a mobile web3 wallet integrator.  It acts an abtraction layer over various wallet SDKs to provide a shared interface for common wallet operations.  Cartera has the built-in support of the following SDKs:

- WalletConnect V1
- WalletConnect V2
- CoinbaseWallet SDK

## Installation

### Swift Package Manager

Add .package(url:_:) to your Package.swift:
```Swift
dependencies: [
   .package(url: "https://github.com/dydxprotocol/cartera-ios", .branch("main")),
],

```
### Cocoapods

Add pod to your Podfile:
```Ruby
pod 'Cartera'
```

## SDK Configuration

To enable the built-in SDK support, create a configuration object for each of the SDKs as follows
```Swift
    private let walletProvidersConfig: WalletProvidersConfig = {
        let walletConnectV1Config = WalletConnectV1Config(clientName: "dYdX",
                                                          clientDescription: "dYdX Trading App",
                                                          iconUrl: "https://media.dydx.exchange/logos/dydx-x.png",
                                                          scheme: "dydx:",
                                                          clientUrl: "https://trade.dydx.exchange/",
                                                          bridgeUrl: "<WC1_BRIDGE_URL>")
        let walletConnectV2Config = WalletConnectV2Config(projectId: "<WC2_PROJECT_ID>",
                                                          clientName: "dYdX",
                                                          clientDescription: "dYdX Trading App",
                                                          clientUrl: "https://trade.dydx.exchange/",
                                                          iconUrls: ["https://media.dydx.exchange/logos/dydx-x.png"],
                                                          redirectNative: "dydxV4",
                                                          redirectUniversal: "https://trade.dydx.exchange/")
        let walletSegueConfig = WalletSegueConfig(callbackUrl: "<WS_CALLBACK_URL>")
        return  WalletProvidersConfig(walletConnectV1: walletConnectV1Config,
                                      walletConnectV2: walletConnectV2Config,
                                      walletSegue: walletSegueConfig)
    }()
```
The above code creates a config object for WalletConnect V1, WalletConnect V2 and CoinbaseSDK.  The configuration data is self-explanatory.  Please refer the the documentation of those SDKs for further explanations. 

Give the configuration to Cartra by calling
```Swift
 CarteraConfig.shared = CarteraConfig(walletProvidersConfig: walletProvidersConfig)
```
You also add additional SDK support by implementing Cartera's interfaces and calling [CarteraConfig.shared.registerProvider()](/Sources/Cartera/CarteraConfig.swift)

## Wallet Configuration

There is a list of supported wallets specified in [wallets_config.json](Sources/Cartera/Resources/wallets_config.json).  Call the following to register those wallets with Cartera:
```Swift
CarteraConfig.shared.registerWallets()
```
Alternatively, you can specify a path of your own wallet config JSON file as follows:
```Swift
CarteraConfig.shared.registerWallets(configJsonPath: "<path_to_config_json>")
```

## Wallet Operations

Once configured, you can obtain a list of supported wallets, along with their status (e.g., installed or not) with
```Swift
   let selectedWallet = CarteraConfig.shared.wallets[0]
```
To operate on a wallet, create a CarteraProvider and, optionally, set its walletStatusDelegate:
```Swift
    private lazy var provider: CarteraProvider = {
         let provider = CarteraProvider()
        provider.walletStatusDelegate = self
        return provider
    }()
```
The following code would ask the selected wallet to sign a personal message:
```SWift
    let request = WalletRequest(wallet: selectedWallet, address: nil, chainId: chainId)
    provider.signMessage(request: request, message: "Test Message", connected: { info in
        print("connected: \(info?.address ?? "")")
    }, completion: { [weak self] signed, error in
        if let error = error {
            // show error
        } else {
            // success
    })
```

## Examples

For reference, there is a [sample app](Example) in the repo.
