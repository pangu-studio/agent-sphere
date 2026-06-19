#include "manager/oidc_token_store.h"

#import <Foundation/Foundation.h>
#import <Security/Security.h>

// JSON serialisation (header-only, already in the project)
#include <nlohmann/json.hpp>

namespace manager {

static NSString* const kService = @"ai.AgentSphere.app";
static NSString* const kAccount = @"oidc_token";

bool OidcSaveToken(const OidcToken& token) {
    nlohmann::json j;
    j["access_token"]  = token.access_token;
    j["refresh_token"] = token.refresh_token;
    j["expires_at"]    = token.expires_at;
    std::string payload = j.dump();

    NSData* data = [NSData dataWithBytes:payload.data() length:payload.size()];

    // Delete any existing item first.
    NSDictionary* del = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kService,
        (__bridge id)kSecAttrAccount: kAccount,
    };
    SecItemDelete((__bridge CFDictionaryRef)del);

    NSDictionary* add = @{
        (__bridge id)kSecClass:           (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:     kService,
        (__bridge id)kSecAttrAccount:     kAccount,
        (__bridge id)kSecValueData:       data,
        (__bridge id)kSecAttrAccessible:  (__bridge id)kSecAttrAccessibleAfterFirstUnlock,
    };
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)add, nullptr);
    return status == errSecSuccess;
}

bool OidcLoadToken(OidcToken* token) {
    NSDictionary* query = @{
        (__bridge id)kSecClass:            (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:      kService,
        (__bridge id)kSecAttrAccount:      kAccount,
        (__bridge id)kSecReturnData:       @YES,
        (__bridge id)kSecMatchLimit:       (__bridge id)kSecMatchLimitOne,
    };

    CFTypeRef result = nullptr;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || !result) return false;

    NSData* data = (__bridge_transfer NSData*)result;
    std::string payload(reinterpret_cast<const char*>(data.bytes), data.length);

    try {
        auto j = nlohmann::json::parse(payload);
        token->access_token  = j.value("access_token",  "");
        token->refresh_token = j.value("refresh_token", "");
        token->expires_at    = j.value("expires_at",    int64_t{0});
    } catch (...) {
        return false;
    }
    return !token->access_token.empty();
}

void OidcClearToken() {
    NSDictionary* del = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kService,
        (__bridge id)kSecAttrAccount: kAccount,
    };
    SecItemDelete((__bridge CFDictionaryRef)del);
}

}  // namespace manager