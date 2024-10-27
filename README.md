HLSPlayer is an open source implementation of AVFoundation.AVPlayer for HTTP Live Streaming (HLS). It includes HLSPlayer based on AVSampleBufferDisplayLayer, HLSParsing, Player and Player.Item protocols with AVPlayer wrapper. There is also an example project with player UI for Apple's stream examples.

Features:
- Base parsing of HLS playlists, both Multivariant and Media.
- fMP4 streams support.
- Video rendering with AVSampleBufferDisplayLayer.
- Play, pause and rewind to selected time.
- Adjustable playback speed.
- Manual and automatic bit rate swithcing.

TODO:
- Playing audio tracks.
- TS streams support.
- HEVC streams support.
- Live streaming support.

Known bugs:
- Jerking during transition between samples.
- Some buffering optimizations needed.

Copyright © 2024 DnV1eX. All rights reserved.
