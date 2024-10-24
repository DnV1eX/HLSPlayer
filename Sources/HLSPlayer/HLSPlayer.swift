//
//  HLSPlayer.swift
//  HLSPlayer
//
//  Created by Alexey Demin on 2024-10-09.
//

import AVFoundation

final class HLSPlayer: Player, @unchecked Sendable {
    
    let layer: AVSampleBufferDisplayLayer = .init()
    
    var defaultRate: Double = 0
    
    var rate: Double = 0 {
        didSet {
            if rate != oldValue {
                onChangeStatus?()
            }
        }
    }
    
    private(set) var isBuffering: Bool = false {
        didSet {
            if isBuffering != oldValue {
                onChangeStatus?()
            }
        }
    }
    
    var onChangeStatus: (() -> Void)?
    
    var volume: Double = 1
    
    var actionAtItemEnd: Action = .none
    
    var itemDidPlayToEndTime: (() -> Void)?
    
    var currentItem: HLSPlayer.Item?

    func setItem(url: URL?) {
        guard let url else { return }
        
        let playerItem = HLSPlayer.Item(url: url)
        currentItem = playerItem
    }
    
    var currentTime: TimeInterval = 0
    
    func seek(to: TimeInterval) {
        
    }
    
    func play() {
        rate = 1
        layer.requestMediaDataWhenReady(on: mediaDataDispatchQueue) { [weak self] in
            guard let self else { return }
            
            while layer.isReadyForMoreMediaData {
                if let sampleBuffer = currentItem?.sampleBuffers.popLast() {
                    layer.enqueue(sampleBuffer)
                    isBuffering = false
                } else {
                    isBuffering = true
                }
            }
        }
    }
    
    func pause() {
        rate = 0
        layer.stopRequestingMediaData()
    }
    
    let mediaDataDispatchQueue = DispatchQueue(label: "MediaDataDispatchQueue")
}

extension HLSPlayer {
    
    final class Item: PlayerItem, @unchecked Sendable {
        
        var preferredPeakBitRate: Double = 0
        
        var presentationSize: CGSize = .zero
        
        let url: URL
        
        @Atomic var segmentMaps: [URL: Data] = [:]
        
        @Atomic var sampleBuffers: [CMSampleBuffer] = []
        
        init(url: URL) {
            self.url = url
            
            Self.loadMultivariantPlaylist(url: url) { result in
                switch result {
                case .success(let multivariantPlaylist):
                    guard let stream = multivariantPlaylist.streams.first else { return }
                    
                    Self.loadMediaPlaylist(url: stream.uri, multivariantPlaylist: multivariantPlaylist) { result in
                        switch result {
                        case .success(let mediaPlaylist):
//                            guard let segment = mediaPlaylist.segments.first else { return }
                            for segment in mediaPlaylist.segments {
                                self.makeSampleBuffer(segment: segment) { sampleBuffer in
                                    self.sampleBuffers.insert(sampleBuffer, at: 0)
                                }
                            }
                        case .failure(let error):
                            print(error)
                        }
                    }
                case .failure(let error):
                    print(error)
                }
            }
        }
        
        static func loadMultivariantPlaylist(url: URL, completionHandler: @escaping @Sendable (Result<HLSParsing.MultivariantPlaylist, Error>) -> Void) {
            URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data else {
                    completionHandler(.failure(error ?? HLSPlayerError.loadMultivariantPlaylistError(response)))
                    return
                }
                print(String(data: data, encoding: .utf8)!)
                do {
                    let multivariantPlaylist = try HLSParsing.MultivariantPlaylist(data: data, baseURI: url)
                    completionHandler(.success(multivariantPlaylist))
                } catch {
                    completionHandler(.failure(error))
                }
            }.resume()
        }
        
