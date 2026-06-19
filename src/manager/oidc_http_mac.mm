// macOS HTTP GET helper for oidc_client.cpp (POSIX build).
// Uses NSURLSession synchronously on a background thread (never call from main thread).

#import <Foundation/Foundation.h>

#include <string>

bool OidcHttpGet_Mac(const std::string& url, std::string* body, std::string* error) {
    NSURL* nsurl = [NSURL URLWithString:[NSString stringWithUTF8String:url.c_str()]];
    if (!nsurl) {
        *error = "invalid URL";
        return false;
    }

    __block NSData* data = nil;
    __block NSError* err = nil;
    __block NSHTTPURLResponse* response = nil;

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    NSURLSessionDataTask* task = [[NSURLSession sharedSession]
        dataTaskWithURL:nsurl
        completionHandler:^(NSData* d, NSURLResponse* r, NSError* e) {
            data     = d;
            err      = e;
            response = (NSHTTPURLResponse*)r;
            dispatch_semaphore_signal(sem);
        }];
    [task resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 30LL * NSEC_PER_SEC));

    if (err) {
        *error = err.localizedDescription.UTF8String ?: "unknown error";
        return false;
    }
    if (!response || response.statusCode < 200 || response.statusCode >= 300) {
        *error = "HTTP " + std::to_string(response ? (int)response.statusCode : 0);
        return false;
    }
    if (data) {
        body->assign(reinterpret_cast<const char*>(data.bytes), data.length);
    }
    return true;
}