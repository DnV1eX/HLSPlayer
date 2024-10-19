//
//  HLSParsing.swift
//  HLSPlayer
//
//  Created by Alexey Demin on 2024-10-15.
//

import Foundation

// https://datatracker.ietf.org/doc/html/draft-pantos-hls-rfc8216bis (HTTP Live Streaming 2nd Edition)

// MARK: - Type declarations

enum HLSParsing {
    
    nonisolated(unsafe) static var isStrict = false
    
    protocol Playlist {
        typealias Error = HLSParsing.PlaylistError
        typealias Tag = HLSParsing.PlaylistTag
    }
    
    enum PlaylistError: Error {
        case stringUTF8DecodingFailure
        case unknownTag(String)
        case multipleOccurrenceOfTag(PlaylistTag)
        case multipleOccurrenceOfTagInSegment(PlaylistTag)
        case unexpectedMediaPlaylistOrSegmentTag(PlaylistTag)
        case unexpectedMultivariantPlaylistTag(PlaylistTag)
        case missingTag(PlaylistTag)
        case wrongTagValueFormat(PlaylistTag, String)
        case missingAttribute(PlaylistTag.Attribute)
        case wrongAttributeFormat(PlaylistTag.Attribute, String)
        case missingStreamURI
        case wrongStreamURIFormat(String)
        case wrongSegmentURIFormat(String)
    }
    
    enum PlaylistTag: String, CustomStringConvertible, CaseIterable {
        // Basic Tags.
        /// Indicates that the file is an Extended M3U Playlist file.
        case extendedM3U = "EXTM3U"
        /// Indicates the compatibility version of the Playlist file, its associated media, and its server.
        case version = "EXT-X-VERSION"
        
        // Media or Multivariant Playlist Tags.
        /// Indicates that all media samples in a Media Segment can be decoded without information from other segments.
        case independentSegments = "EXT-X-INDEPENDENT-SEGMENTS"
        /// Indicates a preferred point at which to start playing a Playlist.
        case start = "EXT-X-START"
        /// Provides a Playlist variable definition or declaration.
        case define = "EXT-X-DEFINE"
        
        // Media Playlist Tags.
        /// Specifies the Target Duration, an upper bound on the duration of all Media Segments in the Playlist.
        case targetDuration = "EXT-X-TARGETDURATION"
        /// Indicates the Media Sequence Number of the first Media Segment that appears in a Playlist file.
        case mediaSequence = "EXT-X-MEDIA-SEQUENCE"
        /// Allows synchronization between different Renditions of the same Variant Stream or different Variant Streams that have EXT-X-DISCONTINUITY tags in their Media Playlists.
        case discontinuitySequence = "EXT-X-DISCONTINUITY-SEQUENCE"
        /// Indicates that no more Media Segments will be added to the Media Playlist file.
        case endlist = "EXT-X-ENDLIST"
        /// Provides mutability information about the Media Playlist file.
        case playlistType = "EXT-X-PLAYLIST-TYPE"
        /// Indicates that each Media Segment in the Playlist describes a single I-frame.
        case iFramesOnly = "EXT-X-I-FRAMES-ONLY"
        /// Provides information about the Partial Segments in the Playlist.
        case partInfo = "EXT-X-PART-INF"
        /// Allows the Server to indicate support for Delivery Directives.
        case serverControl = "EXT-X-SERVER-CONTROL"
        
        // Media Segment Tags.
        /// Specifies the duration of a Media Segment.
        case extendedInfo = "EXTINF"
        /// Indicates that a Media Segment is a sub-range of the resource identified by its URI.
        case byteRange = "EXT-X-BYTERANGE"
        /// Indicates a discontinuity between the Media Segment that follows it and the one that preceded it.
        case discontinuity = "EXT-X-DISCONTINUITY"
        /// Specifies how to decrypt Media Segments.
        case key = "EXT-X-KEY"
        /// Specifies how to obtain the Media Initialization Section required to parse the applicable Media Segments.
        case map = "EXT-X-MAP"
        /// Associates the first sample of a Media Segment with an absolute date and/or time.
        case programDateTime = "EXT-X-PROGRAM-DATE-TIME"
        /// Indicates that the segment URI to which it applies does not contain media data and SHOULD NOT be loaded by clients.
        case gap = "EXT-X-GAP"
        /// Identifies the approximate segment bit rate of the Media Segment(s) to which it applies.
        case bitrate = "EXT-X-BITRATE"
        /// Identifies a Partial Segment.
        case part = "EXT-X-PART"
        
