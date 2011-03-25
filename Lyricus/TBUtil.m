//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import "TBUtil.h"
#import "NSString+ExscapeEdits.h"

@implementation TBUtil

+(NSInteger) showAlert:(NSString *) informativeText withCaption:(NSString *) caption {
	// Shows an alert, pure and simple. Not just for error messages, despite the method names.
	return [[NSAlert alertWithMessageText:caption defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:informativeText]
	 runModal];
}

+(BOOL) string:(NSString *) string isEqualToString:(NSString *)otherString {
	//
	// Compares two track titles, ignoring everything but actual characters, and also ignoring "the" and diacritics (üàñ etc).
	//
	
	if (string == nil || otherString == nil)
		return NO;

	NSString *t1 = [[string 		stringByReplacingOccurrencesOfString:@"The" withString:@"" options:(NSCaseInsensitiveSearch+NSWidthInsensitiveSearch) range:NSMakeRange(0, [string length])] stringByStrippingNonCharacters];
	NSString *t2 = [[otherString stringByReplacingOccurrencesOfString:@"The" withString:@"" options:(NSCaseInsensitiveSearch+NSWidthInsensitiveSearch) range:NSMakeRange(0, [otherString length])] stringByStrippingNonCharacters];
	return ( [t1 compare:t2 options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)] == NSOrderedSame );
}

+(NSString *)getHTMLFromURL:(NSURL *)url error:(NSError **)error {
	return [self getHTMLFromURL:url withCharset:NSISOLatin1StringEncoding error:error];
}

+(NSString *)getHTMLFromURL:(NSURL *)url withCharset:(NSStringEncoding)theEncoding error:(NSError **)error {
	NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLCacheStorageAllowedInMemoryOnly timeoutInterval:10.0];
	NSHTTPURLResponse *response = nil;
	
	NSError *err = nil;
	NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&err];
	NSInteger statusCode = [response statusCode];
	
	if (statusCode != 200 && statusCode != 301 && statusCode != 302 && statusCode != 303 && statusCode != 304 && statusCode != 307
		&& statusCode != 404 && statusCode != 410) {
		// The rationale for this is that if the status code is one of the above, the request should have either succeeded or failed due to a page not existing, rather than errors such as invalid requests or broken connections.
		// Thus the above codes are seen as non-errors by the lyric downloader.

		NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:[NSString stringWithFormat:@"HTTP error. Status code %d", statusCode] forKey:NSLocalizedDescriptionKey];
        if (error != nil) {
            *error = [NSError errorWithDomain:@"org.exscape.Lyricus" code:LyricusHTTPError userInfo:errorDetail];
        }
		// Fall through
	}
	
	if (data == nil)
		return nil;
	
	return [[NSString alloc] initWithData:data encoding:theEncoding];
}

@end
