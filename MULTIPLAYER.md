# Multiplayer

**Mode:** online time attack. The host picks a course (campaign or a verified
community course) and a round length. Everyone rides at once with unlimited
instant retries, and the best time when the clock runs out wins.
Riders pass through each other.

## Play today (direct IP / LAN)

1. Host: **ONLINE → HOST**. The game listens on UDP port **24680**.
2. Friends: **ONLINE → JOIN** with the host's address (`192.168.x.x` on the same
   network; over the internet the host forwards UDP 24680 or uses a VPN such as
   Tailscale or ZeroTier).
3. Host picks a course and length, then **START ROUND**.

## How it works

- Each player simulates their own rider locally (instant controls) and sends
  position, heading and speed 20 times a second. Others render ~100 ms behind,
  interpolated, so motion stays smooth through jitter.
- The host owns the lobby, the course, the round clock and the scoreboard.
  Only the host can issue commands; clients can only send their own state and
  finish claims.
- **Every finish must carry its replay.** The host accepts a time only if the
  replay is for this course and its tick count reproduces the time exactly.
  Full server-side re-simulation of the replay is the next step and needs no
  protocol change.
- Community courses travel as their course code, so every player builds the
  identical geometry.
- Names are sanitised, and non-finite or out-of-range states are dropped.

## Next: Steam

`NetSession` only talks to a `MultiplayerPeer`. GodotSteam's
`SteamMultiplayerPeer` implements the same API: lobbies and invites, NAT
traversal and relays, and no port forwarding. The swap is the two lines that
create the peer, plus a Steam lobby browser in `LobbyScreen`. It needs the
Steamworks app ID and testing on two Steam accounts, so it waits for the
store-page step.

## Tests

`Tools/verify.sh` runs `--net-test`: real ENet sockets over localhost, covering
join, version rejection, relayed states, forged and valid finish claims,
standings and community-course rounds.
