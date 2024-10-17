import Testing
@testable import HLSPlayer

let multivariantPlaylistString = """
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1280000,AVERAGE-BANDWIDTH=1000000
http://example.com/low.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2560000,AVERAGE-BANDWIDTH=2000000
http://example.com/mid.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=7680000,AVERAGE-BANDWIDTH=6000000
http://example.com/hi.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=65000,CODECS="mp4a.40.5"
http://example.com/audio-only.m3u8
"""

@Test func multivariantPlaylist() async throws {
    let playlist = try HLSParsing.MultivariantPlaylist(data: multivariantPlaylistString.data(using: .utf8)!)
    #expect(playlist.streams.count == 4)
    #expect(playlist.streams[0].uri.absoluteString == "http://example.com/low.m3u8")
    #expect(playlist.streams[1].bandwidth == 2560000)
    #expect(playlist.streams[2].averageBandwidth == 6000000)
    #expect(playlist.streams[3].codecs.first == "mp4a.40.5")
}
