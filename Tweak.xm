#include <substrate.h>
#include <arpa/inet.h>
#include <stdbool.h>

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


#define DEBUG 0


#if DEBUG
# define DEBUGLOG(...) do {\
	FILE* flog = fopen("/tmp/mcserver.log", "a");\
	fprintf(flog, __VA_ARGS__);\
	fclose(flog);\
	} while(0)
#else
# define DEBUGLOG(...)
#endif /* DEBUG */



const char* cstring(NSString* str);
NSString* objcstring(const char* str);
const char* stringForKey(const char* key);
void setStringForKey(const char* val, const char* key);
void alert(NSString* title, NSString* message);


// Returns a C style string from an NSString
const char* cstring(NSString* str) {
	return [str UTF8String];
}


// Returns an NSString from a C style string
NSString* objcstring(const char* str) {
	return [NSString stringWithUTF8String:str];
}


// Returns a C string from NSUserDefaults
const char* stringForKey(const char* key) {
	DEBUGLOG("stringForKey(\"%s\")\n", key);
	NSString* str = [[NSUserDefaults standardUserDefaults] stringForKey:objcstring(key)];
	return str ? cstring(str) : NULL;
}


// Sets a string in NSUserDefaults given a key
void setStringForKey(const char* val, const char* key) {
	DEBUGLOG("setStringForKey(\"%s\", \"%s\")\n", val, key);
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:objcstring(val) forKey:objcstring(key)];
	[defaults synchronize];
}


// Displays a UIAlertView given a title and message.
// The only button is one that says "Okay" and does nothing.
void alert(NSString* title, NSString* message) {
	DEBUGLOG("alert(@\"%s\", @\"%s\")\n", [title UTF8String], [message UTF8String]);
	
	UIAlertView* popup = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Okay", nil];
	[popup show];
	[popup release];
}

bool isvalid(const char* ip) {
	struct sockaddr_in sa;
	if(inet_pton(AF_INET, ip, &(sa.sin_addr)) == 1) {
		DEBUGLOG("Validated ip: %s\n", ip);
		return true;
	}
	return false;
}


%hook NSDictionary

+(id)dictionaryWithContentsOfFile:(NSString*)path {
	NSString* fname = [path lastPathComponent];
	DEBUGLOG("Intercepting plist read: %s\n", cstring(fname));
	
	if([fname isEqualToString:@"Root.inApp.plist"]) {
		DEBUGLOG("Using changed plist.\n");
		NSDictionary* ret = [[[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Keyboard/MinecraftPE/Root.inApp.plist"] autorelease];
		
		if(ret) {
			return ret;
		}
		else {
			DEBUGLOG("Error loading plist. Using default one instead.\n");
		}
	}
	
	DEBUGLOG("Running original method.\n");
	return %orig;
}

%end



MSHook(in_addr_t, inet_addr, const char *cp) {
	DEBUGLOG("inet_addr(\"%s\")\n", cp);
	
	/*
	cp should always be "255.255.255.255" except when
	trying to join a local Wi-Fi server, in which
	case it will contain the ip address of the local
	server. This update should now correctly handle
	this case. However, it means that this mod will
	now be incompatible with a binary server patch.
	*/
	if(strcmp(cp, "255.255.255.255") != 0) {
		return _inet_addr(cp);
	}
	
	const char* ip = stringForKey("mp_server");
	// If the key hasn't been set in the plist...
	if(!ip) {
		// ...set it to the default value of "255.255.255.255"
		setStringForKey("255.255.255.255", "mp_server");
		ip = "255.255.255.255";
	}
	
	if(isvalid(ip)) {
		return _inet_addr(ip);
	}
	
	DEBUGLOG("Invalid ip: %s\n", ip);
	alert(@"Invalid IP Address", @"The entered IP address is invalid. Defaulting to local multiplayer.");
	
	setStringForKey("255.255.255.255", "mp_server");
	
	return _inet_addr("255.255.255.255");
}


MSInitialize {
	DEBUGLOG("\n\n\n\nI'm here!\n\n");
	
	MSHookFunction(inet_addr, MSHake(inet_addr));
	%init;
}