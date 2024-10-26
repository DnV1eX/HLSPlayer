//
//  HLSPlayer.swift
//  HLSPlayer
//
//  Created by Alexey Demin on 2024-10-09.
//

import AVFoundation

final class HLSPlayer: Player, @unchecked Sendable {
    
    let layer: AVSampleBufferDisplayLayer = .init()
    
    var defaultRate: Double = 1
    
    var rate: Double = 0 {
        didSet {
            CMTimebaseSetRate(timebase, rate: rate)
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
    
    private(set) var currentItem: HLSPlayer.Item?

    func setItem(url: URL?) {
        layer.stopRequestingMediaData()
        layer.flushAndRemoveImage()
        CMTimebaseSetRate(timebase, rate: .zero)
        CMTimebaseSetTime(timebase, time: .zero)
        guard let url else {
            currentItem = nil
            return
        }
        
        let playerItem = HLSPlayer.Item(url: url, bitRate: Int(4e6)) { [weak self] playerItem in
            guard let self else { return }
            startTime = playerItem.timestampOffset
        }
        currentItem = playerItem
        
        startRequestingMediaData()
    }
    
    private func startRequestingMediaData() {
        layer.requestMediaDataWhenReady(on: mediaDataDispatchQueue) { [weak self] in
            guard let self else { return }
            
            guard let currentItem else {
                stopRequestingMediaData()
                return
            }
            
            while layer.isReadyForMoreMediaData {
                if let sampleBuffer = currentItem.nextSampleBuffer() {
                    layer.enqueue(sampleBuffer)
                } else {
                    isBuffering = (currentItem.state == .loading)
                    if [.finished, .error].contains(currentItem.state) {
                        stopRequestingMediaData()
                        return
                    }
                }
            }
            isBuffering = false
        }
    }
    
    private func stopRequestingMediaData() {
        layer.stopRequestingMediaData()
    }
    
    private func updateTimebase(_ time: TimeInterval) {
        CMTimebaseSetTime(timebase, time: CMTime(seconds: time, preferredTimescale: CMTimebaseGetTime(timebase).timescale))
    }
    
    private var startTime: TimeInterval = 0 {
        didSet {
            if startTime != oldValue {
                updateTimebase(startTime)
            }
        }
    }
    
    private(set) var currentTime: TimeInterval = 0 {
        didSet {
            guard let currentItem else { return }
            
            currentItem.playerTime = currentTime
            guard currentItem.duration == 0 || currentTime < currentItem.duration else {
                pause()
                return
            }
            onChangeStatus?()
//            print(Int(currentTime))
        }
    }
        
    func seek(to time: TimeInterval) {
        updateTimebase(startTime + time)
        currentItem?.flush()
        layer.flush()
    }
    
    func play() {
        rate = defaultRate
    }
    
    func pause() {
        rate = .zero
    }
    
    let mediaDataDispatchQueue = DispatchQueue(label: "MediaDataDispatchQueue")
    
    private var timebase: CMTimebase!
    
    init() {
        let status = CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        if status != noErr {
            print(status)
        }
        
        layer.controlTimebase = timebase
        CMTimebaseSetRate(timebase, rate: .zero)
        CMTimebaseSetTime(timebase, time: .zero)
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else { return }
            let time = CMTimebaseGetTime(timebase)
            currentTime = CMTimeGetSeconds(time) - startTime
        }
    }
}

extension HLSPlayer {
    
    final class Item: PlayerItem, @unchecked Sendable {
        
        enum State: Equatable {
            case loading
            case waiting
            case finished
            case error
            
            nonisolated(unsafe) static var lastError: Error?
            
            static func error(_ error: Error) -> Self {
                Self.lastError = error
                return .error
            }
        }
        
        var preferredPeakBitRate: Double = 0
        
        var presentationSize: CGSize = .zero
        
        let url: URL
        
        @Atomic var bitRate: Int {
            didSet {
                updateSegments()
            }
        }
        
