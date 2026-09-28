# Player and library design reference

The supplied 21-minute Apple Music redesign recording and nine screenshots are visual and interaction references for Petal. The recording presents a critique of Apple Music followed by a concept, rather than a specification of Petal's data sources.

## Behaviors to carry into Petal

| Reference | Petal implementation |
| --- | --- |
| Neutral, dark browsing canvas with artwork supplying most of the color | Neutral dark theme; artwork remains prominent in library grids and player. |
| Compact transport floats above the browsing surface | Rounded mini player with independent progress and controls. |
| Phone player changes among cover art, lyrics, and upcoming tracks | Three player views with a persistent transport and shared playback state. |
| Desktop player presents artwork and synchronized lyrics together | Artwork and transport on the left; lyrics or queue on the right. |
| Desktop browsing gives artwork and collections a wide content area | Library content uses the available width; queue is opened from the player instead of occupying a permanent right rail. |
| Search is clearly separated from browsing | Top search field continues to query Petal's indexed local and cloud tracks. |
| Library surfaces favorites, playlists, artists, albums, and songs | Existing tabs and sidebar preserve those distinct destinations. |

The video includes Apple Music editorial picks, commercial catalog search, radio stations, music videos, and spatial audio marketing. Petal currently indexes the user's own local files and authorized Google Drive/OneDrive audio. Those catalog sections cannot honestly be populated from the existing model and should only be added after their content source and behavior are defined.

## Interaction and visual checks

- Phone widths: artwork, lyrics, and queue each occupy the available player area; title, progress, and playback controls remain accessible.
- Desktop widths: changing lyrics/queue keeps the artwork and transport in place.
- Empty music library: no invented featured music or nonfunctional controls.
- Missing artwork and lyrics: readable fallbacks rather than blank panes.
- Reduced motion: screen changes and backdrop animations honor the OS setting.
- Resizing and fullscreen: avoid route Hero detachment and transparent outgoing panes.

The imagery and artist names in the reference are examples. Petal displays artwork and metadata from the user's own library rather than copying those assets.
