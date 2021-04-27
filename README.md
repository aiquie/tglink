TgLink
======
Link via private chat in telegram:
- remote command execution;
- remote terminal;
- network tunnel;

Both sides are completely equal in remote terminal and network tunnel.

Dependency
----------
- [telegram-cli](https://github.com/kenorb-contrib/tg)
- [socat](http://www.dest-unreach.org/socat/)
- [base64io](https://github.com/aiquie/base64io)

Usage
-----
    bash tglink.sh <contact> <if-addr>/<bits>

Example

    alice$ bash tglink.sh Bob 192.168.111.1/30
    bob$ bash tglink.sh Alice 192.168.111.2/30

Remote command execution
------------------------
You can run commands from any client telegram.

Syntax: ``! <command>``

    Bob   : !echo "Hello Alice" | sed "s/Alice/Bob/"
    Alice : Hello Bob

Protection:
* large output stream: max 4092 characters;
* long command execution: max 10 seconds; 
* command without output: set :) or :( smiles;

Remote terminal
---------------
Pseudoterminal device is created in the home directory: ~/.tgpty

Use any application to work with pseudoterminals: screen, cu, minicom, picocom, ...

    bob$ cu -l ~/.tgpty 
    Connected.
    alice$ stty rows 55 columns 180

Network tunnel
--------------
If you are lucky your app might work :)

But mainly due to the high latency, applications do not work very well :(

    alice$ ping 192.168.111.2
    PING 192.168.111.2 (192.168.111.2) 56(84) bytes of data.
    64 bytes from 192.168.111.2: icmp_seq=1 ttl=64 time=269 ms
    64 bytes from 192.168.111.2: icmp_seq=2 ttl=64 time=287 ms

Notes
-----
Sudo is used to create a TUN device.
For this reason, the root password is requested.

It is possible to interrupt and resume the connection from either side
without restarting the second. But at the same time, it is necessary
to send 5 packets in the reconnected side. For example, when using pseudothermal,
press 5 times key Enter.
