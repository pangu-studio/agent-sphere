// Portions adapted from Starbox (GPL v3)
#pragma once

#include "manager/oidc_client.h"
#include "manager/oidc_token_store.h"

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <string>

// Show a modal login dialog that drives the OIDC browser-flow.
// On success writes *out_token and returns true.
// On cancel / error returns false (out_token is unchanged).
bool ShowLoginDialog(HWND parent, const manager::OidcConfig &config,
                     manager::OidcToken *out_token);