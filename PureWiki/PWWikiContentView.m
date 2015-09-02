/*=============================================================================┐
|             _  _  _       _                                                  |  
|            (_)(_)(_)     | |                            _                    |██
|             _  _  _ _____| | ____ ___  ____  _____    _| |_ ___              |██
|            | || || | ___ | |/ ___) _ \|    \| ___ |  (_   _) _ \             |██
|            | || || | ____| ( (__| |_| | | | | ____|    | || |_| |            |██
|             \_____/|_____)\_)____)___/|_|_|_|_____)     \__)___/             |██
|                                                                              |██
|                 ______                   _  _  _ _ _     _ _                 |██
|                (_____ \                 (_)(_)(_|_) |   (_) |                |██
|                 _____) )   _  ____ _____ _  _  _ _| |  _ _| |                |██
|                |  ____/ | | |/ ___) ___ | || || | | |_/ ) |_|                |██
|                | |    | |_| | |   | ____| || || | |  _ (| |_                 |██
|                |_|    |____/|_|   |_____)\_____/|_|_| \_)_|_|                |██
|                                                                              |██
|                                                                              |██
|                         Copyright (c) 2015 Tong Kuo                          |██
|                                                                              |██
|                             ALL RIGHTS RESERVED.                             |██
|                                                                              |██
└==============================================================================┘██
  ████████████████████████████████████████████████████████████████████████████████
  ██████████████████████████████████████████████████████████████████████████████*/

#import "PWWikiContentView.h"
#import "PWCastrateFactory.h"
#import "PWStackContainerView.h"
#import "PWNavButtonsPairView.h"
#import "PWActionNotifications.h"
#import "PWWikiPageArchive.h"
#import "PWUtilities.h"
#import "PWWikiPageBackForwardList.h"
#import "PWOpenedWikiPage.h"

#import "WikiPage.h"
#import "WikiEngine.h"

// Private Interfaces
@interface PWWikiContentView ()
@end // Private Interfaces

// PWWikiContentView class
@implementation PWWikiContentView

@dynamic wikiPage;
@synthesize owner;

@dynamic UUID;

#pragma mark Initializations
- ( instancetype ) initWithCoder: ( nonnull NSCoder* )_Coder
    {
    if ( self = [ super initWithCoder: _Coder ] )
        {
        self->_wikiEngine = [ WikiEngine engineWithISOLanguageCode: @"en" ];

        self->_backForwardList = [ [ PWWikiPageBackForwardList alloc ] init ];
        self->_backingWebView = [ [ WebView alloc ] initWithFrame: NSMakeRect( 0.f, 0.f, 1.f, 1.f ) frameName: nil groupName: nil ];
        self->_UUID = [ @"🐠" stringByAppendingString: PWNonce() ];
        }

    return self;
    }

- ( void ) awakeFromNib
    {
    [ self->_backingWebView setFrameLoadDelegate: self ];
    [ self->_backingWebView setMaintainsBackForwardList: NO ];

    [ self.webView setPolicyDelegate: self ];
    [ self.webView setFrameLoadDelegate: self ];
    }

#pragma mark Dynamic Properties
- ( void ) setWikiPage: ( WikiPage* )_WikiPage
    {
    [ self->_backingWebView.mainFrame stopLoading ];

    NSURLRequest* request = [ NSURLRequest requestWithURL: _WikiPage.URL ];
    [ self->_backingWebView.mainFrame loadRequest: request ];
    }

- ( WikiPage* ) wikiPage
    {
    return [ ( PWOpenedWikiPage* )( self->_backForwardList.currentItem ) openedWikiPage ];
    }

- ( NSString* ) UUID
    {
    return self->_UUID;
    }

#pragma mark IBActions
- ( IBAction ) goBackAction: ( id )_Sender
    {
    [ self.webView goBack: _Sender ];
    [ self->_backForwardList goBack ];

    #if DEBUG
    NSLog( @">>> (Log:%s) 🐏:\n{%@\nvs.\n%@}", __PRETTY_FUNCTION__
         , self.webView.backForwardList
         , self->_backForwardList
         );
    #endif
    }

- ( IBAction ) goForwardAction: ( id )_Sender
    {
    [ self.webView goForward: _Sender ];
    [ self->_backForwardList goForward ];

    #if DEBUG
    NSLog( @">>> (Log:%s) 🐏:\n{%@\nvs.\n%@}", __PRETTY_FUNCTION__
         , self.webView.backForwardList
         , self->_backForwardList
         );
    #endif
    }

#pragma mark Conforms to <WebFrameLoadDelegate>
//- ( void )        webView: ( WebView* )_WebView
//    didCommitLoadForFrame: ( WebFrame* )_Frame
//    {
//    if ( _WebView == self.webView )
//        NSLog( @"🍇%@", self.webView.backForwardList );
//    }

