# Fedre

Federated receiver network


# Why Fedre?

To receive data crossing the Internet
  - P2P hole-punching: may not work at home or in office
  - Phone as receiver: usually not working as it's behind operator's NAT
  - Single server can't have >65k sockets.

Each user to have a
  - Public receiver point similar to email
  - eg. johndoe@someserver.com, johndoe+1@someserver.com


# Specifications

Federated server list
  - `https://femtost.github.io/fedre/servers.json`

Each server to run
  - `src/server.dart`

Client sample
  - `src/client.html`
