# Introduction

HSP is a simple bidirectional stream based protocol to transmit messages
between two connected peers. Messages carry a message type and received message can
be acknowledged or rejected with an error.

# Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in [RFC 2119](https://tools.ietf.org/html/rfc2119) and
[RFC 8174](https://tools.ietf.org/html/rfc8174).

# Data Types

HSP defines two basic data types, Integers and Byte Arrays:

## Integers

Three integer types are defined:

  * *1-Byte*: 8 bit unsigned integer
  * *2-Byte*: 16 bit unsigned integer
  * *4-Byte*: 32 bit unsigned integer

### Signedness

All key-fields MUST be represented unsigned.

### Byte Order

The byte-order of all key-fields MUST be Big-Endian. Byte-order of
payload-fields are defined by the application.

## ByteArray

A *ByteArray* is just an array of bytes.  The meaning of those bytes is defined
by the application. The application MAY also restrict the maximum length to avoid
utilizing too much memory while receiving but MUST NOT reduce the defined size of the
*Length*-field.

~~~
+--------+------+
| Length | Data |
+--------+------+
~~~

  * *Length*: 4-Byte.
  * *Data*: Arbitrary bytes.

# Protocol

Each peer sends a sequence of messages to the other peer.  The general
structure of each message is:

~~~
+---------+-------------------
| Command | Variable Part
+---------+-------------------
~~~

The *command* is represented by 1-Byte. The *variable part* depends on the *command*.

# Commands

| Value | Command       | Description                                                 |
| ----: | :------------ | :---------------------------------------------------------- |
|     0 | `DATA`        | Send data, don't expect acknowledgement                     |
|     1 | `DATA_ACK`    | Send data, expect `ACK` or `ERROR` in return                |
|     2 | `ACK`         | Acknowledge a previous `DATA_ACK`                           |
|     3 | `PING`        | Expect `PONG` in return                                     |
|     4 | `PONG`        | Response to `PING`                                          |
|     5 | `ERROR`       | Previous `DATA_ACK` could not be processed; with error msg  |
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

  * *Type* (2-Byte): Valid values are specified by the application.  The
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

  * *MessageID* (4-Byte): The *MessageID* is used to correlate messages to their
    Acknowledges or Errors.  They are defined by the sender of the message and
    can be arbitrary numbers.  The same *MessageID* MUST only be reused once a
    response was received for it.
  * *Type* (2-Byte): Valid values are specified by the application.  The
    *Type* defines the format of the *Payload*.
  * *Payload* (*ByteArray*): Arbitrary data.

## ACK

Acknowledge that a `DATA_ACK` was received and processed successfully.

~~~
+---+-----------+
| 2 | MessageID |
+---+-----------+
~~~

  * *MessageID* (4-Byte): The *MessageID* of a previously received `DATA_ACK`.

## PING

Request a `PONG` from the receipient.  For each `PING` received, exactly one
`PONG` MUST be sent.

~~~
+---+
| 3 |
+---+
~~~

## PONG

Acknowledge a `PING`.

~~~
+---+
| 4 |
+---+
~~~

## ERROR

Acknowledge that a `DATA_ACK` was received but could not be processed.

~~~
+---+-----------+------+---------+
| 5 | MessageID | Type | Payload |
+---+-----------+------+---------+
~~~

  * *MessageID* (4-Byte): The *MessageID* of a previously received `DATA_ACK`.
  * *Type* (2-Byte): Application defined error code, meant for automatic
    processing by machines.  The *Type* defines the format of the *Payload*.
  * *Payload* (*ByteArray*): Error details. Can be arbitrary data.

## ERROR\_UNDEF

Acknowledge that a `DATA_ACK` was received but could not be processed.
The reason for the error is not defined.

~~~
+---+-----------+
| 6 | MessageID |
+---+-----------+
~~~

  * *MessageID* (4-Byte): The *MessageID* of a previously received `DATA_ACK`.


# Security Considerations 

Is is strongly recommended to use a secure transport layer such as TLS.

## Authentication

Authentication is optional and defined by the application.  For example, Client
Certificates on a TLS connection may be used or the application can define
message types to implement authentication.
