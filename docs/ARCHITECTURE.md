# MoonArrow architecture

MoonArrow follows the same dependency direction as a production columnar
engine. Lower layers know nothing about schemas, record batches, or user
interfaces.

```text
types      bitmap
   \         /
      array
        |           flatbuffer
     compute             |
        |               ipc
  record_batch <---------+
        |
    dataframe
        |
 CLI / JS / Wasm adapters
```

## Invariants

- Validity and boolean buffers use Arrow's least-significant-bit-first layout.
- Nullable primitive arrays store a physical value for every logical slot.
- UTF-8 arrays use 32-bit-style offsets plus one contiguous byte buffer.
- A record batch has one schema field per column and equal column lengths.
- Non-nullable fields reject columns containing nulls.
- Compute kernels propagate input nulls; null filter predicates select no row.

## IPC boundary

IPC is a separate layer rather than an ad-hoc serializer inside the arrays. The
reader first validates message framing, then interprets FlatBuffers metadata,
then validates every field node and body buffer before constructing arrays. It
does not expose unchecked offsets to higher layers.

The current reader supports flat `Boolean`, `Int32`, `Int64`, `Float64`, `Utf8`,
and `Binary` schemas. A committed PyArrow-produced fixture verifies schema
order, null semantics, boolean bit packing, variable-width offsets, integer
widths, binary payloads, and floating-point body decoding independently of
MoonArrow. Decoded primitive values are materialized into MoonBit arrays; the
current MVP does not claim zero-copy Arrow C Data Interface compatibility.

## Error model

Malformed input and unsupported-but-valid Arrow features are kept distinct.
`IpcError` reports truncated envelopes, invalid tables, offsets and validity
buffers separately from unsupported types, nested fields, dictionary encoding,
and big-endian schemas. This is important for safely accepting untrusted data
and for extending format coverage without weakening validation.
