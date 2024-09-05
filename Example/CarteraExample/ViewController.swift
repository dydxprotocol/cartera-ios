//
//  ViewController.swift
//  CarteraExample
//
//  Created by Rui Huang on 2/22/23.
//

import UIKit
import Cartera
import SDWebImage
import web3
import BigInt

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, WalletStatusDelegate {
    @IBOutlet var tableView: UITableView?
    @IBOutlet var chainSegmentControl: UISegmentedControl?
    @IBOutlet var statusLabel: UILabel?
    @IBOutlet var walletLabel: UILabel?
    @IBOutlet var connectedDeepLinkLabel: UILabel?
  
    private var chainId: Int {
        chainSegmentControl?.selectedSegmentIndex == 0 ? 1 : 5
    }
    
    private lazy var provider: CarteraProvider = {
         let provider = CarteraProvider()
        provider.walletStatusDelegate = self
        return provider
    }()
    
    private var alertController: UIAlertController?
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        CarteraConfig.shared = CarteraConfig(walletProvidersConfig: walletProvidersConfig)
        CarteraConfig.shared.registerWallets()
    }
    
    private var qrCodeStarted = false
    
    @IBAction func qrCodeScan() {
        qrCodeStarted = true
        provider.startDebugLink(chainId: 5) { [weak self] info, error in
            if let error = error {
                print(error)
            } else if let info = info {
                print(info)
                self?.dismiss(animated: true)
                self?.showTestOptions(wallet: info.wallet)
            }
        }
    }
    
    // MARK: UITableViewDelegate, UITableViewDataSource
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "cell") {
            let wallet = CarteraConfig.shared.wallets[indexPath.row]
            cell.textLabel?.text = wallet.name
            if let url = wallet.config?.imageUrl {
                cell.imageView?.sd_setImage(with: URL(string: url))
            }
            if wallet.config?.installed ?? false {
                cell.detailTextLabel?.text = "Installed"
            } else {
                cell.detailTextLabel?.text = "Install..."
            }
            return cell
        }
             
        return UITableViewCell()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        CarteraConfig.shared.wallets.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let wallet = CarteraConfig.shared.wallets[indexPath.row]
        if wallet.config?.installed ?? false {
            showTestOptions(wallet: wallet)
        } else {
            if let link = wallet.appLink, let url = URL(string: link), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:])
            }
        }
    }
    
    // MARK: WalletStatusDelegate
    
    func statusChanged(_ status: Cartera.WalletStatusProtocol) {
        statusLabel?.text = "Status: \(status.state.rawValue)"
        walletLabel?.text = "Wallet: \(status.connectedWallet?.wallet?.name ?? "")"
        connectedDeepLinkLabel?.text = "ConnectionDeeplink: \(status.connectionDeeplink ?? "")"
        
        if qrCodeStarted, let deeplink = provider.walletStatus?.connectionDeeplink {
            qrCodeStarted = false
            let qrCodeVC = QrCodeViewController()
            qrCodeVC.qrCodeString = deeplink
            present(qrCodeVC, animated: true, completion: nil)
        }
    }
    
    // MARK: Private
    
    private func showTestOptions(wallet: Wallet?) {
        let alertController = UIAlertController(title: "Select Wallet Action to Test:", message: nil, preferredStyle: .actionSheet)

        let connectAction = UIAlertAction(title: "Connect", style: .default) { [weak self] _ in
            self?.alertController?.dismiss(animated: true)
            self?.testConnect(wallet: wallet)
        }
        alertController.addAction(connectAction)

        let signPersonalAction = UIAlertAction(title: "Sign Personal Message", style: .default) { [weak self] _ in
            self?.alertController?.dismiss(animated: true)
            self?.testSignMessage(wallet: wallet)
        }
        alertController.addAction(signPersonalAction)
        
        let sendTypedDataAction = UIAlertAction(title: "Sign TypedData", style: .default) { [weak self] _ in
            self?.alertController?.dismiss(animated: true)
            self?.testSignTypedData(wallet: wallet)
        }
        alertController.addAction(sendTypedDataAction)
        
        let sendTransactionAction = UIAlertAction(title: "Sign Transaction", style: .default) { [weak self] _ in
            self?.alertController?.dismiss(animated: true)
            self?.testSendTransaction(wallet: wallet)
        }
        alertController.addAction(sendTransactionAction)
        
        let addChainAction = UIAlertAction(title: "Add/Switch Chain", style: .default) { [weak self] _ in
            self?.alertController?.dismiss(animated: true)
            self?.testAddChain(wallet: wallet)
        }
        alertController.addAction(addChainAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.alertController?.dismiss(animated: true)
        }
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
        
        self.alertController = alertController
    }
    
    private func testConnect(wallet: Wallet?) {
        let request = WalletRequest(wallet: wallet, address: nil, chainId: chainId)
        provider.connect(request: request, completion: { [weak self] info, error in
            if let error = error {
                self?.showError(error: error)
            } else {
                self?.showAlert(title: "Connected", message: "\(info?.address ?? "")")
            }
        })
    }
    
    private func testSignMessage(wallet: Wallet?) {
        let request = WalletRequest(wallet: wallet, address: nil, chainId: chainId)
        provider.signMessage(request: request, message: "Test Message", connected: { info in
            print("connected: \(info?.address ?? "")")
        }, completion: { [weak self] signed, error in
            if let error = error {
                self?.showError(error: error)
            } else {
                self?.showAlert(title: "Signed", message: "\(signed ?? "")")
            }
        })
    }
    
    private func testSignTypedData(wallet: Wallet?) {
        let dydxSign = EIP712DomainTypedDataProvider(name: "dYdX", chainId: chainId, version: nil)
        dydxSign.message = message(action: "Sample Action", chainId: chainId)
     
        let request = WalletRequest(wallet: wallet, address: nil, chainId: chainId)
        provider.sign(request: request, typedDataProvider: dydxSign, connected: { info in
            print("connected: \(info?.address ?? "")")
        }, completion: { [weak self] signed, error in
            if let error = error {
                self?.showError(error: error)
            } else {
                self?.showAlert(title: "Signed", message: "\(signed ?? "")")
            }
        })
    }
    
    private func testSendTransaction(wallet: Wallet?) {
        let request = WalletRequest(wallet: wallet, address: nil, chainId: chainId)
        provider.connect(request: request, completion: { [weak self] info, error in
            guard let self = self, let info = info, let address = info.address else {
                if let error = error {
                    self?.showError(error: error)
                }
                return
            }
            let walletRequest = WalletRequest(wallet: wallet, address: nil, chainId: self.chainId)
            let transaction = EthereumTransaction(from: EthereumAddress(stringLiteral: address),
                                                  to: EthereumAddress.zero,
                                                  value: 0,
                                                  data: nil,
                                                  nonce: nil,
                                                  gasPrice: nil,
                                                  gasLimit: nil,
                                                  chainId: self.chainId)
            let ethereumRequest = EthereumTransactionRequest(transaction: transaction)
            let request = WalletTransactionRequest(walletRequest: walletRequest, ethereum: ethereumRequest)
            self.provider.send(request: request, connected: { info in
                print("connected: \(info?.address ?? "")")
            }, completion: { [weak self] response, error in
                if let error = error {
                    self?.showError(error: error)
                } else {
                    self?.showAlert(title: "Sent", message: "\(response ?? "")")
                }
            })
        })
    }
    
    private func testAddChain(wallet: Wallet?) {
        let request = WalletRequest(wallet: wallet, address: nil, chainId: chainId)
        let payload: String =
"""
        {
            "chainId": "0x61",
            "chainName": "binance",
             "rpcUrls": ["https://data-seed-prebsc-2-s1.binance.org:8545"],
             "iconUrls": [
                "https://s2.coinmarketcap.com/static/img/coins/64x64/1839.png"
           ]
        }
"""
        let decoder = JSONDecoder()
        let chain = try! decoder.decode(EthereumAddChainRequest.self, from: payload.data(using: .utf8)!)
        provider.addChain(request: request, chain: chain, timeOut: nil, connected: { info in
            print("connected: \(info?.address ?? "")")
        }, completion: { [weak self] signed, error in
            if let error = error {
                self?.showError(error: error)
            } else {
                self?.showAlert(title: "Added/Switched", message: "\(signed ?? "")")
            }
        })
    }
    
    private func showError(error: Error) {
        let walletError = error as NSError
        if let title = walletError.userInfo["title"] as? String, let message = walletError.userInfo["message"] as? String {
            showAlert(title: title, message: message)
        } else {
            showAlert(title: "Error", message: "\(error)")
        }
    }
                        
    private func showAlert(title: String?, message: String?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let okAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
             self?.alertController?.dismiss(animated: true)
        }
        alertController.addAction(okAction)

        present(alertController, animated: true, completion: nil)
        
        self.alertController = alertController
    }
    
    private func message(action: String, chainId: Int) -> WalletTypedData {
        var definitions = [[String: String]]()
        var data = [String: Any]()
        definitions.append(type(name: "action", type: "string"))
        data["action"] = action
        if chainId == 1 {
            definitions.append(type(name: "onlySignOn", type: "string"))
            data["onlySignOn"] = "https://trade.dydx.exchange"
        }

        let message = WalletTypedData(typeName: "dYdX")
        message.definitions = definitions
        message.data = data
        return message
    }
    
    private func type(name: String, type: String) -> [String: String] {
        return ["name": name, "type": type]
    }
}

