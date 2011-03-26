//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import <Cocoa/Cocoa.h>
#import "TBLyricSite.h"

@interface TBAZLyrics : TBLyricSite {
	NSMutableDictionary *albumCache;
}

//
// Sorted by calling order
//
-(NSString *) fetchLyricsForTrack:(NSString *)title byArtist:(NSString *)artist error:(NSError **)error;
-(NSString *) getURLForArtist:(NSString *) artist error:(NSError **)error;
-(NSString *) getLyricURLForTrack:(NSString *)title fromArtistURL:(NSString *)artistURL error:(NSError **)error;
-(NSString *) extractLyricsFromURL:(NSString *)url forTrack:(NSString *)trackName error:(NSError **)error;

@end