        // Media Metadata Tags.
        /// Associates a Date Range (i.e., a range of time defined by a starting and ending date) with a set of attribute/value pairs.
        case dateRange = "EXT-X-DATERANGE"
        /// Replaces the segment URI lines and all Media Segment Tags tags that are applied to those segments.
        case skip = "EXT-X-SKIP"
        /// Allows a Client loading media from a live stream to reduce the time to obtain a resource from the Server by issuing its request before the resource is available to be delivered.
        case preloadHint = "EXT-X-PRELOAD-HINT"
        /// Carries information about an associated Rendition that is as up-to-date as the Playlist that contains it.
        case renditionReport = "EXT-X-RENDITION-REPORT"
        
        // Multivariant Playlist Tags.
        /// Is used to relate Media Playlists that contain alternative Renditions of the same content.
        case media = "EXT-X-MEDIA"
        /// Specifies a Variant Stream, which is a set of Renditions that can be combined to play the presentation.
        case streamInfo = "EXT-X-STREAM-INF"
        /// Identifies a Media Playlist file containing the I-frames of a multimedia presentation.
        case iFrameStreamInfo = "EXT-X-I-FRAME-STREAM-INF"
        /// Allows arbitrary session data to be carried in a Multivariant Playlist.
        case sessionData = "EXT-X-SESSION-DATA"
        /// Allows encryption keys from Media Playlists to be specified in a Multivariant Playlist.
        case sessionKey = "EXT-X-SESSION-KEY"
        /// Allows a server to provide a Content Steering Manifest.
        case contentSteering = "EXT-X-CONTENT-STEERING"
        
        var description: String {
            "#" + rawValue
        }
        
        enum `Type` {
            case basic, mediaOrMultivariantPlaylist, mediaPlaylist, mediaSegment, mediaMetadata, multivariantPlaylist
        }
        
        var type: Type {
            switch self {
            case .extendedM3U, .version:
                    .basic
            case .independentSegments, .start, .define:
                    .mediaOrMultivariantPlaylist
            case .targetDuration, .mediaSequence, .discontinuitySequence, .endlist, .playlistType, .iFramesOnly, .partInfo, .serverControl:
                    .mediaPlaylist
            case .extendedInfo, .byteRange, .discontinuity, .key, .map, .programDateTime, .gap, .bitrate, .part:
                    .mediaSegment
            case .dateRange, .skip, .preloadHint, .renditionReport:
                    .mediaMetadata
            case .media, .streamInfo, .iFrameStreamInfo, .sessionData, .sessionKey, .contentSteering:
                    .multivariantPlaylist
            }
        }
        
        static let uniqueTags: [Self] = [.extendedM3U, .version, .independentSegments, .start, .targetDuration, .mediaSequence, .discontinuitySequence, .endlist, .playlistType, .iFramesOnly, .partInfo, .serverControl, .skip, .contentSteering]
        
        static let uniqueInSegmentTags: [Self] = [.extendedInfo, .byteRange, .discontinuity, .programDateTime, .gap]
        
        static let notImplementedTags: [Self] = [.start, .define, .playlistType, .iFramesOnly, .partInfo, .serverControl, .key, .map, .programDateTime, .gap, .bitrate, .part, .dateRange, .skip, .preloadHint, .renditionReport, .media, .iFrameStreamInfo, .sessionData, .sessionKey, .contentSteering]
        
        var isUnique: Bool {
            Self.uniqueTags.contains(self)
        }
        
        var isUniqueInSegment: Bool {
            Self.uniqueInSegmentTags.contains(self)
        }
        
        var isNotImplemented: Bool {
            Self.notImplementedTags.contains(self)
        }
    }
}

