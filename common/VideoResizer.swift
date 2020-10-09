//
//  VideoResizer.swift
//  VideoResizer
//
//  Created by Reynaldo Aguilar on 8/10/20.
//

import Foundation
import AVFoundation

class VideoResizer {
    func resize(asset: AVAsset, to size: CGSize, output: URL, completion: @escaping (Result<Void, Error>) -> Void) throws {
        let channels = [
            audioChannel(asset: asset),
            videoChannel(asset: asset, size: size)
        ].compactMap { $0 }
        
        assert(!channels.isEmpty)
        
        let reader = try AVAssetReader(asset: asset, channels: channels)
        reader.startReading()
        
        let writer = try AVAssetWriter(outputURL: output, channels: channels)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        if let error = writer.error {
            completion(.failure(error))
            return
        }
        
        process(channels: channels) {
            if let error = reader.error {
                completion(.failure(error))
            }
            else {
                writer.finishWriting {
                    if let error = writer.error {
                        completion(.failure(error))
                    }
                    else {
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    private func audioChannel(asset: AVAsset) -> SampleBufferChannel? {
        guard let track = asset.tracks(withMediaType: .audio).first else {
            return nil
        }
        
        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: audioDecompressionSettings())
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioCompressionSettings())
    
        return SampleBufferChannel(source: readerOutput, destination: writerInput)
    }
    
    private func videoChannel(asset: AVAsset, size: CGSize) -> SampleBufferChannel? {
        guard let track = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        
        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: videoDecompressionSettings())
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoCompressionSettings(size: size))
        
        return SampleBufferChannel(source: readerOutput, destination: writerInput)
    }
    
    private func process(channels: [SampleBufferChannel], completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        for channel in channels {
            group.enter()
            
            channel.startTransfer {
                group.leave()
            }
        }
        
        group.notify(queue: DispatchQueue.main, execute: completion)
    }
    
    private func audioDecompressionSettings() -> [String: Any] {
        return [
            AVFormatIDKey: kAudioFormatLinearPCM
        ]
    }
    
    private func audioCompressionSettings() -> [String: Any] {
        var audioChannelLayout = AudioChannelLayout()
        memset(&audioChannelLayout, 0, MemoryLayout<AudioChannelLayout>.size)
        audioChannelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000,
            AVNumberOfChannelsKey: 2,
            AVChannelLayoutKey: NSData(bytes: &audioChannelLayout, length: MemoryLayout<AudioChannelLayout>.size)
        ]
    }
    
    private func videoDecompressionSettings() -> [String: Any] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }
    
    private func videoCompressionSettings(size: CGSize) -> [String: Any] {
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
    }
}

private extension AVAssetReader {
    convenience init(asset: AVAsset, channels: [SampleBufferChannel]) throws {
        try self.init(asset: asset)
        
        channels.map { $0.source }
            .filter(canAdd(_:))
            .forEach(add(_:))
    }
}

private extension AVAssetWriter {
    convenience init(outputURL: URL, channels: [SampleBufferChannel]) throws {
        try self.init(outputURL: outputURL, fileType: .mp4)
        
        channels.map { $0.destination }
            .filter(canAdd(_:))
            .forEach(add(_:))
    }
}

private class SampleBufferChannel {
    let source: AVAssetReaderOutput
    let destination: AVAssetWriterInput
    private let queue: DispatchQueue
    
    init(source: AVAssetReaderOutput, destination: AVAssetWriterInput) {
        self.source = source
        self.destination = destination
        self.queue = DispatchQueue(label: "serialization queue: \(source) to \(destination)", qos: .userInitiated)
    }
    
    func startTransfer(completion: @escaping () -> Void) {
        var completedOrFailed = false
        // avoid using self.* inside the closure
        let (source, destination, queue) = (self.source, self.destination, self.queue)
        
        destination.requestMediaDataWhenReady(on: queue) {
            while destination.isReadyForMoreMediaData && !completedOrFailed {
                if let buffer = source.copyNextSampleBuffer() {
                    completedOrFailed = !destination.append(buffer)
                }
                else {
                    completedOrFailed = true
                }
                
                if completedOrFailed {
                    destination.markAsFinished()
                    
                    queue.async {
                        completion()
                    }
                }
            }
        }
    }
}
