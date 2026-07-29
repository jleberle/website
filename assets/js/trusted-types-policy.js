// Types every innerHTML assignment this site's own scripts make (footnote
// popovers, margin notes, the obfuscated mailto link) so Trusted Types can
// reject any string reaching innerHTML through code that isn't this file.
// createHTML below is a pass-through, not a sanitizer — see "Trusted Types"
// in docs/maintenance.md before piping any external/user-submitted content
// through this policy.
if (window.trustedTypes && trustedTypes.createPolicy) {
  trustedTypes.createPolicy('default', {
    createHTML: function (html) { return html; }
  });
}
