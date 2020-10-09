//
//  ViewController.swift
//  resizer-mac
//
//  Created by Reynaldo Aguilar on 9/10/20.
//

import Cocoa
import AVFoundation
import AVKit

class ViewController: NSViewController {
    let videoName = "rain"
    let resizer = VideoResizer()
    let playerView = AVPlayerView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(playerView)
        
        DispatchQueue.global().async {
            self.process()
        }
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        playerView.frame = view.bounds
    }
    
    func process() {
        resizer.resize(name: videoName) { result in
            switch result {
            case .success:
                self.playerView.player = AVPlayer(url: outputURL)
            case .failure(let error):
                dump(error)
            }
        }
    }
}

