//
//  HLSParsing.swift
//  HLSPlayer
//
//  Created by Alexey Demin on 2024-10-15.
//

import Foundation

// https://datatracker.ietf.org/doc/html/draft-pantos-hls-rfc8216bis (HTTP Live Streaming 2nd Edition)

enum HLSParsing {
    
    protocol Playlist {
        typealias Error = HLSParsing.PlaylistError
        typealias Tag = HLSParsing.PlaylistTag
        typealias Line = Substring
    }
    
    enum PlaylistError: Error {
        case stringUTF8DecodingFailure
        case extendedM3UTagMissing
        case multipleOccurrenceOfTag(PlaylistTag)
        case unexpectedMediaPlaylistOrSegmentTag(PlaylistTag)
        case unexpectedMultivariantPlaylistTag(PlaylistTag)
        case missingTag(PlaylistTag)
        case wrongTagValueFormat(PlaylistTag, String)
        case missingAttribute(PlaylistTag.Attribute)
        case wrongAttributeFormat(PlaylistTag.Attribute, String)
        case missingURIForTag(PlaylistTag)
        case wrongURIFormatForTag(PlaylistTag, String)
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
        
        var isNotImplemented: Bool {
            [.start, .define, .playlistType, .iFramesOnly, .partInfo, .serverControl, .extendedInfo, .byteRange, .discontinuity, .key, .map, .programDateTime, .gap, .bitrate, .part, .dateRange, .skip, .preloadHint, .renditionReport, .media, .iFrameStreamInfo, .sessionData, .sessionKey, .contentSteering].contains(self)
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
    
    protocol Value {
        init?(substring: Substring)
    }
    
    struct AttributeList: Value {
        
        typealias Error = HLSParsing.PlaylistError
        typealias Tag = HLSParsing.PlaylistTag
        
        private let dictionary: [Attribute: Substring]

        init(substring: Substring) {
            dictionary = substring.split(separator: ",").reduce(into: [:]) { partialResult, attribute in
                let pair = attribute.split(separator: "=")
                // Loose attribute parsing: skip invalid format and unknown names; overwrite duplicate names.
                guard pair.count == 2, let name = Tag.Attribute(rawValue: String(pair[0])) else { return }
                partialResult[name] = pair[1]
            }
        }

        func value<T: Tag.Attribute.Value>(_ attribute: Tag.Attribute) throws(Error) -> T {
            guard let attributeValue = dictionary[attribute] else {
                throw .missingAttribute(attribute)
            }
            guard let value = T(substring: attributeValue) else {
                throw .wrongAttributeFormat(attribute, String(attributeValue))
            }
            return value
        }
    }
}

fileprivate extension HLSParsing.Playlist.Line {
    
    typealias Error = HLSParsing.PlaylistError
    typealias Tag = HLSParsing.PlaylistTag

    func value<T: Tag.Value>(for tag: Tag) throws(Error) -> T? {
        guard hasPrefix(tag.description) else {
            return nil
        }
        let valueSubstring = dropFirst(tag.description.count + 1) // Remove tag with colon.
        guard let value = T(substring: valueSubstring) else {
            throw .wrongTagValueFormat(tag, String(valueSubstring))
        }
        return value
    }
}

fileprivate extension Array where Element == HLSParsing.Playlist.Line {
    
    typealias Error = HLSParsing.PlaylistError
    typealias Tag = HLSParsing.PlaylistTag

    init(data: Data) throws(Error) {
        guard let string = String(data: data, encoding: .utf8) else {
            throw .stringUTF8DecodingFailure
        }
        
        let lines = string.split(separator: "\n")
        guard let firstLine = lines.first, firstLine == Tag.extendedM3U.description else {
            throw .extendedM3UTagMissing
        }
        
        self = lines
    }
    
    func contains(anyOf tags: [Tag]) -> Tag? {
        tags.first { tag in
            contains { line in
                line.hasPrefix(tag.description)
            }
        }
    }
    
    func contains(uniqueTag tag: Tag) throws(Error) -> Bool {
        var contains = false
        for line in self where line.hasPrefix(tag.description) {
            if contains {
                throw .multipleOccurrenceOfTag(tag)
            }
            contains = true
        }
        return contains
    }
    
    func value<T: Tag.Value>(for tag: Tag) throws(Error) -> T? {
        var tagLine: Element?
        for line in self where line.hasPrefix(tag.description) {
            if tagLine != nil {
                throw .multipleOccurrenceOfTag(tag)
            }
            tagLine = line
        }
        return try tagLine?.value(for: tag)
    }
    
    func value<T: Tag.Value>(for tag: Tag) throws(Error) -> T {
        guard let value = try value(for: tag) as T? else {
            throw .missingTag(tag)
        }
        return value
    }
    
    func values<T: Tag.Value>(for tag: Tag) throws(Error) -> [T] {
        try map { line throws(Error) in
            try line.value(for: tag)
        }.compactMap { $0 }
    }
    
    func valuesAndURIs<T: Tag.Value>(for tag: Tag) throws(Error) -> [(value: T, uri: URL)] {
        try enumerated().map { index, line throws(Error) in
            guard let value = try line.value(for: tag) as T? else {
                return nil
            }
            let uriLineIndex = index + 1
            guard uriLineIndex < count else {
                throw .missingURIForTag(tag)
            }
            let uriString = String(self[uriLineIndex])
            guard let uri = URL(string: uriString) else {
                throw .wrongURIFormatForTag(tag, uriString)
            }
            return (value, uri)
        }.compactMap { $0 }
    }
}

extension HLSParsing {
    