        static func loadMediaPlaylist(url: URL, multivariantPlaylist: HLSParsing.MultivariantPlaylist?, completionHandler: @escaping @Sendable (Result<HLSParsing.MediaPlaylist, Error>) -> Void) {
            URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data else {
                    completionHandler(.failure(error ?? HLSPlayerError.loadMediaPlaylistError(response)))
                    return
                }
                print(String(data: data, encoding: .utf8)!)
                do {
                    let mediaPlaylist = try HLSParsing.MediaPlaylist(data: data, baseURI: url, multivariantPlaylist: multivariantPlaylist)
                    completionHandler(.success(mediaPlaylist))
                } catch {
                    completionHandler(.failure(error))
                }
            }.resume()
        }
        
        static func loadMediaFragment(url: URL, range: ClosedRange<Data.Index>?, completionHandler: @escaping @Sendable (Result<Data, Error>) -> Void) {
            var request = URLRequest(url: url)
            if let range {
                let rangeValue = "bytes=\(range.lowerBound)-\(range.upperBound)"
                request.setValue(rangeValue, forHTTPHeaderField: "Range")
            }
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    completionHandler(.failure(error))
                    return
                }
                guard let response = response as? HTTPURLResponse, response.statusCode == 206, let data else {
                    completionHandler(.failure(HLSPlayerError.loadMediaFragmentError(response)))
                    return
                }
                completionHandler(.success(data))
            }.resume()
        }
        
        func segmentMap(url: URL, range: ClosedRange<Data.Index>?, completionHandler: @escaping @Sendable (Result<Data, Error>) -> Void) {
            if let segmentMap = segmentMaps[url] {
                completionHandler(.success(segmentMap))
            } else {
                Self.loadMediaFragment(url: url, range: range) { result in
                    switch result {
                    case .success(let data):
                        self.segmentMaps[url] = data
                        completionHandler(.success(data))
                    case .failure(let error):
                        completionHandler(.failure(error))
                    }
                }
            }
        }
        
        static func formatDescription(data: Data) throws -> (formatDescription: CMFormatDescription, timeScale: CMTimeScale)? {
            
            guard let mdhdData = data.atom("moov.trak.mdia.mdhd"), mdhdData.count >= 0x10 else { return nil }
            
            let timeScale = CMTimeScale(Int(data: mdhdData[in: 0xC..<0x10]))
            
            guard let data = data.atom("moov.trak.mdia.minf.stbl.stsd.avc1.avcC"), data.count >= 5 else { return nil }

            let idx = data.startIndex
            let naluLengthSize = Int32(data[idx + 4] & 3) + 1
            var parameterSetPointers: [[UInt8]] = []
            let spsCount = data[idx + 5] & 5
            var spsSizes: [Int] = []
            var ptr = idx + 6
            for _ in 0 ..< spsCount where ptr + 1 < data.endIndex {
                let spsSize = Int((data[ptr] << 8) + data[ptr + 1])
                ptr += 2
                guard ptr + spsSize < data.endIndex else { break }
                spsSizes.append(spsSize)
                let sps = data[ptr ..< ptr + spsSize]
                parameterSetPointers.append(sps.bytes())
                ptr += spsSize
            }
            let ppsCount = data[ptr]
            var ppsSizes: [Int] = []
            ptr += 1
            for _ in 0 ..< ppsCount where ptr + 1 < data.endIndex {
                let ppsSize = Int((data[ptr] << 8) + data[ptr + 1])
                ptr += 2
                guard ptr + ppsSize < data.endIndex else { break }
                ppsSizes.append(ppsSize)
                let pps = data[ptr ..< ptr + ppsSize]
                parameterSetPointers.append(pps.bytes())
                ptr += ppsSize
            }
            let parameterSetSizes = spsSizes + ppsSizes
            var formatDescription: CMFormatDescription?
            let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: nil,
                                                                             parameterSetCount: parameterSetPointers.count,
                                                                             parameterSetPointers: parameterSetPointers.map { UnsafePointer<UInt8>($0) },
                                                                             parameterSetSizes: parameterSetSizes,
                                                                             nalUnitHeaderLength: naluLengthSize,
                                                                             formatDescriptionOut: &formatDescription)
            print(status, formatDescription)
            guard status == noErr, let formatDescription else {
                throw HLSPlayerError.formatDescriptionError(status)
            }
            return (formatDescription, timeScale)
        }
        
        static func blockBuffer(data: Data, timeScale: CMTimeScale) throws -> (blockBuffer: CMBlockBuffer, videoSampleTimings: [CMSampleTimingInfo], videoSampleSizes: [Int]) {
            
            var blockBuffer: CMBlockBuffer?
            var videoSampleTimings: [CMSampleTimingInfo] = []
            var videoSampleSizes: [Int] = []
            
            var defaultSampleDuration = 0
            var defaultSampleSize = 0
            var baseMediaDecodeTime = 0
            
            var lastVideoDataOffset = 0
            var lastVideoDataSize = 0
            var lastAudioDataOffset = 0
            
            var videoData = Data()

            let atoms = data.atoms()
            for (name, data) in atoms {
                var trunIndex = 0
                switch name {
                case "moof":
                    guard let atoms = data.atom("traf")?.atoms() else { continue }
                    let moofAtomSize = 8 + data.count
                    for (name, data) in atoms {
                        let idx = data.startIndex
                        switch name {
                        case "tfhd" where data.count >= 16:
                            defaultSampleDuration = Int(data: data[idx + 8 ..< idx + 12])
                            defaultSampleSize = Int(data: data[idx + 12 ..< idx + 16])

                        case "tfdt" where data.count >= 12:
                            baseMediaDecodeTime = Int(data: data[idx + 8 ..< idx + 12])
                            
                        case "trun" where data.count >= 12:
                            let sampleCount = Int(data: data[idx + 4 ..< idx + 8])
                            let dataOffset = Int(data: data[idx + 8 ..< idx + 12])
                            var sampleSizes: [Int] = []
                            var sampleTimings: [CMSampleTimingInfo] = []
                            var ptr = idx + 12
                            for sampleIndex in 0 ..< sampleCount where ptr + 12 < data.endIndex {
                                let sampleSize = Int(data: data[ptr ..< ptr + 4])
                                sampleSizes.append(sampleSize)
                                let sampleTimeOffset = Int(data: data[ptr + 8 ..< ptr + 12])
                                let duration = CMTime(value: CMTimeValue(defaultSampleDuration), timescale: timeScale)
                                let baseTimeStamp = CMTime(value: CMTimeValue(baseMediaDecodeTime), timescale: timeScale)
                                let decodeTimeStamp = baseTimeStamp + CMTime(value: CMTimeValue(defaultSampleDuration * sampleIndex), timescale: timeScale)
                                let presentationTimeStamp = decodeTimeStamp + CMTime(value: CMTimeValue(sampleTimeOffset), timescale: timeScale)
                                let sampleTimingInfo = CMSampleTimingInfo(duration: duration,
                                                                          presentationTimeStamp: presentationTimeStamp,
                                                                          decodeTimeStamp: decodeTimeStamp)
                                sampleTimings.append(sampleTimingInfo)
                                ptr += 12
                            }
                            if trunIndex == 0 {
                                lastVideoDataOffset = dataOffset - moofAtomSize - 8
                                lastVideoDataSize = sampleSizes.reduce(0, +)
                                videoSampleSizes += sampleSizes
                                videoSampleTimings += sampleTimings
                            }
                            else if trunIndex == 1 {
                                lastAudioDataOffset = dataOffset - moofAtomSize - 8
                            }
                            trunIndex += 1
                        default:
                            continue
                        }
                    }
                case "mdat" where data.count >= lastVideoDataSize + lastVideoDataOffset:
                    videoData += data[size: lastVideoDataSize, offset: lastVideoDataOffset]
                default:
                    break
                }
            }
            let memoryBlock = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: videoData.count)
            videoData.copyBytes(to: memoryBlock)
            
            let status = CMBlockBufferCreateWithMemoryBlock(allocator: nil,
                                                            memoryBlock: memoryBlock.baseAddress,
                                                            blockLength: videoData.count,
                                                            blockAllocator: nil,
                                                            customBlockSource: nil,
                                                            offsetToData: 0,
                                                            dataLength: videoData.count,
                                                            flags: 0,
                                                            blockBufferOut: &blockBuffer)
            print(status, blockBuffer)
            guard status == noErr, let blockBuffer else {
                throw HLSPlayerError.blockBufferError(status)
            }
            return (blockBuffer, videoSampleTimings, videoSampleSizes)
        }
        
        static func sampleBuffer(blockBuffer: CMBlockBuffer, formatDescription: CMFormatDescription, sampleTimings: [CMSampleTimingInfo], sampleSizes: [Int]) -> CMSampleBuffer? {
            var sampleBuffer: CMSampleBuffer?
            let status = CMSampleBufferCreateReady(allocator: nil,
                                                   dataBuffer: blockBuffer,
                                                   formatDescription: formatDescription,
                                                   sampleCount: sampleSizes.count,
                                                   sampleTimingEntryCount: sampleTimings.count,
                                                   sampleTimingArray: sampleTimings,
                                                   sampleSizeEntryCount: sampleSizes.count,
                                                   sampleSizeArray: sampleSizes,
                                                   sampleBufferOut: &sampleBuffer)
            print(status, sampleBuffer)
            return sampleBuffer
        }
        
        func makeSampleBuffer(segment: HLSParsing.MediaPlaylist.Segment, completionHandler: @escaping @Sendable (CMSampleBuffer) -> Void) {
            guard let segmentMap = segment.map else { return }
            
            self.segmentMap(url: segmentMap.uri, range: segmentMap.subrange?.range) { result in
                switch result {
                case .success(let data):
                    guard let (formatDescription, timeScale) = try? Self.formatDescription(data: data) else { return }
                    
                    Self.loadMediaFragment(url: segment.uri, range: segment.subrange?.range) { result in
                        switch result {
                        case .success(let data):
                            guard let (blockBuffer, videoSampleTimings, videoSampleSizes) = try? Self.blockBuffer(data: data, timeScale: timeScale) else { return }

                            guard let sampleBuffer = Self.sampleBuffer(blockBuffer: blockBuffer, formatDescription: formatDescription, sampleTimings: videoSampleTimings, sampleSizes: videoSampleSizes) else { return }
                            
                            completionHandler(sampleBuffer)
                        case .failure(let error):
                            break
                        }
                    }
                case .failure(let error):
                    break
                }
            }
        }
    }
}

