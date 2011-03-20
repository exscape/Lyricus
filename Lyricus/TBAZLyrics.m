
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import "TBAZLyrics.h"
#import "NSString+ExscapeEdits.h"

@implementation TBAZLyrics

-(TBAZLyrics *) init
{
    self = [super init];
	if (self)
	{
		return self;
	}
	return nil;
}

#pragma mark -
#pragma mark Public

-(NSString *) fetchLyricsForTrack:(NSString *)title byArtist:(NSString *)artist error:(NSError **)error {
	//
	// The only method called from the outside
	//
	
	SendNote(@"Trying AZLyrics...\n");
	SendNote(@"\tFetching lyric URL...\n");
	
	NSString *artistURL = [self getURLForArtist:artist error:error] /* cannot fail */;
	if (artistURL == nil)
		return nil;
	NSString *trackURL = [self getLyricURLForTrack:title fromArtistURL: artistURL error:error];
	SendNote(@"\tFetching and parsing lyrics...\n");
	NSString *lyrics = [self extractLyricsFromURL:trackURL forTrack:title error:error];
    
	if (lyrics != nil && [lyrics length] < 5) {
		return nil;
	}
	else
        return lyrics; // may still be nil, but in that case we would return nil anyway
}

#pragma mark -
#pragma mark Internal/private

-(NSString *)getURLForArtist:(NSString *) artist error:(NSError **)error {
#warning FIX
	
}

-(NSString *)getLyricURLForTrack:(NSString *)title fromArtistURL:(NSString *)inURL error:(NSError **)error {
	//
	// Looks through an artist page (i.e. "http://www.azlyrics.com/d/darktranquillity.html") for the track link
	//
	NSURL *artistURL = [NSURL URLWithString:inURL];
    NSError *err = nil;
	NSString *html = [TBUtil getHTMLFromURL:artistURL error:&err];
	if (html == nil) {
        if (err != nil) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Unable to download lyrics. This could be a problem with your internet connection or the site(s) used." forKey:NSLocalizedDescriptionKey];
            if (error != nil) {
                *error = [NSError errorWithDomain:@"org.exscape.org.Lyricus" code:LyricusHTMLFetchError userInfo:errorDetail];
            }
        }
        return nil;
    }
    
	NSString *regex = 
    @"<a href=\"(../lyrics/[^\"]*)\" target=\"_blank\">(.*?)</a><br>";
	
    NSArray *matchArray = [html arrayOfDictionariesByMatchingRegex:regex withKeysAndCaptures:@"url", 1, @"title", 2, nil];
    for (NSDictionary *match in matchArray) {
		if ([TBUtil string:title isEqualToString:[match objectForKey:@"title"]]) // we ignore all non-chars, so that "The Serpent's chalice" matches "the Serpents chalice" and so on.
            return [[match objectForKey:@"url"] stringByReplacingOccurrencesOfRegex:@"^\\.\\./lyrics/" withString:@"http://www.azlyrics.com/lyrics/"];
	}
	return nil;
}

-(NSString *)extractLyricsFromURL:(NSString *)url forTrack:(NSString *)trackName error:(NSError **)error {
	//
	// Extracts and returns the lyrics from a given URL and trackname.
	//
	if (url == nil)
		return nil;
	
	NSString *source;
    NSError *err = nil;
    source = [TBUtil getHTMLFromURL:[NSURL URLWithString:url] error:&err];
	
	if (source == nil) {
        if (err != nil) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Unable to download lyrics. This could be a problem with your internet connection or the site(s) used." forKey:NSLocalizedDescriptionKey];
            if (error != nil) {
                *error = [NSError errorWithDomain:@"org.exscape.org.Lyricus" code:LyricusHTMLFetchError userInfo:errorDetail];
            }
        }
        return nil;
    }

	NSString *regex = 
	@"<!-- start of lyrics -->([\\s\\S]*?)<!-- end of lyrics -->";
    
    NSMutableString *lyrics = [[source stringByMatching:regex capture:1L] mutableCopy];

    [lyrics replaceOccurrencesOfRegex:@"<[^>]*>" withString:@""];
    if (lyrics && ![lyrics isEqual:@""]) {
        return [lyrics stringByTrimmingWhitespace];
    }
    
	// If we've checked all titles, something is wrong, since AZLyrics provides a list of the lyrics supported to be at this URL. This is likely because the regular expression doesn't match due to site updates.
    
    NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
    [errorDetail setValue:@"Unable to parse lyrics. Please report this to the developer at serenity@exscape.org!" forKey:NSLocalizedDescriptionKey];
    if (error != nil) {
        *error = [NSError errorWithDomain:@"org.exscape.org.Lyricus" code:LyricusLyricParseError userInfo:errorDetail];
    }
    return nil;
}

@end
