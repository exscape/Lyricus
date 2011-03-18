    
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import "TBSongmeanings.h"
#import "NSString+ExscapeEdits.h"

@implementation TBSongmeanings

-(TBSongmeanings *) init {
    self = [super init];
    if (self) {
		return self;
	}
	return nil;
}

#pragma mark -
#pragma mark Public

-(NSMutableArray *) fetchLyricsForTrack:(NSString *)title byArtist:(NSString *)artist {
	//
	// The only method called from the outside.
	//
	SendNote(@"Trying songmeanings...\n");
	SendNote(@"\tFetching song list...\n");
	
	NSString *artistURL = [self getURLForArtist:artist];
	if (artistURL == nil) {
		SendNote(@"\tArtist not found!\n");
		return nil;
	}
	SendNote(@"\tFetching lyric URL...\n");
	NSString *trackURL = [self getLyricURLForTrack:title fromArtistURL:artistURL];
	if (trackURL == nil) {
		SendNote(@"\tTrack not found!\n");
		return nil;
	}
	
	SendNote(@"\tFetching and parsing lyrics...\n");
	NSString *lyrics = [self extractLyricsFromURL:trackURL];
	if (lyrics == nil)
		return nil;
	
	return [NSMutableArray arrayWithObjects:trackURL, lyrics, nil];
}

#pragma mark -
#pragma mark Private/internal

-(NSString *)getURLForArtist:(NSString *) inArtist {
	//
	// Does a search for the artist name, and tries to return the URL to the artist's page,
	// which in turn contains a link to all the artist's songs.
	//
	
	if (inArtist == nil | [inArtist length] < 1)
		return nil;
	
	NSString *artist = [inArtist stringByReplacingOccurrencesOfString:@" " withString:@"+"];
	artist = [artist stringByAddingPercentEscapesUsingEncoding:NSISOLatin1StringEncoding];
    NSURL *url = [NSURL URLWithString: [NSString stringWithFormat:@"http://www.songmeanings.net/query/?q=%@&type=artists&page=1&start=0&mm=1&pp=20&b=Search", artist]];

	// Do the search and fetch results
	NSString *html = [TBUtil getHTMLFromURL:url];
	if (html == nil)
		return nil;
	
	if ([html containsString:@"There are <strong>no results</strong>"])
		return nil;
	// else continue...


    NSString *regex = 
    @"<div class=\"row-left\">\\s*<a href=\"http://www.songmeanings.net/artist/view/songs/(\\d+)/\"><strong>(.*?)</strong></a>\\s*</div>";
 	
    NSArray *matchArray = [html arrayOfDictionariesByMatchingRegex:regex withKeysAndCaptures:@"id", 1, @"artist", 2, nil];

    for (NSDictionary *match in matchArray) {
		if ([inArtist isEqualToCharactersInString:[match objectForKey:@"artist"] ignoringCase:YES])
			return [NSString stringWithFormat:@"http://www.songmeanings.net/artist/view/songs/%@/", [match objectForKey:@"id"]];
	}

	return nil;
}

-(NSString *)getLyricURLForTrack:(NSString *)title fromArtistURL:(NSString *)artistURL {
	//
	// Given an artist URL and a track, this tries to return the URL to the actual lyric.
	//
	
	NSString *html = [TBUtil getHTMLFromURL:[NSURL URLWithString:artistURL]];
	if (html == nil) 
		return nil;
	NSString *regex = 
      @"<tr class='row[01]'><td><a href=\"/songs/view/(\\d+)/\">(.*?)</a></td>";
    
	NSArray *matchArray = [html arrayOfDictionariesByMatchingRegex:regex withKeysAndCaptures:@"id", 1, @"title",2, nil];
    for (NSDictionary *match in matchArray) {
		
		if ([TBUtil string:title isEqualToString:[match objectForKey:@"title"]])
			return [NSString stringWithFormat:@"http://www.songmeanings.net/songs/view/%@/", [match objectForKey:@"id"]];
	}
	return nil;
}

-(NSString *)extractLyricsFromURL:(NSString *)url {
	//
	// Given an URL and the track's name, tries to extract the lyrics.
	//
	if (url == nil)
		return nil;
	NSString *html = [TBUtil getHTMLFromURL:[NSURL URLWithString:url]];
	if (html == nil) return nil;
	
	// Why THE HELL is this required!?!! Took me HOURS of debugging to find out. Seems to break even with dot matches all,
	// so lets use this:
	html = [html stringByReplacingOccurrencesOfString:@"\r" withString:@""];
	html = [html stringByReplacingOccurrencesOfString:@"\n" withString:@""];

	NSString *regex = 
	@"<!-- end ringtones -->(.*?)<!--ringtones and media links -->";
    NSMutableString *lyrics = [[html stringByMatching:regex capture:1L] mutableCopy];

    if (lyrics == nil) 
			return nil;

    [lyrics replaceOccurrencesOfRegex:@"<br />" withString:@"\n"];
    [lyrics replaceOccurrencesOfRegex:@"<[^>]*>" withString:@""];
    return [lyrics stringByTrimmingWhitespace];
}


@end
