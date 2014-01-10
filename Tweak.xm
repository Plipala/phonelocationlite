/* How to Hook with Logos
Hooks are written with syntax similar to that of an Objective-C @implementation.
You don't need to #include <substrate.h>, it will be done automatically, as will
the generation of a class list and an automatic constructor.

%hook ClassName

// Hooking a class method
+ (id)sharedInstance {
	return %orig;
}

// Hooking an instance method with an argument.
- (void)messageName:(int)argument {
	%log; // Write a message about this call, including its class, name and arguments, to the system log.

	%orig; // Call through to the original function with its original arguments.
	%orig(nil); // Call through to the original function with a custom argument.

	// If you use %orig(), you MUST supply all arguments (except for self and _cmd, the automatically generated ones.)
}

// Hooking an instance method with no arguments.
- (id)noArguments {
	%log;
	id awesome = %orig;
	[awesome doSomethingElse];

	return awesome;
}

// Always make sure you clean up after yourself; Not doing so could have grave consequences!
%end
*/

// #include <objc/runtime.h>

// %hook InCallLCDView

// -(void)setLabel:(id)label{
// 	%orig(@"Hook!");
// }

// -(void)setLabel:(id)label alternateLabel:(id)label2{
// 	%orig(@"Hook!",@"Alternate");
// }

// -(void)setText:(id)text{
// 	%orig(@"Plipala");	
// }

// -(void)setText:(id)text animating:(BOOL)animating{
// 	%orig(@"Plipala",animating);
// }

// %end

// @interface TPLCDView
// -(void)setSecondLineText:(id)text;
// @end

// %hook TPLCDView

// -(void)setLabel:(id)label{
// 	NSLog(@"hook In TPLCDView");
// 	NSLog(@"self %@",self);
// 	[self setSecondLineText:@"Plipala"];
// }

// -(void)setLabel:(id)label alternateLabel:(id)label2{
// 	NSLog(@"hook In TPLCDView alternateLabel");
// 	%orig(@"Hook!",@"Alternate");
// 	[self setSecondLineText:@"Plipala"];
// }

// %end
#include "area.h"
#import <UIKit/UIKit.h>

extern "C" {
NSString *CTCallCopyAddress(void *, id call);
}

static Area *area;

@interface TUTelephonyCall
-(id)call;
-(int)status;
@end

@interface KLocationDataProvider
+(id)sharedInstance;
-(NSString *)getLocation:(NSString *)address withCarrier:(BOOL)withCarrier;
@end

NSString * getLocation (NSString *address){
	if (address == nil)
	{
		return nil;
	}
	char *area_str = NULL;
	NSString *formattedAddress = [address stringByReplacingOccurrencesOfString:@"-" withString:@""];
	formattedAddress = [formattedAddress stringByReplacingOccurrencesOfString:@"(" withString:@""];
	formattedAddress = [formattedAddress stringByReplacingOccurrencesOfString:@")" withString:@""];
	formattedAddress = [formattedAddress stringByReplacingOccurrencesOfString:@" " withString:@""];
    area_str = Area_get(area, [formattedAddress UTF8String], AREA_WITH_NAME | AREA_WITH_TYPE);
	if(area_str != NULL) {
		return  [NSString stringWithCString:area_str encoding:NSUTF8StringEncoding];
	}
	else {
		return nil;
	}
}

%group Incoming
%hook MPIncomingPhoneCallController

-(void)setIncomingCallerLabel:(id)label{
	NSString *location = nil;
	id __incomingCall = [self valueForKey:@"_incomingCall"];
	if ([__incomingCall isKindOfClass:objc_getClass("TUTelephonyCall")])
	{
		NSString *number = CTCallCopyAddress(NULL,[(TUTelephonyCall*)__incomingCall call]);

		if (number != nil) {
			location = getLocation(number);
		}
	}
	if (location != nil)
	{
		%orig(location);
	}
	else {
		%orig;
	}
}

%end
%end

%group SpringBoard
%hook SBPluginManager

-(void)loadAllLaunchPlugins{
	%orig;
	%init(Incoming);
}

%end
%end

@interface InCallLCDView
-(void)setLabel:(id)label alternateLabel:(id)label2;
-(void)setLabel2:(id)a2 alternateLabel:(id)label;
@end

%group MobilePhone

