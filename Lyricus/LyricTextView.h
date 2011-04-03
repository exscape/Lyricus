//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import <Foundation/Foundation.h>


@interface LyricTextView : NSTextView {
}

@end

@interface NSObject (LyricusDragging)
-(BOOL)dragReceivedWithTrack:(NSDictionary *)track;
@end
