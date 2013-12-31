//
//  JCSubscriptionManagerConfigs.h
//  SubscriptionManager
//
//  Created by Joseph Chen on 11/23/13.
//  Copyright (c) 2013 Joseph Chen. All rights reserved.
//

// Should debug/sandbox settings be used?
#ifndef SANDBOX_MODE
#if DEBUG
#define SANDBOX_MODE YES
#else
#define SANDBOX_MODE NO
#endif
#endif

// Your receipt verification server.
#warning Edit to correct URL.
#ifndef OWN_VERIFICATION_SERVER
#define OWN_VERIFICATION_SERVER @"https://www.yourserver.com/verifyReceipt.php"
#endif

// Apple's server is used to verify receipt if your server is down.
#ifndef APPLE_VERIFICATION_SERVER
#if DEBUG
#define APPLE_VERIFICATION_SERVER @"https://sandbox.itunes.apple.com/verifyReceipt" // Test server.
#else
#define APPLE_VERIFICATION_SERVER @"https://buy.itunes.apple.com/verifyReceipt" // Production server.
#endif
#endif

// This is your shared secret for autorenewable subscriptions on iTunesConnect.
#warning Set to your app's shared secret.
#ifndef AUTORENEWABLE_SUBSCRIPTION_SHARED_SECRET
#define AUTORENEWABLE_SUBSCRIPTION_SHARED_SECRET @""
#endif

