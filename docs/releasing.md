# Releasing Lamina

For maintainers. TASK-29 moves releases and the update feed to GitHub Releases (decision-3); until then this still
describes the R2 bucket the tooling inherited.

Files go to the `lamina/` folder of the downloads bucket (downloads.itsjavi.com), like the other apps.

```bash
make release                  # build/release: Lamina.app, zip, DMG, SHA256SUMS
make appcast                  # signs the zip, writes build/appcast/appcast.xml
make bump V=patch PUSH=1      # bump VERSION, tag vX.Y.Z on main, push → release workflow
```

`make release` signs and notarizes when `DEVELOPER_ID` and `NOTARY_PROFILE` are set (see `scripts/release.sh`);
otherwise it builds ad-hoc and lists what's missing.

Sparkle's private EdDSA key lives in the login Keychain under the account `lamina` (never in the repo); the public
key is `Resources/SparklePublicKey.txt`. Create them once with:

```bash
swift package resolve && .build/artifacts/sparkle/Sparkle/bin/generate_keys --account lamina
```

and save the printed public key to `Resources/SparklePublicKey.txt`. Back the private key up (and export it for CI)
with `generate_keys --account lamina -x lamina-sparkle.key`. Losing it means installed copies can't accept
updates signed with a new key. `make appcast` refuses a key that doesn't match the app's public key. Upload the zip
first, then `appcast.xml`.

CI (`.github/workflows/`): `ci.yml` runs the tests; `release.yml` runs on `vX.Y.Z` tags and uses these optional secrets
in a `release` environment: `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`, `APPLE_ID`, `APPLE_APP_PASSWORD`,
`APPLE_TEAM_ID`, `SPARKLE_PRIVATE_KEY`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`.
