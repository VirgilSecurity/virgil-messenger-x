//
//  TwilioAccessManager.h
//  TwilioAccessManager
//
//  Copyright (c) 2017 Twilio, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

/** Block that will be called when a new token is set.  Useful to update client instances. */
typedef void (^TAMUpdateBlock)(NSString *_Nonnull updatedToken);

@protocol TwilioAccessManagerDelegate;

/** Helper library to manage access token life cycle events. */
@interface TwilioAccessManager : NSObject

/** Delegate which will receive events related to access token expiry. */
@property (nonatomic, assign, nonnull) id<TwilioAccessManagerDelegate> delegate;

/** The current token in use. */
@property (nonatomic, strong, readonly, nullable) NSString *currentToken;

/** The current token's expiration time. */
@property (nonatomic, strong, readonly, nullable) NSDate *expiryTime;

/** Create a new access manager instance with the specified initial token and delegate. 
 
 @param token String based access token.
 @param delegate Delegate to receive lifecycle events.
 @return The new TwilioAccessManager instance.
 */
+ (nullable instancetype)accessManagerWithToken:(nonnull NSString *)token
                                       delegate:(nonnull id<TwilioAccessManagerDelegate>)delegate;

/* Direct instantiation is not supported, please use convenience method. */
- (nonnull instancetype) init __attribute__((unavailable("please use accessManagerWithToken:delegate: to construct instead")));

/** Returns the version of the helper
 
 @return The access manager version.
 */
- (nonnull NSString *)version;

/** Terminates all timers and releases any associated listeners. */
- (void)shutdown;

/** Registers a new listener to receive token updates.  This block should maintain a reference
 to the client(s) you wish to keep updated.  You may have one or more listeners for a given
 access manager.
 
 An important note around strong/weak references here.  The client identifier should be a STRONGly
 held object, for instance the Twilio client sdk instance this update listener is for.  This allows
 access manager to stop sending updates to this client when it goes out of scope.
 
 By contrast, any references to your clients within the update block should be WEAK to avoid
 retain loops which will keep not only your client but this listener in scope until manually removed.
 For example, the recommended way to use this method is:
 
     TwilioAccessManager *accessManager = [TwilioAccessManager accessManagerWithToken:INIITAL_TOKEN_GOES_HERE delegate:self];
     TwilioExampleClient *client = [TwilioExampleClient clientWithToken:accessManager.currentToken];
     __weak typeof(client) weakClient = client;
     [accessManager registerClient:client forUpdates:^(NSString *updatedToken) {
         [weakClient updateToken:updatedToken];
     }];
 
 @param client A key to uniquely identify this listener for later removal.  Can be the client you wish to update or anything else strongly held by your code.  When 'client' goes out of scope, so will the listener.
 @param updateBlock The update block that will be called when a new token arrives.
 */
- (void)registerClient:(nonnull id)client forUpdates:(nonnull TAMUpdateBlock)updateBlock;

/** Unregisters the specified client from token updates.
 
 @param client The key that uniquely identifies the listener for removal.
 */
- (void)unregisterClient:(nonnull id)client;

/** Update the token for this access manager and notify registered listeners.
 
 @param token The new access token.
 */
- (void)updateToken:(nonnull NSString *)token;

@end

/** 
 The TwilioAccessManagerDelegate will let your application know when tokens are either
 about to expire or have already expired.
 
 The accessManagerTokenWillExpire: delegate method will be called 3 minutes prior to token expiry or
 immediately if the token is already expired.
 
 The accessManagerTokenExpired: delegate method will be called upon token expiry or immediately
 if the token is already expired.
 
 It is usually best to implement just one of these methods, with the accessManagerTokenWillExpire:
 method being the recommended as it allows your client SDK's to update their access token before
 an interruption in communication with Twilio may occur.
 */
@protocol TwilioAccessManagerDelegate <NSObject>
@optional

/** Called when the access token is within 3 minutes of expiring.
 
 @param accessManager The access manager instance that needs to be updated.
 */
- (void)accessManagerTokenWillExpire:(nonnull TwilioAccessManager *)accessManager;

/** Called when the access token has expired.  May be called after expiry if the application
 was in backgrounded at the time of expiration.
 
 @param accessManager The access manager instance that needs to be updated.
 */
- (void)accessManagerTokenExpired:(nonnull TwilioAccessManager *)accessManager;

/** Called if an access token is provided that is in an invalid format.
 
 @param accessManager The access manager instance that experienced the error.
 */
- (void)accessManagerTokenInvalid:(nonnull TwilioAccessManager *)accessManager;
@end
