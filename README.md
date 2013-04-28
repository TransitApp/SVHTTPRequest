# SVHTTPRequest

SVHTTPRequest lets you easily interact with RESTful (GET, POST, DELETE, PUT) web APIs. It is blocked-based, uses `NSURLConnection`, ARC, as well as `NSJSONSerialization` to automatically parse JSON responses.

**SVHTTPRequest features:**

* class methods for quickly making `GET`, `POST`, `PUT`, `DELETE`, `HEAD` and download requests.
* completion block handler returning `response` (`NSObject` if JSON, otherwise `NSData`), `NSHTTPURLResponse` and `NSError` objects.
* persistent `basePath` and basic authentication signing when using `SVHTTPClient`.
* support for `multipart/form-data` parameters in POST and PUT requests.
* talks with the network activity indicator (iOS only).

## Installation

### From CocoaPods

Add `pod 'SVHTTPRequest'` to your Podfile or `pod 'SVHTTPRequest', :head` if you're feeling adventurous.

### Manually

_**If your project doesn't use ARC**: you must add the `-fobjc-arc` compiler flag to `SVHTTPRequest.m` and `SVHTTPClient.m` in Target Settings > Build Phases > Compile Sources._

* Drag the `SVHTTPRequest/SVHTTPRequest` folder into your project. 
* `#import "SVHTTPRequest.h"` (this will import `SVHTTPClient` as well)

## Usage

(see sample Xcode project in `/Demo`)

The easiest way to make a request is using the `SVHTTPRequest` convenience methods:

```objective-c
[SVHTTPRequest GET:@"https://api.github.com/repos/samvermette/SVHTTPRequest"
        parameters:nil
        completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
            watchersLabel.text = [NSString stringWithFormat:@"SVHTTPRequest has %@ watchers", [response valueForKey:@"watchers"]];
        }];
```

If most of your requests are made to the same API endpoint, you should instead use `SVHTTPClient` so you can set parameters (`basePath`, `cachePolicy`, `sendParametersAsJSON`, `"userAgent`) that will be used for each request:

```objective-c
[[SVHTTPClient sharedClient] setBasePath:@"http://api.twitter.com/1/"];

[[SVHTTPClient sharedClient] GET:@"users/show.json"
                      parameters:[NSDictionary dictionaryWithObject:@"samvermette" forKey:@"screen_name"]
                      completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
                          followersLabel.text = [NSString stringWithFormat:@"@samvermette has %@ followers", [response valueForKey:@"followers_count"]];
                      }];
```

You can have mutiple SVHTTPClient instances using the `sharedClientWithIdentifier:` method.

If you would like to set those properties on individual requests, you'll need to alloc/init the request, set the attributes, and then call `start`:

```objective-c
SVHTTPRequest *request = [[SVHTTPRequest alloc] initWithAddress:@"http://github.com/api/v2/json/repos/show/samvermette/SVHTTPRequest"
                                                         method:SVHTTPRequestMethodGET 
                                                     parameters:nil 
                                                     completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
                                                         watchersLabel.text = [NSString stringWithFormat:@"SVHTTPRequest has %@ watchers", [[response valueForKey:@"repository"] valueForKey:@"watchers"]];
                                                     }];
request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
[request start];
```


### Making a download request

You can tell SVHTTPRequest to save a GET response directly to disk and track the progress along the way:

```objective-c
[SVHTTPRequest GET:@"http://example.com/db.sqlite.zip" 
        parameters:nil 
        saveToPath:[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"store.zip"]
          progress:^(float progress) {
              progressLabel.text = [NSString stringWithFormat:@"Downloading (%.0f%%)", progress*100];
          } 
        completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
            progressLabel.text = @"Download complete";
            // process file
        }];
```
                        
### Cancelling requests

Make sure you cancel requests for which the user isn't waiting on anymore:

```objective-c
SVHTTPRequest *request = [SVHTTPRequest GET:@"http://api.twitter.com/1/users/show.json"
                                 parameters:[NSDictionary dictionaryWithObject:@"samvermette" forKey:@"screen_name"]
                                 completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
                                     NSLog(@"%@", response);
                                 }];
   
[request cancel];
```

If you're using SVHTTPClient, you can do that by calling `cancelRequestsWithPath:` or `cancelAllRequests`.

### Disabling logging

By default, SVHTTPRequest will log messages to the console every time a request is made. You can disable this by adding the compiler flag `-DSVHTTPREQUEST_DISABLE_LOGGING` to SVHTTPRequest.m in Target Settings > Build Phases.

## Under the hood

All SVHTTPRequest requests are made asynchronously using NSURLConnection's built-in asynchronous methods. The completion block, however, is executed on the main thread. You should dispatch it to a separate thread/queue if it's resource intensive enough that it hogs the main thread. This can be done easily using [Grand Central Dispatch](http://developer.apple.com/library/mac/#documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html):

```objective-c
completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        // cpu-intensive code
    });
}];
```

## Credits

SVHTTPRequest is brought to you by [Sam Vermette](http://samvermette.com) and [contributors to the project](https://github.com/samvermette/SVHTTPRequest/contributors). If you have feature suggestions or bug reports, feel free to help out by sending pull requests or by [creating new issues](https://github.com/samvermette/SVHTTPRequest/issues/new). If you're using SVHTTPRequest in your project, attribution would be nice.