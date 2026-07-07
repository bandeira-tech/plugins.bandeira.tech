# B3nd - learn how to think in this new architecture

B3nd is a software application development framework designed to
decouple the deployment of new digital capabilities from the
infrastructure that serves it, allowing more applications and
services and user interfaces to be delivered with less new or
specialized infrastructure nodes.

It's built on top 2 simple types that have large implications

1) all programs are Protocol Interface Nodes = { receive(outputs[]), read(urls[]), observe(urls[]), status() }
2) all data     is  Output = [uri: string, payload: unknown]

This way, a web app on a browser, a mobile app on a phone, a cli on a desktop, and all backend APIs are
enabled to talk to each other using the predictable interface and addressed data primitive.

This enables transparent composition of Protocol Interface Nodes (PINs), for example

a) a web app can be built using a browser localStorage client PIN and then switched to a target
   backend node for deployment
b) a backend node can be built using a local SQLlite database and then switched to a target
   production database for deployment
c) different resources can be routed by their Output.uri to different backends
d) data can be received and processed without full semantic context by different nodes
e) applications can create their own data branch coordinating from a shared starting point
f) domain validations can be run locally and data sent to dumb endpoint

In all these scenarios all the components can be expected to have the same shape, same
interface and contract at communication level, making it easy for cooperation through
composition and routing, separating infrastructure from actual domain code.

The domain is then expressed on the Output uri structure and payload type, as well as in
the domain specific nodes and their classification, validation and handling of data
received.

## Data Availability Layer

B3nd is a universal data availability layer that standardize how every and all components
interact with each other, settling the infrastructure complexity with simple shapes that
are easily composable showing data moving around and being interpreted as needed when needed
and sometimes just stored for later user in any other type of application.

By using b3nd you can simply rig up specialized frontend domain clients that are simple
and can run in browser even via fetch, and connect to many types of servers all serving
the same interface of Protocol Interface Node, and exchanging URLs and Outputs.

The servers and clients are called Protocol Interface Nodes as they provide domain and data
protocols an interface to communicate with network nodes.

The protocol, the semantics of what a PIN Output means, and the expectations on its
operators is what you can build on top of the data availability layer to provide complex
software applications and services, that can be distributed and even decentralized.

A good metaphor is thinking of all PINs wired in a digital board, some gate a cluster of PINs,
interpreting the packets it receives as needed at that point, and some store data and replicate,
then downstream another PIN sends a derived request to an external service.

## Ship a domain, not an installation


## Architecture Affordances for Protocol Designers, Users and Operators

- You can add semantics and/or function to Output URIs, i.e. data://nl/entries/{ts}-update.md, whatsapp://send/1/33/entry.json
- You can add semantics and/or function to Output Payloeads, i.e. JSON, yaml, md, proto, bytes, utxo...
- You can add semantics and/or function to the PIN coordination, i.e. server expects signed uris, client expects resource to be saved and replicated n times

So essentially protocols control what data should look like and what it expects from node operators when they receive them.



## Architecture Affordances for Backend Operators