extension HLSParsing.PlaylistTag {
    enum Attribute: String {
        // EXT-X-STREAM-INF
        /// Represents the peak segment bit rate of the Variant Stream.
        case bandwidth = "BANDWIDTH"
        /// Represents the average segment bit rate of the Variant Stream.
        case averageBandwidth = "AVERAGE-BANDWIDTH"
        /// An abstract, relative measure of the playback quality-of-experience of the Variant Stream.
        case score = "SCORE"
        /// A comma-separated list of formats, where each format specifies a media sample type that is present in one or more Renditions specified by the Variant Stream.
        case codecs = "CODECS"
        /// Describes media samples with both a backward-compatible base layer and a newer enhancement layer.
        case supplementalCodecs = "SUPPLEMENTAL-CODECS"
        /// The optimal pixel resolution at which to display all the video in the Variant Stream.
        case resolution = "RESOLUTION"
        /// The maximum frame rate for all the video in the Variant Stream, rounded to three decimal places.
        case frameRate = "FRAME-RATE"
        // HDCP-LEVEL, ALLOWED-CPC, VIDEO-RANGE, REQ-VIDEO-LAYOUT, STABLE-VARIANT-ID, AUDIO, VIDEO, SUBTITLES, CLOSED-CAPTIONS, PATHWAY-ID
        
        var tag: HLSParsing.PlaylistTag {
            switch self {
            case .bandwidth, .averageBandwidth, .score, .codecs, .supplementalCodecs, .resolution, .frameRate:
                    .streamInfo
            }
        }
    }
}

extension HLSParsing.PlaylistTag.Attribute {
    
    struct Resolution: LosslessStringConvertible {
        let width: Int
        let height: Int
        
        var description: String {
            "\(width)x\(height)"
        }
        
        init?(_ description: String) {
            let pair = description.split(separator: "x")
            guard pair.count == 2, let width = Int(pair[0]), let height = Int(pair[1]) else {
                return nil
            }
            self.width = width
            self.height = height
        }
    }
    
    struct ByteRange: LosslessStringConvertible {
        let length: Int
        let offset: Int?
        
        var description: String {
            [length, offset].compactMap(\.self).map(String.init).joined(separator: "@")
        }
        
        init?(_ description: String) {
            let pair = description.split(separator: "@")
            guard !pair.isEmpty, let length = Int(pair[0]) else {
                return nil
            }
            self.length = length
            self.offset = pair.count == 2 ? Int(pair[1]) : nil
        }
    }
}

// MARK: - Parsing playlists

extension HLSParsing {
    
    struct MultivariantPlaylist: Playlist {
        
        typealias Stream = (bandwidth: Int,
                            averageBandwidth: Int?,
                            score: Double?,
                            codecs: [String],
                            supplementalCodecs: [String],
                            resolution: Tag.Attribute.Resolution?,
                            frameRate: Double?,
                            uri: URL)
        
        let version: Int?
        let independentSegments: Bool
        let streams: [Stream]
        
        init(data: Data) throws(Playlist.Error) {
            
            let lines = try Self.lines(data)
            // Collects the last substrings for encountered tags.
            var tagList: Playlist.TagList = [Tag.extendedM3U: ""]
            var lastTag: Tag?
            var streams: [Stream] = []
            
            for line in lines {
                if line.hasPrefix("#EXT") {
                    // Tag.
                    guard let (tag, substring) = try HLSParsing.throwIfStrict(line.tagAndSubstring) else {
                        continue // Skip unknown tag.
                    }
                    if [.mediaPlaylist, .mediaSegment].contains(tag.type) {
                        throw .unexpectedMediaPlaylistOrSegmentTag(tag)
                    }
                    if tag.isUnique && tagList.keys.contains(tag) {
                        throw .multipleOccurrenceOfTag(tag)
                    }
                    if lastTag == .streamInfo {
                        throw .missingStreamURI
                    }
                    if tag.isNotImplemented {
                        print("The \(tag.rawValue) tag parsing is not implemented.")
                    }
                    tagList[tag] = substring
                    lastTag = tag
                }
                else if line.hasPrefix("#") {
                    // Comment.
                    print(line)
                }
                else {
                    // URI.
                    guard let uri = URL(string: String(line)) else {
                        try HLSParsing.throwIfStrict(error: .wrongStreamURIFormat(String(line)))
                        continue // Ignore malformed URIs.
                    }
                    let streamInfo: Tag.AttributeList = try tagList.value(.streamInfo)
                    let stream: Stream = (bandwidth: try streamInfo.value(.bandwidth),
                                          averageBandwidth: try? streamInfo.value(.averageBandwidth),
                                          score: try? streamInfo.value(.score),
                                          codecs: (try? (streamInfo.value(.codecs) as String).split(separator: ",").map(String.init)) ?? [],
                                          supplementalCodecs: (try? (streamInfo.value(.supplementalCodecs) as String).split(separator: ",").map(String.init)) ?? [],
                                          resolution: try? streamInfo.value(.resolution),
                                          frameRate: try? streamInfo.value(.frameRate),
                                          uri: uri)
                    streams.append(stream)
                    
                    lastTag = nil
                }
            }
            if lastTag == .streamInfo {
                throw .missingStreamURI
            }
            version = try tagList.value(.version)
            independentSegments = tagList.keys.contains(.independentSegments)
            self.streams = streams
        }
    }
    