        @Atomic var playerTime: TimeInterval = 0
        
        let onUpdate: (HLSPlayer.Item) -> Void
        
        @Atomic private(set) var timestampOffset: TimeInterval = 0 {
            didSet {
                onUpdate(self)
            }
        }
        
        @Atomic private(set) var duration: TimeInterval = 0 {
            didSet {
                onUpdate(self)
            }
        }

        @Atomic private var multivariantPlaylist: HLSParsing.MultivariantPlaylist?
        
        // Ordered by bandwidth.
        @Atomic var streams: [HLSParsing.MultivariantPlaylist.Stream] = [] {
            didSet {
                updateSegments()
            }
        }
        
        // Ordered by timestamp.
        @Atomic var segments: [(timestamp: TimeInterval, segment: HLSParsing.MediaPlaylist.Segment)] = [] {
            didSet {
                flush()
            }
        }
        
        // Cache.
        @Atomic var segmentMaps: [URL: Data] = [:]
        
        func nextSampleBuffer() -> CMSampleBuffer? {
            guard let (timestamp, sampleBuffer) = sampleBufferQueue.popLast() else {
                updateSampleBuffers()
                return nil
            }
            updateSampleBuffers()
            return (playerTime == 0 && timestamp != 0) ? nil : sampleBuffer
        }
        
        func flush() {
            sampleBufferQueue = []
            updateSampleBuffers()
        }
        
        @Atomic private var loadingSegmentTimestamps: Set<TimeInterval> = []

        @Atomic private var sampleBufferQueue: [(timestamp: TimeInterval, sampleBuffer: CMSampleBuffer)] = []
        
        func loadingSegmentOrEnqueuingSampleBuffer(with timestamp: TimeInterval) -> Bool {
            loadingSegmentTimestamps.contains(timestamp) || sampleBufferQueue.lazy.map(\.timestamp).contains(timestamp)
        }
        
        @Atomic var state: State = .loading {
            didSet {
                print(state, State.lastError)
            }
        }
        
        init(url: URL, bitRate: Int, onUpdate: @escaping (HLSPlayer.Item) -> Void) {
            self.url = url
            self.bitRate = bitRate
            self.onUpdate = onUpdate
            
            Self.loadMultivariantPlaylist(url: url) { [self] result in
                switch result {
                case .success(let multivariantPlaylist):
                    self.multivariantPlaylist = multivariantPlaylist
                    streams = multivariantPlaylist.streams.sorted { $0.bandwidth < $1.bandwidth }
                case .failure(let error):
                    state = .error(error)
                }
            }
        }
        
        func updateSegments() {
            guard let stream = streams.last { $0.bandwidth < bitRate } ?? streams.first else {
                state = .error(HLSPlayerError.streamsMissing)
                return
            }
            Self.loadMediaPlaylist(url: stream.uri, multivariantPlaylist: multivariantPlaylist) { [self] result in
                switch result {
                case .success(let mediaPlaylist):
                    segments = mediaPlaylist.segments.reduce(into: []) { array, segment in
                        array.append((array.last.map { $0.timestamp + $0.segment.duration } ?? 0, segment))
                    }
                    duration = segments.last.map { $0 + $1.duration } ?? 0
                case .failure(let error):
                    state = .error(error)
                }
            }
        }
        
        func updateSampleBuffers() {
            sampleBufferQueue.removeAll { $0.timestamp < playerTime }
            
            guard state != .error else { return }
            
            guard sampleBufferQueue.count + loadingSegmentTimestamps.count < 6 else { return }
            
            guard let (timestamp, segment) = segments.first(where: { $0.timestamp >= playerTime && !loadingSegmentOrEnqueuingSampleBuffer(with: $0.timestamp) }) else {
                if state != .loading {
                    state = segments.isEmpty ? .error(HLSPlayerError.segmentsMissing) : .finished
                }
                return
            }
            loadingSegmentTimestamps.insert(timestamp)
            state = .loading
            makeSampleBuffer(segment: segment) { [self] result in
                switch result {
                case .success(let sampleBuffer):
                    if timestamp == 0 {
                        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        timestampOffset = time.seconds
                    }
                    sampleBufferQueue.insert((timestamp, sampleBuffer), at: sampleBufferQueue.firstIndex { $0.timestamp < timestamp } ?? sampleBufferQueue.endIndex)
                    state = .waiting
                case .failure(let error):
                    state = .error(error)
                }
                loadingSegmentTimestamps.remove(timestamp)
                updateSampleBuffers()
            }
        }
        
