//
//  ViewController.swift
//  VideoResizer
//
//  Created by Reynaldo Aguilar on 8/10/20.
//

import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController {
    let videoName = "rain"
    
    @IBOutlet weak var statusLabel: UILabel!
    let resizer = VideoResizer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        statusLabel.text = "Resizing..."
        
        DispatchQueue.global().async {
            self.process()
        }
    }
    
    private func process() {
        resizer.resize(name: videoName) { result in
            switch result {
            case .success:
                self.statusLabel.text = "Done"
                let playerVC = AVPlayerViewController()
                playerVC.player = AVPlayer(url: outputURL)
                self.present(playerVC, animated: true, completion: nil)
            case .failure(let error):
                self.statusLabel.text = "\(error)"
                dump(error)
            }
        }
    }
}
