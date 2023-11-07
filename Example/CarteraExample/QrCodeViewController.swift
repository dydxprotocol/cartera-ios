//
//  QrCodeViewController.swift
//  CarteraExample
//
//  Created by Rui Huang on 7/6/23.
//

import Foundation
import UIKit

class QrCodeViewController: UIViewController {
    private var imageView: UIImageView?
    
    var qrCodeString: String? {
        didSet {
            if qrCodeString != oldValue {
                loadQRCode()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        // Create a UIImageView to display the QR code
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        imageView.center = view.center
        view.addSubview(imageView)
        
        self.imageView = imageView
        
        loadQRCode()
    }
    
    private func loadQRCode() {
        // Generate the QR code image
        if let qrCodeString = qrCodeString , let qrCodeImage = generateQRCode(from: qrCodeString) {
            imageView?.image = qrCodeImage
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .isoLatin1)
        
        // Create a QR code filter
        guard let qrCodeFilter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        
        qrCodeFilter.setValue(data, forKey: "inputMessage")
        qrCodeFilter.setValue("Q", forKey: "inputCorrectionLevel")
        
        // Generate the CIImage
        guard let ciImage = qrCodeFilter.outputImage else { return nil }
        
        // Scale the CIImage to increase the size of the QR code
        let scale = 10
        let scaledCIImage = ciImage.transformed(by: CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale)))
        
        // Convert the CIImage to a UIImage
        let qrCodeImage = UIImage(ciImage: scaledCIImage)
        
        return qrCodeImage
    }
}