        static func loadMultivariantPlaylist(url: URL, completionHandler: @escaping @Sendable (Result<HLSParsing.MultivariantPlaylist, Error>) -> Void) {
            URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data else {
                    completionHandler(.failure(error ?? HLSPlayerError.loadMultivariantPlaylistError(response)))
                    return
                }
//                print(String(data: data, encoding: .utf8)!)
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
//                print(String(data: data, encoding: .utf8)!)
                do {
                    let mediaPlaylist = try HLSParsing.MediaPlaylist(data: data, baseURI: url, multivariantPlaylist: multivariantPlaylist)
                    completionHandler(.success(mediaPlaylist))
                } catch {
                    completionHandler(.failure(error))
                }
            }.resume()
        }
        
        static func loadMediaSegment(url: URL, range: ClosedRange<Data.Index>?, completionHandler: @escaping @Sendable (Result<Data, Error>) -> Void) {
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
                    completionHandler(.failure(HLSPlayerError.loadMediaSegmentError(response)))
                    return
                }
                completionHandler(.success(data))
            }.resume()
        }
        
        func segmentMap(url: URL, range: ClosedRange<Data.Index>?, completionHandler: @escaping @Sendable (Result<Data, Error>) -> Void) {
            if let segmentMap = segmentMaps[url] {
                completionHandler(.success(segmentMap))
            } else {
                Self.loadMediaSegment(url: url, range: range) { result in
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
        
        static func formatDescription(data: Data) throws -> (formatDescription: CMFormatDescription, timeScale: CMTimeScale) {
            
            guard let mdhdData = data.atom("moov.trak.mdia.mdhd"), mdhdData.count >= 0x10 else {
                throw HLSPlayerError.formatDescriptionError(nil)
            }
            
            let timeScale = CMTimeScale(Int(data: mdhdData[in: 0xC..<0x10]))
            
            guard let data = data.atom("moov.trak.mdia.minf.stbl.stsd.avc1.avcC"), data.count >= 5 else {
                throw HLSPlayerError.formatDescriptionError(nil)
            }

            let idx = data.startIndex
            let naluLengthSize = Int32(data[idx + 4] & 3) + 1
            var parameterSetPointers: [[UInt8]] = []
            let spsCount = data[idx + 5] & 5
            var spsSizes: [Int] = []
            var ptr = idx + 6
            for _ in 0 ..< spsCount where ptr + 1 < data.endIndex {
                let spsSize = Int((data[ptr] << 8) + data[ptr + 1])
                ptr += 2
                guard ptr + spsSize <= data.endIndex else { break }
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
                guard ptr + ppsSize <= data.endIndex else { break }
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
//            print(status, formatDescription)
            guard status == noErr, let formatDescription else {
                throw HLSPlayerError.formatDescriptionError(status)
            }
            return (formatDescription, timeScale)
        }
        
        static func blockBuffer(data: Data, timeScale: CMTimeScale) throws -> (blockBuffer: CMBlockBuffer, sampleTimings: [CMSampleTimingInfo], sampleSizes: [Int]) {
            
            var blockBuffer: CMBlockBuffer?
            var sampleTimings: [CMSampleTimingInfo] = []
            var sampleSizes: [Int] = []
            
            var lastFragmentDataRanges: [(size: Data.Index, offset: Data.Index)] = []
            
            var fragmentsData = Data()

            let atoms = data.atoms()
            for (name, data) in atoms {
                var defaultSampleDuration = 0
                var defaultSampleSize = 0
                var baseMediaDecodeTime = 0
                
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
                            var dataSize = 0
                            var ptr = idx + 12
                            for sampleIndex in 0 ..< sampleCount where ptr + 12 <= data.endIndex {
                                let sampleSize = Int(data: data[ptr ..< ptr + 4])
                                dataSize += sampleSize
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
                            lastFragmentDataRanges.append((dataSize, dataOffset - moofAtomSize - 8))
                            baseMediaDecodeTime += defaultSampleDuration * sampleCount
                        default:
                            continue
                        }
                    }
                case "mdat":
                    for (size, offset) in lastFragmentDataRanges where size + offset <= data.count {
                        fragmentsData += data[size: size, offset: offset]
                    }
                    lastFragmentDataRanges = []
                default:
                    break
                }
            }
            let memoryBlock = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: fragmentsData.count)
            fragmentsData.copyBytes(to: memoryBlock)
            
            let status = CMBlockBufferCreateWithMemoryBlock(allocator: nil,
                                                            memoryBlock: memoryBlock.baseAddress,
                                                            blockLength: fragmentsData.count,
                                                            blockAllocator: nil,
                                                            customBlockSource: nil,
                                                            offsetToData: 0,
                                                            dataLength: fragmentsData.count,
                                                            flags: 0,
                                                            blockBufferOut: &blockBuffer)
//            print(status, blockBuffer)
            guard status == noErr, let blockBuffer else {
                throw HLSPlayerError.blockBufferError(status)
            }
            return (blockBuffer, sampleTimings, sampleSizes)
        }
        
        static func sampleBuffer(blockBuffer: CMBlockBuffer, formatDescription: CMFormatDescription, sampleTimings: [CMSampleTimingInfo], sampleSizes: [Int]) throws -> CMSampleBuffer {
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
//            print(status, sampleBuffer)
            guard status == noErr, let sampleBuffer else {
                throw HLSPlayerError.sampleBufferError(status)
            }
            return sampleBuffer
        }
        
        func makeSampleBuffer(segment: HLSParsing.MediaPlaylist.Segment, completionHandler: @escaping @Sendable (Result<CMSampleBuffer, Error>) -> Void) {
            guard let segmentMap = segment.map else {
                completionHandler(.failure(HLSPlayerError.segmentMapMissing))
                return
            }
            
            self.segmentMap(url: segmentMap.uri, range: segmentMap.subrange?.range) { result in
                switch result {
                case .success(let data):
                    do {
                        let (formatDescription, timeScale) = try Self.formatDescription(data: data)
                        
                        Self.loadMediaSegment(url: segment.uri, range: segment.subrange?.range) { result in
                            switch result {
                            case .success(let data):
                                completionHandler(Result(catching: {
                                    let (blockBuffer, sampleTimings, sampleSizes) = try Self.blockBuffer(data: data, timeScale: timeScale)
                                    
                                    return try Self.sampleBuffer(blockBuffer: blockBuffer, formatDescription: formatDescription, sampleTimings: sampleTimings, sampleSizes: sampleSizes)
                                }))
                            case .failure(let error):
                                completionHandler(.failure(error))
                            }
                        }
                    } catch {
                        completionHandler(.failure(error))
                    }
                case .failure(let error):
                    completionHandler(.failure(error))
                }
            }
        }
    }
}

enum HLSPlayerError: Error {
    case loadMultivariantPlaylistError(URLResponse?)
    case loadMediaPlaylistError(URLResponse?)
    case loadMediaSegmentError(URLResponse?)
    case formatDescriptionError(OSStatus?)
    case blockBufferError(OSStatus?)
    case sampleBufferError(OSStatus?)
    case streamsMissing
    case segmentsMissing
    case segmentMapMissing
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