extern "C" {
	void FigVibratorPlayVibrationWithDictionary(CFDictionaryRef dict, bool mul, float factor);
	void FigVibratorInitialize(void * f);
}
void vibrateMadly()
{
	static bool initlized = NO;
	if (!initlized)
	{
		FigVibratorInitialize(0);
		initlized = YES;
	}
	
 	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                 				[NSNumber numberWithFloat: 0.0f], @"OnDuration",
                 				[NSNumber numberWithFloat: 0.0f], @"OffDuration",
                 				[NSNumber numberWithFloat: 0.15f], @"Period",
                 				[NSNumber numberWithFloat: 1.0f], @"Intensity",
                 				[NSNumber numberWithFloat: 0.2f], @"TotalDuration",
                 				nil];

	FigVibratorPlayVibrationWithDictionary((CFDictionaryRef) dict, NO, 0.0f);
}

static int lastStatus[2];

%hook InCallController

-(void)_callStatusChanged:(id)changed{
	%orig;
	if ([changed isKindOfClass:objc_getClass("TUTelephonyCall")])
	{
		unsigned __currentCall;
		object_getInstanceVariable(self,"_currentCall",(void**)&__currentCall);
		
		int status = [(TUTelephonyCall*)changed status];

		if (lastStatus[__currentCall] == 3 && status == 1)
		{
			vibrateMadly();
		}
		lastStatus[__currentCall] = status;

		if (status == 3)
		{
			NSString *number = CTCallCopyAddress(NULL,[(TUTelephonyCall*)changed call]);
			if (number != nil) {
				NSString *location = getLocation(number);
				if (location != nil)
				{
					InCallLCDView *__lcdView = [self valueForKey:@"_lcd"];
					if (__currentCall == 0)
					{
						[__lcdView setLabel:location alternateLabel:nil];
					}
					else {
						[__lcdView setLabel2:location alternateLabel:nil];
					}
				}
				
			}
		}
	}
}
%end

@interface PHRecentCall
-(id)destinationLocation;
@end

%hook PHRecentCall
-(id)destinationStringForDisplay{
	id res = %orig;
	CFTypeRef __destinationPhoneNumber;
	object_getInstanceVariable(self,"_destinationPhoneNumber",(void**)&__destinationPhoneNumber);
	if (__destinationPhoneNumber != NULL)
	{
		NSString *address = [NSString stringWithFormat:@"%@",__destinationPhoneNumber];
		NSString *location = getLocation(address);
		if (location != nil)
		{
			if ([res isEqualToString:[[NSBundle mainBundle] localizedStringForKey:@"UNKNOWN_LABEL" value:nil table:@"Recents"]])
			{
				return location;
			}
			return [NSString stringWithFormat:@"%@ | %@",res,location];
		}
	}
	
	return res;
}
%end
%end

%group MobileSMS

@interface CKConversation
@property(retain, nonatomic) NSArray* recipients;
-(id)uniqueIdentifier;
@end

@interface CKEntity
@property(readonly, assign, nonatomic) NSString* originalAddress; 
@end

static NSMutableDictionary *smsLocationCache = nil;

%hook CKUIBehavior

-(id)conversationListDateFont{
	id res = %orig;
	return [(UIFont*)res fontWithSize:14.0f];
}

-(id)conversationListSenderFont{
	id res = %orig;
	return [(UIFont*)res fontWithSize:14.0f];
}

%end

%hook CKConversation

-(NSString *)name{
	NSString *res = %orig;
	NSString *location = [smsLocationCache objectForKey:[self uniqueIdentifier]];
	if (!location)
	{
		if ([[self recipients] count]  !=1)
		{
			[smsLocationCache setObject:@"" forKey:[self uniqueIdentifier]];
			return res;
		}
		else {
			NSString *fetchLocation = getLocation([[[self recipients] objectAtIndex:0] originalAddress]);
			if (fetchLocation != nil)
			{
				[smsLocationCache setObject:fetchLocation forKey:[self uniqueIdentifier]];
				return [NSString stringWithFormat:@"%@ | %@",res,fetchLocation];
			}
			else {
				[smsLocationCache setObject:@"" forKey:[self uniqueIdentifier]];
				return res;
			}
		}
	}
	else {
		if ([location length] > 0)
		{
			return [NSString stringWithFormat:@"%@ | %@",res,location];
		}
	}
	return res;
}

%end

%end

%ctor{
	%init();
	area = Area_load("/var/mobile/Library/PhoneLocationLite/data", 10*1024);
	if  ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"])
	{
		%init(SpringBoard);
	}
	if  ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.mobilephone"])
	{
		%init(MobilePhone);
	}
	if  ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.MobileSMS"])
	{
		smsLocationCache = [[NSMutableDictionary alloc] init];
		%init(MobileSMS);
	}
}