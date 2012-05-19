//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import <Cocoa/Cocoa.h>

@interface TBUtil : NSObject {

}

+(NSString *)getHTMLFromURL:(NSURL *)url error:(NSError **)error; // ISO Latin-1
+(NSString *)getHTMLFromURLUsingUTF8:(NSURL *)url error:(NSError **)error;
+(NSString *)getHTMLFromURL:(NSURL *)url withCharset:(NSStringEncoding)theEncoding error:(NSError **)error;
+(BOOL) string:(NSString *) string isEqualToString:(NSString *)otherTitle;
+(NSInteger) showAlert:(NSString *) errText withCaption:(NSString *) caption;

@end