    struct MediaPlaylist: Playlist {
        
        typealias Segment = (duration: Double,
                             title: String?,
                             subrange: Tag.Attribute.ByteRange?,
                             discontinuity: Bool,
                             uri: URL)
        
        let version: Int?
        let independentSegments: Bool
        let targetDuration: Int
        let mediaSequence: Int?
        let discontinuitySequence: Int?
        let endlist: Bool
        let segments: [Segment]
        
        init(data: Data, baseURI: URL, multivariantPlaylist: MultivariantPlaylist?) throws(Playlist.Error) {
            
            let lines = try Self.lines(data)
            // Collects the last substrings for encountered tags.
            var tagList: Playlist.TagList = [Tag.extendedM3U: ""]
            var segments: [Segment] = []
            
            for line in lines {
                if line.hasPrefix("#EXT") {
                    // Tag.
                    guard let (tag, substring) = try HLSParsing.throwIfStrict(line.tagAndSubstring) else {
                        continue // Skip unknown tag.
                    }
                    if tag.type == .multivariantPlaylist {
                        throw .unexpectedMultivariantPlaylistTag(tag)
                    }
                    if tag.isUnique && tagList.keys.contains(tag) {
                        throw .multipleOccurrenceOfTag(tag)
                    }
                    if tag.isUniqueInSegment && tagList.keys.contains(tag) {
                        try HLSParsing.throwIfStrict(error: .multipleOccurrenceOfTagInSegment(tag))
                        // Overwrite duplicate segment tag.
                    }
                    if tag.isNotImplemented {
                        print("The \(tag.rawValue) tag parsing is not implemented.")
                    }
                    tagList[tag] = substring
                }
                else if line.hasPrefix("#") {
                    // Comment.
                    print(line)
                }
                else {
                    // URI.
                    guard let uri = URL(string: String(line)) else {
                        try HLSParsing.throwIfStrict(error: .wrongSegmentURIFormat(String(line)))
                        continue // Ignore malformed URIs.
                    }
                    let info: Tag.Info = try tagList.value(.extendedInfo)
                    let segment: Segment = (duration: info.duration,
                                            title: info.title,
                                            subrange: try tagList.value(.byteRange),
                                            discontinuity: tagList.keys.contains(.discontinuity),
                                            uri: uri)
                    segments.append(segment)
                    
                    for tag in Tag.uniqueInSegmentTags {
                        tagList.removeValue(forKey: tag)
                    }
                }
            }
            version = try tagList.value(.version)
            independentSegments = tagList.keys.contains(.independentSegments) || multivariantPlaylist?.independentSegments ?? false
            targetDuration = try tagList.value(.targetDuration)
            mediaSequence = try tagList.value(.mediaSequence)
            discontinuitySequence = try tagList.value(.discontinuitySequence)
            endlist = tagList.keys.contains(.endlist)
            self.segments = segments
        }
    }
}

// MARK: - Fileprivate extensions

extension HLSParsing {
    
    fileprivate static func throwIfStrict(error: PlaylistError) throws(PlaylistError) {
        if isStrict {
            throw error
        } else {
            print(error)
        }
    }
    
    fileprivate static func throwIfStrict<T>(_ closure: () throws(PlaylistError) -> T) throws(PlaylistError) -> T? {
        do {
            return try closure()
        } catch {
            try throwIfStrict(error: error)
            return nil
        }
    }
}

extension HLSParsing.Playlist {
    
    fileprivate typealias TagList = [Tag: Substring]
    fileprivate typealias Line = Substring
    
    fileprivate static func lines(_ data: Data) throws(Error) -> [Line] {
        
        guard let string = String(data: data, encoding: .utf8) else {
            throw .stringUTF8DecodingFailure
        }
        var lines = string.split(whereSeparator: \.isNewline)

        guard !lines.isEmpty, lines.removeFirst() == Tag.extendedM3U.description else {
            throw .missingTag(.extendedM3U)
        }
        return lines
    }
}