    struct MultivariantPlaylist: Playlist {
        
        let version: Int
        
        let independentSegments: Bool
        
        let streams: [(bandwidth: Int,
                       averageBandwidth: Int?,
                       score: Double?,
                       codecs: [String],
                       supplementalCodecs: [String],
                       resolution: Tag.Attribute.Resolution?,
                       frameRate: Double?,
                       uri: URL)]
        
        init(data: Data) throws(Playlist.Error) {
            let lines = try [Line](data: data)

            if let tag = lines.contains(anyOf: Tag.allCases.filter { [.mediaPlaylist, .mediaSegment].contains($0.type) }) {
                throw .unexpectedMediaPlaylistOrSegmentTag(tag)
            }
            
            version = try lines.value(for: .version) ?? 1
            
            independentSegments = try lines.contains(uniqueTag: .independentSegments)
            
            let streamInfo = try lines.valuesAndURIs(for: .streamInfo) as [(Tag.AttributeList, URL)]
            streams = try streamInfo.map { attributeList, uri throws(Playlist.Error) in
                (bandwidth: try attributeList.value(.bandwidth),
                 averageBandwidth: try? attributeList.value(.averageBandwidth),
                 score: try? attributeList.value(.score),
                 codecs: (try? (attributeList.value(.codecs) as String).split(separator: ",").map(String.init)) ?? [],
                 supplementalCodecs: (try? (attributeList.value(.supplementalCodecs) as String).split(separator: ",").map(String.init)) ?? [],
                 resolution: try? attributeList.value(.resolution),
                 frameRate: try? attributeList.value(.frameRate),
                 uri: uri)
            }
        }
    }
    
    struct MediaPlaylist: Playlist {
        
        let version: Int
        
        let independentSegments: Bool
        
        let targetDuration: Int
        
        let mediaSequence: Int?
        
        let discontinuitySequence: Int?
        
        let endlist: Bool
        
        init(data: Data, playlist: MultivariantPlaylist?) throws(Playlist.Error) {
            let lines = try [Line](data: data)

            if let tag = lines.contains(anyOf: Tag.allCases.filter { $0.type == .multivariantPlaylist }) {
                throw .unexpectedMultivariantPlaylistTag(tag)
            }
            
            version = try lines.value(for: .version) ?? 1

            independentSegments = try lines.contains(uniqueTag: .independentSegments) || playlist?.independentSegments ?? false
            
            targetDuration = try lines.value(for: .targetDuration)
            
            mediaSequence = try lines.value(for: .mediaSequence)
            
            discontinuitySequence = try lines.value(for: .discontinuitySequence)
            
            endlist = try lines.contains(uniqueTag: .endlist)
        }
    }
}

extension HLSParsing.PlaylistTag.Attribute {
    
    protocol Value: HLSParsing.PlaylistTag.Value {
        init?(substring: Substring)
    }
    
    struct Resolution: LosslessStringConvertible, Value {
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
}

extension HLSParsing.PlaylistTag.Value where Self: LosslessStringConvertible {
    init?(substring: Substring) {
        self.init(String(substring))
    }
}

extension Int: HLSParsing.PlaylistTag.Attribute.Value { }

extension Double: HLSParsing.PlaylistTag.Attribute.Value { }

extension String: HLSParsing.PlaylistTag.Attribute.Value {
    init?(substring: Substring) {
        self = substring.trimmingCharacters(in: .init(charactersIn: "\""))
    }
}

extension Substring: HLSParsing.PlaylistTag.Attribute.Value {
    init?(substring: Substring) {
        self = substring
    }
}
