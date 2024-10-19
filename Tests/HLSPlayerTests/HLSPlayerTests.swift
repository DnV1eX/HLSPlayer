import Testing
import Foundation
@testable import HLSPlayer

@Suite struct HLSParsingTests {
    
    init() {
        HLSParsing.isStrict = true
    }
    
    @Test func simpleMediaPlaylist() async throws {
        let data = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXT-X-VERSION:3
            #EXTINF:9.009,
            http://media.example.com/first.ts
            #EXTINF:9.009,
            http://media.example.com/second.ts
            #EXTINF:3.003,
            http://media.example.com/third.ts
            #EXT-X-ENDLIST
            """.data(using: .utf8)!
        let url = URL(string: "http://dnv1ex.com")!
        let playlist = try HLSParsing.MediaPlaylist(data: data, baseURI: url, multivariantPlaylist: nil)
        #expect(playlist.targetDuration == 10)
        #expect(playlist.version == 3)
        #expect(playlist.segments.count == 3)
        #expect(playlist.segments[0].duration == 9.009)
        #expect(playlist.segments[1].uri.absoluteString == "http://media.example.com/second.ts")
        #expect(playlist.segments[2].duration == 3.003)
        #expect(playlist.endlist == true)
    }
    
    @Test func liveMediaPlaylistUsingHTTPS() async throws {
        let data = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:8
            #EXT-X-MEDIA-SEQUENCE:2680
            
            #EXTINF:7.975,
            https://priv.example.com/fileSequence2680.ts
            #EXTINF:7.941,
            https://priv.example.com/fileSequence2681.ts
            #EXTINF:7.975,
            https://priv.example.com/fileSequence2682.ts
            """.data(using: .utf8)!
        let url = URL(string: "http://dnv1ex.com")!
        let playlist = try HLSParsing.MediaPlaylist(data: data, baseURI: url, multivariantPlaylist: nil)
        #expect(playlist.version == 3)
        #expect(playlist.targetDuration == 8)
        #expect(playlist.mediaSequence == 2680)
        #expect(playlist.segments.count == 3)
        #expect(playlist.segments[0].duration == 7.975)
        #expect(playlist.segments[1].duration == 7.941)
        #expect(playlist.segments[2].uri.absoluteString == "https://priv.example.com/fileSequence2682.ts")
        #expect(playlist.endlist == false)
    }
    
    // The EXT-X-KEY tag is not supported yet.
    @Test func playlistWithEncryptedMediaSegments() async throws {
        let data = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-MEDIA-SEQUENCE:7794
            #EXT-X-TARGETDURATION:15

            #EXT-X-KEY:METHOD=AES-128,URI="https://priv.example.com/key.php?r=52"

            #EXTINF:2.833,
            http://media.example.com/fileSequence52-A.ts
            #EXTINF:15.0,
            http://media.example.com/fileSequence52-B.ts
            #EXTINF:13.333,
            http://media.example.com/fileSequence52-C.ts

            #EXT-X-KEY:METHOD=AES-128,URI="https://priv.example.com/key.php?r=53"

            #EXTINF:15.0,
            http://media.example.com/fileSequence53-A.ts
            """.data(using: .utf8)!
        let url = URL(string: "http://dnv1ex.com")!
        let playlist = try HLSParsing.MediaPlaylist(data: data, baseURI: url, multivariantPlaylist: nil)
        #expect(playlist.version == 3)
        #expect(playlist.mediaSequence == 7794)
        #expect(playlist.targetDuration == 15)
        #expect(playlist.segments.count == 4)
        #expect(playlist.segments[0].duration == 2.833)
        #expect(playlist.segments[0].uri.absoluteString == "http://media.example.com/fileSequence52-A.ts")
        #expect(playlist.segments[3].duration == 15.0)
        #expect(playlist.segments[3].uri.absoluteString == "http://media.example.com/fileSequence53-A.ts")
        #expect(playlist.endlist == false)
    }
    
    @Test func multivariantPlaylist() async throws {
        let data = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=1280000,AVERAGE-BANDWIDTH=1000000
            http://example.com/low.m3u8
            #EXT-X-STREAM-INF:BANDWIDTH=2560000,AVERAGE-BANDWIDTH=2000000
            http://example.com/mid.m3u8
            #EXT-X-STREAM-INF:BANDWIDTH=7680000,AVERAGE-BANDWIDTH=6000000
            http://example.com/hi.m3u8
            #EXT-X-STREAM-INF:BANDWIDTH=65000,CODECS="mp4a.40.5"
            http://example.com/audio-only.m3u8
            """.data(using: .utf8)!
        let playlist = try HLSParsing.MultivariantPlaylist(data: data)
        #expect(playlist.streams.count == 4)
        #expect(playlist.streams[0].uri.absoluteString == "http://example.com/low.m3u8")
        #expect(playlist.streams[1].bandwidth == 2560000)
        #expect(playlist.streams[2].averageBandwidth == 6000000)
        #expect(playlist.streams[3].codecs.first == "mp4a.40.5")
    }
}
