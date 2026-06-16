// Portions adapted from Starbox (GPL v3)
#include "manager/oidc_token_store.h"

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <wincred.h>

#include <nlohmann/json.hpp>

#include <string>
#include <vector>

namespace manager {

static const wchar_t *kCredTarget = L"AgentSphere/OidcToken";

bool OidcSaveToken(const OidcToken &token) {
  nlohmann::json j;
  j["access_token"] = token.access_token;
  j["refresh_token"] = token.refresh_token;
  j["expires_at"] = token.expires_at;
  if (!token.display_name.empty()) j["display_name"] = token.display_name;
  if (!token.email.empty()) j["email"] = token.email;
  std::string payload = j.dump();

  CREDENTIALW cred{};
  cred.Type = CRED_TYPE_GENERIC;
  cred.TargetName = const_cast<wchar_t *>(kCredTarget);
  cred.CredentialBlobSize = static_cast<DWORD>(payload.size());
  cred.CredentialBlob =
      reinterpret_cast<LPBYTE>(const_cast<char *>(payload.data()));
  cred.Persist = CRED_PERSIST_LOCAL_MACHINE;

  return CredWriteW(&cred, 0) == TRUE;
}

bool OidcLoadToken(OidcToken *token) {
  PCREDENTIALW cred = nullptr;
  if (!CredReadW(kCredTarget, CRED_TYPE_GENERIC, 0, &cred))
    return false;

  std::string payload(reinterpret_cast<const char *>(cred->CredentialBlob),
                      cred->CredentialBlobSize);
  CredFree(cred);

  try {
    auto j = nlohmann::json::parse(payload);
    token->access_token = j.value("access_token", "");
    token->refresh_token = j.value("refresh_token", "");
    token->expires_at = j.value("expires_at", int64_t{0});
    token->display_name = j.value("display_name", "");
    token->email = j.value("email", "");
  } catch (...) {
    return false;
  }
  return !token->access_token.empty();
}

void OidcClearToken() { CredDeleteW(kCredTarget, CRED_TYPE_GENERIC, 0); }

} // namespace manager