extension HLSParsing.Playlist.Line {
    
    fileprivate typealias Error = HLSParsing.PlaylistError
    fileprivate typealias Tag = HLSParsing.PlaylistTag
    
    fileprivate func tagAndSubstring() throws(Error) -> (tag: Tag, substring: Substring) {
        for tag in Tag.allCases {
            if tag.description == self {
                return (tag, "")
            }
            else if hasPrefix(tag.description + ":") {
                return (tag, dropFirst(tag.description.count + 1))
            }
        }
        throw .unknownTag(String(self))
    }
}

extension HLSParsing.PlaylistTag {
    
    fileprivate typealias Error = HLSParsing.PlaylistError
    
    fileprivate typealias AttributeList = [Attribute: Substring]
    
    fileprivate protocol Value {
        init?(substring: Substring)
    }
    
    fileprivate struct Info: Value {
        let duration: Double
        let title: String?
        
        init?(substring: Substring) {
            let pair = substring.split(separator: ",", maxSplits: 1)
            guard !pair.isEmpty, let duration = Double(pair[0]) else {
                return nil
            }
            self.duration = duration
            self.title = pair.count == 2 ? String(pair[1]) : nil
        }
    }
    
    fileprivate func value<T: Value>(_ substring: Substring) throws(Error) -> T {
        guard let value = T(substring: substring) else {
            throw .wrongTagValueFormat(self, String(substring))
        }
        return value
    }
    
    fileprivate func value<T: Value>(_ substring: Substring) throws(Error) -> T? {
        guard let value = T(substring: substring) else {
            try HLSParsing.throwIfStrict(error: .wrongTagValueFormat(self, String(substring)))
            return nil
        }
        return value
    }
}

extension HLSParsing.PlaylistTag.Attribute {
    
    fileprivate protocol Value: HLSParsing.PlaylistTag.Value {
        init?(substring: Substring)
    }
}

extension Dictionary {
    
    fileprivate typealias Error = HLSParsing.PlaylistError
    fileprivate typealias Tag = HLSParsing.PlaylistTag
}

extension HLSParsing.Playlist.TagList {
    
    fileprivate func value<T: Tag.Value>(_ tag: Tag) throws(Error) -> T {
        guard let substring = self[tag] else {
            throw .missingTag(tag)
        }
        return try tag.value(substring)
    }
    
    fileprivate func value<T: Tag.Value>(_ tag: Tag) throws(Error) -> T? {
        guard let substring = self[tag] else {
            return nil
        }
        return try tag.value(substring)
    }
}

extension HLSParsing.PlaylistTag.AttributeList: HLSParsing.PlaylistTag.Value {
    
    fileprivate init(substring: Substring) {
        self = substring.split(separator: ",").reduce(into: [:]) { partialResult, attribute in
            let pair = attribute.split(separator: "=")
            // Loose attribute parsing: skip invalid format and unknown names; overwrite duplicate names.
            guard pair.count == 2, let name = Tag.Attribute(rawValue: String(pair[0])) else { return }
            partialResult[name] = pair[1]
        }
    }

    fileprivate func value<T: Tag.Attribute.Value>(_ attribute: Tag.Attribute) throws(Error) -> T {
        guard let attributeValue = self[attribute] else {
            throw .missingAttribute(attribute)
        }
        guard let value = T(substring: attributeValue) else {
            throw .wrongAttributeFormat(attribute, String(attributeValue))
        }
        return value
    }
}

extension HLSParsing.PlaylistTag.Value where Self: LosslessStringConvertible {
    fileprivate init?(substring: Substring) {
        self.init(String(substring))
    }
}

extension Int: HLSParsing.PlaylistTag.Attribute.Value { }

extension Double: HLSParsing.PlaylistTag.Attribute.Value { }

extension String: HLSParsing.PlaylistTag.Attribute.Value {
    fileprivate init?(substring: Substring) {
        self = substring.trimmingCharacters(in: .init(charactersIn: "\""))
    }
}

extension Substring: HLSParsing.PlaylistTag.Attribute.Value {
    fileprivate init?(substring: Substring) {
        self = substring
    }
}

extension HLSParsing.PlaylistTag.Attribute.Resolution: HLSParsing.PlaylistTag.Attribute.Value { }

extension HLSParsing.PlaylistTag.Attribute.ByteRange: HLSParsing.PlaylistTag.Attribute.Value { }
