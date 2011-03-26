//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import <Cocoa/Cocoa.h>
#import "TBLyricClass.h"

@interface TBDarklyrics : TBLyricClass {
	NSMutableDictionary *albumCache;
}

//
// Sorted by calling order
//
-(NSString *) fetchLyricsForTrack:(NSString *)title byArtist:(NSString *)artist error:(NSError **)error;
-(NSURL *) getURLForArtist:(NSString *) artist;
-(NSString *) getLyricURLForTrack:(NSString *)title fromArtistURL:(NSURL *)artistURL error:(NSError **)error;
-(NSString *) extractLyricsFromURL:(NSString *)url forTrack:(NSString *)trackName error:(NSError **)error;

@end
