/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "nsShellService.h"
#include "nsString.h"

#include "GeneratedJNIWrappers.h"

using namespace mozilla;

NS_IMPL_ISUPPORTS(nsShellService, nsIShellService)

NS_IMETHODIMP
nsShellService::SwitchTask()
{
  return NS_ERROR_NOT_IMPLEMENTED;
}

NS_IMETHODIMP
nsShellService::CreateShortcut(const nsAString& aTitle, const nsAString& aURI,
                                const nsAString& aIcondata, const nsAString& aIntent)
{
  if (!aTitle.Length() || !aURI.Length())
    return NS_ERROR_FAILURE;

  java::GeckoAppShell::CreateShortcut(aTitle, aURI);
  return NS_OK;
}

// Desktop nsIShellService surface (used by the palemoon/ chrome):
// no desktop shell to control on Android, so these are stubs.

NS_IMETHODIMP
nsShellService::IsDefaultBrowser(bool aStartupCheck, bool aForAllTypes,
                                 bool* aIsDefaultBrowser)
{
  *aIsDefaultBrowser = false;
  return NS_OK;
}

NS_IMETHODIMP
nsShellService::SetDefaultBrowser(bool aClaimAllTypes, bool aForAllUsers)
{
  return NS_OK;
}

NS_IMETHODIMP
nsShellService::SetDesktopBackground(nsIDOMElement* aElement, int32_t aPosition)
{
  return NS_ERROR_NOT_IMPLEMENTED;
}

NS_IMETHODIMP
nsShellService::OpenApplication(int32_t aApplication)
{
  return NS_ERROR_NOT_IMPLEMENTED;
}

NS_IMETHODIMP
nsShellService::GetDesktopBackgroundColor(uint32_t* aDesktopBackgroundColor)
{
  *aDesktopBackgroundColor = 0;
  return NS_OK;
}

NS_IMETHODIMP
nsShellService::SetDesktopBackgroundColor(uint32_t aDesktopBackgroundColor)
{
  return NS_OK;
}

NS_IMETHODIMP
nsShellService::OpenApplicationWithURI(nsIFile* aApplication,
                                       const nsACString& aURI)
{
  return NS_ERROR_NOT_IMPLEMENTED;
}

NS_IMETHODIMP
nsShellService::GetDefaultFeedReader(nsIFile** aDefaultFeedReader)
{
  *aDefaultFeedReader = nullptr;
  return NS_OK;
}
