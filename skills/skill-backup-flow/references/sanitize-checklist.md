# Sanitize Checklist

Before commit:

- Remove real usernames, hostnames, phone numbers, serial numbers, PINs.
- Replace sensitive values in examples with placeholders.
- Ensure no private runtime config files are included.
- Check for token-like strings: api keys, bearer tokens, passwords.
- Confirm `.gitignore` blocks local config/secret files.