- ( void )        webView: ( WebView* )_WebView
    didFinishLoadForFrame: ( WebFrame* )_Frame
    {
    NSError* error = nil;

    if ( _Frame == [ _WebView mainFrame ] )
        {
        if ( _WebView == self->_backingWebView )
            {
            PWWikiPageArchive* castratedWikiPageArchive = nil;

            NSURL* archiveURL =
                [ [ PWCastrateFactory defaultFactory ] castrateFrameOnDisk: _Frame error: &error archive: &castratedWikiPageArchive ];

            if ( !error )
                {
                [ self->_wikiEngine searchAllPagesThatHaveValue: castratedWikiPageArchive.wikiPageTitle
                                                   inNamespaces: nil
                                                           what: WikiEngineSearchWhatPageText
                                                          limit: 1
                                                        success:
                    ^( NSArray* _MatchedPages )
                        {
                        if ( _MatchedPages )
                            {
//                            NSLog( @"%@", _Frame.dataSource.response );
//                            NSLog( @"%@", self.webView.backForwardList );
                            NSLog( @"🍇%@", archiveURL );
                            [ self.webView.mainFrame loadRequest: [ NSURLRequest requestWithURL: archiveURL ] ];
//                            NSLog( @"%@", self.webView.backForwardList );

                            // Resume routing navigation action
                            [ self.webView setPolicyDelegate: self ];

                            PWOpenedWikiPage* openedWikiPage =
                                [ PWOpenedWikiPage openedWikiPageWithHostContentViewUUID: self.UUID openedWikiPage: _MatchedPages.firstObject ];

                            [ self->_backForwardList addItem: openedWikiPage ];
                            }
                        } failure:
                            ^( NSError* _Error )
                                {
                                NSLog( @"%@", _Error );
                                } stopAllOtherTasks: YES ];
                }
            else
                NSLog( @"%@", error );
            }

        else if ( _WebView == self.webView )
            {
            [ self.owner.navButtonsPairView reload ];
            [ self.webView setPolicyDelegate: self ];

            #if DEBUG
            NSLog( @">>> (Log:%s) 🌰Current back-forward list:\n{%@\nvs.\n%@}", __PRETTY_FUNCTION__
                 , self.webView.backForwardList
                 , self->_backForwardList
                 );

            WebHistoryItem* currentItem = self.webView.backForwardList.currentItem;
            NSLog( @">>> (Info) 🍉Current back-forward item: %@"
                 , @{ @"URL" : currentItem.URLString ?: [ NSNull null ]
                    , @"Original URL" : currentItem.originalURLString ?: [ NSNull null ]
                    , @"Title" : currentItem.title ?: [ NSNull null ]
                    , @"Alternate Title" : currentItem.alternateTitle ?: [ NSNull null ]
                    , @"Last Visited Time Interval" : @( currentItem.lastVisitedTimeInterval )
                    }
                 );
            #endif
            }
        }
    }

#pragma mark Conforms to <WebPolicyDelegate>

// Routes all the navigation action that occured in self.webView
- ( void )                  webView: ( WebView* )_WebView
    decidePolicyForNavigationAction: ( NSDictionary* )_ActionInformation
                            request: ( NSURLRequest* )_Request
                              frame: ( WebFrame* )_Frame
                   decisionListener: ( id <WebPolicyDecisionListener> )_Listener
    {
    if ( _WebView == self.webView )
        {
        // Pause routing navigation action to avoid the infinite recursion
        [ self.webView setPolicyDelegate: nil ];

        if ( [ _Request.URL.scheme isEqualToString: @"file" ] )
            [ _Listener use ];
        else
            {
            [ self->_backingWebView.mainFrame loadRequest: _Request ];
            [ _Listener ignore ];
            }
        }
    }

@end // PWWikiContentView class

/*===============================================================================┐
|                                                                                | 
|                      ++++++     =++++~     +++=     =+++                       | 
|                        +++,       +++      =+        ++                        | 
|                        =+++       ~+++     +        =+                         | 
|                         +++=       =++=   +=        +                          | 
|                          +++        +++= +=        +=                          | 
|                          =+++        ++++=        =+                           | 
|                           +++=       =+++         +                            | 
|                            +++~       +++=       +=                            | 
|                            ,+++      ~++++=     ==                             | 
|                             ++++     +  +++     +                              | 
|                              +++=   +   ~+++   +,                              | 
|                               +++  +:    =+++ ==                               | 
|                               =++++=      +++++                                | 
|                                +++=        +++                                 | 
|                                 ++          +=                                 | 
|                                                                                | 
└===============================================================================*/