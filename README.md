# hsp-spec

# Introduction

# Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in [RFC 2119](https://tools.ietf.org/html/rfc2119).

# Protocol Overview

The HSP is a simple bidirectional stream based protocol to transmit messages
between two connected peers.

# Data Types

## VarInt

The *VarInt* (variable length integer) type encodes unsigned integers
into sequences of bytes.  Each integer has exactly one encoding.

The integer is split into groups of seven bits. Each group makes up the lower
seven bits of a byte, least significant group first. The most significant bit
of each byte is set if and only if more bytes follow.

To make the encoding unambigious, the last byte MUST NOT be zero, unless it
is the only byte in the encoding (i.e. the encoding of the value zero). There
must be at least one byte in the encoding.

The application SHOULD impose a maximum value to avoid integer and buffer
overflows.

The *VarInt* has the same encoding as the Google protobuf "Base 128 Varint":

<https://developers.google.com/protocol-buffers/docs/encoding#varints>


**Examples:**

|      Decimal | VarInt (hex)       |
|  ----------: | :----------------- |
|          `0` | `00`               |
|          `1` | `01`               |
|        `127` | `7f`               |
|        `128` | `80 01`            |
|        `129` | `81 01`            |
|    `1936442` | `ba 98 76`         |
|  `165580141` | `ed 9a fa 4e`      |
| `4294967295` | `ff ff ff ff 0f`   |

## ByteArray

A *ByteArray* is just an array of bytes.  The meaning of those bytes is defined
by the application.  The application SHOULD impose a maximum length to avoid
utilizing too much memory while receiving.

~~~
+--------+------+
| Length | Data |
+--------+------+
~~~

  * *Length* (*VarInt*): Number of bytes in *Data*.
  * *Data*: Arbitrary bytes.

# Protocol

Each peer sends a sequence of messages to the other peer.  The general
structure of each message is:

~~~
+---------+-------------------
| Command | Variable Part
+---------+-------------------
~~~

The *command* is a VarInt. The *variable part* depends on the *command*.

# Commands

| Value | Command       | Description                                                 |
| ----: | :------------ | :---------------------------------------------------------- |
|     0 | `DATA`        | Send data, don't expect acknowledgement                     |
|     1 | `DATA_ACK`    | Send data, expect `ACK` or `ERROR` in return                |
|     2 | `ACK`         | Acknowledge a previous `DATA_ACK`                           |
|     3 | `ERROR`       | Previous `DATA_ACK` could not be processed; with error msg  |
|     4 | `PING`        | Expect `PONG` in return                                     |
|     5 | `PONG`        | Response to `PING`                                          |
|     6 | `ERROR_UNDEF` | Previous `DATA_ACK` could not be processed; unknown error   |

## DATA

Send data to the peer.  This has fire-and-forget semantics.  If the peer doesn't
receive the message (e.g. due to connection loss) or cannot process it for
whatever reason, the sender will never know.

The sender SHOULD NOT try to guess if the recipient got a message by looking for
example at TCP ACKs as those cannot be trusted even if TLS is used.

~~~
+---+------+---------+
| 0 | Type | Payload |
+---+------+---------+
~~~

  * *Type* (*VarInt*): Valid values are specified by the application.  The
    *Type* defines the format of the *Payload*.
  * *Payload* (*ByteArray*): Arbitrary data.


## DATA\_ACK

Send data to the peer.  Each such message MUST eventually be acknowledged by
the recipient, either with an `ACK`, an `ERROR` or an `ERROR_UNDEF`.  If multiple `DATA_ACK`
messages are sent, the responses MAY arrive in different order.  If the
connection is lost before a response is received, the sender SHOULD
assume that the recipient did not receive it and MAY try to send it again after
it reconnected.

~~~
+---+-----------+------+---------+
| 1 | MessageID | Type | Payload |
+---+-----------+------+---------+
~~~

  * *MessageID* (*VarInt*): The *MessageID* is used to correlate messages to their
    Acknowledges or Errors.  They are defined by the sender of the message and
    can be arbitrary numbers.  The same *MessageID* MUST only be reused once an
    response was received for it.  The recipient SHOULD allow at least
    128 bits for the *MessageID* to support UUIDs.
  * *Type* (*VarInt*): Valid values are specified by the application.  The
    *Type* defines the format of the *Payload*.
  * *Payload* (*ByteArray*): Arbitrary data.

## ACK

Acknowledge that a `DATA_ACK` was received and processed successfully.

~~~
+---+-----------+
| 2 | MessageID |
+---+-----------+
~~~

  * *MessageID* (*VarInt*): The *MessageID* of a previously received `DATA_ACK`.

## ERROR\_UNDEF

Acknowledge that a `DATA_ACK` was received but could not be processed.

~~~
+---+-----------+------+---------+
| 3 | MessageID | Type | Payload |
+---+-----------+------+---------+
~~~

  * *MessageID* (*VarInt*): The *MessageID* of a previously received `DATA_ACK`.
  * *Type* (*VarInt*): Application defined error code, meant for automatic
    processing by machines.  The *Type* defines the format of the *Payload*.
  * *Payload* (*ByteArray*): Error details. Can be arbitrary data.

## PING

Request a `PONG` from the receipient.  For each `PING` received, exactly one
`PONG` MUST be sent.

~~~
+---+
| 4 |
+---+
~~~

## PONG

Acknowledge a `PING`.

~~~
+---+
| 5 |
+---+
~~~

## ERROR\_UNDEF

Acknowledge that a `DATA_ACK` was received but could not be processed.
The reason for the error is not defined.

~~~
+---+-----------+
| 6 | MessageID |
+---+-----------+
~~~

  * *MessageID* (*VarInt*): The *MessageID* of a previously received `DATA_ACK`.


# Security Considerations 

Is is strongly recommended to use a secure transport layer such as TLS.

## Authentication

Authentication is optional and defined by the application.  For example, Client
Certificates on a TLS connection may be used or the application can define
message types to implement authentication.
