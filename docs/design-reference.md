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

## Spotify concept reference

The supplied Spotify redesign recording adds ideas around fast library filters, an always accessible mini player, focused album/artist pages, and lyrics next to playback on desktop. Petal keeps its Apple-inspired visual system and maps those ideas to its existing favorites, songs, artists, albums, genres, playlists, and current queue. The video also depicts recommendations, friends, podcasts and a streaming catalog; those require content or social services that Petal does not currently have.

Text metadata stays Unicode end to end. The importer reads embedded tags where supported and uses a filename fallback for malformed tags; the display repair handles common wrongly decoded UTF-8 across Indic, Arabic, Cyrillic, Greek, CJK, and other scripts. Packaged fonts cover the listed common scripts, with operating-system font fallback for others. Unknown encodings, malformed tags, or absent system glyphs can still require a manual metadata correction; "every language" cannot be guaranteed by a fixed decoder.

Flutter's vsync drives transitions at the device refresh rate rather than a hard-coded 60 fps timer. Touch drag updates are isolated from the player subtree, and the large blurred backdrop finishes its entrance instead of repainting perpetually at 120/144/160 Hz. Real frame timing still needs profiling on representative devices.

On first launch, three short steps explain library and playback, platform-specific local import, and optional Google Drive/OneDrive access. Android requests audio scanning permission only from its dedicated step; iOS and web explain their filesystem limits. Users can continue without an account and connect a source later.
