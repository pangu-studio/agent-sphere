#pragma once

#include <cstdint>
#include <string>

namespace manager {

struct OidcToken {
    std::string access_token;
    std::string refresh_token;  // may be empty
    int64_t expires_at = 0;     // unix timestamp (seconds); 0 = unknown
    // User info (from JWT payload or /api/auth/me)
    std::string display_name;   // name > preferred_username > sub
    std::string email;
};

// Platform-specific persistent token storage.
// Implementations: oidc_token_store_mac.mm, oidc_token_store_win.cpp
bool OidcSaveToken(const OidcToken& token);
bool OidcLoadToken(OidcToken* token);
void OidcClearToken();

}  // namespace manager