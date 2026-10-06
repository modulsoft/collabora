/* -*- js-indent-level: 8 -*- */
/*
 * OpenBP Docs branding.
 *
 * SPDX-License-Identifier: MPL-2.0
 *
 * coolwsd injects this file into every page after global.js, so the globals
 * below win over the server-side defaults.
 */

var brandProductName = 'OpenBP Docs';
var brandProductURL = 'https://openbp.io';
var brandProductFAQURL = 'https://openbp.io';

// The runtime binaries are the upstream development-edition build, which
// forces the welcome dialog, feedback popups and update notices on. This
// script runs after global.js has read those flags from the page and before
// the deferred bundle.js uses them, so switch them off here.
window.enableWelcomeMessage = false;
window.autoShowWelcome = false;
window.autoShowFeedback = false;
window.allowUpdateNotification = false;

(function () {
	// The document header logo is a link to brandProductURL. Keep users in
	// the editor: show the product name as tooltip, open the site in a new tab.
	function setLogo() {
		var logo = document.querySelector('#document-header > a');
		if (!logo) {
			setTimeout(setLogo, 250);
			return;
		}
		logo.setAttribute('data-cooltip', brandProductName);
		logo.setAttribute('href', brandProductURL);
		logo.setAttribute('target', '_blank');
		logo.setAttribute('rel', 'noopener');
	}

	if (document.readyState === 'loading')
		document.addEventListener('DOMContentLoaded', setLogo);
	else
		setLogo();
})();
