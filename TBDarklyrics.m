
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import "TBDarklyrics.h"
#import "NSString+ExscapeEdits.h"

@implementation TBDarklyrics

-(TBDarklyrics *) init
{
    self = [super init];
	if (self)
	{
		albumCache = [[NSMutableDictionary alloc] init];
		return self;
	}
	return nil;
}

#pragma mark -
#pragma mark Public

-(NSMutableArray *) fetchLyricsForTrack:(NSString *)title byArtist:(NSString *)artist {
	//
	// The only method called from the outside
	//
	
	SendNote(@"Trying darklyrics...\n");
	SendNote(@"\tFetching lyric URL...\n");
	
	NSString *artistURL = [self getURLForArtist:artist];
	if (artistURL == nil)
		return nil;
	NSString *trackURL = [self getLyricURLForTrack:title fromArtistURL: artistURL];
	SendNote(@"\tFetching and parsing lyrics...\n");
	NSString *lyrics = [self extractLyricsFromURL:trackURL forTrack:title];
	if (lyrics != nil && [lyrics length] < 5) {
		return nil;
	}
	else if (lyrics == nil)
		return nil;
	else {
		//	lyrics = [lyrics stringByAppendingString:@"\n\nLyrics from www.darklyrics.com"];
		return [NSMutableArray arrayWithObjects:trackURL, lyrics, nil];
	}
}

#pragma mark -
#pragma mark Internal/private

-(NSString *)getURLForArtist:(NSString *) artist {
	// Easy enough, all URLs seem to be in the form "http://www.darklyrics.com/t/theartistnamegoeshere.html"
	
	// First, make the artist name lowercase and remove all non-chars
	artist = [[artist lowercaseString] stringByStrippingNonCharacters];
	
	if (artist == nil || [artist length] < 1)
		return nil;
	
	// Then, create the URL and return it.
	return [NSString stringWithFormat:@"http://www.darklyrics.com/%c/%@.html", [artist characterAtIndex:0], artist];
}

-(NSString *)extractLyricsFromURL:(NSString *)url forTrack:(NSString *)trackName{
	//
	// Extracts and returns the lyrics from a given URL and trackname. (Duh, see the line above ;)
	//
	if (url == nil)
		return nil;
	
	// This cache is only used for the session, and means that instead of re-downloading the lyrics for an album
	// 10 times for 10 tracks, we'll only download it once. The cache is NOT saved between sessions, which also shouldn't be necessary.
	// (Darklyrics displays the lyrics for ALL tracks an on album on the same page, so fetching it 10 times for 10 tracks is just stupid.)
	NSString *source;
	if ([albumCache objectForKey:url] != nil) {
		source = [albumCache objectForKey:url];
//		NSLog(@"Using cached darklyrics page");
	}
	else {
		source = [TBUtil getHTMLFromURL:[NSURL URLWithString:url]];
//		NSLog(@"Downloading and caching darklyrics page");
		if (source)
			[albumCache setObject:source forKey:url];
	}
	
	if (source == nil)
		return nil;
	
	NSMutableString *lyrics;
	NSString *regex = 
	@"(?i)<h3><a name=\"\\d+\">\\d+\\. ([^<]*?)</a></h3><br />\\s*([\\s\\S]+?)(?=<br /><br />)";

	// Ah, the beauty of regular expressions.
    NSArray *matchesArray = [source arrayOfDictionariesByMatchingRegex:regex withKeysAndCaptures:@"title", 1, @"lyrics", 2, nil];

    for (NSDictionary *match in matchesArray) {
		if ([TBUtil string:[match objectForKey:@"title"] isEqualToString:trackName]) {
            lyrics = [[match objectForKey:@"lyrics"] mutableCopy];
            [lyrics replaceOccurrencesOfRegex:@"<[^>]*>" withString:@""];
			
			return [lyrics stringByTrimmingWhitespace];
		}
	}
	// If we've checked all titles, and none matched, oh well...
	return nil;
}

-(NSString *)getLyricURLForTrack:(NSString *)title fromArtistURL:(NSString *)inURL {
	//
	// Looks through an artist page (i.e. "http://www.darklyrics.com/d/darktranquillity.html") for the track link
	//
	NSURL *artistURL = [NSURL URLWithString:inURL];
	NSString *html = [TBUtil getHTMLFromURL:artistURL];
	if (html == nil) 
		return nil;
    
	NSString *regex = 
	@"<a href=\"../([^#]*?)\\#\\d+\">([^<]*?)</a><br />";
	
    NSArray *matchArray = [html arrayOfDictionariesByMatchingRegex:regex withKeysAndCaptures:@"url", 1, @"title", 2, nil];
    for (NSDictionary *match in matchArray) {
		if ([TBUtil string:title isEqualToString:[match objectForKey:@"title"]]) // we ignore all non-chars, so that "The Serpent's chalice" matches "the Serpents chalice" and so on.
            return [[match objectForKey:@"url"] stringByReplacingOccurrencesOfRegex:@"^lyrics/" withString:@"http://www.darklyrics.com/lyrics/"];
	}
	return nil;
}

@end
