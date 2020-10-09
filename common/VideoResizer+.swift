//
//  VideoResizer+.swift
//  VideoResizer
//
//  Created by Reynaldo Aguilar on 9/10/20.
//

import Foundation
import AVFoundation

let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("video.mp4")

extension VideoResizer {
    func resize(name: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let inputURL = Bundle.main.url(forResource: name, withExtension: "mp4")!
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try! FileManager.default.removeItem(at: outputURL)
        }
        
        try! resize(asset: AVAsset(url: inputURL), to: CGSize(width: 1920, height: 1080), output: outputURL) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
