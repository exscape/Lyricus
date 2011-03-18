
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import "NSProgressIndicator+ThreadSafeUpdating.h"


@implementation NSProgressIndicator (ThreadSafeUpdating)

//
// Note:these methods are obviously not thread safe on their own, but they make it easier to say
// [progressIndicator performSelector:@selector(thrSetCurrentValue:) onMainThread... etc.
//

-(void) thrSetMaxValue:(NSNumber *)max {
	[self setMaxValue:[max doubleValue]];
}
-(void) thrSetMinValue:(NSNumber *)min {
	[self setMinValue:[min doubleValue]];
}

-(void) thrSetCurrentValue:(NSNumber *)current {
	[self setDoubleValue:[current doubleValue]];
}

-(void) thrIncrementBy:(NSNumber *)delta {
	[self incrementBy:[delta doubleValue]];
}

@end