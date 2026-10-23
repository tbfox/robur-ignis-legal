# Terms of Service hashes

Every row in `tosAgreement` stores two SHA-256 hashes:

| Column          | What it fingerprints                          | Same for everyone on a version? |
| --------------- | --------------------------------------------- | ------------------------------- |
| `tosHash`       | The text of the terms that were agreed to     | Yes                             |
| `agreementHash` | The agreement row itself, including `tosHash` | No                              |

`tosHash` proves which terms were agreed to. `agreementHash` makes the row
tamper-evident: change any covered column afterwards and hashing the row again
gives a different result.

Both are written as **64 lowercase hexadecimal characters**, with no prefix
(no `sha256:`) and no surrounding whitespace.

The hashes are computed and stored by `robur-ignis-admin`: see
`src/lib/tos.ts` (`fetchTosAtCommit`, `sha256Hex`) and
`src/services/TosService.ts` (`hashAgreement`, `recordAgreement`) there. This
copy lives with the terms so the format is on record next to them; the
original is `docs/tos-hashes.md` in `robur-ignis-admin`.

---

## 1. `tosHash`: the hash of the terms

### Where the input comes from

The terms live in this repo, [`tbfox/robur-ignis-legal`](https://github.com/tbfox/robur-ignis-legal),
under `agreements/coaching/`, which holds three files:

| File          | Contents                                              |
| ------------- | ----------------------------------------------------- |
| `version.txt` | The version, e.g. `v1.0` (usually with a trailing newline) |
| `TOS.md`      | The terms themselves                                  |
| `hash.sha256` | The expected hash, written by the legal repo          |

All three are read at the **same commit**: the full 40-character commit SHA that
the `/tos` page loaded. That commit is stored as `tosVersion.gitHash`, the first
time anyone agrees to that version.

### Exact bytes hashed

```
tosHash = lowercase_hex( SHA-256( bytes(version.txt) || bytes(TOS.md) ) )
```

- `||` means the two byte strings joined with **nothing in between**. No
  separator or newline is added.
- The bytes are the files **exactly as stored in git**, as served by
  `raw.githubusercontent.com`. Nothing is trimmed, decoded or normalized before
  hashing, so a trailing newline in `version.txt` is part of the input, and so
  is every line ending in `TOS.md`.
- `version.txt` comes first.

This matches this repo's own check (`check.sh`):

```sh
cat version.txt TOS.md | shasum -a 256
```

### How it's checked before saving

1. `hash.sha256` is decoded as UTF-8, trimmed of surrounding whitespace, and
   lowercased.
2. The hash computed above must equal it. If it doesn't, the terms fail their
   integrity check and nothing is saved. The `/tos` page also refuses agreement
   when this check fails.
3. The server repeats steps 1 and 2 itself at the commit the page reports. It
   doesn't trust the page's answer.
4. The version the page shows (`version.txt` decoded and trimmed) and the hash
   it shows must match what the server read. If either differs, the request is
   rejected with a 400.

The value stored in `tosHash` is the one from step 1, which steps 2 and 3 have
proven equal to the computed hash.

### Worked example

```sh
printf 'v1.0\n'   > version.txt
printf 'Terms.\n' > TOS.md
cat version.txt TOS.md | shasum -a 256
# 7ae7f71d209e35de94069288391a084a76096d80cdcd271467532df47b712c83
```

The bytes hashed are `v1.0\nTerms.\n` (12 bytes). Without the trailing newline
in `version.txt` the hash would be different.

---

## 2. `agreementHash`: the hash of the agreement row

### Exact bytes hashed

```
agreementHash = lowercase_hex( SHA-256( UTF-8( canonical ) ) )
```

where `canonical` is a **JSON array of exactly six elements, in this order**:

| # | Field            | JSON type | Exact value                                                     |
| - | ---------------- | --------- | --------------------------------------------------------------- |
| 0 | `name`           | string    | The name as submitted, trimmed (see below)                      |
| 1 | `email`          | string    | The email as submitted, trimmed and lowercased                  |
| 2 | `tosVersion`     | string    | `version.txt`, trimmed, e.g. `"v1.0"`                           |
| 3 | `checkboxFilled` | boolean   | Always `true`, since the server refuses `false`                 |
| 4 | `tosHash`        | string    | The 64-character lowercase hex value from section 1            |
| 5 | `agreedAt`       | string    | The timestamp in UTC as `YYYY-MM-DDTHH:mm:ss.sssZ` (see below) |

The array is serialized with JavaScript's `JSON.stringify`, which means:

- **No whitespace** anywhere: no space after `,`, no newlines, no indentation.
- Strings are wrapped in `"`. Inside them, `"` becomes `\"` and `\` becomes
  `\\`. The control characters U+0000 to U+001F become `\b`, `\f`, `\n`, `\r`,
  `\t` or `\u00XX` (lowercase hex). Lone surrogates become `\uDXXX`.
  Everything else is written as-is: non-ASCII characters such as `é` are
  **not** escaped to `é`, and `/` is not escaped.
- The boolean is the bare literal `true`, not the string `"true"` and not `1`.

The resulting string is encoded as **UTF-8 with no byte-order mark** and no
trailing newline, and that byte string is hashed.

Positions matter: the array is positional, with no keys, so reordering the
fields changes the hash.

### Field details

**`name`**: the submitted string with leading and trailing whitespace removed
(JavaScript `String.prototype.trim`, which also strips Unicode whitespace such
as non-breaking spaces). Inner whitespace and capitalization are kept, and no
Unicode normalization is applied: `é` typed as one code point (U+00E9) and as
`e` + U+0301 hash differently. It's the same string stored in the `name`
column.

**`email`**: trimmed as above, then lowercased with `toLowerCase()`. It's the
same string stored in the `email` column.

**`tosVersion`**: the same string stored in the `tosVersion` column and in
`tosVersion.tosVersion`.

**`agreedAt`**: set by the server (not the database) the moment before the row
is written, then formatted with JavaScript's `Date.prototype.toISOString()`:

- always UTC, always ending in `Z` (never `+00:00`)
- always exactly three digits of milliseconds, e.g. `2026-10-23T20:15:42.137Z`
  (a whole second is written `.000Z`)
- 24 characters long

The stored column holds the same instant. Postgres (`timestamptz`) and SQLite
(an ISO 8601 text column) both keep millisecond precision, so reading the row
back and calling `toISOString()` gives the same string again.

### Columns *not* covered

`id`, `tosId` and `agreementHash` itself are not part of the input. `tosId`
links to the same version that `tosVersion` names, and `tosHash` pins the
exact text.

### Worked example

Inputs, after trimming and lowercasing:

```
name           José "Pepe" Núñez
email          jose@example.com
tosVersion     v1.0
checkboxFilled true
tosHash        7ae7f71d209e35de94069288391a084a76096d80cdcd271467532df47b712c83
agreedAt       2026-10-23T20:15:42.137Z
```

Canonical string (one line, exactly as hashed):

```
["José \"Pepe\" Núñez","jose@example.com","v1.0",true,"7ae7f71d209e35de94069288391a084a76096d80cdcd271467532df47b712c83","2026-10-23T20:15:42.137Z"]
```

The first bytes show the UTF-8 encoding and the escaped quotes:

```
5b 22 4a 6f 73 c3 a9 20 5c 22 50 65 70 65 5c 22   ["José \"Pepe\"
20 4e c3 ba c3 b1 65 7a 22 2c ...                  Núñez",...
```

Result:

```
agreementHash = 1f5bf2e574036462a7eff387e421f8e4f05995b88ad52113eeb9f39ce1e38c12
```

To reproduce it from a shell:

```sh
printf '%s' '["José \"Pepe\" Núñez","jose@example.com","v1.0",true,"7ae7f71d209e35de94069288391a084a76096d80cdcd271467532df47b712c83","2026-10-23T20:15:42.137Z"]' \
  | shasum -a 256
```

(`printf '%s'` leaves out the trailing newline that `echo` would add.)

---

## Verifying a saved row

1. Read the row's `name`, `email`, `tosVersion`, `checkboxFilled`, `tosHash`
   and `agreedAt`.
2. Rebuild the canonical array from them, with `agreedAt` formatted as above,
   and hash it. The result must equal `agreementHash`.
3. To confirm `tosHash` itself, look up the row's `tosVersion.gitHash`, fetch
   `version.txt` and `TOS.md` at that commit, and hash them as in section 1.
   This only holds if the version's text didn't change in a later commit
   without a version bump: a version stays pinned to the first commit anyone
   agreed to it at.

In `robur-ignis-admin`, step 2 is:

```ts
import { hashAgreement } from "@/services/TosService";

const ok = (await hashAgreement(row)) === row.agreementHash;
```

### What this does and doesn't prove

A match shows that the covered columns haven't changed since the hash was
written. It doesn't prove the row was written by this server: anyone who can
edit the table can also compute a new hash, since nothing here is secret.

### Rows from before migration 019

Agreements saved before `019_add_tos_hash_to_tos_agreement` stored the terms
hash in `agreementHash`. The migration copied that value into `tosHash`, so for
those rows `agreementHash = tosHash`, and step 2 above will not match.