enum HLSPlayerError: Error {
    case loadMultivariantPlaylistError(URLResponse?)
    case loadMediaPlaylistError(URLResponse?)
    case loadMediaFragmentError(URLResponse?)
    case formatDescriptionError(OSStatus)
    case blockBufferError(OSStatus)
}

@propertyWrapper
public class Atomic<T: Sendable>: @unchecked Sendable {
    
    private let queue = DispatchQueue(label: "AtomicProperty", attributes: .concurrent)
    private var value: T
    public var wrappedValue: T {
        get { queue.sync { value } }
        set { queue.async(flags: .barrier) { self.value = newValue } }
    }
    public init(wrappedValue: T) {
        value = wrappedValue
    }
}

extension CMSampleBuffer: @unchecked Sendable { }

extension Data {
    
    func atoms(offset: Index = 0) -> [(name: String, data: Data)] {
        var ptr = startIndex + offset
        var atoms: [(String, Data)] = []
        while endIndex >= ptr + 8,
              case let size = Swift.max(8, Int(data: self[ptr ..< ptr + 4])),
              let name = String(data: self[ptr + 4 ..< ptr + 8], encoding: .utf8),
              endIndex >= ptr + size {
            let data = self[ptr + 8 ..< ptr + size]
            atoms.append((name, data))
            ptr += size
        }
        return atoms
    }
    
    func atom(_ path: String) -> Data? {
        var data: Data? = self
        for name in path.split(separator: ".") {
            let offset = switch name {
            case "avc1": 8
            case "avcC": 94
            default: 0
            }
            data = data?.atoms(offset: offset).first { atom in atom.name == name }?.data
        }
        return data
    }
    
    func bytes() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        copyBytes(to: &bytes, count: count)
        return bytes
    }
    
    subscript(in range: Range<Index>) -> Self {
        self[range.lowerBound + startIndex ..< range.upperBound + startIndex]
    }
    
    subscript(_ range: Range<Index>, offset offset: Index) -> Self {
        self[range.lowerBound + offset ..< range.upperBound + offset]
    }
    
    subscript(size size: Index, offset offset: Index = 0) -> Self {
        self[startIndex + offset ..< startIndex + size + offset]
    }
}

extension Int {
    init(data: Data) {
        self = data.reduce(0) { $0 << 8 | Int($1) }
    }
}
